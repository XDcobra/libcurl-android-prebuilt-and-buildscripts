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

mkdir -p "$WORKDIR/downloads" "$WORKDIR/build" "$WORKDIR/install" "$WORKDIR/../app/src/main/jniLibs"
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

  # Verify OpenSSL ABI install exists
  OPENSSL_ABI_ROOT="$OPENSSL_INSTALL_BASE/$ABI"
  if [ ! -d "$OPENSSL_ABI_ROOT" ] || [ ! -d "$OPENSSL_ABI_ROOT/include" ] || [ ! -d "$OPENSSL_ABI_ROOT/lib" ]; then
    echo "ERROR: OpenSSL ABI folder not found: $OPENSSL_ABI_ROOT" >&2
    echo "Expected structure: <OpenSslInstallBase>/<abi>/include and .../lib" >&2
    echo "Hint: Initialize the openssl submodule (prebuilt) with 'git submodule update --init --recursive' or set OPENSSL_ROOT_DIR to the openssl/install base." >&2
    exit 1
  fi

  CMAKE_ARGS=(
    "$SRCDIR"
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake"
    -DANDROID_ABI="$ABI"
    -DANDROID_PLATFORM=21
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_SHARED_LIBS=ON
    -DENABLE_MANUAL=OFF
    -DBUILD_TESTING=OFF
    -DCURL_STATICLIB=OFF
    -DANDROID_STL=c++_static
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"
  )
  if [ -n "$OPENSSL_ROOT_DIR" ]; then
    CMAKE_ARGS+=( -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT_DIR" )
  fi

  cmake "${CMAKE_ARGS[@]}"
  cmake --build . --target install --parallel $(nproc 2>/dev/null || echo 4)
  popd >/dev/null

  JNI_DEST="$WORKDIR/../app/src/main/jniLibs/$ABI"
  mkdir -p "$JNI_DEST"
  if [ -f "$INSTALL_DIR/lib/libcurl.so" ]; then
    cp "$INSTALL_DIR/lib/libcurl.so" "$JNI_DEST/libcurl.so"
    echo "Installed libcurl.so -> $JNI_DEST/libcurl.so"
  else
    echo "Warning: libcurl.so not found in $INSTALL_DIR/lib" >&2
  fi
done

echo "libcurl build finished. jniLibs updated under app/src/main/jniLibs/."
