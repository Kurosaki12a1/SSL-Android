#!/usr/bin/env bash
# Build .so from C++ sources for Android ABIs with 16KB alignment (2^14)
# Works on Windows via MSYS2.
#
# Usage:
#   bash build_android_so.sh
#   NDK=/c/Android/ndk/28.0.13004108 API=29 LIB_NAME=mylib SRC_DIR=./cpp OUT_ROOT=app/src/main/jniLibs bash build_android_so.sh

set -euo pipefail

# ---- Config (override via env) ----------------------------------------------
NDK_DEFAULT="/D/Software/android-ndk-r28c-windows/android-ndk-r28c"  # MSYS path to your NDK
API_DEFAULT=29                               # minSdk
LIB_NAME_DEFAULT="mylib"                     # -> libmylib.so
SRC_DIR_DEFAULT="../cpp"                      # where your *.cpp live
OUT_ROOT_DEFAULT="jniLibs"                   # <-- changed from 'out' to 'jniLibs'

NDK="${NDK:-$NDK_DEFAULT}"
API="${API:-$API_DEFAULT}"
LIB_NAME="${LIB_NAME:-$LIB_NAME_DEFAULT}"
SRC_DIR="${SRC_DIR:-$SRC_DIR_DEFAULT}"
OUT_ROOT="${OUT_ROOT:-$OUT_ROOT_DEFAULT}"

ABIS=("arm64-v8a" "x86" "x86_64" "armeabi-v7a")

# ---- Helpers ----------------------------------------------------------------
triple_for_abi() {
  case "$1" in
    arm64-v8a)    echo "aarch64-linux-android" ;;
    x86_64)       echo "x86_64-linux-android" ;;
    x86)          echo "i686-linux-android" ;;
    armeabi-v7a)  echo "armv7a-linux-androideabi" ;;
    *) echo "Unsupported ABI: $1" >&2; return 1 ;;
  esac
}

extra_cflags_for_abi() {
  case "$1" in
    armeabi-v7a)  echo "-mthumb" ;;
    *)            echo "" ;;
  esac
}

# ---- Checks -----------------------------------------------------------------
TOOLBIN="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin"
[[ -d "$TOOLBIN" ]] || { echo "NDK toolchain not found: $TOOLBIN" >&2; exit 1; }

shopt -s nullglob
CPP_FILES=("$SRC_DIR"/*.cpp)
(( ${#CPP_FILES[@]} > 0 )) || { echo "No *.cpp in: $SRC_DIR" >&2; exit 1; }

LLVM_READELF="$TOOLBIN/llvm-readelf.exe"
[[ -x "$LLVM_READELF" ]] || { echo "llvm-readelf not found: $LLVM_READELF" >&2; exit 1; }

echo "NDK     : $NDK"
echo "API     : $API"
echo "LIB     : lib${LIB_NAME}.so"
echo "SRC_DIR : $SRC_DIR  (#files=${#CPP_FILES[@]})"
echo "OUT_ROOT: $OUT_ROOT"
echo "ABIs    : ${ABIS[*]}"
echo

# ---- Build ------------------------------------------------------------------
for ABI in "${ABIS[@]}"; do
  TRIPLE="$(triple_for_abi "$ABI")"
  CXX="$TOOLBIN/${TRIPLE}${API}-clang++"
  [[ -x "$CXX" ]] || CXX="${CXX}.cmd"
  [[ -x "$CXX" ]] || { echo "Compiler not found: $CXX" >&2; exit 1; }

  OUT_DIR="$OUT_ROOT/$ABI"
  mkdir -p "$OUT_DIR"

  echo "==> [$ABI] Compile"
  for src in "${CPP_FILES[@]}"; do
    base="$(basename "${src%.cpp}")"
    "$CXX" -fPIC -O2 -DANDROID $(extra_cflags_for_abi "$ABI") \
      -c "$src" -o "$OUT_DIR/$base.o"
  done

  echo "==> [$ABI] Link -> $OUT_DIR/lib${LIB_NAME}.so (16KB alignment)"
  "$CXX" -shared -o "$OUT_DIR/lib${LIB_NAME}.so" "$OUT_DIR"/*.o \
    -Wl,-z,max-page-size=16384 -Wl,-soname,lib${LIB_NAME}.so

  rm -f "$OUT_DIR"/*.o
  ls -lh "$OUT_DIR/lib${LIB_NAME}.so"

  echo "==> [$ABI] Verify (expect Align 0x4000)"
  if "$LLVM_READELF" -l "$OUT_DIR/lib${LIB_NAME}.so" | grep -q "Align 0x4000"; then
    echo "OK: 16KB alignment"
  else
    echo "WARN: Not 16KB; inspect:"
    echo "      $LLVM_READELF -l \"$OUT_DIR/lib${LIB_NAME}.so\" | sed -n '1,120p'"
  fi
  echo
done

echo "Done. Output: $OUT_ROOT/<abi>/lib${LIB_NAME}.so"