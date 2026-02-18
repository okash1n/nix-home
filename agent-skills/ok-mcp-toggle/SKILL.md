---
name: ok-mcp-toggle
description: nix-home で asana/notion を必要な時だけ有効化し、作業後に既定構成へ戻す。MCP有効化の手順を覚えずに安全に切り替えたいときに使う。
compatibility: claude,codex,gemini
---

# OK MCP Toggle

## 目的

`asana` / `notion` を必要なセッションだけ有効化し、作業後は最小構成に戻す。  
`make mcp` の既定（`jina` / `claude-mem` のみ有効）を維持したまま、プロジェクト単位で切り替える。

## Trigger Examples

- 「Asana連携が必要だからこの作業中だけMCPを有効化して」
- 「Notionのデータを読むので一時的にON、終わったら戻して」
- 「MCPの有効化手順を覚えてないので代わりに切り替えて」

## Workflow

1. 対象プロジェクトで実行し、保存先を確認する  
   `scripts/mcp_asana_notion.sh paths`
2. プロジェクト用 MCP を有効化する  
   `scripts/mcp_asana_notion.sh on`
3. プロジェクト用環境変数を読み込む  
   `source .nix-home/mcp-project.env`
4. 必要なら OAuth ログインを完了する（Codex）  
   `scripts/mcp_asana_notion.sh login`
5. MCP を使う作業を実行する
6. 作業完了後に `asana` / `notion` を戻す  
   `scripts/mcp_asana_notion.sh off`

## Notes

- `on/off/login/status` は現在ディレクトリ（Git 管理下なら repo root）単位で設定を分離する。
- プロジェクト設定は既定で `.git/nix-home-mcp/`（非 Git ディレクトリでは `.nix-home/mcp/`）に保存する。
- MCP の有効/無効を切り替えた後は、`source .nix-home/mcp-project.env` 済みのシェルで対象 AI CLI を起動する。
- `force_disabled` が `force_enabled` より優先されるため、必要時は `status` で確認する。
- Codex が使えない環境では `login` はスキップし、Claude/Gemini 側の OAuth UI で認可する。

## Resources

- `scripts/mcp_asana_notion.sh`: on/off/status/login をまとめて実行するエントリーポイント
