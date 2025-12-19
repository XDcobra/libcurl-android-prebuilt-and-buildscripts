#!/usr/bin/env bash
set -euo pipefail

NDK=${ANDROID_NDK_HOME:-}
if [ -z "$NDK" ]; then
  echo "ERROR: ANDROID_NDK_HOME is not set. Please set it to your Android NDK path." >&2
  exit 1
fi

CURL_VERSION=${CURL_VERSION:-8.4.0}
DIST="curl-${CURL_VERSION}"
URL="https://curl.se/download/${DIST}.tar.xz"
WORKDIR="$(cd "$(dirname "$0")" >/dev/null && pwd)"
SRCDIR="$WORKDIR/$DIST"

mkdir -p "$WORKDIR/downloads" "$WORKDIR/build" "$WORKDIR/install"
cd "$WORKDIR/downloads"

if [ ! -f "${DIST}.tar.xz" ]; then
  echo "Downloading ${DIST}..."
  wget -q --show-progress "$URL"
fi

if [ ! -d "$SRCDIR" ]; then
  echo "Extracting ${DIST}..."
  tar -xf "${DIST}.tar.xz" -C "$WORKDIR"
fi

ABIS=("arm64-v8a" "armeabi-v7a" "x86_64")
# Optionally provide OPENSSL_ROOT_DIR to point to prebuilt OpenSSL for Android
OPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR:-}

# Build type and strip control (can be provided via env or CI)
BUILD_TYPE=${BUILD_TYPE:-Release}
STRIP=${STRIP:-0} # set to 1 to prefer stripped OpenSSL installs

# Default OpenSSL install base: <scriptDir>/openssl/install unless OPENSSL_ROOT_DIR provided
if [ -z "$OPENSSL_ROOT_DIR" ]; then
  OPENSSL_INSTALL_BASE="$WORKDIR/openssl/install"
else
  OPENSSL_INSTALL_BASE="$OPENSSL_ROOT_DIR"
fi
for ABI in "${ABIS[@]}"; do
  echo "Building libcurl for $ABI"
  BUILD_DIR="$WORKDIR/build/$ABI"
  INSTALL_DIR="$WORKDIR/install/$ABI"
  mkdir -p "$BUILD_DIR" "$INSTALL_DIR"
  pushd "$BUILD_DIR" >/dev/null

  # Determine OpenSSL ABI install path.
  # Prefer per-build install: <installBase>/<BuildType>-<stripped|unstripped>/<abi>
  strip_label="unstripped"
  if [ "$STRIP" = "1" ]; then
    strip_label="stripped"
  fi

  candidate="$OPENSSL_INSTALL_BASE/$BUILD_TYPE-$strip_label/$ABI"
  if [ -d "$candidate" ] && [ -d "$candidate/include" ] && [ -d "$candidate/lib" ]; then
    OPENSSL_ABI_ROOT="$candidate"
  elif [ -d "$OPENSSL_INSTALL_BASE/$ABI" ] && [ -d "$OPENSSL_INSTALL_BASE/$ABI/include" ] && [ -d "$OPENSSL_INSTALL_BASE/$ABI/lib" ]; then
    # fallback to legacy install/<abi>/ layout
    OPENSSL_ABI_ROOT="$OPENSSL_INSTALL_BASE/$ABI"
  else
    echo "ERROR: OpenSSL ABI folder not found (checked $candidate and $OPENSSL_INSTALL_BASE/$ABI)" >&2
    echo "Expected structure: <OpenSslInstallBase>/<BuildType>-<stripped|unstripped>/<abi>/include and .../lib or legacy <OpenSslInstallBase>/<abi>/include and .../lib" >&2
    echo "Hint: Initialize the openssl submodule (prebuilt) with 'git submodule update --init --recursive' or set OPENSSL_ROOT_DIR to the openssl/install base or a BuildType-specific folder." >&2
    exit 1
  fi

  CMAKE_ARGS=(
    "$SRCDIR"
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake"
    -DANDROID_ABI="$ABI"
    -DANDROID_PLATFORM=21
    -DCMAKE_BUILD_TYPE=$BUILD_TYPE
    -DBUILD_SHARED_LIBS=ON
    -DENABLE_MANUAL=OFF
    -DBUILD_TESTING=OFF
    -DCURL_STATICLIB=OFF
    -DANDROID_STL=c++_static
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"
  )
  # Pass per-ABI OpenSSL root to CMake so configure can find includes/libs
  if [ -n "$OPENSSL_ABI_ROOT" ]; then
    CMAKE_ARGS+=( -DOPENSSL_ROOT_DIR="$OPENSSL_ABI_ROOT" )
  fi

  cmake "${CMAKE_ARGS[@]}"
  cmake --build . --target install --parallel $(nproc 2>/dev/null || echo 4)
  popd >/dev/null

  # Outputs remain in the install directory
done

echo "libcurl build finished. Libraries are available under the 'install' directories."
