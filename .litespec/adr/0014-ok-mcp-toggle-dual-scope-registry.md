# ADR 0014: ok-mcp-toggle を global/project 両対応にする

- Status: Accepted
- Date: 2026-02-25

## Context

- 実運用では「常時有効化（global）」と「プロジェクト時のみ有効化（project）」の2パターンが必要。
- global-only 運用では、プロジェクト単位での有効化要件を満たせない。
- OAuth 認証情報はホーム配下に保持し、プロジェクト側は設定宣言のみ持つ設計が要件。

## Decision

- `ok-mcp-toggle` は `global` / `project` の両スコープを扱う。
- レジストリの各 MCP に `scope` を持たせ、`enable/disable/remove/status/preauth` で反映する。
- クライアント差異はアダプタで吸収する:
  - Claude: `--scope user|project`
  - Gemini: user settings / project settings を使い分け
- `project` 有効化時は ignore 方針（`.gitignore` / `.git/info/exclude` / 追加しない）を対話で選択可能にする。
- `codex` は引き続き対象外。

## Consequences

- 利点:
  - 利用形態に応じた最小権限で MCP を配置できる。
  - 同一レジストリで global/project 運用を統一できる。
- トレードオフ:
  - クライアントごとの scope 実装差を吸収する保守コストが増える。
  - OAuth preauth は完全自動化できず、最終認証が必要なケースが残る。

## Alternatives

1. global-only を維持する  
   - プロジェクト限定有効化の要件を満たせないため不採用。
2. project-only に寄せる  
   - 常時利用MCPの運用コストが上がるため不採用。
3. codex も同一トグル対象に含める  
   - 現状の運用方針（codex は対象外）と矛盾するため不採用。

