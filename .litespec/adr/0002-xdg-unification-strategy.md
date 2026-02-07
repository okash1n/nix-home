# ADR 0002: XDG準拠への統一とソースディレクトリ構造

- Status: Accepted
- Date: 2025-02-08

## Context

- AI CLI（Claude Code / Codex / Gemini）がそれぞれ `~/.claude/`、`~/.codex/`、`~/.gemini/` に設定を保存し、ホームディレクトリが散らかる。
- 3つのCLIがそれぞれ異なる指示ファイル（`CLAUDE.md`、`AGENTS.md`、`GEMINI.md`）を参照するため、共通ルールを伝える方法がない。
- Nix管理のソースファイル（`home/zsh/` など）と展開先（`~/.config/zsh/`）の対応が直感的でない。
- プロジェクトの `AGENTS.md`（litespec運用ルール）をAI CLIが見逃す可能性がある。

## Decision

### 1. 設定ディレクトリを `~/.config/` に統一する

環境変数で各CLIの設定ディレクトリを `~/.config/` 配下に変更する。

```nix
home.sessionVariables = {
  CLAUDE_CONFIG_DIR = "$HOME/.config/claude";
  CODEX_HOME = "$HOME/.config/codex";
  GEMINI_CLI_HOME = "$HOME/.config/gemini";
  VIMINIT = "source $HOME/.config/vim/vimrc";
};
```

### 2. ソースディレクトリ構造を展開先と対応させる

Nix管理のソースファイルを `home/dot_config/` に集約し、展開先（`~/.config/`）と1対1で対応させる。

```
home/dot_config/zsh/     → ~/.config/zsh/
home/dot_config/claude/  → ~/.config/claude/
home/dot_config/vim/     → ~/.config/vim/
```

### 3. AGENTS.md で3つのCLIを統一する

グローバル共通指示を `~/.config/AGENTS.md` に配置し、各CLIの指示ファイルから参照させる。

```
~/.config/AGENTS.md           ← グローバル共通指示
~/.config/claude/CLAUDE.md    ← 「AGENTS.md を見ろ」と記載
~/.config/codex/AGENTS.md     ← 「AGENTS.md を見ろ」と記載
~/.config/gemini/GEMINI.md    ← 「AGENTS.md を見ろ」と記載
```

各指示ファイルには以下の参照順序を記載する：
1. `~/.config/AGENTS.md`（グローバル共通）
2. プロジェクト直下の `AGENTS.md`（プロジェクト固有、存在する場合）

## Consequences

### 期待される効果

- ホームディレクトリがクリーンになる（`~/.config/` に集約）。
- 3つのAI CLIが同じルールで動作する。
- プロジェクトの `AGENTS.md`（litespec運用など）を見逃さなくなる。
- ソースファイルを見るだけで展開先が分かる。
- 新規ファイル追加時に配置場所で迷わない。

### トレードオフ

- 既存の `~/.claude/` 等から手動で移行が必要。
- 環境変数を設定しないと動作しない（Nix管理前提）。
- XDG非準拠アプリごとに環境変数を調べる必要がある。

## Alternatives

### A1: デフォルトのまま使う

各CLIのデフォルトディレクトリ（`~/.claude/` 等）をそのまま使用する。

却下理由：
- ホームディレクトリが散らかる。
- 3つのCLIに共通ルールを伝える方法がない。

### A2: ソースディレクトリを `dotconfig/` にする

`home/` ディレクトリを使わず、`dotconfig/` を直接使用する。

却下理由：
- `home/` は「ホームディレクトリに展開されるもの」という意味で分かりやすい。
- 将来 `~/.config/` 以外（例: `~/.vim/`）に展開するファイルが出た場合に `home/dot_vim/` で対応できる。

### A3: 各CLIに個別の指示を書く

`CLAUDE.md`、`AGENTS.md`、`GEMINI.md` にそれぞれ同じ内容を書く。

却下理由：
- 重複が多く保守性が悪い。
- 変更時に3箇所を更新する必要がある。
