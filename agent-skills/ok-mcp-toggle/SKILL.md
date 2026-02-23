---
name: ok-mcp-toggle
description: nix-home で setup-mcp 管理下のMCPを必要な時だけ有効化し、作業後に既定構成へ戻す。MCP有効化の手順を覚えずに安全に切り替えたいときに使う。
compatibility: claude,codex,gemini
---

# OK MCP Toggle

## 目的

`setup-mcp` 管理下の MCP（例: `codex` / `jina` / `claude-mem` / `asana` / `notion` / `box`）を必要なセッションだけ有効化し、作業後は最小構成に戻す。  
`make mcp` の既定（`jina` / `claude-mem` のみ有効）を維持したまま、プロジェクト単位で切り替える。

## Trigger Examples

- 「Box連携が必要だからこの作業中だけMCPを有効化して」
- 「このプロジェクトでは `asana notion box` だけONにして」
- 「setup-mcp で定義されている MCP 一覧を見たい」
- 「MCPの有効化手順を覚えてないので代わりに切り替えて」

## Workflow

1. 対象プロジェクトで実行し、保存先を確認する  
   `scripts/mcp_asana_notion.sh paths`
2. 管理対象MCP一覧と既定ターゲットを確認する  
   `scripts/mcp_asana_notion.sh servers`
3. プロジェクト用 MCP を有効化する  
   `scripts/mcp_asana_notion.sh on [--all|server...]`
4. プロジェクト用環境変数を読み込む  
   `source .nix-home/mcp-project.env`
5. 必要なら OAuth ログインを完了する（Codex）  
   `scripts/mcp_asana_notion.sh login [--all|server...]`
6. MCP を使う作業を実行する
7. 作業完了後に有効化した MCP を戻す  
   `scripts/mcp_asana_notion.sh off [--all|server...]`

## Notes

- `on/off/login/status` は現在ディレクトリ（Git 管理下なら repo root）単位で設定を分離する。
- プロジェクト設定は既定で `.git/nix-home-mcp/`（非 Git ディレクトリでは `.nix-home/mcp/`）に保存する。
- 管理対象MCPは `scripts/setup-codex-mcp.sh` / `scripts/setup-claude-mcp.sh` / `scripts/setup-gemini-mcp.sh` の `# MCP:` ヘッダから自動検出する。
- `on/off/login` で引数省略時は、既定で `NIX_HOME_MCP_TOGGLE_DEFAULT_EXCLUDE`（既定: `jina,claude-mem`）以外を対象にする。
- MCP の有効/無効を切り替えた後は、`source .nix-home/mcp-project.env` 済みのシェルで対象 AI CLI を起動する。
- `force_disabled` が `force_enabled` より優先されるため、必要時は `status` で確認する。
- Codex が使えない環境では `login` はスキップし、Claude/Gemini 側の OAuth UI で認可する。

## Resources

- `scripts/mcp_asana_notion.sh`: on/off/status/login/servers/paths をまとめて実行するエントリーポイント
