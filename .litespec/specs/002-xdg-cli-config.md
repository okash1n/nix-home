# 002-XDG準拠CLI設定とAGENTS.md統一

## 目的

- AI CLI（Claude Code / Codex / Gemini / Happy）の設定ディレクトリを XDG 準拠（`~/.config/`）に統一する。
- 4つのAI CLIが同じ指示ファイル（`AGENTS.md`）を参照する仕組みを構築する。
- Nix管理の設定ファイル構造を展開先と対応させ、管理しやすくする。
- Claude Code Team 機能を Nix 管理の設定で安定して有効化する。

## ユーザーストーリー

- AI CLIの利用者として、どのCLI（Claude / Codex / Gemini / Happy）を使っても同じ共通ルールに従ってほしい。
- dotfiles管理者として、`~/.config/` 配下に設定を統一し、ホームディレクトリの散らかりを防ぎたい。
- Nix管理者として、ソースファイルと展開先の対応を明確にし、どこに何が展開されるか一目で分かるようにしたい。

## スコープ

- AI CLI（Claude Code / Codex / Gemini / Happy）の設定ディレクトリを環境変数で `~/.config/` 配下に変更する。
- 共通指示ファイル（`AGENTS.md`）を1ソースで全AI CLIに配置する。
- Claude Code の Team 関連設定（環境変数、`teammateMode`）を Nix 管理で補完する。
- Gemini CLIの `context.fileName` を activation script で自動設定する。
- `~/nix-home/agent-skills` を個人用 skill ソースとして管理し、Claude / Codex / Gemini の skills ディレクトリへ自動同期する。
- Git template hooks でプロジェクトの `AGENTS.md` から `CLAUDE.md` へのシンボリックリンクを自動作成する。
- Vim の設定ディレクトリを `~/.config/vim/` に移行する。
- `athenai` ラッパーコマンドを Nix 管理で提供する。

## 非スコープ

- AI CLIの認証情報や動的に生成されるファイルの管理（CLIに委ねる）。
- XDG非対応かつ環境変数での変更も困難なアプリケーション（Bashなど）の対応。

## 機能要件

### FR-001 AI CLI設定ディレクトリのXDG準拠

- `CLAUDE_CONFIG_DIR` 環境変数で Claude Code の設定ディレクトリを `~/.config/claude/` に設定する。
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 環境変数を `1` に設定し、Claude Code Team 機能を有効化する。
- `CODEX_HOME` 環境変数で Codex CLI の設定ディレクトリを `~/.config/codex/` に設定する。
- `GEMINI_CLI_HOME` 環境変数で Gemini CLI の設定ディレクトリを `~/.config/gemini/` に設定する。
- `HAPPY_HOME_DIR` 環境変数で Happy CLI の設定ディレクトリを `~/.config/happy/` に設定する。
- `NIX_HOME_AGENT_SKILLS_DIR` 環境変数で個人用 skill ソースを `~/nix-home/agent-skills` に設定する。
- `NIX_HOME_MCP_DEFAULT_ENABLED` 環境変数で MCP 既定有効状態を制御する（既定: `0` = OFF）。
- `NIX_HOME_MCP_FORCE_ENABLED` / `NIX_HOME_MCP_FORCE_DISABLED` 環境変数で MCP の例外を制御する（カンマ区切り、同一サーバーが両方に含まれる場合は `force_disabled` を優先）。
- 環境変数は `environment.variables`（nix-darwin システムレベル）で管理する。
- GUI アプリ（VS Code 等）からの起動経路を安定させるため、`launchd.user.envVariables` にも同等の値を設定する。
- `launchd` の値は `$HOME` 展開に依存しないよう、`/Users/<username>/...` の絶対パスで設定する。
- `__NIX_DARWIN_SET_ENVIRONMENT_DONE=1` のみ継承されるシェル（VS Code 統合ターミナル等）でも値が欠落しないよう、`~/.zshenv`・`~/.config/zsh/.zshenv` と `~/.bashrc` にフォールバック export を入れる。
- `launchd.user.envVariables` を有効化するため、`system.primaryUser` を設定する。
- 旧ホーム直下パス（`~/.claude` / `~/.codex` / `~/.gemini` / `~/.happy`）には `home.file` の番兵ファイルを配置し、誤って legacy パスへ設定が生成される問題を早期検知できるようにする。

