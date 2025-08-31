````markdown
# Android `.so` Builder (16KB aligned) — Windows + MSYS2

This repo already includes the build script. **Just run it** to compile your C++ into Android `.so` for `arm64-v8a`, `x86_64`, `x86`, `armeabi-v7a`, with **16KB page alignment**.

---

## Prerequisites (Windows)

- **MSYS2** (use the “MSYS2 UCRT64” terminal)
- **Android NDK** (side-by-side, e.g. `28.0.13004108`)
- Optional: **Perl** (not required for this C++ flow)

Install/update tools in MSYS2:
```bash
pacman -Syu
pacman -S --needed binutils dos2unix
````

---

## Quick Start

From the repo root (where the script is):

```bash
chmod +x build_android_so.sh
dos2unix build_android_so.sh   # only if CRLF issues
bash ./build_android_so.sh
```

**Output:**
`jniLibs/<abi>/libmylib.so`

> 16KB alignment is enforced at link time via `-Wl,-z,max-page-size=16384` (critical for `arm64-v8a`/`x86_64`).

---

## Customize (optional)

Override via environment variables:

```bash
NDK="/c/Android/ndk/28.0.13004108" \
API=29 \
SRC_DIR=./cpp \
OUT_ROOT=app/src/main/jniLibs \
LIB_NAME=mylib \
bash ./build_android_so.sh
```

* `NDK` — path to your NDK (MSYS style `/c/...`)
* `API` — minSdk (e.g. `29`)
* `SRC_DIR` — folder with your `*.cpp` (default `./cpp`)
* `OUT_ROOT` — output root (default `jniLibs`)
* `LIB_NAME` — output name (default `mylib` → `libmylib.so`)

---

## Verify 16KB Alignment

```bash
/c/Android/ndk/28.0.13004108/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-readelf.exe \
  -l jniLibs/arm64-v8a/libmylib.so | grep Align
# Expect: Align 0x4000 (== 16384 bytes == 16KB)
```

---

## Notes

* For Android apps, set `OUT_ROOT=app/src/main/jniLibs` so Gradle picks the libs automatically.
* Remove any old prebuilt `.so` with the same name under `jniLibs` to avoid packaging the wrong file.

```
::contentReference[oaicite:0]{index=0}
```
