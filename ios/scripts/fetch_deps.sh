#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DEPS_DIR="$ROOT_DIR/deps"

mkdir -p "$DEPS_DIR"

if [ ! -d "$DEPS_DIR/StikJIT.xcframework" ]; then
    echo "Downloading StikJIT.xcframework 2.0.1 from StikDebug/StikJIT..."
    gh release download 2.0.1 -R StikDebug/StikJIT -p "StikJIT.xcframework.zip" -D "$DEPS_DIR"
    unzip -q "$DEPS_DIR/StikJIT.xcframework.zip" -d "$DEPS_DIR"
    rm -f "$DEPS_DIR/StikJIT.xcframework.zip"
    python3 -c "import glob; [open(p, 'w').write(open(p).read().replace('::', '.')) for p in glob.glob('$DEPS_DIR/StikJIT.xcframework/**/*.swiftinterface', recursive=True)]"
    echo "StikJIT.xcframework installed at $DEPS_DIR/StikJIT.xcframework"
else
    echo "StikJIT.xcframework already exists in deps."
fi
