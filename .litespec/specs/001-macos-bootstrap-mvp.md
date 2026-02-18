# 001-macos-bootstrap-mvp

## 目的

- OS 初期化後でも `make init` 1 回で、普段使いのシェル環境を短時間で復旧できるようにする。
- dotfiles で実現していた体験を、Nix ベースで再現可能かつ更新可能な形に移行する。

## ユーザーストーリー

- 頻繁に新規環境を作る利用者として、手動セットアップを繰り返したくない。
- macOS 初期化直後でも、`zsh` / 主要 CLI / AI CLI をすぐ使いたい。
- 見た目（フォント、テーマ）を含めて、いつでも同じ作業環境に戻したい。

## スコープ

- `nix-darwin` + `home-manager` による macOS 構成管理
- `init.sh`（`make init` 呼び出し）での初期導入自動化
- `zsh` / prompt / alias / functions の復元
- CLI と AI CLI の導入
- フォント導入（HackGen NF、LINE Seed JP、IBM Plex Sans JP、IBM Plex Mono）
- `Hanabi Theme`（`hanabi-works/hanabi-theme`）を使ったテーマ適用
- `vim` / `VS Code` の導入とテーマ適用
- 再実行可能性（冪等）とバックアップ挙動

## 非スコープ

- GUI アプリ設定の全面自動化（Karabiner、Raycast など）
- secrets の完全自動配布（`sops-nix` は後続フェーズ）
- Linux / WSL の本実装

## 機能要件

### FR-001 ブートストラップ

- `nix-home` 本体リポジトリは `~/nix-home` 配下で運用し、`ghq` 配下には配置しない。
- `init.sh` は macOS で `xcode-select -p` を事前確認し、未導入時は導入を促して終了する。
- `init.sh` は GitHub SSH 接続を事前確認し、失敗時は鍵登録を促して終了する。
- `init.sh` は未導入時に Nix を導入する。
- `init.sh` はリポジトリを取得または更新する。
- `init.sh` は `hanabi-works/hanabi-theme` の取得・更新に `ghq get -u` を利用し、`ghq` の動作確認も兼ねる。
- `hanabi-theme` の取得・更新は既定で SSH（`git@github.com:hanabi-works/hanabi-theme.git`）を利用する（必要に応じて `HANABI_THEME_REPO` で上書き可能）。
- `ghq get -u` が失敗した場合でも、既存チェックアウトを退避してクリーンに再取得し、最新状態で継続できる。
- `init.sh` は `darwin-rebuild switch --flake` を実行する。
- `init.sh` はログファイルを出力し、失敗時に参照先を表示する。
- `make init` は `init.sh` を呼び出す。
- `make init` 実行時の sudo パスワード入力は冒頭の1回に集約する。
- 対話的な TTY 上で `make init` を実行した場合、完了後に `zsh -l` を再起動して設定を即時反映する（必要に応じて `NIX_HOME_SKIP_SHELL_RELOAD=1` で無効化できる）。
- `make init` は `nix` 管理の `zsh` をログインシェルに設定する（必要に応じて `NIX_HOME_SKIP_LOGIN_SHELL=1` で無効化できる）。

### FR-002 ホスト切り替え

- ホスト名に応じて flake 出力を切り替えられる。
- `hosts/darwin/` 配下にホスト名と同名の `.nix` ファイルを配置することで、ホスト固有の設定を定義できる。
- `hosts/darwin/default.nix` は汎用ベース設定として、ホスト固有ファイルから `imports` される。
- Makefile は `hostname -s` でホスト名を取得し、対応する `.nix` ファイルが存在すればそのホスト名を flake ターゲットに使用する。存在しなければ `default` にフォールバックする。
- デフォルトの macOS ホスト設定を1つ持つ。

### FR-002a 日常操作ターゲット

- `make build` は `darwin-rebuild build` を実行し、ビルドのみ行う（システム適用はしない）。
- `make switch` は `darwin-rebuild switch` を実行し、システムに適用する。
- `make update` は `nix flake update` 後に `build` → `switch` の順で実行する（検証方針「switch 前に build」に準拠）。
- `make switch` / `make init` は Home Manager activation を通じて、各 AI CLI の MCP セットアップを自動実行する。
- MCP 自動セットアップ時は `sops-env.sh` から環境変数を読み込み、`launchctl` に `JINA_API_KEY` を同期する。
- `make switch` / `make init` は Home Manager activation を通じて、`llm-agents` 自動更新用 launchd agent（`com.okash1n.nix-home.llm-agents-update`）を登録・再同期する。
- `llm-agents` 自動更新で `flake.lock` が更新された場合、`darwin-rebuild build` と `darwin-rebuild switch` を自動実行する。
- MCP の既定モードは `NIX_HOME_MCP_DEFAULT_ENABLED=0`（OFF）とし、`NIX_HOME_MCP_DEFAULT_ENABLED=1` を指定した場合のみ既定ONで同期する。
- MCP の例外は `NIX_HOME_MCP_FORCE_ENABLED` / `NIX_HOME_MCP_FORCE_DISABLED`（カンマ区切り）で制御し、既定は `NIX_HOME_MCP_FORCE_ENABLED=jina,claude-mem` とする。
- `make mcp` は上記と同じセットアップ処理を手動で再実行する。
- 各 MCP セットアップスクリプトは、対象コマンドが未導入の場合は warn + skip で継続する。

