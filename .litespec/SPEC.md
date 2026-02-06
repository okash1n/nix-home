# SPEC: nix-home (MVP)

## 目的
- OS 初期化後に、1コマンドで macOS シェル環境を復旧できるようにする。
- `zsh` / `powerlevel10k` / 主要 CLI / AI CLI（Codex / Claude Code / Gemini）を短時間で使える状態に戻す。

## 背景
- OS の再初期化頻度が高く、手動セットアップの繰り返しコストが高い。
- 既存 dotfiles 運用を、Nix 前提の宣言的構成へ移行したい。

## ユースケース
- 新規 macOS セットアップ直後に `make init`（または `./init.sh`）を1回実行する。
- 数十分以内に普段使うシェルと CLI が利用可能になる。
- 同じ手順を再実行しても壊れない（冪等）。

## スコープ（MVP）
- `nix-darwin` + `home-manager` による macOS 構成管理。
- `init.sh`（`make init` から呼び出す）による初期導入自動化。
- `zsh` と `powerlevel10k` の再現。
- alias / functions / 基本 CLI の再現。
- AI CLI（Codex / Claude Code / Gemini）の利用可能状態の再現。
- 主要フォントの導入（HackGen NF、LINE Seed JP、IBM Plex JP、IBM Plex Mono）。
- `Dracula Pro`（private repository）を使ったターミナルテーマ適用。

## 非スコープ（MVP）
- GUI アプリの全面自動化（Karabiner、Raycast など）。
- secrets の完全自動配布（`sops-nix` 導入は次フェーズ）。
- Linux / WSL の本実装（将来拡張の前提だけ定義）。

## 対象環境
- 優先: macOS Apple Silicon（実装・検証対象）。
- 将来: WSL2 Ubuntu（systemd 有効）/ Linux x86_64。

## アーキテクチャ方針
- `flake.nix` を単一エントリポイントにする。
- macOS は `nix-darwin` を適用し、ユーザー環境は `home-manager` で管理する。
- `zsh` は `sheldon` 依存を持たず、Nix 設定で完結させる。
- `powerlevel10k` はテーマ本体を Nix で導入し、設定は `.p10k.zsh` として管理する。
- 変更追跡と再現性のため `flake.lock` を必須とする。

## 機能要件

### FR-001 ブートストラップ
- `init.sh` は macOS で `xcode-select -p` を事前確認し、未導入時は導入を促して終了する。
- `init.sh` は GitHub SSH 接続を事前確認し、失敗時は鍵登録を促して終了する。
- `init.sh` は未導入時に Nix を導入する。
- `init.sh` はリポジトリを取得または更新する。
- `init.sh` は `Dracula Pro` private repository を `ghq` 配下に取得または更新する。
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
- `~/.config/zsh/.zshrc` を Nix 管理で生成する。
- `~/.config/zsh/.p10k.zsh` を Nix 管理で生成する。

### FR-004 CLI 再現
- `git`、`curl`、`jq`、`fzf`、`ghq`、`awk`、`grep`、`sed` を導入する。
- `zsh` は macOS 標準ではなくパッケージ版を導入する。
- `bash` もパッケージ版を導入する。
- AI CLI（Codex / Claude Code / Gemini）をコマンド実行可能にする。
- `git` のグローバル設定（`user.name` / `user.email` / global ignore）を Nix 管理で復元する。

### FR-006 フォント導入
- HackGen NF を導入する。
- LINE Seed JP を導入する。
- IBM Plex JP を導入する。
- IBM Plex Mono を導入する。

### FR-008 ストアメンテナンス
- Nix Store のガベージコレクションを自動実行する。
- 古い世代を定期的に削除し、容量増加を抑制する。
- Nix Store の最適化を自動実行する。

### FR-007 ターミナルテーマ管理
- `Ghostty` 本体を Nix 管理で導入する。
- `~/.config/ghostty/config` を Nix 管理で生成し、HackGen と Dracula Pro 配色を適用する。
- `Terminal.app` は `Dracula Pro` プロファイルを既定に設定する。
- GUI セッションが有効な環境では、`Terminal.app` の起動有無に依存せずテーマ適用処理（import / defaults / フォント設定）を試行する。
- `Dracula Pro` が未取得の場合は処理をスキップし、復旧手順をログに表示する。
- GUI セッションが無い環境では `Terminal.app` への適用処理をスキップして停止しない。

### FR-005 冪等性
- 同一マシンで `make init`（または `./init.sh`）を再実行しても、致命的エラーで停止しない。
- 再実行後もシェル設定が破損しない。
- 既存 dotfile と管理対象が衝突した場合は、自動バックアップして適用を継続する。
- 過去 Nix installer が残した `/etc/*rc.backup-before-nix` 衝突を自動退避し、初期化を継続する。

## 非機能要件
- 再現性: `flake.lock` 固定で同一構成を再現できる。
- 可観測性: ブートストラップログで失敗箇所を追跡できる。
- 保守性: `hosts/` `home/` `modules/` を分割し、責務を明確化する。
- 更新性: 必要に応じてパッケージのバージョン更新を行える。

## DoD（受け入れ条件）
- クリーン macOS で `make init` 実行後、ログインシェルが `zsh` で起動する。
- `powerlevel10k` が表示される。
- `~/.config/zsh/.zshrc` と `~/.config/zsh/.p10k.zsh` が存在する。
- `command -v ghostty` が成功する。
- `~/.config/ghostty/config` が存在し、HackGen と Dracula Pro 配色が反映される。
- 主要 alias / functions が機能する。
- `command -v git nix zsh codex claude gemini` が成功する。
- `git config --global user.name` と `git config --global user.email` が期待値を返す。
- HackGen NF / LINE Seed JP / IBM Plex JP / IBM Plex Mono が利用可能。
- `Dracula Pro` private repository のテーマ資産を使って `Terminal.app` の既定プロファイルが `Dracula Pro` になる。
- ヘッドレス環境では `make init` が `setupTerminalDraculaPro` でハングせず完了する。
- Nix Store の自動 GC / 最適化設定が有効になっている。
- 2回連続で `make init` 実行しても破綻しない。
- `.litespec/README.md` に初期化手順と検証手順が記載されている。

## 実装マイルストーン
- M1: flake 骨格（`nix-darwin` + `home-manager`）と `init.sh` / `make init` の最小導入。
- M2: `zsh` / `powerlevel10k` / alias / functions の移行。
- M3: 基本 CLI と AI CLI の移行、`.litespec/README.md` の検証手順整備。
- M4: 再実行テストと不具合修正。

## 依存・前提
- インターネット接続。
- GitHub からリポジトリ取得可能（SSH または HTTPS）。
- GitHub へ登録済みの SSH 鍵（private repository 取得のため）。
- macOS で `nix-darwin` 実行可能な管理者権限。
- Xcode Command Line Tools が利用可能。

## リスク・懸念
- AI CLI の認証情報投入は初期フェーズでは手動になる可能性がある。
- GUI アプリ設定を初期段階で含めるとスコープが過大化する。
- 初回 Nix 導入時の失敗原因が環境依存になりやすい。

## 変更範囲
- `flake.nix` / `flake.lock`
- `init.sh`
- `Makefile`
- `hosts/`
- `home/`
- `modules/`
- `.litespec/README.md`
- `.litespec/adr/`

## 参照
- Nix: https://nixos.org/
- home-manager: https://github.com/nix-community/home-manager
- nix-darwin: https://github.com/LnL7/nix-darwin
