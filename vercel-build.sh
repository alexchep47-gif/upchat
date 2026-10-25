#!/usr/bin/env bash
set -euo pipefail
FLUTTER_DIR=/tmp/flutter
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  rm -rf "$FLUTTER_DIR"
  git clone https://github.com/flutter/flutter.git -b 3.24.5 --depth 1 "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --version
flutter pub get
flutter build web --release --base-href /
BUILD_ID="${VERCEL_GIT_COMMIT_SHA:-$(git rev-parse --short HEAD)}"
if [ -f build/web/index.html ]; then
  sed -i "s|flutter_bootstrap.js|flutter_bootstrap.js?v=${BUILD_ID}|g" build/web/index.html
  sed -i "s|flutter.js|flutter.js?v=${BUILD_ID}|g" build/web/index.html
fi
