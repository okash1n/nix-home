# ADR 0009: Claude Team 有効化と athenai ラッパーの Nix 管理

- Status: Accepted
- Date: 2026-02-11

## Context

- Claude Code Team 機能を利用するには、実行環境で `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` が必要。
- 既存環境では起動経路（launchd / VS Code 統合ターミナル / login shell）により、環境変数が欠落するケースがある。
- Team 実行時の挙動（`teammateMode`）を毎回手動設定すると再現性が落ちる。
- `athenai` は別リポジトリ（`~/ghq/github.com/athenai-dev/athenai`）で開発しており、Claude Code から統一コマンドで呼び出したい。
- 本リポジトリ方針では、CLI 導線は `nix-home` で宣言的に管理する。

## Decision

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` を system / launchd / shell fallback の全レイヤーで配布する。
- `home.activation` で `~/.config/claude/settings.json` を検査し、`teammateMode` が未設定の場合のみ `auto` を追記する。
  - `settings.json` が存在しない場合は `{"teammateMode":"auto"}` で新規作成する。
  - 既存の `teammateMode` は上書きしない（ユーザー設定優先）。
  - 不正 JSON は更新せずに警告してスキップする。
- `pkgs.writeShellScriptBin` で `athenai` ラッパーを提供し、既定で `~/ghq/github.com/athenai-dev/athenai` を参照する。
  - `ATHENAI_REPO` が指定された場合はそのパスを優先する。
  - 参照先が不正な場合は明示的エラーで終了する。

## Consequences

- Claude Code Team 機能が起動経路に依存せず安定して有効化される。
- `teammateMode` の初期設定が自動化されつつ、既存のユーザー設定は保持される。
- Claude Code から `athenai` を固定コマンドで実行でき、環境再構築後も導線が再現される。
- `athenai` の実体リポジトリが未配置の場合、ラッパーは実行失敗するためセットアップ確認が必要。

## Alternatives Considered

1. **`~/.config/claude/settings.json` を手動編集する**
   - 利点: 実装が最小。
   - 欠点: 再構築時に再現できず、運用ミスが起きやすいため不採用。
2. **`teammateMode` を常に上書きする**
   - 利点: 設定が揃う。
   - 欠点: 利用者が選んだ値を壊すため不採用。
3. **`athenai` を各シェル alias で定義する**
   - 利点: 実装が簡単。
   - 欠点: シェル依存で再現性が落ち、非対話環境で使いにくいため不採用。
