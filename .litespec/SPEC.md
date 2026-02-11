# SPEC（インデックス）

このファイルは `nix-home` の「全体概要」と「詳細仕様への導線」を管理します。
機能ごとの詳細は `.litespec/specs/` に分割して管理します。

## 目的

- OS 初期化後に、`make init` 1 回で macOS シェル環境を復旧できるようにする。
- `zsh` / 主要 CLI / AI CLI を短時間で再利用可能にする。
- `Hanabi Theme` を軸に、ターミナル見た目（Ghostty / Terminal.app / Vim / VS Code）を揃える。

## 背景

- OS の再初期化頻度が高く、手動セットアップの反復コストが高い。
- 既存 dotfiles 運用を Nix 前提の宣言的構成へ移行したい。

## スコープ

- `nix-darwin` + `home-manager` による macOS 構成管理
- `init.sh` と `make init` による一発初期化
- `make build` / `make switch` による日常のビルド・適用操作
- `make update` による flake 入力の更新とビルド・適用
- `make mcp` による AI CLI の MCP サーバー設定
- VS Code の設定（settings/keybindings/snippets）と拡張リストの宣言管理
- シェル/CLI/フォント/テーマの再現（Ghostty / Terminal.app / Vim / VS Code）

## 非スコープ

- GUI アプリの全面自動化
- secrets の完全自動配布
- Linux / WSL の本実装（将来拡張の前提整理は実施）

## 対象環境

- 優先: macOS Apple Silicon
- 将来: WSL2 Ubuntu（systemd 有効） / Linux x86_64

## 成功条件（DoD）

- クリーン macOS で `make init` 後、`zsh` が利用可能である（既定プロンプトは `powerlevel10k`、配色は `Hanabi`）。
- クリーン macOS で `make init` 後、ログインシェルが `nix` 管理の `zsh` に設定される。
- `git` / `nix` / `zsh` / `codex` / `claude` / `gemini` / `happy` / `athenai` がコマンド実行可能である。
- Claude Code Team 機能の前提環境変数（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`）が有効である。
- `Ghostty` / `Terminal.app` / `Vim` / `VS Code` に `Hanabi Theme` が適用される。
- VS Code の `settings.json` / `keybindings.json` / snippets が Nix 管理で再現される。
- `make init` を再実行しても破綻しない。
- `make build` でビルドが成功する。
- `make switch` でシステム適用が成功する。
- `make update` で flake 入力を更新しビルド・適用できる。
- `make mcp` で AI CLI の MCP 設定がセットアップされる（未導入コマンドはスキップ）。

## 詳細仕様一覧

- [MVP: macOS ブートストラップ仕様](./specs/001-macos-bootstrap-mvp.md)
- [XDG準拠CLI設定とAGENTS.md統一](./specs/002-xdg-cli-config.md)
- [未管理ファイル検出](./specs/003-unmanaged-files-check.md)

## 変更ルール

- 全体方針に影響する変更: このファイルを更新する
- 機能仕様の変更: 該当する `.litespec/specs/*.md` を更新する
- 大きな技術判断: `.litespec/adr/` に記録する

## 参照

- 詳細仕様ガイド: `.litespec/specs/README.md`
- 詳細仕様テンプレート: `.litespec/specs/0000-template.md`
