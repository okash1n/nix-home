# ADR 0012: llm-agents 入力の定期更新を launchd で自動化

- Status: Accepted
- Date: 2026-02-18

## Context

- `llm-agents.nix` は更新頻度が高く、手動更新だけでは Codex / Claude Code / Gemini CLI の追従が遅れやすい。
- 現在の運用では `make update` 実行時にまとめて更新するため、差分把握と反映タイミングが利用者依存だった。
- ユーザー要件として、毎日 `06:00` / `18:00` に定期的に更新処理を走らせたい。
- `make switch` / `make init` 後に launchd 未登録が残らないよう、自己修復可能な登録フローが必要だった。

## Decision

- `scripts/auto-update-llm-agents.sh` を追加し、`nix flake lock --update-input llm-agents` を実行し、差分が出た場合は `darwin-rebuild build/switch` まで自動実行する。
- `scripts/setup-llm-agents-auto-update.sh` を追加し、`~/Library/LaunchAgents/com.okash1n.nix-home.llm-agents-update.plist` を生成・再同期する。
- launchd の `StartCalendarInterval` は 2 本（`06:00` / `18:00`）で構成し、`RunAtLoad=true` を有効化する。
- Home Manager に `home.activation.setupLlmAgentsAutoUpdate` を追加し、`make switch` / `make init`（= switch 経由）時に毎回登録チェックを実施する。
- `scripts/init.sh` にもセットアップスクリプト呼び出しを追加し、初期化時に明示的に登録処理を試行する。
- `darwin-rebuild switch` を launchd から無対話実行できるよう、`modules/darwin/base.nix` の `security.sudo.extraConfig` に `darwin-rebuild` の `NOPASSWD` ルールを追加する。
- 自動更新スクリプトは安全側で動作し、`main` 以外のブランチまたは `flake.lock` 以外の追跡変更がある場合は更新をスキップする。

## Alternatives Considered

1. `make update` の手動運用を継続する: 更新遅延と適用漏れが解消されないため不採用。
2. launchd ではなく cron を使う: macOS 標準運用（ユーザーセッション統合、可観測性）との整合が弱いため不採用。
3. `launchd` 設定を Nix の宣言だけで完結させる: 実ユーザーの `gui/user` domain 再登録を即時自己修復しづらいため不採用。

## Consequences

- `llm-agents` 入力の更新と system 適用（`darwin-rebuild switch`）を 1 日 2 回自動試行できる。
- `make switch` / `make init` 実行時に launchd 未登録状態が残りにくくなる。
- `flake.lock` は自動更新対象になるため、手元作業中の変更状況によっては更新がスキップされる（安全優先）。
- `darwin-rebuild` への `NOPASSWD` 付与により、ユーザーセッションから無対話で system 適用できる一方、sudo 権限の境界は緩くなる。
