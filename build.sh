#!/usr/bin/env bash
# macTonaldo 를 .app 번들로 빌드한다.
set -euo pipefail

APP_NAME="macTonaldo"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"
ARCH="$(uname -m)"

echo "==> 빌드 ($ARCH)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -parse-as-library -O \
  -target "${ARCH}-apple-macos14.0" \
  -o "$APP/Contents/MacOS/$APP_NAME" \
  "$ROOT"/Sources/*.swift

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "==> 서명 (ad-hoc)"
codesign --force --sign - "$APP"

echo "==> 완료: $APP"
