#!/usr/bin/env bash
# MacTonalDo 를 .pkg 설치본으로 묶는다. 결과는 dist/ 아래에 놓인다.
#
# 환경 변수
#   APP_SIGN_IDENTITY        Developer ID Application — 앱에 서명한다
#   INSTALLER_SIGN_IDENTITY  Developer ID Installer   — pkg 에 서명한다
#   NOTARY_PROFILE           notarytool 키체인 프로파일 이름 — 공증까지 맡긴다
#
# 셋 다 없으면 서명도 공증도 없는 pkg 가 나온다. 만들어지기는 하지만
# 받는 사람 맥에서 "확인되지 않은 개발자" 로 막힌다. README 의 '배포' 를 보라.
set -euo pipefail

APP_NAME="MacTonalDo"
PKG_ID="local.mactonaldo.app"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/build/$APP_NAME.app"
DIST="$ROOT/dist"

echo "==> 앱 빌드"
"$ROOT/build.sh"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
OUT="$DIST/$APP_NAME-$VERSION.pkg"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> 담을 자리 꾸리기 ($VERSION)"
mkdir -p "$WORK/root" "$WORK/resources" "$DIST"
cp -R "$APP" "$WORK/root/"

cp "$ROOT/Packaging/resources/"*.html "$WORK/resources/"
cp "$ROOT/LICENSE" "$WORK/resources/LICENSE.txt"
sed "s/__VERSION__/$VERSION/" "$ROOT/Packaging/distribution.xml" > "$WORK/distribution.xml"

echo "==> 묶기"
pkgbuild \
  --root "$WORK/root" \
  --install-location /Applications \
  --identifier "$PKG_ID" \
  --version "$VERSION" \
  --scripts "$ROOT/Packaging/scripts" \
  "$WORK/component.pkg" >/dev/null

productbuild \
  --distribution "$WORK/distribution.xml" \
  --package-path "$WORK" \
  --resources "$WORK/resources" \
  "$WORK/unsigned.pkg" >/dev/null

if [[ -n "${INSTALLER_SIGN_IDENTITY:-}" ]]; then
  echo "==> pkg 서명 ($INSTALLER_SIGN_IDENTITY)"
  productsign --sign "$INSTALLER_SIGN_IDENTITY" "$WORK/unsigned.pkg" "$OUT"
else
  echo "==> pkg 서명 건너뜀 (INSTALLER_SIGN_IDENTITY 없음)"
  cp "$WORK/unsigned.pkg" "$OUT"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "==> 공증 맡기기 (몇 분 걸린다)"
  xcrun notarytool submit "$OUT" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$OUT"
else
  echo "==> 공증 건너뜀 (NOTARY_PROFILE 없음)"
fi

echo
echo "==> 완료: $OUT"
echo "    크기: $(du -h "$OUT" | cut -f1)"
pkgutil --check-signature "$OUT" | sed -n '1,3p' | sed 's/^/    /'
