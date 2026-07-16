#!/bin/zsh
# herdr.dev の公式ロゴからアプリアイコン (herdr.icns / herdr-icon.png) を生成する。
# ロゴの著作権は herdr プロジェクトに帰属するため、リポジトリには含めずビルド時に取得する。
set -euo pipefail

HERE="${0:A:h}"
LOGO="$HERE/herdr-official-logo.png"

if [[ ! -f "$LOGO" ]]; then
  echo "==> 公式ロゴを herdr.dev からダウンロード"
  curl -fsSL https://herdr.dev/assets/logo.png -o "$LOGO"
fi

echo "==> squircle アイコンを生成"
swift "$HERE/squircle-icon.swift" "$LOGO" "$HERE/herdr-icon.png"

echo "==> .icns を生成"
ICONSET="$(mktemp -d)/herdr.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$HERE/herdr-icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$HERE/herdr-icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$HERE/herdr.icns"
echo "完了: herdr-icon.png / herdr.icns"
