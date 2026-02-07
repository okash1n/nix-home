# 002-XDG準拠CLI設定とAGENTS.md統一

## 目的

- AI CLI（Claude Code / Codex / Gemini）の設定ディレクトリを XDG 準拠（`~/.config/`）に統一する。
- 3つのAI CLIが同じ指示ファイル（`AGENTS.md`）を参照する仕組みを構築する。
- Nix管理の設定ファイル構造を展開先と対応させ、管理しやすくする。

## ユーザーストーリー

- AI CLIの利用者として、どのCLI（Claude / Codex / Gemini）を使っても同じ共通ルールに従ってほしい。
- dotfiles管理者として、`~/.config/` 配下に設定を統一し、ホームディレクトリの散らかりを防ぎたい。
- Nix管理者として、ソースファイルと展開先の対応を明確にし、どこに何が展開されるか一目で分かるようにしたい。

## スコープ

- AI CLI（Claude Code / Codex / Gemini）の設定ディレクトリを環境変数で `~/.config/` 配下に変更する。
- 共通指示ファイル（`~/.config/AGENTS.md`）を Nix 管理で配置する。
- 各CLI用の指示ファイル（`CLAUDE.md` / `AGENTS.md` / `GEMINI.md`）を Nix 管理で配置する。
- Nix管理のソースディレクトリ構造を `home/dot_config/` に再編成する。
- Vim の設定ディレクトリを `~/.config/vim/` に移行する。

## 非スコープ

- AI CLIの認証情報や動的に生成されるファイルの管理（CLIに委ねる）。
- XDG非対応かつ環境変数での変更も困難なアプリケーション（Bashなど）の対応。

## 機能要件

### FR-001 AI CLI設定ディレクトリのXDG準拠

- `CLAUDE_CONFIG_DIR` 環境変数で Claude Code の設定ディレクトリを `~/.config/claude/` に設定する。
- `CODEX_HOME` 環境変数で Codex CLI の設定ディレクトリを `~/.config/codex/` に設定する。
- `GEMINI_CLI_HOME` 環境変数で Gemini CLI の設定ディレクトリを `~/.config/gemini/` に設定する。
- 環境変数は `home.sessionVariables` で管理する。

### FR-002 共通指示ファイル（AGENTS.md）の配置

- `~/.config/AGENTS.md` を Nix 管理で配置する。
- このファイルには全プロジェクト共通の指示（言語設定、コーディング規約など）を記載する。
- ソースファイルは `home/dot_config/AGENTS.md` に配置する。

### FR-003 各CLI用指示ファイルの配置

- `~/.config/claude/CLAUDE.md` を Nix 管理で配置する。
- `~/.config/codex/AGENTS.md` を Nix 管理で配置する。
- `~/.config/gemini/GEMINI.md` を Nix 管理で配置する。
- 各ファイルには以下の参照順序を指示として記載する：
  1. `~/.config/AGENTS.md`（グローバル共通指示）
  2. プロジェクト直下の `AGENTS.md`（プロジェクト固有指示、存在する場合）
- ソースファイルは `home/dot_config/{claude,codex,gemini}/` に配置する。

### FR-004 ソースディレクトリ構造の再編成

- Nix管理の設定ファイルソースを `home/dot_config/` ディレクトリに集約する。
- 既存の `home/zsh/` を `home/dot_config/zsh/` に移動する。
- ディレクトリ構造を展開先（`~/.config/`）と対応させる。

### FR-005 Vim設定のXDG準拠

- `VIMINIT` 環境変数で Vim の設定ファイルを `~/.config/vim/vimrc` に設定する。
- `~/.config/vim/vimrc` を Nix 管理で配置する。
- `~/.config/vim/colors/hanabi.vim` を配置する（activation script経由）。
- 既存の `~/.vimrc` と `~/.vim/` への配置を廃止する。

## 非機能要件

- 保守性: ソースディレクトリと展開先の対応が明確で、新規ファイル追加時に迷わない。
- 一貫性: 3つのAI CLIが同じルールで動作する。
- 可逆性: 既存の `~/.claude/` 等から `~/.config/` への移行が可能。

## 受け入れ条件（DoD）

- `echo $CLAUDE_CONFIG_DIR` が `~/.config/claude` を返す。
- `echo $CODEX_HOME` が `~/.config/codex` を返す。
- `echo $GEMINI_CLI_HOME` が `~/.config/gemini` を返す。
- `echo $VIMINIT` が `source ~/.config/vim/vimrc` を返す。
- `~/.config/AGENTS.md` が存在し、Nix store へのシンボリックリンクである。
- `~/.config/claude/CLAUDE.md` が存在し、共通指示への参照を含む。
- `~/.config/codex/AGENTS.md` が存在し、共通指示への参照を含む。
- `~/.config/gemini/GEMINI.md` が存在し、共通指示への参照を含む。
- `~/.config/vim/vimrc` が存在し、`colorscheme hanabi` を含む。
- `~/.config/vim/colors/hanabi.vim` が存在する。
- `~/nix-home/home/dot_config/` ディレクトリが存在し、zsh / claude / codex / gemini / vim の設定ソースを含む。
- Claude Code が `~/.config/AGENTS.md` とプロジェクトの `AGENTS.md` を参照する。
- `make init` 2回連続実行で破綻しない。

## 依存・前提

- 001-macos-bootstrap-mvp が適用済みであること。
- Claude Code / Codex / Gemini がインストール済みであること。

## テスト観点

- 正常系: `make init` 後、各環境変数と設定ファイルが期待どおり配置される。
- 正常系: AI CLIが `~/.config/AGENTS.md` を参照し、プロジェクトルールに従う。
- 回帰: 既存のzsh / ghostty / git設定が引き続き動作する。
- 移行: 既存の `~/.claude/` 等がある状態から移行しても問題ない。

## 実装メモ

- 既存の `~/.claude/` 等は手動で `~/.config/` に移動する必要がある（移行手順をREADMEに記載）。
- 各CLIが動的に生成するファイル（`settings.json`、認証情報など）はNix管理外とする。
- `home.file` で管理されるファイルは読み取り専用シンボリックリンクになるため、直接編集は不可。
