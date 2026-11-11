#!/usr/bin/env bash
# 아이콘을 그려 Resources/AppIcon.icns 로 굽는다.
# 아이콘 모양을 바꿨을 때만 돌리면 된다. 결과물은 저장소에 함께 둔다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> 그리기"
# swift 인터프리터로는 AppKit 이 링크되지 않아 먼저 컴파일한다.
swiftc -O -o "$WORK/makeicon" "$ROOT/Tools/MakeAppIcon.swift"
"$WORK/makeicon" "$WORK/AppIcon.iconset"

echo "==> .icns 로 묶기"
iconutil -c icns "$WORK/AppIcon.iconset" -o "$ROOT/Resources/AppIcon.icns"

echo "==> 완료: $ROOT/Resources/AppIcon.icns"
