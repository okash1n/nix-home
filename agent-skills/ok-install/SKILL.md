---
name: ok-install
description: nix-home でグローバルCLIを追加・適用・検証する。ユーザーが「グローバルインストールして」「npm -g の代わりに Nix で入れて」「caddy や marp を追加して switch までして」などを依頼したときに使う。~/nix-home/modules/home/base.nix を更新し、make build と make switch、command -v 検証まで実行する。
compatibility: claude,codex,gemini
---

# OK Install

## 目的

`~/nix-home` を唯一のグローバルツール導入経路として使い、以下を1回の流れで完了する。

1. package 追加
2. `make build`
3. `make switch`
4. 動作確認

## 前提

- `~/nix-home` が存在する。
- `make build` / `make switch` が使える。
- macOS の権限要件（App Management など）で `switch` が止まる可能性を考慮する。

## 手順

### 1. 追加対象を決める

- 通常のパッケージは `pkgs` セットに追加する（例: `caddy`, `marp-cli`）。
- `pkgs.llm-agents` 由来のパッケージだけ `llm-agents` セットに追加する（例: `codex`, `claude-code` など）。

### 2. package を追加する

```bash
scripts/install_tool.sh --attr <nix-attr> --verify <command-name>
```

複数コマンド検証:

```bash
scripts/install_tool.sh --attr marp-cli --verify marp
```

`llm-agents` へ追加する場合:

```bash
scripts/install_tool.sh --attr codex --group llm-agents --verify codex
```

### 3. 失敗時の扱い

- `make switch` が権限エラー（App Management）で失敗したら、権限付与を案内して再実行する。
- `attr` が誤っている場合は、代替 `attr` を特定してから再実行する。
- 既に追加済みなら、重複追加せず build/switch/verify だけ行う。

## 品質チェック

- `modules/home/base.nix` に重複がない。
- `make build` が成功する。
- `make switch` が成功する。
- `command -v <verify>` が成功する。

## 実装補助

- package 追加ロジック: `scripts/add_package.py`
- 一括実行: `scripts/install_tool.sh`
- 対象ファイル: `~/nix-home/modules/home/base.nix`
