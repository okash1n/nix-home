---
name: "ok-jina"
description: "Jina MCP の read/search ツール群（read_url, parallel_read_url, search_arxiv, search_ssrn, search_bibtex）を direct API とローカルスクリプトで実行する。MCP接続を避けたいときに使う。"
compatibility: "claude,codex,gemini"
metadata:
  source_manifest: "references/source-manifest.json"
  source_manifest_required: true
---

# Ok Jina

## Overview

MCP サーバーを有効化せずに、Jina の主要 read/search 機能を直接 API で実行する。
現時点では、nix-home の Jina MCP フィルタ構成と同じ 5 ツールを対象にする。

## Trigger Examples

- 「このURLを本文抽出して要約したい。MCPは使いたくない」
- 「arXiv/SSRNを検索して論文候補を出したい」
- 「BibTeX をまとめて出したい」
- 「MCP無効のまま Jina 相当機能を使いたい」

## Workflow

1. 要求を 5 機能のどれかにマップする  
`read-url`, `parallel-read-url`, `search-arxiv`, `search-ssrn`, `search-bibtex`
2. 必要なら `JINA_API_KEY` の有無を確認する  
`search-arxiv` / `search-ssrn` は必須、`read-url` は任意、`search-bibtex` は不要
3. `scripts/jina_ops.py` を実行して JSON を取得する
4. 取得結果を用途別に整形する（要約、比較、引用作成など）
5. 失敗時は API エラー分類に沿って再試行または代替経路へ切り替える

## Source Evidence

- 根拠ソースは `references/source-manifest.json` に記録済み
- 仕様追従時は `snapshot` と `retrieved_at` を必ず更新する

## Implementation Strategy

比較対象:

- 公式CLI
- 公式SDK
- 直接HTTP

選定結果:

- 現時点の対象5機能に対しては direct HTTP を採用する
  - `read_url` / `parallel_read_url`: `https://r.jina.ai/`
  - `search_arxiv` / `search_ssrn`: `https://svip.jina.ai/`
  - `search_bibtex`: DBLP + Semantic Scholar を直接参照

理由:

- 5機能を最短で deterministic に実装できる
- MCP接続・MCP設定依存を排除できる
- 検索/抽出ロジックを `scripts/jina_ops.py` で一元管理できる

## Tool Parity

MCP 構成（`include_tags=search,read` + 一部除外）で実運用していた範囲を対象にする。

- `read_url` -> `jina_ops.py read-url`
- `parallel_read_url` -> `jina_ops.py parallel-read-url`
- `search_arxiv` -> `jina_ops.py search-arxiv`
- `search_ssrn` -> `jina_ops.py search-ssrn`
- `search_bibtex` -> `jina_ops.py search-bibtex`

`search_web`, `search_images`, `capture_screenshot_url`, `search_jina_blog` は対象外。

## Commands

```bash
# single URL
scripts/jina_ops.py read-url --url https://example.com --pretty

# multiple URLs
scripts/jina_ops.py parallel-read-url --url https://example.com --url https://example.org --pretty

# arXiv search (JINA_API_KEY required)
scripts/jina_ops.py search-arxiv --query "transformer optimization" --num 10 --pretty

# SSRN search (JINA_API_KEY required)
scripts/jina_ops.py search-ssrn --query "behavioral finance" --num 10 --pretty

# BibTeX search (no JINA_API_KEY required)
scripts/jina_ops.py search-bibtex --query "attention is all you need" --num 5 --pretty
```

## Error Handling

- HTTP 401/403: `JINA_API_KEY` 設定と権限を確認
- HTTP 429: 待機して再試行（必要なら `num` を減らす）
- HTTP 5xx: 一時障害として再試行
- 並列実行 timeout: `--timeout` を引き上げるか URL/検索数を減らす

## Agent Compatibility

- `compatibility` は `claude,codex,gemini` にする。
- 特定エージェント専用の処理だけに依存しない。
- 専用処理が必要な場合は代替手順を併記する。

## Resources

- `scripts/jina_ops.py`: 実行本体（5機能）
- `scripts/test_jina_ops.py`: ヘルパー処理のユニットテスト
- `references/source-manifest.json`: 根拠ソースのスナップショット
