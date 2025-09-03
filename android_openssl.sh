#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ANDROID_TARGET_API=29 ANDROID_TARGET_ABI=arm64-v8a OPENSSL_VERSION=3.3.1 ANDROID_NDK_VERSION=r28 \
#   bash build_openssl_android.sh
#
# NOTE:
# - Lỗi undefined symbol SSL_library_init ... là do APP gọi API cũ.
#   OpenSSL 1.1+/3.x KHÔNG có các symbol này. Sửa app theo hướng dẫn bên dưới.

WORK_PATH=$(cd "$(dirname "$0")"; pwd)

ANDROID_TARGET_API=${ANDROID_TARGET_API:-29}
ANDROID_TARGET_ABI=${ANDROID_TARGET_ABI:-arm64-v8a}
OPENSSL_VERSION=${OPENSSL_VERSION:-3.3.1}
ANDROID_NDK_VERSION=${ANDROID_NDK_VERSION:-r28}
ANDROID_NDK_PATH=${ANDROID_NDK_PATH:-"${WORK_PATH}/android-ndk-${ANDROID_NDK_VERSION}"}
OPENSSL_PATH=${OPENSSL_PATH:-"${WORK_PATH}/openssl-${OPENSSL_VERSION}"}
OUTPUT_PATH=${OUTPUT_PATH:-"${WORK_PATH}/openssl_${OPENSSL_VERSION}_${ANDROID_TARGET_ABI}"}

# Optional: bật deprecated headers (chỉ thêm khai báo, KHÔNG tạo lại symbol cũ)
ENABLE_DEPRECATED=${ENABLE_DEPRECATED:-0}  # 0|1

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "Build on macOS..."
  PLATFORM="darwin"
  nproc() { sysctl -n hw.logicalcpu; }
else
  echo "Build on Linux..."
  PLATFORM="linux"
fi

triple_for_abi() {
  case "$1" in
    armeabi-v7a)  echo "armv7a-linux-androideabi" ;;
    arm64-v8a)    echo "aarch64-linux-android" ;;
    x86)          echo "i686-linux-android" ;;
    x86_64)       echo "x86_64-linux-android" ;;
    riscv64)      echo "riscv64-linux-android" ;;
    *) echo "Unsupported ABI: $1" >&2; exit 1 ;;
  esac
}

android_target_for_abi() {
  case "$1" in
    armeabi-v7a)  echo "android-arm" ;;
    arm64-v8a)    echo "android-arm64" ;;
    x86)          echo "android-x86" ;;
    x86_64)       echo "android-x86_64" ;;
    riscv64)      echo "android-riscv64" ;;
    *) echo "Unsupported ABI: $1" >&2; exit 1 ;;
  esac
}

build() {
  rm -rf "${OUTPUT_PATH}"
  mkdir -p "${OUTPUT_PATH}"

  cd "${OPENSSL_PATH}"

  export ANDROID_NDK_ROOT="${ANDROID_NDK_PATH}"
  export PATH="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin:$PATH"

  # 16KB page alignment cho ELF
  export CFLAGS="-fPIC -Os -O2"
  export CXXFLAGS="-fPIC -Os -O2"
  export CPPFLAGS="-DANDROID -fPIC -Os -O2"
  export LDFLAGS="-Wl,-z,max-page-size=16384"

  ANDR_TARGET="$(android_target_for_abi "${ANDROID_TARGET_ABI}")"

  CONFIG_OPTS=( "${ANDR_TARGET}" "-D__ANDROID_API__=${ANDROID_TARGET_API}" "shared" "--prefix=${OUTPUT_PATH}" "--libdir=lib" )
  if [[ "${ENABLE_DEPRECATED}" == "1" ]]; then
    # chỉ bật khai báo deprecated trong headers (không hồi sinh SSL_library_init)
    CONFIG_OPTS+=( "enable-deprecated" )
  fi

  echo "Configure: ${CONFIG_OPTS[*]}"
  ./Configure "${CONFIG_OPTS[@]}"

  make -j"$(nproc)"
  make install_sw

  echo
  echo "==> Output in: ${OUTPUT_PATH}"
  echo "   include/openssl/*.h"
  echo "   lib/libssl.so, lib/libcrypto.so"
}

