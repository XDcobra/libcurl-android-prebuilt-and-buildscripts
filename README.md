# libcurl-build (prebuilt + build scripts)

This repository folder contains prebuilt `libcurl` binaries for Android ABIs and reproducible build scripts to (re)build `libcurl` yourself on Windows and Linux.

# What this folder includes
- `install/<abi>/` — prebuilt outputs for each ABI (shared libs + headers)
    - Prebuilt (arm64-v8a): [arm64-v8a](install/arm64-v8a/)
    - Prebuilt (armeabi-v7a): [armeabi-v7a](install/armeabi-v7a/)
    - Prebuilt (x86_64): [x86_64](install/x86_64/)
- `build_all.ps1` — PowerShell script to build libcurl for ABIs on Windows (uses CMake + Android NDK)
- `build_all.sh` — Bash script to build libcurl for ABIs on Linux/macOS/WSL
- `openssl/` — helper folder with OpenSSL prebuilds and build helpers (used as TLS backend)

# Quick summary
- Purpose: provide ready-to-use `libcurl.so` per ABI and a simple way to rebuild them (reproducible builds)
- Supported ABIs: `arm64-v8a`, `armeabi-v7a`, `x86_64` (see `install/`)

# Cloning the repository

There are two common ways to clone this repository depending on whether you want to build OpenSSL yourself or use the prebuilt OpenSSL provided as a submodule:

- If you plan to build OpenSSL yourself (you will build the `openssl` folder locally), do a normal clone:

```powershell
git clone https://github.com/XDcobra/libcurl-android-prebuilt-and-buildscripts
```

Then build as described below.

- If you want to use the prebuilt OpenSSL libraries included as a submodule, clone with submodules so the `openssl` content is fetched automatically:

```powershell
git clone --recurse-submodules https://github.com/XDcobra/libcurl-android-prebuilt-and-buildscripts
```

Or, if you already cloned without `--recurse-submodules`, initialize submodules afterward:

```powershell
git submodule update --init --recursive
```

Note: The build scripts expect OpenSSL files to be present under `openssl/install/<abi>/`. If you don't initialize the submodule, the `openssl/` content will be missing and the build will fail until you fetch it.

# Quick Start
## Windows (PowerShell)
```powershell
# set NDK path if not already
$env:ANDROID_NDK_HOME = 'C:\Users\<you>\AppData\Local\Android\Sdk\ndk\<version>'
# optionally set OpenSSL install base if you built OpenSSL into a custom location. Otherwise it defaults to /openssl/install
$env:OPENSSL_ANDROID_INSTALL = 'C:\path\to\openssl\install'

# run the build (requires prerequisites below)
powershell -NoProfile -ExecutionPolicy Bypass -File build_all.ps1
```

## Linux / macOS / WSL
```bash
export ANDROID_NDK_HOME=/path/to/android-ndk
export OPENSSL_ANDROID_INSTALL=/path/to/openssl/install
bash ./build_all.sh
```

# What the scripts do
- Configure CMake with the Android toolchain file and point `OPENSSL_ROOT_DIR` / libs to per-ABI OpenSSL installs.
- Build with Ninja.
- Install `libcurl.so` into `build/<abi>/install/lib/` then copy the resulting `libcurl.so` (and `libssl.so`/`libcrypto.so` if using shared OpenSSL) into `../app/src/main/jniLibs/<abi>/` so your Android project can pick them up.

# Prerequisites

## Windows
- Android NDK (side-by-side or bundle). Set `ANDROID_NDK_HOME` to the NDK root. Install via Android Studio or check out [here](https://developer.android.com/studio/projects/install-ndk)
- [CMake](https://cmake.org/download/) (>= 3.15) and Ninja: add `C:\Program Files\CMake\bin` and Ninja to PATH.
```
choco install ninja
```
- Visual Studio (for [general build tools](https://visualstudio.microsoft.com/de/downloads/?q=build+tools)) — the build scripts use CMake/Ninja and the NDK clang cross‑toolchain.
- (Optional) MSYS2 / Perl / Make if you plan to build OpenSSL with the included Windows helpers.
```
choco install msys2
```
Install/update in an MSYS2 shell:
```bash
pacman -Syu
# restart MSYS2 if it asks you to, then:
pacman -S --needed base-devel make perl git
````

## Linux / WSL / macOS
- Android NDK. Set `ANDROID_NDK_HOME`.
- CMake, Ninja, clang, make, perl (for OpenSSL builds).

## Environment variables used by the scripts
- `ANDROID_NDK_HOME` — path to the Android NDK (required)
- `OPENSSL_ANDROID_INSTALL` or `OPENSSL_ROOT_DIR` — path to the OpenSSL per-ABI install base (defaults to `openssl/install/` under this folder)
- `CURL_VERSION` (optional) — override curl version the script downloads

## Notes on OpenSSL
- The build scripts expect either shared OpenSSL libraries (`libssl.so`/`libcrypto.so`) or static libs (`libssl.a`/`libcrypto.a`) present under `openssl/install/<abi>/lib` and headers under `openssl/install/<abi>/include`.
- This repository includes already prebuilt openssl libraries for all supported ABIs. In case you want to build your own openssl libraries, feel free to use my repo on how to build them easily [openssl-android-prebuilt-and-buildscripts](https://github.com/XDcobra/openssl-android-prebuilt-and-buildscripts)

# Support / Troubleshooting
- If CMake fails to find OpenSSL, make sure `OPENSSL_ROOT_DIR` and the `include`/`lib` paths exist for the ABI you're building.
- On Windows prefer running the build in a Developer PowerShell with NDK/Toolchain in PATH, or use WSL/Git-Bash for the OpenSSL build steps.

# License
- This folder contains OpenSSL libraries which are licensed under the OpenSSL license. Keep `LICENSE`/`LICENSE.txt` with the distributed artifacts.

