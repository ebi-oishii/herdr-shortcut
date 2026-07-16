# herdr-shortcut

[herdr](https://herdr.dev)（ターミナル常駐のエージェントマルチプレクサ）を、macOS で普通のデスクトップアプリのように **Dock からワンクリックで開く**ためのランチャー生成スクリプト。

One-click macOS launcher generator for [herdr](https://herdr.dev) — open your herd like a desktop app.

<img src="https://herdr.dev/assets/logo.png" width="96" alt="herdr logo (© herdr project)">

## これは何？

herdr は「a binary, not an app」という思想のターミナルツールで、公式には GUI もランチャーも存在しない。このスクリプトは `/Applications/Herdr.app` を生成し、次の体験を実現する：

- **Dock クリックで herdr が開く**（公式ロゴの角丸アイコン）
- 普段使いのターミナル（Ghostty 等）の Dock アイコン・ピン留め・挙動には**一切影響しない**
- ウィンドウを閉じてもセッションは `herdr server` に残り、次のクリックで復帰（Slack 的な常駐アプリ感覚）
- **デタッチ（`ctrl+b q`）してもウィンドウは落ちない** — その場にセッションメニューが出て、再アタッチ（`r`）・別セッションへの切替・新規セッション作成（名前を入力）・ウィンドウを閉じる（Enter）を選べる
- 確認ダイアログなし・余計なタブなし・二重起動なし

## 必要なもの

- macOS（Apple Silicon / macOS 26 で検証）
- herdr（`brew install herdr`）
- Xcode Command Line Tools（`xcode-select --install` — ghostty モードで cc / swift を使用）
- ターミナル：[Ghostty](https://ghostty.org)（推奨）/ iTerm2 / WezTerm / macOS 標準ターミナル

## 使い方

```sh
git clone git@github.com:ebi-oishii/herdr-shortcut.git
cd herdr-shortcut
./build-herdr-app.sh                      # Ghostty で開く（デフォルト・推奨）
```

できあがった `/Applications/Herdr.app` を Dock にドラッグすれば完成。

別のターミナルで開きたい場合：

```sh
./build-herdr-app.sh --terminal iterm2    # iTerm2
./build-herdr-app.sh --terminal wezterm   # WezTerm
./build-herdr-app.sh --terminal terminal  # macOS 標準ターミナル
```

herdr が PATH 外にある場合は `HERDR_BIN=/path/to/herdr ./build-herdr-app.sh`。

## モードの違い

| | ghostty（デフォルト） | iterm2 / wezterm / terminal |
|---|---|---|
| 方式 | Ghostty.app を複製し別バンドル ID の独立アプリ化 | ターミナル本体を呼ぶだけの軽量ランチャー |
| 実行中の Dock 表示 | 専用アイコン（完全独立） | 選んだターミナルのアイコン |
| ターミナル更新への追従 | 起動時に自動検知して複製を作り直す | 影響なし（参照のみ） |
| 備考 | ad-hoc 再署名を含む | 初回クリック時に Automation 許可が 1 回出る |

## herdr 自体がターミナルを内包しているのに、これは要るのか？

herdr が内包しているのは「各エージェントに与える本物の擬似端末（ペイン）」であって、herdr の **TUI 自体はどこかのターミナルエミュレータの中でしか動けない**。このプロジェクトが提供するのはその「住処」の方 — Dock / Spotlight / Cmd+Tab に独立したアプリとして現れる専用ウィンドウと、デタッチ後も「セッションの入り口」であり続けるふるまい — であり、herdr の機能とは重複しない。

機能だけ見ればターミナルで `herdr` と打つのと等価なので、価値は**起動導線と識別**に全振りしている。それが要らない人にはこのプロジェクトは不要（それが herdr の思想でもある）。

## 仕組み・設計メモ（macOS のハマりどころ集）

このシンプルな要件が一筋縄でいかない理由：

1. **Ghostty 1.3 は `-e` で渡したコマンドを毎回確認する**（セキュリティ仕様・無効化不可・承認も記憶されない）→ バンドル内設定ファイルの `command` として渡すと信頼される
2. **同一バンドル ID のままでは Dock 分離が不可能** — ラッパー .app から exec しても、AppKit のチェックイン時に LaunchServices の登録が実バンドルに書き換えられる → 複製して `CFBundleIdentifier` を書き換える
3. **Info.plist を書き換えると内部バイナリの署名が無効になる**（Mach-O 署名は plist のハッシュを内包）→ ghostty 本体も ad-hoc で再署名
4. **署名付きバンドルのメイン実行ファイルがシェルスクリプトだと launchd がスポーン拒否**（error 162）→ C の小さな Mach-O スタブで exec
5. **Ghostty はカスタム Dock アイコンを defaults（`CustomGhosttyIcon2`）に永続化する** — Dock タイルは `NSDockTilePlugIn` が描画するため、アイコンがおかしくなったら `defaults delete <bundle-id> CustomGhosttyIcon2 && killall Dock`
6. **herdr はデタッチするとクライアントプロセスが終了する** — そのままではウィンドウごと閉じてしまうため、`command` には herdr 直接ではなくセッションループ（`herdr-session.sh`）を渡し、終了後にメニューを出して再アタッチ・セッション切替できるようにしている

## 注意

- ghostty モードの複製は ad-hoc 署名になるため、フォルダアクセス等の TCC 許可は本家 Ghostty とは別に求められる
- herdr 公式ロゴは再配布を避けるため、ビルド時に herdr.dev から取得する（`generate-icons.sh`）
- herdr / Ghostty / macOS の将来の変更で動かなくなる可能性はある（動作確認: herdr 0.7.3 / Ghostty 1.3.1 / macOS 26）

## ライセンス

このリポジトリのスクリプト類は [MIT](LICENSE)。herdr ロゴは herdr プロジェクトに、Ghostty は Ghostty プロジェクトに帰属します。
