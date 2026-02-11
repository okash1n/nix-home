# ADR 0008: Happy CLI を llm-agents で導入し XDG 設定へ統一する

- Status: Accepted
- Date: 2026-02-11

## Context

- `nix-home` は AI CLI を `llm-agents` overlay（`codex` / `claude-code` / `gemini-cli`）で一元管理している。
- Happy CLI の推奨導入は `npm install -g happy-coder` だが、このリポジトリ方針ではグローバル直インストールを許可しない。
- 既存の XDG 方針では `CLAUDE_CONFIG_DIR` / `CODEX_HOME` / `GEMINI_CLI_HOME` を `~/.config/*` に統一している。
- Happy 既定の `~/.happy` をそのまま使うと、XDG 統一方針とホーム直下整理方針に反する。

## Decision

- Happy CLI は `pkgs.llm-agents.happy-coder` で導入する。
- 環境変数 `HAPPY_HOME_DIR` を `~/.config/happy`（launchd は絶対パス）に固定する。
- 旧パス誤利用の検知として `~/.happy` に番兵ファイルを配置する。
- 共通指示ファイルを `~/.config/happy/AGENTS.md` にも配置し、他 AI CLI と同じ運用ルールを適用する。

## Consequences

- Happy CLI も他 AI CLI と同じ導入経路（Nix）・同じ設定配置（XDG）で運用できる。
- `npm -g` を使わずに再現可能な環境を維持できる。
- `~/.happy` を期待する既存ローカル運用がある場合は移行が必要になる。
- `llm-agents` 側の更新タイミングに `happy-coder` バージョンが追随するため、厳密固定が必要な場合は別途 pin 戦略が必要になる。

## Alternatives Considered

1. **`npm install -g happy-coder` を使う**
   - 利点: upstream 推奨手順に一致する。
   - 欠点: リポジトリ方針（グローバル直インストール禁止）に違反するため不採用。

2. **`~/.happy` の既定値を維持する**
   - 利点: upstream 既定に合わせられる。
   - 欠点: XDG 統一方針とホーム直下整理方針に反するため不採用。

3. **Happy だけ独自 derivation でバージョン固定する**
   - 利点: 版管理を厳密に制御できる。
   - 欠点: 保守コストが増え、既存の `llm-agents` 一元管理方針から外れるため現時点では不採用。
