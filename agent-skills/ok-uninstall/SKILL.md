---
name: ok-uninstall
description: nix-home でグローバルCLIを削除・適用・検証する。ユーザーが「このツールをグローバルから外して」「nix-home から消して switch までして」などを依頼したときに使う。~/nix-home/modules/home/base.nix から attr を削除し、make build と make switch、必要なら command -v の不在確認まで実行する。
compatibility: claude,codex,gemini
---

# OK Uninstall

## 目的

`~/nix-home` から不要なグローバルツールを安全に外し、環境に反映する。

## 手順

### 1. 削除対象を決める

- `pkgs` 由来なら `--group pkgs`
- `pkgs.llm-agents` 由来なら `--group llm-agents`

### 2. 削除して反映する

```bash
scripts/uninstall_tool.sh --attr <nix-attr> [--group pkgs|llm-agents]
```

コマンド不在まで確認する場合:

```bash
scripts/uninstall_tool.sh --attr marp-cli --verify marp
```

### 3. 失敗時

- `make switch` が権限エラーで止まる場合は、権限付与後に再実行する。
- 既に削除済みでも build/switch は継続し、最終状態を検証する。

## 品質チェック

- `modules/home/base.nix` から対象 attr が消えている。
- `make build` が成功する。
- `make switch` が成功する。
- `--verify` を指定した場合、`command -v` が失敗する。

## 実装補助

- package 削除ロジック: `scripts/remove_package.py`
- 一括実行: `scripts/uninstall_tool.sh`
