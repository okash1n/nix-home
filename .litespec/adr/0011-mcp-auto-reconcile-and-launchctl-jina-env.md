# ADR 0011: MCP 自動再同期と launchctl への JINA_API_KEY 反映

- Status: Accepted
- Date: 2026-02-18

## Context

- `make mcp` の手動実行時のみ MCP 設定が更新され、`make switch` / `make init` では同期されなかった。
- 既存の MCP セットアップは「設定済みならスキップ」だったため、`JINA_API_KEY` の更新や誤設定から自動復旧できなかった。
- Codex の `mcp-remote` + `${JINA_API_KEY}` ヘッダー方式では、環境変数展開に依存して未認証になるケースがあった。
- GUI 起動経路では `launchctl` 側の `JINA_API_KEY` 不在が起こり得た。

## Decision

- `scripts/setup-mcp.sh` を MCP 同期の共通エントリーポイントとして追加する。
- `Makefile` の `mcp` ターゲットは `setup-mcp.sh` を呼び出す。
- Home Manager に `home.activation.setupMcpServers` を追加し、`sops-nix` 後に `setup-mcp.sh` を実行する。
- `setup-mcp.sh` は `sops-env.sh` を読み込み、`launchctl setenv/unsetenv JINA_API_KEY` を実行して GUI プロセス向け環境も同期する。
- MCP の既定有効状態は `NIX_HOME_MCP_DEFAULT_ENABLED`（既定 `0`）で制御する。
- MCP の例外は `NIX_HOME_MCP_FORCE_ENABLED` / `NIX_HOME_MCP_FORCE_DISABLED` で制御し、既定は `NIX_HOME_MCP_FORCE_ENABLED=jina,claude-mem` とする。
- MCP 設定は「スキップ」ではなく再同期（reconcile）を基本にする。
  - Codex: `jina` を streamable HTTP + `bearer_token_env_var=JINA_API_KEY` で設定し、`enabled` フラグを `NIX_HOME_MCP_DEFAULT_ENABLED` に追従させる。
  - Codex: `asana` / `notion` は OAuth 互換性のため `npx -y mcp-remote <url>`（stdio bridge）で設定し、`enabled` フラグを `NIX_HOME_MCP_DEFAULT_ENABLED` に追従させる。
  - Claude: `NIX_HOME_MCP_DEFAULT_ENABLED` と force 例外に応じて user scope の `codex` / `jina` / `asana` / `notion` を再設定または remove する（disable 機能がないため）。
  - Gemini: `~/.config/gemini/.gemini/settings.json` の `mcpServers` を upsert し、`~/.config/gemini/.gemini/mcp-server-enablement.json` で enabled 状態を管理する。

## Alternatives Considered

1. `make mcp` の手動運用を継続する: 適用漏れが発生しやすく、キー更新の追従も遅れるため不採用。
2. `launchd.user.envVariables` に実キーを直接入れる: Nix store にシークレットが露出するため不採用。
3. Codex を `mcp-remote --header` のまま維持する: 環境変数展開失敗時の不安定さが残るため不採用。

## Consequences

- `make switch` / `make init` で MCP 設定が自動同期され、手動の `make mcp` は再同期用途に限定される。
- `JINA_API_KEY` 更新後の追従性が改善され、Codex の Jina 認証失敗を回避しやすくなる。
- MCP 設定不整合の自己修復が可能になる一方、各 CLI 設定への再書き込み頻度は増える。
- Claude は既定OFF時に server remove となるため、既定ON運用へ切り替える際は `NIX_HOME_MCP_DEFAULT_ENABLED=1 make mcp`（または `make switch`）が必要になる。
