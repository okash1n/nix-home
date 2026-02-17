---
name: ok-search
description: nix-home でグローバルCLI候補を探索する。ユーザーが「このツール入る？」「attr は何？」「brew search 的に探して」などを依頼したときに使う。現在の nix-home 反映状況、nixpkgs 検索、llm-agents overlay 検索をまとめて実行する。
compatibility: claude,codex,gemini
---

# OK Search

## 目的

グローバルツール追加前に、候補 attr と現在状態を素早く確認する。

## 手順

### 1. 検索実行

```bash
scripts/search_tool.sh --query <keyword>
```

このコマンドは以下を表示する:

- `modules/home/base.nix` の現在インストール済み attr（`pkgs` / `llm-agents`）
- `nix search nixpkgs <query>` の結果
- `llm-agents` overlay の一致 attr

### 2. 結果の扱い

- 目的に合う attr が見つかったら `ok-install` を使って導入する。
- 削除相談なら `ok-uninstall` を使う。

## 品質チェック

- ローカル反映状況（installed）が表示される。
- `nixpkgs` 検索が実行される（ネットワーク条件依存）。
- `llm-agents` 検索結果が表示される。

## 実装補助

- ローカル一覧抽出: `scripts/search_package.py`
- 統合検索: `scripts/search_tool.sh`
