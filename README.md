# Building OpenSSL `.so` Libraries for Android (Windows 11 + MSYS2 + NDK r28)

This guide shows how to build **libcrypto.so** and **libssl.so** from OpenSSL for Android ABIs (`arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86`).  

---

## 1. Prerequisites

- **Windows**
- [MSYS2](https://www.msys2.org/) (use **MSYS2 UCRT64** or **MSYS2 MinGW64** shell)
- [Android NDK r28](https://developer.android.com/ndk/downloads)  
  Extract to a folder, e.g. `D:\Android\android-ndk-r28c`
- [OpenSSL source](https://www.openssl.org/source/)  
  Extract to a folder, e.g. `C:\src\openssl-3.5.2`

Inside **MSYS2**, install build tools:
```bash
pacman -S --needed base-devel perl nasm unzip
```

---

## 2. Environment Setup

In MSYS2 shell:
```bash
# Change this path to your NDK location
export ANDROID_NDK_ROOT=/d/Android/android-ndk-r28c
export PATH=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/windows-x86_64/bin:$PATH

# Go to your OpenSSL source folder
cd /c/src/openssl-3.5.2
```

Verify toolchain: (minSdk = 29)
```bash
clang --version
aarch64-linux-android29-clang --version
```

---

## 3. Build Instructions (minSdk = 29)

> Run `make distclean` before each new build.
> Note: You can change "29" to minSdk of your Android app.

### arm64-v8a
```bash
make distclean 2>/dev/null || true
export CC="aarch64-linux-android29-clang" AR="llvm-ar" RANLIB="llvm-ranlib" NM="llvm-nm" LD="ld.lld"

./Configure android-arm64 -D__ANDROID_API__=29 shared   --prefix=$PWD/out/android/arm64 --openssldir=$PWD/out/android/arm64/ssl

make -j8
make install_sw
```

### armeabi-v7a (optional, 32-bit ARM)
```bash
make distclean
export CC="armv7a-linux-androideabi29-clang" AR="llvm-ar" RANLIB="llvm-ranlib" NM="llvm-nm" LD="ld.lld"

./Configure android-arm -D__ANDROID_API__=29 shared   --prefix=$PWD/out/android/armeabi-v7a --openssldir=$PWD/out/android/armeabi-v7a/ssl

make -j8
make install_sw
```

### x86_64
```bash
make distclean
export CC="x86_64-linux-android29-clang" AR="llvm-ar" RANLIB="llvm-ranlib" NM="llvm-nm" LD="ld.lld"

./Configure android-x86_64 -D__ANDROID_API__=29 shared   --prefix=$PWD/out/android/x86_64 --openssldir=$PWD/out/android/x86_64/ssl

make -j8
make install_sw
```

### x86 32-bit
```bash
make distclean
export CC="i686-linux-android29-clang" AR="llvm-ar" RANLIB="llvm-ranlib" NM="llvm-nm" LD="ld.lld"

./Configure android-x86 -D__ANDROID_API__=29 shared   --prefix=$PWD/out/android/x86 --openssldir=$PWD/out/android/x86/ssl

make -j8
make install_sw
```

---

## 4. Output

Each build generates:
```
out/android/<abi>/lib/libcrypto.so
out/android/<abi>/lib/libssl.so
```

Copy them into your Android project:
```
app/src/main/jniLibs/arm64-v8a/
app/src/main/jniLibs/armeabi-v7a/
app/src/main/jniLibs/x86_64/
```

---

## 5. Gradle Configuration

```gradle
android {
  defaultConfig {
    minSdk 29
    targetSdk 35
    ndk {
      abiFilters "arm64-v8a", "x86_64" // add "armeabi-v7a" if needed
    }
  }
}
```

---

✅ Done — OpenSSL `.so` libraries are now ready for Android integration.  