### FR-003 シェル再現

- `zsh` をデフォルトシェルとして利用可能にする。
- 既定は `powerlevel10k` のプロンプト構造が表示される。
- `hanabi.p10k.zsh` により、`powerlevel10k` の配色を Hanabi に寄せる（プロンプト構造は維持）。
- `Hanabi` の Zsh プロンプトテーマ（`hanabi.zsh-theme`）は保持し、必要に応じて `NIX_HOME_ZSH_PROMPT=hanabi` で切り替え可能にする。
- alias / functions を Nix 管理で復元する。
- 既存 dotfiles 由来の主要関数（例: `fgh`）を利用可能にする。
- 履歴・補完キャッシュなどの XDG パスを一貫させる。
- 履歴ファイル保存先ディレクトリ（例: `~/.local/state/zsh`）が存在しない場合は自動作成する。
- `~/.zshenv` を Nix 管理で生成し、`ZDOTDIR` を `~/.config/zsh` に設定する。
- `~/.config/zsh/.zshrc` を Nix 管理で生成する。
- `~/.config/zsh/.p10k.zsh` を Nix 管理で生成する（切り替え用）。
- `~/.config/zsh/hanabi.p10k.zsh` を配置する（p10k 向け配色上書き用）。

### FR-004 CLI 再現

- `git`、`curl`、`wget`、`jq`、`fzf`、`fd`、`rg`、`ghq`、`awk`、`grep`、`sed` を導入する。
- `zsh` は macOS 標準ではなくパッケージ版を導入する。
- `bash` もパッケージ版を導入する。
- `node` / `pnpm` / `bun` を導入する。
- `python3` / `uv` を導入する。
- `tmux` を導入する。
- `dust` / `yazi` を導入する。
- `vim` を導入する。
- AI CLI（Codex / Claude Code / Gemini / Happy / Agent Browser）をコマンド実行可能にする。
- `playwright` CLI をコマンド実行可能にする。
- `athenai` ラッパーコマンドを配置し、`~/ghq/github.com/athenai-dev/athenai` の CLI を起動できるようにする（`ATHENAI_REPO` で上書き可能）。
- `git` のグローバル設定（`user.name` / `user.email` / global ignore）を Nix 管理で復元する。

### FR-005 冪等性

- 同一マシンで `make init`（または `./init.sh`）を再実行しても、致命的エラーで停止しない。
- 再実行後もシェル設定が破損しない。
- 既存 dotfile と管理対象が衝突した場合は、自動バックアップして適用を継続する。
- 過去 Nix installer が残した `/etc/*rc.backup-before-nix` 衝突を自動退避し、初期化を継続する。

### FR-006 フォント導入

- HackGen NF を導入する。
- LINE Seed JP を導入する。
- IBM Plex Sans JP を導入する。
- IBM Plex Mono を導入する。

### FR-007 テーマ適用

- `Ghostty` 本体を Nix 管理で導入する。
- `Ghostty` は `/Applications/Nix Apps` から GUI 起動できる状態にする。
- `~/.config/ghostty/config` を Nix 管理で生成し、HackGen と `Hanabi`（`theme = hanabi`）を適用する。
- `Terminal.app` は `Hanabi` プロファイルを既定に設定する。
- `Terminal.app` の `Hanabi` プロファイルには HackGen 系フォント（優先: `HackGen Console NF`）を適用し、適用結果を検証する。
- `Terminal.app` のテーマ適用処理（import / defaults / フォント設定）は `make init` 実行時のみ試行し、`make switch` では実行しない。
- GUI セッションが有効な環境では、`make init` 実行時に `Terminal.app` の起動有無に依存せずテーマ適用処理を試行する。
- `Terminal.app` が起動中の場合、既存ウィンドウ/タブの current settings も `Hanabi` に合わせる。
- `Hanabi` プロファイルの import 失敗時は `defaults` の既定設定更新を強行せず、失敗理由をログに出す。
- `hanabi-theme` が未取得の場合は処理をスキップし、復旧手順をログに表示する。
- GUI セッションが無い環境では `Terminal.app` への適用処理をスキップして停止しない。
- GUI セッションで初回セットアップ完了時は `Ghostty` を自動起動する（再実行時は既定で再起動しない）。
- `vim` の colorscheme を `hanabi` に設定する（`~/.vim/colors/hanabi.vim` を配置し、`~/.vimrc` を生成）。
- `VS Code` の `settings.json` / `keybindings.json` / `snippets` を Home Manager (`home.file`) で宣言的に管理する。
- `home.file` には `mkOutOfStoreSymlink` を使い、VS Code からの編集が `~/nix-home/home/dot_config/vscode/` 配下へ直接反映されるようにする。
- `settings.json` は最小設定（テーマとフォント）を維持する。
- `keybindings.json` は空配列（`[]`）を宣言し、OS差分のある独自キーバインドを持ち込まない。
- `VS Code` 拡張リストは `home/dot_config/vscode/extensions.txt` を正本として管理する。
- activation script は `extensions.txt` の未導入分をインストールし、VS Code 側で追加された拡張を `extensions.txt` へ取り込む（additive sync）。

