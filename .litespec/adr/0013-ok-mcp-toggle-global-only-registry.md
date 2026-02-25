# ADR 0013: ok-mcp-toggle を global-only レジストリ管理へ再設計する

- Status: Superseded
- Date: 2026-02-24

> Superseded by ADR 0014 (`global/project` 両対応への再拡張)。

## Context

- 既存の `ok-mcp-toggle` は、プロジェクト状態ファイルとホーム配下設定更新が混在し、責務が曖昧だった。
- `codex` の MCP 管理は project scope 前提での統一が難しく、`claude` / `gemini` と同一モデルで扱うと運用が不安定になる。
- 利用者要件として、引数記憶に依存しない対話中心の運用、`add` 時の事前認証、一覧と状態の可視化が必要になった。

## Decision

- `ok-mcp-toggle` を global-only MCP 管理ツールとして再設計する。
- 管理対象クライアントは `claude` / `gemini` とし、`codex` は対象外とする。
- データモデルを以下へ分離する:
  - `registry.json`: 静的定義（MCP定義）
  - `state.json`: 動的状態（preauth結果、最終エラー等）
- CLI を以下へ再編する:
  - `list`, `add`, `remove`, `enable`, `disable`, `status`, `preauth`
- 対話モードを既定とし、非対話実行は明示引数時のみ許可する。
- `add` は常に事前認証を実行し、失敗時は登録しない。
- `remove` はレジストリ削除に加え、対象クライアントから設定削除/無効化を行う。
- 認証情報はホーム配下に保持し、`remove` で削除しない。
- `scope=project` の登録を禁止する。

## Consequences

- 利点:
  - 管理責務が明確になり、意図しないプロジェクト横断影響を抑えやすくなる。
  - レジストリと状態の分離により、一覧性と障害調査性が向上する。
  - 対話中心化により、日常操作のミスを減らせる。
- トレードオフ:
  - 既存CLIとの互換性は失われるため、利用者の再学習が必要になる。
  - 自動化用途では非対話引数の設計を明確に維持する必要がある。

## Alternatives

1. 既存 `on/off/apply/...` を維持したまま段階的改修する  
   - 一時的に混乱は減るが、旧設計の曖昧さを温存するため不採用。
2. project scope 管理を維持しつつ global 管理と併存する  
   - 実装・運用複雑性が高く、現在要件（global中心）と一致しないため不採用。
3. `codex` を含む3クライアント統一制御を継続する  
   - `codex` 側の性質差により統一モデルが破綻しやすいため不採用。
