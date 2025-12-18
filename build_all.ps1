param(
    [string]$NDK = $env:ANDROID_NDK_HOME,
    [string]$CurlVersion = $env:CURL_VERSION,

    # Base folder that contains: <base>\<abi>\include and <base>\<abi>\lib
    # Example: ...\openssl\install
    [string]$OpenSslInstallBase = $env:OPENSSL_ANDROID_INSTALL
)

if (-not $NDK) {
    Write-Error "ANDROID_NDK_HOME is not set. Please set it to your Android NDK path."
    exit 1
}

if (-not $CurlVersion) { $CurlVersion = "8.17.0" }

$Dist    = "curl-$CurlVersion"
$Archive = "$Dist.tar.xz"
$Url     = "https://curl.se/download/$Archive"

$WorkDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SrcDir  = Join-Path $WorkDir $Dist

# Default OpenSSL install base: <scriptDir>\openssl\install
if (-not $OpenSslInstallBase) {
    $OpenSslInstallBase = Join-Path $WorkDir "openssl\install"
}

New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir downloads),(Join-Path $WorkDir build),(Join-Path $WorkDir install) | Out-Null
Set-Location (Join-Path $WorkDir downloads)

if (-not (Test-Path $Archive)) {
    Write-Host "Downloading $Archive..."
    Invoke-WebRequest -Uri $Url -OutFile $Archive
}

if (-not (Test-Path $SrcDir)) {
    Write-Host "Extracting $Archive..."
    tar -xf $Archive -C $WorkDir
}

# ABIs to build
$ABIs = @('arm64-v8a','armeabi-v7a','x86_64')

# prefer Ninja generator to avoid Visual Studio generator on Windows when cross-compiling for Android
if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
    Write-Error "ninja build tool not found in PATH. Install Ninja (choco install ninja) or add it to PATH and re-run."
    exit 1
}

$parallel = [Environment]::ProcessorCount

foreach ($abi in $ABIs) {
    Write-Host "============================================="
    Write-Host "Building libcurl for $abi"
    Write-Host "============================================="

    # OpenSSL per-ABI root: <base>\<abi>\{include,lib,bin}
    $opensslAbiRoot    = Join-Path $OpenSslInstallBase $abi
    $opensslIncludeDir = Join-Path $opensslAbiRoot "include"
    $opensslLibDir     = Join-Path $opensslAbiRoot "lib"

    if (-not (Test-Path $opensslAbiRoot)) {
        Write-Error "OpenSSL ABI folder not found: $opensslAbiRoot"
        Write-Error "Expected structure: <OpenSslInstallBase>\\<abi>\\include and ...\\lib"
        Write-Host "Hint: Initialize the openssl submodule (prebuilt) or set the environment variable OPENSSL_ANDROID_INSTALL to the openssl/install base."
        Write-Host "Example: git submodule update --init --recursive  OR  $env:OPENSSL_ANDROID_INSTALL = 'C:\path\to\openssl\install'"
        exit 1
    }
    if (-not (Test-Path $opensslIncludeDir)) {
        Write-Error "OpenSSL include folder not found: $opensslIncludeDir"
        Write-Host "Hint: Initialize the openssl submodule (prebuilt) or set the environment variable OPENSSL_ANDROID_INSTALL to the openssl/install base."
        Write-Host "Example: git submodule update --init --recursive  OR  $env:OPENSSL_ANDROID_INSTALL = 'C:\path\to\openssl\install'"
        exit 1
    }
    if (-not (Test-Path $opensslLibDir)) {
        Write-Error "OpenSSL lib folder not found: $opensslLibDir"
        Write-Host "Hint: Initialize the openssl submodule (prebuilt) or set the environment variable OPENSSL_ANDROID_INSTALL to the openssl/install base."
        Write-Host "Example: git submodule update --init --recursive  OR  $env:OPENSSL_ANDROID_INSTALL = 'C:\path\to\openssl\install'"
        exit 1
    }

    # Prefer shared libs if present (matching your OpenSSL build goal: .so)
    $sslSo    = Join-Path $opensslLibDir "libssl.so"
    $cryptoSo = Join-Path $opensslLibDir "libcrypto.so"

    # Fallback to static libs if .so not present
    $sslA     = Join-Path $opensslLibDir "libssl.a"
    $cryptoA  = Join-Path $opensslLibDir "libcrypto.a"

    $useStatic = $false
    if ((Test-Path $sslSo) -and (Test-Path $cryptoSo)) {
        $opensslSslLib    = $sslSo
        $opensslCryptoLib = $cryptoSo
        $useStatic = $false
        Write-Host "[OpenSSL] Using shared libs (.so)"
    }
    elseif ((Test-Path $sslA) -and (Test-Path $cryptoA)) {
        $opensslSslLib    = $sslA
        $opensslCryptoLib = $cryptoA
        $useStatic = $true
        Write-Host "[OpenSSL] Using static libs (.a)"
    }
    else {
        Write-Error "Could not find usable OpenSSL libs for $abi in: $opensslLibDir"
        Write-Error "Expected either libssl.so+libcrypto.so OR libssl.a+libcrypto.a"
        exit 1
    }

    $build   = Join-Path $WorkDir "build\$abi"
    $install = Join-Path $WorkDir "install\$abi"

    # ensure a clean build directory
    if (Test-Path $build) { Remove-Item -Recurse -Force $build }
    New-Item -ItemType Directory -Force -Path $build   | Out-Null
    New-Item -ItemType Directory -Force -Path $install | Out-Null

    Push-Location $build

    $cmakeArgs = @(
        "-G", "Ninja",
        $SrcDir,

        "-DCMAKE_TOOLCHAIN_FILE=$NDK\build\cmake\android.toolchain.cmake",
        "-DANDROID_ABI=$abi",
        "-DANDROID_PLATFORM=21",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_INSTALL_PREFIX=$install",

        # libcurl build toggles
        "-DBUILD_SHARED_LIBS=ON",
        "-DENABLE_MANUAL=OFF",
        "-DBUILD_TESTING=OFF",
        "-DCURL_STATICLIB=OFF",
        "-DANDROID_STL=c++_static",

        # Force OpenSSL usage + point directly to headers/libs for this ABI
        "-DCURL_USE_OPENSSL=ON",
        "-DOPENSSL_ROOT_DIR=$opensslAbiRoot",
        "-DOPENSSL_INCLUDE_DIR=$opensslIncludeDir",
        "-DOPENSSL_SSL_LIBRARY=$opensslSslLib",
        "-DOPENSSL_CRYPTO_LIBRARY=$opensslCryptoLib",
        "-DOPENSSL_USE_STATIC_LIBS=$($useStatic.ToString().ToUpper())",
        "-DCURL_USE_LIBPSL=OFF"
    )

    & cmake @cmakeArgs
    if ($LASTEXITCODE -ne 0) { throw "cmake configure failed for $abi" }

    & cmake --build . --target install --parallel $parallel
    if ($LASTEXITCODE -ne 0) { throw "cmake build failed for $abi" }

    Pop-Location
    # Outputs remain in the install directory; skipping copy to app jniLibs.
    Write-Host "[OK] $abi done."
}

Write-Host "libcurl build finished. Libraries are available under the 'install' directories."