### FR-002 共通指示の配置

- `home/dot_config/AGENTS.md` を共通指示のソースとして管理する。
- 共通指示を以下の4箇所に Nix 管理で配置する：
  - `~/.config/AGENTS.md`（グローバル共通）
  - `~/.config/codex/AGENTS.md`（Codex用）
  - `~/.config/gemini/GEMINI.md`（Gemini用）
  - `~/.config/happy/AGENTS.md`（Happy用）
- 上記4箇所は同じファイル（Nix store）へのシンボリックリンクとなる。

### FR-002a Claude Code固有指示の結合配置

- `home/dot_config/claude/CLAUDE.md` に Claude Code 固有の指示を管理する。
- `~/.config/claude/CLAUDE.md` は、Nixビルド時に共通指示（AGENTS.md）と Claude 固有指示を `builtins.readFile` で結合して生成する。
- 結合順序: AGENTS.md の内容 → 改行 → CLAUDE.md の内容。

### FR-003 Gemini CLIのcontext.fileName自動設定

- `home.activation.setupGeminiContext` で Gemini CLI の `settings.json` に `context.fileName` を設定する。
- `settings.json` が存在しない場合はスキップする（初回起動時に自動生成されるため）。
- 既に設定済みの場合は何もしない（冪等性）。
- 設定内容: `["AGENTS.md", "GEMINI.md"]`

### FR-003a Claude Code の teammateMode 自動設定

- `home.activation` で Claude Code の `settings.json` を検査し、`teammateMode` が未設定の場合のみ `auto` を追記する。
- `settings.json` が存在しない場合は `{"teammateMode":"auto"}` で新規作成する。
- 既に `teammateMode` が存在する場合は上書きしない（ユーザー設定優先）。
- `settings.json` が不正な JSON の場合は更新せず、警告ログを出してスキップする。

### FR-003b 個人用 skill のエージェント間同期

- `home.activation.setupAgentSkills` で `NIX_HOME_AGENT_SKILLS_DIR`（既定: `~/nix-home/agent-skills`）配下を走査する。
- `SKILL.md` を持つディレクトリのみを有効な skill とみなす。
- 有効な skill を以下へ `ln -sfn` で同期する：
  - `~/.config/claude/skills/<skill-name>`
  - `~/.config/codex/skills/<skill-name>`
  - `~/.config/gemini/.gemini/skills/<skill-name>`
- 既存の同名パスが通常ディレクトリ/通常ファイル（非 symlink）の場合は上書きせずスキップする。
- 既存の同名 symlink が `NIX_HOME_AGENT_SKILLS_DIR` 配下を指していない場合は上書きせずスキップする。
- 過去に同期された symlink（`NIX_HOME_AGENT_SKILLS_DIR` 配下を指すもの）のうち、ソースに存在しない skill は削除する（クリーンアップ）。

### FR-003c MCP 設定と JINA_API_KEY の自動同期