clean_pack() {
  # Dọn phần không cần để nhúng vào dự án
  if [[ -d "${OUTPUT_PATH}" ]]; then
    rm -rf "${OUTPUT_PATH}/bin" \
           "${OUTPUT_PATH}/share" \
           "${OUTPUT_PATH}/ssl" \
           "${OUTPUT_PATH}/lib/cmake" \
           "${OUTPUT_PATH}/lib/engines-3" \
           "${OUTPUT_PATH}/lib/ossl-modules" \
           "${OUTPUT_PATH}/lib/pkgconfig" || true
  fi
}

post_check() {
  # Dump symbol để bạn kiểm chứng nhanh (không cần, nhưng hữu ích)
  local TRIPLE="$(triple_for_abi "${ANDROID_TARGET_ABI}")"
  local TOOLBIN="${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin"
  local READELF="${TOOLBIN}/llvm-readelf"
  local NM="${TOOLBIN}/llvm-nm"

  echo
  echo "==> Check page alignment (expect Align 0x4000)"
  "${READELF}" -l "${OUTPUT_PATH}/lib/libssl.so"   | grep -m1 -E "Align"
  "${READELF}" -l "${OUTPUT_PATH}/lib/libcrypto.so"| grep -m1 -E "Align"

  echo
  echo "==> Grep legacy symbols (nếu thấy -> bạn đang build headers/lib cũ):"
  "${NM}" -D "${OUTPUT_PATH}/lib/libssl.so"    | grep -E "SSL_library_init|SSL_load_error_strings|SSL_get_peer_certificate" || true
  "${NM}" -D "${OUTPUT_PATH}/lib/libcrypto.so" | grep -E "OpenSSL_add_all_algorithms" || true
}

build
clean_pack
post_check

cat <<'MSG'

========================================================
CÁCH LINK TRONG APP (để KHÔNG lỗi undefined symbol):
1) Dùng đúng headers vừa build:
   -I <path>/openssl_${OPENSSL_VERSION}_${ANDROID_TARGET_ABI}/include
   -L <path>/openssl_${OPENSSL_VERSION}_${ANDROID_TARGET_ABI}/lib
   -lssl -lcrypto -lz -ldl (và -llog -lc++_shared)

2) Ép API mới ở bước COMPILE của APP:
   -DOPENSSL_API_COMPAT=0x10100000L    # cho 1.1+
   # hoặc
   -DOPENSSL_API_COMPAT=0x30000000L    # cho 3.x

   (Tuỳ chọn để bắt lỗi sớm:)
   -DOPENSSL_NO_DEPRECATED=1

3) Sửa code APP dùng API mới:
   - Thay init:
       #include <openssl/ssl.h>
       #include <openssl/err.h>
       #if OPENSSL_VERSION_NUMBER < 0x10100000L
         SSL_library_init();
         SSL_load_error_strings();
         OpenSSL_add_all_algorithms();
       #else
         OPENSSL_init_ssl(0, nullptr);
         // optional: OPENSSL_init_crypto(0, nullptr);
       #endif

   - Thay lấy cert peer (OpenSSL 3):
       X509* cert = SSL_get1_peer_certificate(ssl);
       // nhớ X509_free(cert);

4) Thứ tự link trong APP:
   -lssl -lcrypto -lz -ldl -llog -lc++_shared   (lưu ý: -lssl TRƯỚC -lcrypto)

5) Copy runtime .so vào app/src/main/jniLibs/<abi>/:
   libssl.so, libcrypto.so, libc++_shared.so (và các .so khác của bạn).

========================================================
MSG