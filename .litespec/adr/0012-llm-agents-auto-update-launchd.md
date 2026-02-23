# ADR 0012: llm-agents 入力の定期更新を launchd で自動化

- Status: Accepted
- Date: 2026-02-18

## Context

- `llm-agents.nix` は更新頻度が高く、手動更新だけでは Codex / Claude Code / Gemini CLI の追従が遅れやすい。
- 現在の運用では `make update` 実行時にまとめて更新するため、差分把握と反映タイミングが利用者依存だった。
- ユーザー要件として、毎日 `06:00` / `18:00` に定期的に更新処理を走らせたい。
- `make switch` / `make init` 後に launchd 未登録が残らないよう、自己修復可能な登録フローが必要だった。

## Decision

- `scripts/auto-update-llm-agents.sh` は `~/nix-home` とは別の専用 clean worktree を使って `nix flake lock --update-input llm-agents` を実行し、`home-manager switch` を自動実行する。
- `scripts/setup-llm-agents-auto-update.sh` を追加し、`~/Library/LaunchAgents/com.okash1n.nix-home.llm-agents-update.plist` を生成・再同期する。
- launchd の `StartCalendarInterval` は 2 本（`06:00` / `18:00`）で構成し、`RunAtLoad=true` を有効化する。
- Home Manager に `home.activation.setupLlmAgentsAutoUpdate` を追加し、`make switch` / `make init`（= switch 経由）時に毎回登録チェックを実施する。
- `scripts/init.sh` にもセットアップスクリプト呼び出しを追加し、初期化時に明示的に登録処理を試行する。
- 自動更新スクリプトは `NIX_HOME_LLM_AGENTS_UPDATE_REMOTE/NIX_HOME_LLM_AGENTS_UPDATE_BRANCH` を基準に専用 worktree を毎回クリーン化して実行し、`~/nix-home` 側のブランチや追跡変更の有無に依存しない。
- system 設定の適用（`darwin-rebuild switch`）は手動運用に分離する。

## Alternatives Considered

1. `make update` の手動運用を継続する: 更新遅延と適用漏れが解消されないため不採用。
2. launchd ではなく cron を使う: macOS 標準運用（ユーザーセッション統合、可観測性）との整合が弱いため不採用。
3. `launchd` 設定を Nix の宣言だけで完結させる: 実ユーザーの `gui/user` domain 再登録を即時自己修復しづらいため不採用。

## Consequences

- `llm-agents` 入力更新と Home Manager 適用（`home-manager switch`）を 1 日 2 回自動試行できる。
- `make switch` / `make init` 実行時に launchd 未登録状態が残りにくくなる。
- `~/nix-home` 側の手元変更と自動更新処理を分離できるため、作業中でも定期更新フローを継続しやすい。
- 定期ジョブは root 権限に依存しないため、App Management 制約による停止要因を切り離せる。
