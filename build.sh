#!/usr/bin/env bash
# MacTonalDo 를 .app 번들로 빌드한다.
#
# 환경 변수
#   UNIVERSAL=0          이 맥의 아키텍처로만 빌드한다 (빠르다. 혼자 쓸 때)
#   APP_SIGN_IDENTITY    Developer ID Application 인증서 이름. 없으면 ad-hoc 서명.
#   BUILD_DIR            결과를 놓을 자리. 기본은 build/
set -euo pipefail

APP_NAME="MacTonalDo"
MIN_MACOS="14.0"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build}"
APP="$BUILD/$APP_NAME.app"
BIN="$APP/Contents/MacOS/$APP_NAME"

if [[ "${UNIVERSAL:-1}" == "1" ]]; then
  TARGETS=(arm64 x86_64)
else
  TARGETS=("$(uname -m)")
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SLICES=()
for arch in "${TARGETS[@]}"; do
  echo "==> 빌드 ($arch)"
  swiftc -parse-as-library -O \
    -target "${arch}-apple-macos${MIN_MACOS}" \
    -o "$WORK/$arch" \
    "$ROOT"/Sources/*.swift
  SLICES+=("$WORK/$arch")
done

if (( ${#SLICES[@]} > 1 )); then
  echo "==> 한 덩어리로 합치기 (${TARGETS[*]})"
  lipo -create "${SLICES[@]}" -output "$BIN"
else
  cp "${SLICES[0]}" "$BIN"
fi

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Developer ID 인증서가 있으면 APP_SIGN_IDENTITY 로 넘겨 준다.
# 없으면 ad-hoc(-) 으로 서명한다. 이 맥에서는 돌아가지만 남의 맥에서는 Gatekeeper 가 막는다.
SIGN_ID="${APP_SIGN_IDENTITY:--}"
if [[ "$SIGN_ID" == "-" ]]; then
  echo "==> 서명 (ad-hoc)"
  codesign --force --sign - "$APP"
else
  echo "==> 서명 ($SIGN_ID)"
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
fi

echo "==> 완료: $APP"
lipo -archs "$BIN" | sed 's/^/    아키텍처: /'
