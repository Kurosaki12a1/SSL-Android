#!/bin/bash -e

WORK_PATH=$(cd "$(dirname "$0")";pwd)

ANDROID_TARGET_API=$1
ANDROID_TARGET_ABI=$2
OPENSSL_VERSION=$3
ANDROID_NDK_VERSION=$4
ANDROID_NDK_PATH=${WORK_PATH}/android-ndk-${ANDROID_NDK_VERSION}
OPENSSL_PATH=${WORK_PATH}/openssl-${OPENSSL_VERSION}
OUTPUT_PATH=${WORK_PATH}/openssl_${OPENSSL_VERSION}_${ANDROID_TARGET_ABI}

# OPTIONAL: bật header deprecated (0/1). Mặc định 0.
ENABLE_DEPRECATED=${ENABLE_DEPRECATED:-0}

if [ "$(uname -s)" == "Darwin" ]; then
    echo "Build on macOS..."
    PLATFORM="darwin"
    nproc() { sysctl -n hw.logicalcpu; }
else
    echo "Build on Linux..."
    PLATFORM="linux"
fi

# Map target cho 1.0.x và 1.1+/3.x
_tgt_10() {
  case "$1" in
    armeabi-v7a)  echo "android-arm" ;;
    arm64-v8a)    echo "android64-aarch64" ;;
    x86)          echo "android-x86" ;;
    x86_64)       echo "android64" ;;
    riscv64)      echo "android-riscv64" ;;
    *) echo "Unsupported ABI: $1"; exit 1 ;;
  esac
}
_tgt_11() {
  case "$1" in
    armeabi-v7a)  echo "android-arm" ;;
    arm64-v8a)    echo "android-arm64" ;;
    x86)          echo "android-x86" ;;
    x86_64)       echo "android-x86_64" ;;
    riscv64)      echo "android-riscv64" ;;
    *) echo "Unsupported ABI: $1"; exit 1 ;;
  esac
}
_triple() {
  case "$1" in
    armeabi-v7a)  echo "armv7a-linux-androideabi" ;;
    arm64-v8a)    echo "aarch64-linux-android" ;;
    x86)          echo "i686-linux-android" ;;
    x86_64)       echo "x86_64-linux-android" ;;
    riscv64)      echo "riscv64-linux-android" ;;
    *) echo "Unsupported ABI: $1"; exit 1 ;;
  esac
}

function build(){
    rm -rf ${OUTPUT_PATH}
    mkdir -p ${OUTPUT_PATH}

    cd ${OPENSSL_PATH}

    export ANDROID_NDK_ROOT=${ANDROID_NDK_PATH}
    export PATH=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin:$PATH

    # Flags (giữ nguyên + 16KB)
    export CFLAGS="-fPIC -Os -O2"
    export CXXFLAGS="-fPIC -Os -O2"
    export CPPFLAGS="-DANDROID -fPIC -Os -O2"
    export LDFLAGS="-Wl,-z,max-page-size=16384"

    # Tool clang theo ABI+API (để 1.0.x cũng dùng được)
    TRIPLE=$(_triple "${ANDROID_TARGET_ABI}")
    export CC="${TRIPLE}${ANDROID_TARGET_API}-clang"
    export AR="llvm-ar"
    export RANLIB="llvm-ranlib"
    export NM="llvm-nm"

    CONFIG_OPTS="shared --prefix=${OUTPUT_PATH}"
    if [ "${ENABLE_DEPRECATED}" = "1" ]; then
        CONFIG_OPTS="enable-deprecated ${CONFIG_OPTS}"
    fi

    echo "OPENSSL_VERSION=${OPENSSL_VERSION}"

    # --- NHÁNH 1.0.x (ví dụ 1.0.2o) ---
    if [[ "${OPENSSL_VERSION}" == 1.0.* || "${OPENSSL_VERSION}" == 1.0.2* ]]; then
        echo "==> Legacy build (OpenSSL 1.0.x)"
        TARGET=$(_tgt_10 "${ANDROID_TARGET_ABI}")

        # 1.0.x dùng perl Configure + make depend (bắt buộc)
        # Nếu gặp lỗi asm với clang, thêm 'no-asm' vào cuối dòng Configure.
        perl ./Configure ${TARGET} -D__ANDROID_API__=${ANDROID_TARGET_API} shared no-engine no-hw no-dso ${CONFIG_OPTS}
        make clean || true
        make depend
        make -j"$(nproc)"
        make install_sw

    else
        # --- NHÁNH 1.1.0+ / 3.x ---
        echo "==> Modern build (OpenSSL >= 1.1)"
        TARGET=$(_tgt_11 "${ANDROID_TARGET_ABI}")
        ./Configure ${TARGET} -D__ANDROID_API__=${ANDROID_TARGET_API} ${CONFIG_OPTS}
        make -j"$(nproc)"
        make install_sw
    fi

    echo "Build completed! Check ${OUTPUT_PATH}"

    # --- Kiểm tra nhanh: page-size & legacy symbols ---
    TOOLBIN=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin
    if [ -x "${TOOLBIN}/llvm-readelf" ]; then
      echo "Check page alignment (expect Align 0x4000):"
      ${TOOLBIN}/llvm-readelf -l ${OUTPUT_PATH}/lib/libssl.so   | grep -m1 Align || true
      ${TOOLBIN}/llvm-readelf -l ${OUTPUT_PATH}/lib/libcrypto.so| grep -m1 Align || true
    fi
    if [ -x "${TOOLBIN}/llvm-nm" ]; then
      echo "Check legacy symbols in libssl.so:"
      ${TOOLBIN}/llvm-nm -D ${OUTPUT_PATH}/lib/libssl.so | grep -E "SSL_library_init|SSL_load_error_strings|SSL_get_peer_certificate" || true
    fi
}

function clean(){
    if [ -d ${OUTPUT_PATH} ]; then
        rm -rf ${OUTPUT_PATH}/bin
        rm -rf ${OUTPUT_PATH}/share
        rm -rf ${OUTPUT_PATH}/ssl
        rm -rf ${OUTPUT_PATH}/lib/cmake
        rm -rf ${OUTPUT_PATH}/lib/engines-3
        rm -rf ${OUTPUT_PATH}/lib/ossl-modules
        rm -rf ${OUTPUT_PATH}/lib/pkgconfig
    fi
}

build
clean

echo "Done."
echo "NOTE:"
echo "- 1.0.x sẽ có các symbol cũ (SSL_library_init, OpenSSL_add_all_algorithms...)."
echo "- 1.1+/3.x KHÔNG còn các symbol này -> sửa app dùng OPENSSL_init_ssl(), v.v."