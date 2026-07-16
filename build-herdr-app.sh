#!/bin/zsh
# herdr をワンクリックで開くデスクトップアプリ /Applications/Herdr.app を作る。
#
# 使い方:
#   ./build-herdr-app.sh                       # Ghostty で開く（デフォルト・推奨）
#   ./build-herdr-app.sh --terminal iterm2     # iTerm2 で開く
#   ./build-herdr-app.sh --terminal wezterm    # WezTerm で開く
#   ./build-herdr-app.sh --terminal terminal   # macOS 標準ターミナルで開く
#
# ghostty: Ghostty.app を複製して別バンドル ID の独立アプリにする。
#   Dock 上で通常の Ghostty と完全に分離され、実行中も専用アイコン。
#   Ghostty 更新時は起動スタブが検知して自動でこのスクリプトを再実行する。
# それ以外: ターミナル本体を参照するだけの軽量ランチャー。
#   実行中のウィンドウは選んだターミナルのアイコン・識別で表示される。
#   ターミナル本体の更新の影響を受けない。初回クリック時に
#   「"Herdr" が "<ターミナル>" を制御しようとしています」の許可が 1 回出る。
set -euo pipefail

APP=/Applications/Herdr.app
BUNDLE_ID=io.github.ebi-oishii.herdr-shortcut
HERE="${0:A:h}"
TERMINAL=ghostty

while [[ $# -gt 0 ]]; do
  case "$1" in
    --terminal) TERMINAL="$2"; shift 2 ;;
    *) echo "ERROR: 不明な引数: $1"; exit 1 ;;
  esac
done

# herdr バイナリの場所を解決（環境変数 HERDR_BIN で上書き可能）
HERDR_BIN="${HERDR_BIN:-$(command -v herdr 2>/dev/null || true)}"
if [[ -z "$HERDR_BIN" ]]; then
  for p in /opt/homebrew/bin/herdr /usr/local/bin/herdr; do
    [[ -x "$p" ]] && HERDR_BIN="$p" && break
  done
fi
[[ -n "$HERDR_BIN" ]] || { echo "ERROR: herdr が見つかりません（brew install herdr）"; exit 1 }

# アイコンがなければ公式ロゴから生成
[[ -f "$HERE/herdr.icns" && -f "$HERE/herdr-icon.png" ]] || "$HERE/generate-icons.sh"

# デタッチ後もウィンドウを保ち、再アタッチ／セッション切替を可能にするループを配置
install_session_script() {
  sed "s|@HERDR_BIN@|$HERDR_BIN|" "$HERE/herdr-session.sh.template" \
    > "$APP/Contents/Resources/herdr-session.sh"
  chmod +x "$APP/Contents/Resources/herdr-session.sh"
}
SESSION_SH=/Applications/Herdr.app/Contents/Resources/herdr-session.sh

# ---- 軽量ランチャー共通部（iterm2 / wezterm / terminal）----
build_light_bundle() {
  local launcher_body="$1"
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  cp "$HERE/herdr.icns" "$APP/Contents/Resources/herdr.icns"
  install_session_script
  cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Herdr</string>
    <key>CFBundleDisplayName</key><string>Herdr</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>2.0</string>
    <key>CFBundleShortVersionString</key><string>2.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>herdr-launcher</string>
    <key>CFBundleIconFile</key><string>herdr</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
  print -r -- "$launcher_body" > "$APP/Contents/MacOS/herdr-launcher"
  chmod +x "$APP/Contents/MacOS/herdr-launcher"
  # 軽量版は未署名のまま（メイン実行ファイルがシェルスクリプトのため署名すると launchd に拒否される）
}

case "$TERMINAL" in

