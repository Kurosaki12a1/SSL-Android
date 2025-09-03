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
    export alias nproc="sysctl -n hw.logicalcpu"
else
    echo "Build on Linux..."
    PLATFORM="linux"
fi

function build(){
    rm -rf ${OUTPUT_PATH}
    mkdir ${OUTPUT_PATH}

    cd ${OPENSSL_PATH}

    export ANDROID_NDK_ROOT=${ANDROID_NDK_PATH}
    export PATH=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin:$PATH

    # Flags (giữ nguyên + 16KB)
    export CFLAGS="-fPIC -Os -O2"
    export CXXFLAGS="-fPIC -Os -O2"
    export CPPFLAGS="-DANDROID -fPIC -Os -O2"
    export LDFLAGS="-Wl,-z,max-page-size=16384"

    # Tùy chọn Configure
    CONFIG_OPTS="shared --prefix=${OUTPUT_PATH}"
    if [ "${ENABLE_DEPRECATED}" = "1" ]; then
        # chỉ thêm khai báo API cũ trong headers (KHÔNG tạo lại symbol cũ)
        CONFIG_OPTS="enable-deprecated ${CONFIG_OPTS}"
    fi

    # Chọn target theo ABI (giữ y nguyên tên biến/flow)
    if   [ "${ANDROID_TARGET_ABI}" == "armeabi-v7a" ]; then
        ./Configure android-arm     -D__ANDROID_API__=${ANDROID_TARGET_API} ${CONFIG_OPTS}
    elif [ "${ANDROID_TARGET_ABI}" == "arm64-v8a"   ]; then
        ./Configure android-arm64   -D__ANDROID_API__=${ANDROID_TARGET_API} ${CONFIG_OPTS}
    elif [ "${ANDROID_TARGET_ABI}" == "x86"         ]; then
        ./Configure android-x86     -D__ANDROID_API__=${ANDROID_TARGET_API} ${CONFIG_OPTS}
    elif [ "${ANDROID_TARGET_ABI}" == "x86_64"      ]; then
        ./Configure android-x86_64  -D__ANDROID_API__=${ANDROID_TARGET_API} ${CONFIG_OPTS}
    elif [ "${ANDROID_TARGET_ABI}" == "riscv64"     ]; then
        ./Configure android-riscv64 -D__ANDROID_API__=${ANDROID_TARGET_API} ${CONFIG_OPTS}
    else
        echo "Unsupported target ABI: ${ANDROID_TARGET_ABI}"
        exit 1
    fi

    make -j$(nproc)
    make install

    echo "Build completed! Check ${OUTPUT_PATH}"

    # --- Kiểm tra nhanh: page-size & symbol cũ ---
    TOOLBIN=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${PLATFORM}-x86_64/bin
    if [ -x "${TOOLBIN}/llvm-readelf" ]; then
      echo "Check page alignment (expect Align 0x4000):"
      ${TOOLBIN}/llvm-readelf -l ${OUTPUT_PATH}/lib/libssl.so   | grep -m1 Align || true
      ${TOOLBIN}/llvm-readelf -l ${OUTPUT_PATH}/lib/libcrypto.so| grep -m1 Align || true
    fi
    if [ -x "${TOOLBIN}/llvm-nm" ]; then
      echo "Check legacy symbols (nếu thấy => bạn build version rất cũ):"
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
echo "NOTE: Nếu app còn gọi SSL_library_init/SSL_load_error_strings/SSL_get_peer_certificate:"
echo " - Đây là API 1.0.x. OpenSSL ${OPENSSL_VERSION} (>=1.1/3.x) KHÔNG có symbol này."
echo " - Sửa app sang API mới hoặc biên dịch với -DOPENSSL_API_COMPAT=0x10100000L (hay 0x30000000L) rồi đổi hàm."