---
name: ok-mcp-toggle
description: ok-mcp-toggle が管理する MCP を global/project scope で有効化/無効化する。管理対象は claude/gemini で、codex は対象外。
compatibility: claude,gemini
---

# OK MCP Toggle

## 目的

`ok-mcp-toggle` 管理下の MCP を `global/project` 両対応で管理する。
対象クライアントは `claude` / `gemini`。`codex` は管理対象外。
認証情報はホーム配下に保持し、レジストリには機密値を保存しない。

## User Interaction Contract

- ユーザーに `scripts/mcp_toggle.sh` や CLI の直接実行を要求しない。
- 有効化/無効化/追加/削除は常にエージェントが代行する。
- 変更系コマンド（`add` / `enable` / `disable` / `remove` / `preauth`）の前に、必ず1回は確認ターンを挟む。
- 実行前に必要な選択（対象MCP、scope、clients、ignore方針）をユーザーに確認してから実行する。
- エージェントが推測で `ignore-target` や `clients` を決めて実行しない。

## Trigger Examples

- 「MCP 一覧を見せて」
- 「notion と asana を有効化して」
- 「box を remove して」
- 「ok-mcp-toggle で管理している MCP 一覧を見たい」
- 「Jina を add して preauth までやって」

## Workflow

1. 一覧を確認する  
   `scripts/mcp_toggle.sh list`
2. 必要ならガイド付きで追加する（add は常に preauth 実行）  
   `scripts/mcp_toggle.sh add [name] --preset PRESET --scope global|project --clients <...>`
3. 有効化する（project を含む場合は ignore 方針を明示）  
   `scripts/mcp_toggle.sh enable <servers...> --scope <global|project|all> --clients <...> --ignore-target <gitignore|exclude|none> --ignore-granularity <mcp|client>`
4. 状態を確認する  
   `scripts/mcp_toggle.sh status`
5. 不要なものを無効化・削除する  
   `scripts/mcp_toggle.sh disable` / `scripts/mcp_toggle.sh remove`

## Notes

- `scope=global` はユーザー設定、`scope=project` はプロジェクト設定に反映する。
- `enable/disable/preauth/status/remove` は scope を選択できる。
- `enable` で project scope を含む場合、ignore 方針（`.gitignore` / `.git/info/exclude` / 追加しない）を必ず決定してから実行する。
- `mcp_toggle.sh` は非対話CLIとして扱い、暗黙の既定値を使わない（`--clients` / 対象MCP / `--ignore-target` を必須化）。
- 対話はスクリプト側ではなくエージェント側の責務で行う。
- `codex` は管理対象外。`claude` / `gemini` のみ反映する。
- レジストリは `config/registry.json`、状態は `config/state.json`。
- `add` は事前認証（preauth）失敗時に登録しない。
- `box` は HTTP MCP として `claude/gemini` に設定する。旧 `codex + mcp-remote callback` 方式は使わない。
- `list` / `status` は、`codex` に旧MCP設定（asana/notion/box/jina）が残っている場合に警告を出す。
- `asana` / `box` は Claude で OAuth client 情報が必要なため、`ASANA_MCP_CLIENT_ID` / `ASANA_MCP_CLIENT_SECRET` と `BOX_MCP_CLIENT_ID` / `BOX_MCP_CLIENT_SECRET` を使用する。
- `asana` の endpoint はクライアント別に分ける（Claude: `https://mcp.asana.com/v2/mcp`、Gemini: `https://mcp.asana.com/mcp`）。
- `asana` / `notion` の Gemini 定義には OAuth エンドポイントを明示する（`oauth.authorizationUrl/tokenUrl/registrationUrl`）。これにより `/mcp auth` 時の動的 discovery 起因の resource mismatch を回避する。
- `oauth` の preauth は完全自動ではない。`status` が `needs-auth` / `pending_user_auth` の場合はクライアント側で最終認証が必要。

## Resources

- `scripts/mcp_toggle.sh`: list/add/remove/enable/disable/status/preauth のエントリーポイント
- `config/registry.json`: 管理対象MCPの静的定義
- `config/state.json`: preauth 状態と最終エラー