- `home.activation.setupMcpServers` を `sops-nix` の後に実行し、`switch` / `init` 時に MCP 設定を自動同期する。
- MCP 同期処理は `scripts/setup-mcp.sh` を共通エントリーポイントとして使用し、`make mcp` からも同じ処理を呼び出す。
- `setup-mcp.sh` は `~/.config/sops-nix/secrets/rendered/sops-env.sh` を読み込み、`JINA_API_KEY` を `launchctl setenv` で GUI プロセス向けにも同期する。
- `JINA_API_KEY` が未設定の場合は `launchctl unsetenv JINA_API_KEY` を実行し、警告を出して継続する。
- MCP 既定有効状態は `NIX_HOME_MCP_DEFAULT_ENABLED` で制御する（既定: `0` = OFF、`1` = ON）。
- MCP 例外は `NIX_HOME_MCP_FORCE_ENABLED` / `NIX_HOME_MCP_FORCE_DISABLED`（カンマ区切り）で制御する（既定: `NIX_HOME_MCP_FORCE_ENABLED=jina,claude-mem`）。
- `scripts/setup-codex-mcp.sh` は Codex の `jina` MCP を streamable HTTP + `bearer_token_env_var=JINA_API_KEY` で再設定し、`config.toml` の `enabled` フラグを `NIX_HOME_MCP_DEFAULT_ENABLED` に追従させる。
- `scripts/setup-codex-mcp.sh` は Codex の `asana` / `notion` MCP を `npx -y mcp-remote https://mcp.asana.com/v2/mcp` / `npx -y mcp-remote https://mcp.notion.com/mcp`（stdio bridge）で再設定し、`enabled` フラグを `NIX_HOME_MCP_DEFAULT_ENABLED` と force 例外に追従させる。
- `scripts/setup-claude-mcp.sh` は Claude の user scope `codex` / `jina` / `asana` / `notion` MCP を再設定または remove し、`NIX_HOME_MCP_DEFAULT_ENABLED` と force 例外に追従させる（Claude CLI に disable 機能がないため）。
- `scripts/setup-gemini-mcp.sh` は `~/.config/gemini/.gemini/settings.json` の `mcpServers` を upsert し、`jina.headers.Authorization` に `Bearer ${JINA_API_KEY}` を保持する。
- `scripts/setup-gemini-mcp.sh` は `asana` / `notion` を `https://mcp.asana.com/v2/mcp` / `https://mcp.notion.com/mcp` の HTTP MCP として upsert する。
- `scripts/setup-gemini-mcp.sh` は `~/.config/gemini/.gemini/mcp-server-enablement.json` を更新し、`NIX_HOME_MCP_DEFAULT_ENABLED` に応じて server ごとの enabled 状態を反映する。
- MCP 同期は「既存ならスキップ」ではなく差分再同期（reconcile）を基本とし、キー更新時にも追従する。

### FR-004 Git template hooks によるCLAUDE.md自動リンク

- `~/.config/git/template/hooks/` に以下のフックを配置する：
  - `setup-claude-symlink`: 共通ロジック（AGENTS.md → CLAUDE.md リンク作成）
  - `post-checkout`: clone/switch 時に実行
  - `post-merge`: pull/merge 時に実行
- `.gitconfig` に `init.templateDir = ~/.config/git/template` を設定する。
- フックの動作：
  1. リポジトリルートに `AGENTS.md` があり、`CLAUDE.md` がなければシンボリックリンクを作成
  2. `.git/info/exclude` に `CLAUDE.md` を追加（コミットされない gitignore）
- 制限事項：既存リポジトリには適用されない（手動でリンク作成が必要）

### FR-005 Vim設定のXDG準拠

- `VIMINIT` 環境変数で Vim の設定ファイルを `~/.config/vim/vimrc` に設定する。
- `~/.config/vim/vimrc` を Nix 管理で配置する。
- `~/.config/vim/colors/hanabi.vim` を配置する（activation script経由）。
- 既存の `~/.vimrc` と `~/.vim/` への配置を廃止する。

### FR-006 athenai ラッパーコマンド

- `athenai` コマンドを Nix 管理で提供する。
- 既定で `ATHENAI_REPO=~/ghq/github.com/athenai-dev/athenai` を参照し、`bun run --cwd "$ATHENAI_REPO" src/cli/index.ts` を実行する。
- `ATHENAI_REPO` を指定した場合は指定先を優先する。
- 参照先に `src/cli/index.ts` が見つからない場合は、明示的なエラーメッセージを表示して終了する。

## 非機能要件

- 保守性: 1ソースで全AI CLIの指示ファイルを管理でき、変更が即座に全ツールに反映される。
- 一貫性: 4つのAI CLIが同じルールで動作する。
- 冪等性: `make init` を何度実行しても同じ結果になる。
- 可逆性: 既存の `~/.claude/` 等から `~/.config/` への移行が可能。

## 受け入れ条件（DoD）

