# 001-macos-bootstrap-mvp

## 目的

- OS 初期化後でも `make init` 1 回で、普段使いのシェル環境を短時間で復旧できるようにする。
- dotfiles で実現していた体験を、Nix ベースで再現可能かつ更新可能な形に移行する。

## ユーザーストーリー

- 頻繁に新規環境を作る利用者として、手動セットアップを繰り返したくない。
- macOS 初期化直後でも、`zsh` / `powerlevel10k` / 主要 CLI / AI CLI をすぐ使いたい。
- 見た目（フォント、テーマ）を含めて、いつでも同じ作業環境に戻したい。

## スコープ

- `nix-darwin` + `home-manager` による macOS 構成管理
- `init.sh`（`make init` 呼び出し）での初期導入自動化
- `zsh` / `powerlevel10k` / alias / functions の復元
- CLI と AI CLI の導入
- フォント導入（HackGen NF、LINE Seed JP、IBM Plex Sans JP、IBM Plex Mono）
- `Dracula Pro` private repository を使ったテーマ適用
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
- `init.sh` は `Dracula Pro` private repository の取得・更新に `ghq get -u` を利用し、`ghq` の動作確認も兼ねる。
- `init.sh` は `darwin-rebuild switch --flake` を実行する。
- `init.sh` はログファイルを出力し、失敗時に参照先を表示する。
- `init.sh` はユーザーレベルで `~/.zshenv` に `ZDOTDIR` を設定する。
- `make init` は `init.sh` を呼び出す。
- `make init` 実行時の sudo パスワード入力は冒頭の1回に集約する。

### FR-002 ホスト切り替え

- ホスト名に応じて flake 出力を切り替えられる。
- デフォルトの macOS ホスト設定を1つ持つ。

### FR-003 シェル再現

- `zsh` をデフォルトシェルとして利用可能にする。
- `powerlevel10k` が有効なプロンプトが表示される。
- 既存 dotfiles の `powerlevel10k` 設定（見た目）を維持する。
- alias / functions を Nix 管理で復元する。
- 履歴・補完キャッシュなどの XDG パスを一貫させる。
- 履歴ファイル保存先ディレクトリ（例: `~/.local/state/zsh`）が存在しない場合は自動作成する。
- `~/.config/zsh/.zshrc` を Nix 管理で生成する。
- `~/.config/zsh/.p10k.zsh` を Nix 管理で生成する。

### FR-004 CLI 再現

- `git`、`curl`、`jq`、`fzf`、`ghq`、`awk`、`grep`、`sed` を導入する。
- `zsh` は macOS 標準ではなくパッケージ版を導入する。
- `bash` もパッケージ版を導入する。
- AI CLI（Codex / Claude Code / Gemini）をコマンド実行可能にする。
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

### FR-007 ターミナルテーマ管理

- `Ghostty` 本体を Nix 管理で導入する。
- `Ghostty` は `/Applications/Nix Apps` から GUI 起動できる状態にする。
- `~/.config/ghostty/config` を Nix 管理で生成し、HackGen と Dracula Pro 配色を適用する。
- `Terminal.app` は `Dracula Pro` プロファイルを既定に設定する。
- `Terminal.app` の `Dracula Pro` プロファイルには HackGen 系フォント（優先: `HackGen Console NF`）を適用し、適用結果を検証する。
- GUI セッションが有効な環境では、`Terminal.app` の起動有無に依存せずテーマ適用処理（import / defaults / フォント設定）を試行する。
- `Terminal.app` が起動中の場合、既存ウィンドウ/タブの current settings も `Dracula Pro` に合わせる。
- `Dracula Pro` プロファイルの import 失敗時は `defaults` の既定設定更新を強行せず、失敗理由をログに出す。
- `Dracula Pro` が未取得の場合は処理をスキップし、復旧手順をログに表示する。
- GUI セッションが無い環境では `Terminal.app` への適用処理をスキップして停止しない。
- GUI セッションで初回セットアップ完了時は `Ghostty` を自動起動する（再実行時は既定で再起動しない）。

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
- `powerlevel10k` が表示される。
- `~/.config/zsh/.zshrc` と `~/.config/zsh/.p10k.zsh` が存在する。
- `command -v ghostty` が成功する。
- `/Applications/Nix Apps` 配下に `Ghostty.app` が作成される。
- `~/.config/ghostty/config` が存在し、HackGen と Dracula Pro 配色が反映される。
- 主要 alias / functions が機能する。
- `command -v git nix zsh codex claude gemini` が成功する。
- `git config --global user.name` と `git config --global user.email` が期待値を返す。
- HackGen NF / LINE Seed JP / IBM Plex Sans JP / IBM Plex Mono が利用可能。
- `Dracula Pro` private repository のテーマ資産を使って `Terminal.app` の既定プロファイルが `Dracula Pro` になる。
- `Terminal.app` の `Dracula Pro` プロファイルに HackGen 系フォントが設定される。
- GUI セッションの初回 `make init` 完了時に `Ghostty` が自動起動する。
- ヘッドレス環境では `make init` が `setupTerminalDraculaPro` でハングせず完了する。
- Nix Store の自動 GC / 最適化設定が有効になっている。
- 2回連続で `make init` 実行しても破綻しない。
- `.litespec/README.md` に初期化手順と検証手順が記載されている。

## 依存・前提

- インターネット接続。
- GitHub からリポジトリ取得可能（SSH または HTTPS）。
- GitHub へ登録済みの SSH 鍵（private repository 取得のため）。
- macOS で `nix-darwin` 実行可能な管理者権限。
- Xcode Command Line Tools が利用可能。

## テスト観点

- 正常系: クリーン環境で `make init` が完了し、主要コマンドが利用可能になる。
- 異常系: SSH 未設定、CLT 未導入、GUI なし環境で想定どおり fail fast / skip する。
- 回帰: `make init` 再実行時に `.hm-bak` 方針で破綻しない。

## 実装メモ

- 変更追跡と再現性のため `flake.lock` を必須とする。
- マイルストーン管理は README と issue で補完し、仕様の受け入れ条件と整合を取る。