### FR-007a macOSスクリーンショット設定

- `system.defaults.screencapture."disable-shadow"` を有効化し、ウィンドウのスクリーンショット撮影時に影を付けない。

### FR-008 ストアメンテナンス

- Nix Store のガベージコレクションを自動実行する。
- 古い世代を定期的に削除し、容量増加を抑制する。
- Nix Store の最適化を自動実行する。

## 非機能要件

- 再現性: `flake.lock` 固定で同一構成を再現できる。
- 可観測性: ブートストラップログで失敗箇所を追跡できる。
- 保守性: `hosts/` `home/` `modules/` を分割し、責務を明確化する。
- 更新性: 必要に応じてパッケージのバージョン更新を行える。

## 受け入れ条件（DoD）

- クリーン macOS で `make init` 実行後、ログインシェルが `zsh` で起動する。
- `nix-home` 本体が `~/nix-home` に配置されている。
- `powerlevel10k` のプロンプト構造が表示され、Hanabi 配色（`hanabi.p10k.zsh`）が適用される。
- `~/.config/zsh/.zshrc` と `~/.config/zsh/.p10k.zsh` が存在する。
- `~/.config/zsh/hanabi.zsh-theme` が存在する。
- `~/.config/zsh/hanabi.p10k.zsh` が存在する。
- `command -v ghostty` が成功する。
- `/Applications/Nix Apps` 配下に `Ghostty.app` が作成される。
- `~/.config/ghostty/config` が存在し、HackGen と `theme = hanabi` が反映される。
- 主要 alias / functions が機能する。
- `command -v git nix zsh playwright codex claude gemini happy agent-browser athenai caddy marp` が成功する。
- `command -v rg bun node pnpm uv python3 tmux wget` が成功する。
- `command -v dust yazi` が成功する。
- `command -v vim` が成功する。
- `git config --global user.name` と `git config --global user.email` が期待値を返す。
- HackGen NF / LINE Seed JP / IBM Plex Sans JP / IBM Plex Mono が利用可能。
- `hanabi-theme` のテーマ資産を使って `Terminal.app` の既定プロファイルが `Hanabi` になる。
- `Terminal.app` の `Hanabi` プロファイルに HackGen 系フォントが設定される。
- GUI セッションの初回 `make init` 完了時に `Ghostty` が自動起動する。
- `make switch` 実行時に `Terminal.app` と `Ghostty` が自動起動しない。
- `make switch` / `make init` 実行後、`com.okash1n.nix-home.llm-agents-update` launchd agent が存在する。
- `llm-agents` 自動更新で `flake.lock` に差分が発生した場合、自動で `darwin-rebuild switch` が完了する。
- `~/.vim/colors/hanabi.vim` が存在し、`~/.vimrc` に `colorscheme hanabi` が入る。
- `code --list-extensions` に `okash1n.hanabi-theme-vscode` が含まれる。
- `home/dot_config/vscode/extensions.txt` が存在し、拡張IDを1行1件で保持する。
- `~/Library/Application Support/Code/User/settings.json` が Nix 管理リンクとして存在し、`workbench.colorTheme` が `Hanabi` になっている。
- `~/Library/Application Support/Code/User/settings.json` が Nix 管理リンクとして存在し、`editor.fontFamily` が `HackGen Console NF` になっている。
- `~/Library/Application Support/Code/User/keybindings.json` が Nix 管理リンクとして存在し、内容が `[]` である。
- `defaults read com.apple.screencapture disable-shadow` が `1`（true）を返す。
- ヘッドレス環境では `make init` がテーマ適用処理でハングせず完了する。
- Nix Store の自動 GC / 最適化設定が有効になっている。
- 2回連続で `make init` 実行しても破綻しない。
- `.litespec/README.md` に初期化手順と検証手順が記載されている。

## 依存・前提

- インターネット接続。
- GitHub からリポジトリ取得可能（既定は SSH、必要に応じて `REPO_URL` / `HANABI_THEME_REPO` で HTTPS に切り替え可能）。
- GitHub へ登録済みの SSH 鍵（既定 URL を利用する場合）。
- macOS で `nix-darwin` 実行可能な管理者権限。
- Xcode Command Line Tools が利用可能。

## テスト観点

- 正常系: クリーン環境で `make init` が完了し、主要コマンドが利用可能になる。
- 異常系: SSH 未設定、CLT 未導入、GUI なし環境で想定どおり fail fast / skip する。
- 回帰: `make init` 再実行時に `.hm-bak` 方針で破綻しない。

## 実装メモ

- 変更追跡と再現性のため `flake.lock` を必須とする。
- マイルストーン管理は README と issue で補完し、仕様の受け入れ条件と整合を取る。
