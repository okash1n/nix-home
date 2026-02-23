# nix-home での Agent Skill 運用

## ソース管理場所

- `~/nix-home/agent-skills/<skill-name>/`

## 同期先

- `~/.config/claude/skills/<skill-name>`
- `~/.config/codex/skills/<skill-name>`
- `~/.config/gemini/.gemini/skills/<skill-name>`

## 推奨フロー

- 恒久反映: `make switch`（home activation で同期）
- 即時反映: `scripts/sync_links.py`

## 依存ツール方針

- Skill 実装で公式CLIを使う場合、グローバル導入は Nix 経由に統一する。
- attr 探索は `ok-search`、導入は `ok-install` を使う。
- `npm -g` / `pip install` / `go install` / `cargo install` / `brew install` / `curl | sh` をグローバル導入手段として使わない。

## 安全ルール

- 同名の通常ファイル/通常ディレクトリは上書きしない。
- `agent-skills` 以外を指す既存 symlink は上書きしない。
- `agent-skills` 配下の skill は Claude/Codex/Gemini 共通利用を前提に設計する。
