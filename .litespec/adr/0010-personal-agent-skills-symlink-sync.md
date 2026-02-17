# ADR 0010: 個人用 agent skills をリポジトリ管理し各CLIへ symlink 同期する

- Status: Accepted
- Date: 2026-02-17

## Context

- 個人用 skill を `nix-home` 側で宣言的に管理したい。
- Claude / Codex / Gemini の各 `skills/` ディレクトリには、公式 skill がアプリ側から追加される可能性がある。
- 各 `skills/` ディレクトリ全体を Nix で置き換えると、公式 skill との競合や上書きが発生する。
- `make init` / `make switch` 時に自動同期される運用が必要。

## Decision

- 個人用 skill のソースを `~/nix-home/agent-skills`（`NIX_HOME_AGENT_SKILLS_DIR`）で管理する。
- `home.activation.setupAgentSkills` を追加し、`make init` / `make switch` 時に以下へ skill 単位で symlink 同期する。
  - `~/.config/claude/skills`
  - `~/.config/codex/skills`
  - `~/.config/gemini/.gemini/skills`
- `SKILL.md` を持つディレクトリだけを有効な skill とみなす。
- 既存の通常ファイル/通常ディレクトリ（非 symlink）は上書きしない。
- 既存 symlink が `NIX_HOME_AGENT_SKILLS_DIR` 配下を指していない場合は上書きしない。
- 過去に同期された symlink（`NIX_HOME_AGENT_SKILLS_DIR` 配下を指すもの）だけをクリーンアップ対象にする。

## Consequences

- 個人用 skill は `nix-home` の Git 管理下で一元運用できる。
- 公式 skill との共存が可能で、アプリ側インストールを阻害しない。
- 同名 skill が既に通常ディレクトリとして存在する場合は同期されないため、命名衝突を避ける運用（例: `ok-` 接頭辞）が必要。

## Alternatives Considered

1. **各エージェントの `skills/` ディレクトリ全体を Nix 管理する**
   - 利点: 宣言的管理が単純。
   - 欠点: 公式 skill と競合しやすく、ユーザーのアプリ操作を阻害するため不採用。

2. **専用 `make` ターゲットでのみ同期する**
   - 利点: 実装が単純。
   - 欠点: 実行忘れで状態ドリフトしやすいため不採用。

3. **symlink ではなく skill をコピーする**
   - 利点: エージェント側から見て通常ディレクトリとして扱える。
   - 欠点: 3箇所に複製が発生し、更新同期が複雑になるため不採用。
