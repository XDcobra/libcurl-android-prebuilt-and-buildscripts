# libcurl-build (prebuilt + build scripts)

This repository folder contains prebuilt `libcurl` binaries for Android ABIs and reproducible build scripts to (re)build `libcurl` yourself on Windows and Linux.

# What this folder includes
- `install/<BuildType>-<stripped|unstripped>/<abi>/` — prebuilt outputs organized by build type and strip state (shared libs + headers)
    - Examples (per-variant paths):
        - [`install/RelWithDebInfo-unstripped/arm64-v8a/`](/install/RelWithDebInfo-unstripped/)
        - [`install/RelWithDebInfo-stripped/arm64-v8a/`](/install/RelWithDebInfo-stripped/)
        - [`install/Release-unstripped/arm64-v8a/`](/install/Release-unstripped/)
        - [`install/Release-stripped/arm64-v8a/`](/install/Release-stripped/)
        - [`install/Debug-unstripped/arm64-v8a/`](/install/Debug-unstripped/)
        - [`install/Debug-stripped/arm64-v8a/`](/install/Debug-stripped/)
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

Note: The build scripts expect OpenSSL files to be present under a per-build install tree such as `openssl/install/<BuildType>-<stripped|unstripped>/<abi>/`. You can either set `OPENSSL_ANDROID_INSTALL` to a BuildType-specific path (for example `openssl/install/RelWithDebInfo-unstripped`) or copy the ABI folders into `openssl/install/<abi>/` as needed.

# Quick Start
## Windows (PowerShell)
```powershell
# set NDK path if not already
$env:ANDROID_NDK_HOME = 'C:\Users\<you>\AppData\Local\Android\Sdk\ndk\<version>'
# optionally set OpenSSL install base if you built OpenSSL into a custom location. Otherwise it defaults to /openssl/install
$env:OPENSSL_ANDROID_INSTALL = 'C:\path\to\openssl\install'

# Build Release, strip artifacts for arm64-v8a only
powershell -NoProfile -ExecutionPolicy Bypass -File build_all.ps1 -BuildType Release -Strip -ABIs @('arm64-v8a')
```

## Linux / macOS / WSL
```bash
export ANDROID_NDK_HOME=/path/to/android-ndk
export OPENSSL_ANDROID_INSTALL=/path/to/openssl/install
# Build Release, prefer stripped OpenSSL installs and build (all ABIs by default)
export BUILD_TYPE=Release
export STRIP=1
bash ./build_all.sh
```

Note: both scripts build all supported ABIs by default. To target only `arm64-v8a`:
- with PowerShell use the `-ABIs` parameter: `-ABIs @('arm64-v8a')` (example shown above).
- with the Bash script edit the `ABIS=(...)` array near the top of `build_all.sh` and keep only `arm64-v8a` (or set up a wrapper that exports a custom `ABIS` value before invoking the script).
You can also control the build type and whether the Bash script prefers `stripped` installs via environment variables:

```bash
# choose build type (RelWithDebInfo, Release, Debug)
export BUILD_TYPE=RelWithDebInfo
# prefer stripped OpenSSL installs (set to 1 to prefer `-stripped` folders)
export STRIP=0
bash ./build_all.sh
```

If `OPENSSL_ANDROID_INSTALL` is not supplied the script will look for per-build OpenSSL installs under `openssl/install/<BUILD_TYPE>-<stripped|unstripped>/<abi>/` and fall back to the legacy `openssl/install/<abi>/` layout.

# BuildType and Strip flags

`build_all.ps1` now supports two additional options to control build type and whether installed artifacts are stripped:

- `-BuildType` : one of `RelWithDebInfo`, `Release`, `Debug`. Default is `Release`. The value is passed to CMake as `-DCMAKE_BUILD_TYPE`.
- `-Strip` : switch. When specified, the script will attempt to strip installed shared libraries and binaries using the NDK's `llvm-strip` (or `strip`) tool.

Install layout
- Outputs are stored under `install/<BuildType>-<stripLabel>/<abi>/...` where `stripLabel` is `stripped` when `-Strip` is used and `unstripped` otherwise.

Examples
```powershell
# RelWithDebInfo and stripped outputs
powershell -NoProfile -ExecutionPolicy Bypass -File build_all.ps1 -NDK 'C:\path\to\android-ndk' -BuildType RelWithDebInfo -Strip

# Debug unstripped
powershell -NoProfile -ExecutionPolicy Bypass -File build_all.ps1 -NDK 'C:\path\to\android-ndk' -BuildType Debug
```

See [build_all.ps1](build_all.ps1) for details.

### Only strip existing unstripped installs

If you already have unstripped outputs (for example `install\RelWithDebInfo-unstripped`), you can run the script in "strip-only" mode which copies the unstripped install tree to a `-stripped` variant and runs the NDK `llvm-strip` on `.so` and binaries.

Requirements:
- The source folder must exist: `install\<BuildType>-unstripped\`.
- `ANDROID_NDK_HOME` or `-NDK` must point to an NDK with `toolchains\llvm\prebuilt\<host>`.

Example (copy unstripped Release -> stripped and strip):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build_all.ps1 -BuildType Release -OnlyStrip:$true -NDK 'C:\path\to\android-ndk'
```

After completion the stripped outputs are available under:
`install\<BuildType>-stripped\<abi>\...`

# What the scripts do
- Configure CMake with the Android toolchain file and point `OPENSSL_ROOT_DIR` / libs to per-ABI OpenSSL installs.
- Build with Ninja.
-- Install `libcurl.so` into `install/<BuildType>-<stripLabel>/<abi>/lib/` then copy the resulting `libcurl.so` (and `libssl.so`/`libcrypto.so` if using shared OpenSSL) into `../app/src/main/jniLibs/<abi>/` so your Android project can pick them up.

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
- `OPENSSL_ANDROID_INSTALL` or `OPENSSL_ROOT_DIR` — path to the OpenSSL install base. If you built OpenSSL with build helpers in this repo the outputs are organized under `openssl/install/<BuildType>-<stripped|unstripped>/` so point this variable to the desired build-type folder (e.g. `openssl/install/RelWithDebInfo-unstripped`).
- `BUILD_TYPE` (bash): controls `-DCMAKE_BUILD_TYPE` when running `build_all.sh` (default: `Release`).
- `STRIP` (bash): if set to `1`, the bash script will prefer `-stripped` OpenSSL installs when resolving the OpenSSL ABI folder (default: `0`).
- `CURL_VERSION` (optional) — override curl version the script downloads

## Notes on OpenSSL
- The build scripts will prefer per-build OpenSSL install folders: `openssl/install/<BuildType>-<stripped|unstripped>/<abi>/lib` with headers under `.../<abi>/include`.
- If those are not present, the scripts will fall back to the legacy layout `openssl/install/<abi>/lib` and `openssl/install/<abi>/include`.
- This repository includes a submodule containing prebuilt OpenSSL libraries for the supported ABIs. If you want to build your own OpenSSL libraries, see [openssl-android-prebuilt-and-buildscripts](https://github.com/XDcobra/openssl-android-prebuilt-and-buildscripts).

# Support / Troubleshooting
- If CMake fails to find OpenSSL, make sure `OPENSSL_ROOT_DIR` and the `include`/`lib` paths exist for the ABI you're building.
- On Windows prefer running the build in a Developer PowerShell with NDK/Toolchain in PATH, or use WSL/Git-Bash for the OpenSSL build steps.

# License
- This folder contains OpenSSL libraries which are licensed under the OpenSSL license. Keep `LICENSE`/`LICENSE.txt` with the distributed artifacts.

