#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DEPS_DIR="$ROOT_DIR/deps"
mkdir -p "$DEPS_DIR"

if [ ! -d "$DEPS_DIR/StikJIT.xcframework" ]; then
    echo "Cloning and building StikJIT with the runner toolchain..."
    STIKJIT_TMP="$DEPS_DIR/StikJIT-src"
    rm -rf "$STIKJIT_TMP"
    git clone --depth 1 https://github.com/StikDebug/StikJIT.git "$STIKJIT_TMP"
    cd "$STIKJIT_TMP"
    xcodegen generate
    xcodebuild archive \
        -project StikJIT.xcodeproj \
        -scheme StikJIT \
        -destination 'generic/platform=iOS' \
        -archivePath build/StikJIT-iOS \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        CODE_SIGNING_ALLOWED=NO \
        -quiet
    xcodebuild -create-xcframework \
        -framework build/StikJIT-iOS.xcarchive/Products/Library/Frameworks/StikJIT.framework \
        -output "$DEPS_DIR/StikJIT.xcframework"
    cd "$ROOT_DIR"
    rm -rf "$STIKJIT_TMP"
    echo "StikJIT.xcframework built successfully at $DEPS_DIR/StikJIT.xcframework"
else
    echo "StikJIT.xcframework already exists in deps."
fi