- `echo $CLAUDE_CONFIG_DIR` が `~/.config/claude` を返す。
- `echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` が `1` を返す。
- `echo $CODEX_HOME` が `~/.config/codex` を返す。
- `echo $GEMINI_CLI_HOME` が `~/.config/gemini` を返す。
- `echo $HAPPY_HOME_DIR` が `~/.config/happy` を返す。
- `echo $NIX_HOME_AGENT_SKILLS_DIR` が `~/nix-home/agent-skills` を返す。
- `echo $NIX_HOME_MCP_DEFAULT_ENABLED` が `0` を返す。
- `echo $NIX_HOME_MCP_FORCE_ENABLED` が `jina,claude-mem` を返す。
- `echo $VIMINIT` が `source ~/.config/vim/vimrc` を返す。
- `env -i HOME=$HOME USER=$USER __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 zsh -c 'source ~/.zshenv; echo $CODEX_HOME'` が `~/.config/codex` を返す。
- `env -i HOME=$HOME USER=$USER __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 zsh -c 'source ~/.zshenv; echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'` が `1` を返す。
- `env -i HOME=$HOME USER=$USER ZDOTDIR=$HOME/.config/zsh __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 zsh -c 'echo $CODEX_HOME'` が `~/.config/codex` を返す。
- `env -i HOME=$HOME USER=$USER ZDOTDIR=$HOME/.config/zsh __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 zsh -c 'echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'` が `1` を返す。
- `env -i HOME=$HOME USER=$USER __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 bash -lc 'source ~/.bashrc; echo $CODEX_HOME'` が `~/.config/codex` を返す。
- `env -i HOME=$HOME USER=$USER __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 bash -lc 'source ~/.bashrc; echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'` が `1` を返す。
- `env -i HOME=$HOME USER=$USER __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 zsh -c 'source ~/.zshenv; echo $HAPPY_HOME_DIR'` が `~/.config/happy` を返す。
- `env -i HOME=$HOME USER=$USER ZDOTDIR=$HOME/.config/zsh __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 zsh -c 'echo $HAPPY_HOME_DIR'` が `~/.config/happy` を返す。
- `env -i HOME=$HOME USER=$USER __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 bash -lc 'source ~/.bashrc; echo $HAPPY_HOME_DIR'` が `~/.config/happy` を返す。
- `~/.config/AGENTS.md` が存在し、Nix store へのシンボリックリンクである。
- `~/.config/claude/CLAUDE.md` が存在し、共通指示（AGENTS.md）と Claude 固有指示の両方を含む。
- `~/.config/codex/AGENTS.md` が存在し、`~/.config/AGENTS.md` と同じ Nix store パスを指す。
- `~/.config/gemini/GEMINI.md` が存在し、`~/.config/AGENTS.md` と同じ Nix store パスを指す。
- `~/.config/happy/AGENTS.md` が存在し、`~/.config/AGENTS.md` と同じ Nix store パスを指す。
- `~/.claude` / `~/.codex` / `~/.gemini` / `~/.happy` が Nix 管理の読み取り専用シンボリックリンク（番兵ファイル）として存在する。
- `~/nix-home/agent-skills/<skill-name>/SKILL.md` が存在する場合、`~/.config/claude/skills/<skill-name>` / `~/.config/codex/skills/<skill-name>` / `~/.config/gemini/.gemini/skills/<skill-name>` が同ソースへの symlink として存在する。
- `~/.config/claude/settings.json` の `teammateMode` が未設定の場合、activation 後に `auto` が設定される。
- `~/.config/gemini/settings.json` に `context.fileName` が設定されている。
- `make switch` 後、`launchctl getenv JINA_API_KEY` が空でない。
- `NIX_HOME_MCP_DEFAULT_ENABLED=0 make mcp` 実行後、`codex mcp get jina --json | jq -r '.enabled'` が `true` を返す（force enabled）。
- `NIX_HOME_MCP_DEFAULT_ENABLED=0 make mcp` 実行後、`claude mcp get jina` が利用可能である（force enabled）。
- `NIX_HOME_MCP_DEFAULT_ENABLED=0 make mcp` 実行後、`claude mcp get codex` は見つからない状態になる（force 対象外のため user scope から remove）。
- `NIX_HOME_MCP_DEFAULT_ENABLED=0 make mcp` 実行後、`jq -r '.jina.enabled, .\"claude-mem\".enabled, .codex.enabled' ~/.config/gemini/.gemini/mcp-server-enablement.json` が `true, true, false` を返す。
- `NIX_HOME_MCP_DEFAULT_ENABLED=0 make mcp` 実行後、`codex mcp get asana --json | jq -r '.enabled'` と `codex mcp get notion --json | jq -r '.enabled'` が `false` を返す。
- `NIX_HOME_MCP_DEFAULT_ENABLED=0 make mcp` 実行後でも、`NIX_HOME_MCP_FORCE_ENABLED` に含まれる server（既定: `jina`, `claude-mem`）は enabled 状態で維持される。
- `NIX_HOME_MCP_DEFAULT_ENABLED=1 make mcp` 実行後、`codex mcp get jina` で `bearer_token_env_var: JINA_API_KEY` が確認できる。
- `NIX_HOME_MCP_DEFAULT_ENABLED=1 make mcp` 実行後、`jq '.mcpServers.jina.headers.Authorization' ~/.config/gemini/.gemini/settings.json` が `"Bearer ${JINA_API_KEY}"` を返す。
- `~/.config/git/template/hooks/` に `post-checkout`、`post-merge`、`setup-claude-symlink` が存在する。
- `.gitconfig` に `init.templateDir` が設定されている。
- `~/.config/vim/vimrc` が存在し、`colorscheme hanabi` を含む。
- `~/.config/vim/colors/hanabi.vim` が存在する。
- `command -v athenai` が成功する。
- `ATHENAI_REPO=~/ghq/github.com/athenai-dev/athenai athenai --help` が成功する。
- `ghq get` で AGENTS.md を含むリポジトリを clone すると、CLAUDE.md シンボリックリンクが自動作成される。
- `make init` 2回連続実行で破綻しない。