ghostty)
  SRC=/Applications/Ghostty.app
  [[ -d "$SRC" ]] || { echo "ERROR: $SRC がありません"; exit 1 }
  command -v cc >/dev/null || { echo "ERROR: cc がありません（xcode-select --install）"; exit 1 }

  echo "==> Ghostty.app を複製 ($(du -sh "$SRC" | cut -f1))"
  rm -rf "$APP"
  ditto "$SRC" "$APP"

  echo "==> バンドル情報を Herdr 用に書き換え"
  P="$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$P"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName Herdr" "$P"
  /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable herdr-launcher" "$P"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile herdr" "$P"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$P" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Herdr" "$P" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Herdr" "$P"

  cp "$HERE/herdr.icns" "$APP/Contents/Resources/herdr.icns"
  cp "$HERE/herdr-icon.png" "$APP/Contents/Resources/herdr-icon.png"
  sed "s|@HERDR_BIN@|$HERDR_BIN|" "$HERE/herdr.conf.template" > "$APP/Contents/Resources/herdr.conf"
  install_session_script

  # 本家バイナリのスタンプ（サイズ+更新時刻）と、自動リビルド用に自分のパスを記録。
  # 起動スタブがこれを見て「Ghostty 更新後の初回起動時に自動で作り直し」を行う。
  stat -f "%z %m" "$SRC/Contents/MacOS/ghostty" > "$APP/Contents/Resources/ghostty-src.stamp"
  echo "${0:A}" >> "$APP/Contents/Resources/ghostty-src.stamp"

  echo "==> 起動スタブをコンパイルして配置"
  cc -O2 -o "$APP/Contents/MacOS/herdr-launcher" "$HERE/herdr-launcher.c"

  echo "==> ad-hoc 再署名（Info.plist 改変で元署名が無効になるため ghostty 本体も署名し直す）"
  codesign --force --preserve-metadata=entitlements --sign - "$APP/Contents/MacOS/ghostty" 2>&1 | grep -v "replacing existing signature" || true
  codesign --force --sign - "$APP" 2>&1 | grep -v "replacing existing signature" || true
  ;;

iterm2)
  [[ -d /Applications/iTerm.app ]] || { echo "ERROR: /Applications/iTerm.app がありません"; exit 1 }
  echo "==> iTerm2 用の軽量ランチャーを作成"
  build_light_bundle "#!/bin/zsh
# 既に herdr クライアントが動いていれば iTerm を前面に出すだけ
if pgrep -f \"${HERDR_BIN}\$\" >/dev/null; then
  exec osascript -e 'tell application \"iTerm\" to activate'
fi
exec osascript \\
  -e 'tell application \"iTerm\"' \\
  -e '  activate' \\
  -e '  create window with default profile command \"${SESSION_SH}\"' \\
  -e 'end tell'"
  ;;

wezterm)
  [[ -d /Applications/WezTerm.app ]] || { echo "ERROR: /Applications/WezTerm.app がありません"; exit 1 }
  echo "==> WezTerm 用の軽量ランチャーを作成"
  build_light_bundle "#!/bin/zsh
# 既に herdr 用 WezTerm が動いていれば前面に出すだけ
if pgrep -f \"wezterm-gui.*start.*herdr\" >/dev/null; then
  exec osascript -e 'tell application \"WezTerm\" to activate'
fi
exec open -na /Applications/WezTerm.app --args start -- ${SESSION_SH}"
  ;;

terminal)
  echo "==> macOS 標準ターミナル用の軽量ランチャーを作成"
  build_light_bundle "#!/bin/zsh
# 既に herdr クライアントが動いていればターミナルを前面に出すだけ
if pgrep -f \"${HERDR_BIN}\$\" >/dev/null; then
  exec osascript -e 'tell application \"Terminal\" to activate'
fi
exec osascript \\
  -e 'tell application \"Terminal\"' \\
  -e '  do script \"exec ${SESSION_SH}\"' \\
  -e '  activate' \\
  -e 'end tell'"
  ;;

*)
  echo "ERROR: --terminal は ghostty / iterm2 / wezterm / terminal のいずれかを指定してください"
  exit 1
  ;;
esac

echo "==> LaunchServices に登録"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

echo "完了: $APP (terminal = $TERMINAL, herdr = $HERDR_BIN)"
