#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DEPS_DIR="$ROOT_DIR/deps"
mkdir -p "$DEPS_DIR"

if [ ! -d "$DEPS_DIR/StikJIT" ]; then
    echo "Cloning StikJIT source repository..."
    git clone --depth 1 https://github.com/StikDebug/StikJIT.git "$DEPS_DIR/StikJIT"
    echo "StikJIT sources installed at $DEPS_DIR/StikJIT"
else
    echo "StikJIT already exists in deps."
fi