## 依存・前提

- 001-macos-bootstrap-mvp が適用済みであること。
- Claude Code / Codex / Gemini / Happy がインストール済みであること。
- 個人用 skill ソースを `~/nix-home/agent-skills` で管理すること。
- `athenai` リポジトリが `~/ghq/github.com/athenai-dev/athenai` に存在するか、`ATHENAI_REPO` で参照先を指定できること。

## テスト観点

- 正常系: `make init` 後、各環境変数と設定ファイルが期待どおり配置される。
- 正常系: codex/gemini/happy の指示ファイルが AGENTS.md と同じ Nix store パスを指す。
- 正常系: CLAUDE.md が共通指示と Claude 固有指示の両方を含む。
- 正常系: Claude Code の `teammateMode` が未設定時のみ `auto` で補完される。
- 正常系: `~/nix-home/agent-skills` の有効 skill が Claude / Codex / Gemini の `skills/` に同期される。
- 正常系: エージェント側に同名の通常ディレクトリがある場合、上書きせずにスキップされる。
- 正常系: `make switch` 実行後に `launchctl getenv JINA_API_KEY` が設定される。
- 正常系: `NIX_HOME_MCP_DEFAULT_ENABLED=0` では force 対象外の MCP が disabled/remove 状態で同期される。
- 正常系: `NIX_HOME_MCP_DEFAULT_ENABLED=0` でも、`NIX_HOME_MCP_FORCE_ENABLED` に含まれる server は enabled 状態で同期される。
- 正常系: `NIX_HOME_MCP_DEFAULT_ENABLED=1` では Codex/Claude/Gemini の MCP が enabled 状態で同期される。
- 正常系: `JINA_API_KEY` を更新した後の `make switch` で、各 CLI の `jina` 設定が新値に追従する。
- 正常系: `ghq get` で AGENTS.md を含むリポジトリを clone すると CLAUDE.md が自動作成される。
- 正常系: `git pull` で AGENTS.md が追加された場合、CLAUDE.md が自動作成される。
- 正常系: `athenai --help` が実行できる。
- 回帰: 既存のzsh / ghostty / git設定が引き続き動作する。
- 移行: 既存の `~/.claude/` 等がある状態から移行しても問題ない。
- 冪等性: Gemini の `context.fileName` は既に設定済みなら再設定されない。

## 実装メモ

- 既存の `~/.claude/` 等は手動で `~/.config/` に移動する必要がある（移行手順をREADMEに記載）。
- 各CLIが動的に生成するファイル（`settings.json`、認証情報など）はNix管理外とする。
- `home.file` で管理されるファイルは読み取り専用シンボリックリンクになるため、直接編集は不可。
- `skills/` 配下は各エージェントが公式 skill を配置するため、ディレクトリ全体は Nix 管理しない（skill 単位 symlink のみ管理）。
- Git template は新規 clone にのみ適用される。既存リポジトリへの適用は手動。
- Gemini の `settings.json` が存在しない場合（初回起動前）は activation をスキップする。
