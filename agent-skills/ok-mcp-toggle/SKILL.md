---
name: ok-mcp-toggle
description: nix-home で asana/notion を必要な時だけ有効化し、作業後に既定構成へ戻す。MCP有効化の手順を覚えずに安全に切り替えたいときに使う。
compatibility: claude,codex,gemini
---

# OK MCP Toggle

## 目的

`asana` / `notion` を必要なセッションだけ有効化し、作業後は最小構成に戻す。  
環境変数の組み合わせを毎回思い出さず、決め打ちスクリプトで切り替える。

## Trigger Examples

- 「Asana連携が必要だからこの作業中だけMCPを有効化して」
- 「Notionのデータを読むので一時的にON、終わったら戻して」
- 「MCPの有効化手順を覚えてないので代わりに切り替えて」

## Workflow

1. 一時有効化を実行する  
   `scripts/mcp_asana_notion.sh on`
2. 状態を確認する  
   `scripts/mcp_asana_notion.sh status`
3. 必要なら OAuth ログインを完了する（Codex）  
   `scripts/mcp_asana_notion.sh login`
4. MCP を使う作業を実行する
5. 作業完了後に既定構成へ戻す  
   `scripts/mcp_asana_notion.sh off`

## Notes

- MCP の有効/無効を切り替えた後は、対象 AI CLI の新しいセッションを開始して反映する。
- `force_disabled` が `force_enabled` より優先されるため、必要時は `status` で確認する。
- Codex が使えない環境では `login` はスキップし、Claude/Gemini 側の OAuth UI で認可する。

## Resources

- `scripts/mcp_asana_notion.sh`: on/off/status/login をまとめて実行するエントリーポイント
