# SSL-Android-16kb-alignment

SSL-Android is a project to build OpenSSL libraries for Android platforms. It supports various Android architectures such as `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`, and `riscv64`. The project is designed to be customizable and can be built for different API levels and target ABIs.

### Features
- Build OpenSSL libraries (`.so`) for Android.
- Supports **16KB alignment** for Android shared libraries.
- Easily customizable via GitHub Actions.
- Built for various target ABIs including `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`, and `riscv64`.

### Requirements
- **Android NDK**: Version r28c (can change in github action)
- **Android Build Tools**: Minimum version 35.0.0-rc3 is required for `zipalign`.
- **GitHub Actions**: For automating the build and release process.

### How to Use

1. **Fork the Repository**:
   - Fork this repository to your own GitHub account to start using it.

2. **Modify the `build.yml` for Minimum SDK**:
   - After forking, navigate to the `.github/workflows/build.yml` file.
   - Update the **minimum SDK** version in the `ANDROID_TARGET_API` section as required.
     ```yaml
     android_target_api: 29  # Change this value to your desired SDK version
     ```

3. **Build the Project**:
   - Once the fork is completed and the SDK version is updated, GitHub Actions will automatically start the build process for your project.
   - The project will generate OpenSSL `.so` libraries for Android with support for the target API level and architecture you configured.

4. **16KB Alignment**:
   - The build process has been configured to support **16KB alignment** by passing the `-Wl,-z,max-page-size=16384` linker flag during the compilation process.

5. **Check Build Results**:
   - After the build completes, you can check the output for your built libraries in the `openssl_${OPENSSL_VERSION}_${ANDROID_TARGET_ABI}` directory.
   - You can also find the generated `.tar.gz` files containing the libraries for each architecture.

6. **Upload Release**:
   - If you want to generate a release, the `build_new.yml` script will automatically package the `.so` files and upload them to your GitHub releases when the build completes successfully.

### GitHub Actions

This repository uses **GitHub Actions** for continuous integration. It automates the process of downloading the Android NDK, building OpenSSL for Android, and uploading the generated libraries as a release.

- **Workflow Trigger**: The workflow is triggered on pushes to the `main` branch or manually via the GitHub interface using `workflow_dispatch`.
- **Steps**: 
  1. Checkout the repository.
  2. Download the Android NDK.
  3. Build OpenSSL with the appropriate configuration.
  4. Generate a release tag and upload the libraries.

