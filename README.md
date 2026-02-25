# nix-home

Nix 前提で macOS シェル環境を一発復旧するための個人用設定リポジトリです。

## 前提

- macOS (Apple Silicon)
- Xcode Command Line Tools が導入済み
- GitHub SSH 鍵が登録済み（`ssh -T git@github.com` が成功）

## 初期化コマンド

`nix-home` 本体は `~/nix-home` 配下で運用します（`ghq` 配下には置かない）。
`hanabi-theme` は `ghq` 配下（`~/ghq/github.com/hanabi-works/hanabi-theme`）で管理します（`init.sh` が `ghq get -u` で同期します）。

```bash
if [ -d ~/nix-home/.git ]; then
  cd ~/nix-home
  git pull --ff-only
else
  git clone git@github.com:okash1n/nix-home.git ~/nix-home
  cd ~/nix-home
fi

	make init
	```

	対話的な TTY 上で `make init` を実行した場合、完了後に `zsh -l` を起動して設定を即時反映します。
	抑止したい場合は `NIX_HOME_SKIP_SHELL_RELOAD=1 make init` を使います。

`init.sh` は以下を実行します。

- Xcode CLT / GitHub SSH の preflight チェック
- `hanabi-theme` repository の取得または更新（`ghq get -u`、配置先は `~/ghq/github.com/hanabi-works/hanabi-theme`）
- `zsh` の履歴/キャッシュ用ディレクトリの事前作成（`~/.local/state/zsh` / `~/.cache/zsh`）
- `nix-darwin` + `home-manager` の適用
- `llm-agents` 自動更新用 launchd agent の登録（`~/Library/LaunchAgents/com.okash1n.nix-home.llm-agents-update.plist`）
- GUI セッションの初回適用後に `Ghostty` を自動起動
- 既存 dotfile 衝突時の自動バックアップ（`*.hm-bak`）
- Nix Store の自動 GC / 最適化設定の適用（容量増加を抑制）
- 過去 Nix installer の `*.backup-before-nix` 衝突を自動退避して継続

## 反映される主な設定

- `zsh`（既定プロンプト: `powerlevel10k` + `Hanabi` 配色、切替: `NIX_HOME_ZSH_PROMPT=hanabi`）
- `dotfiles` 由来の `zsh` aliases / functions（`fgh` を含む）
- CLI: `git` `curl` `wget` `jq` `fzf` `fd` `rg` `ghq` `awk` `grep` `sed` `tmux` `dust` `yazi` `node` `pnpm` `bun` `python3` `uv` `caddy` `marp` `vim` `playwright` `codex` `claude` `gemini` `happy` `agent-browser` `athenai`
- AI CLI の設定ディレクトリ: `~/.config/claude` `~/.config/codex` `~/.config/gemini` `~/.config/happy`
- 個人用 skills: `~/nix-home/agent-skills` をソースとして、`make switch` / `make init` 時に `~/.config/claude/skills/`、`~/.config/codex/skills/`、`~/.config/gemini/.gemini/skills/` へシンボリックリンク同期
- MCP 運用: `ok-mcp-toggle` スキルで MCP を global/project scope で有効化/無効化（対象クライアントは `claude` / `gemini`、`codex` は管理対象外）
- MCP 管理定義: `agent-skills/ok-mcp-toggle/config/registry.json`（動的状態は `agent-skills/ok-mcp-toggle/config/state.json`）
- `llm-agents` 入力の定期更新: launchd (`com.okash1n.nix-home.llm-agents-update`) で毎日 `06:00` / `18:00` に専用 clean worktree 上で `nix flake lock --update-input llm-agents` を実行し、`home-manager switch` を自動実行（リトライ付き）。作業中の `~/nix-home` ワークツリー状態には依存しない。
- Claude Code Team 機能: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`（Nix で配布）
- `git` グローバル設定（`user.name` / `user.email` / global ignore）
- `Ghostty` 本体（`/Applications/Nix Apps/Ghostty.app`）と `~/.config/ghostty/config`（HackGen + `theme = hanabi`）
- `VS Code` 本体（`/Applications/Nix Apps/Visual Studio Code.app`）と Marketplace 拡張 `okash1n.hanabi-theme-vscode`（`workbench.colorTheme = Hanabi`）
- フォント: HackGen NF / LINE Seed JP / IBM Plex Sans JP / IBM Plex Mono
- `Terminal.app` の `Hanabi` 既定プロファイル設定
- `Vim` の `colorscheme hanabi`（`~/.config/vim/colors/hanabi.vim` / `~/.config/vim/vimrc`）
- Nix Store の自動メンテナンス（GC / optimise）

MCP の切り替えは `./agent-skills/ok-mcp-toggle/scripts/mcp_toggle.sh list|add|remove|enable|disable|status|preauth` を使います（`--scope global|project|all` 対応）。
`enable` で project scope 対象を反映する場合、対話で `.gitignore` / `.git/info/exclude` への ignore 追加有無を選択できます。
non-interactive 実行では暗黙選択を行わないため、`--clients` と対象MCP、project 時は `--ignore-target` を明示します。
`oauth` サーバーの `preauth` は設定反映までを自動化し、`status` で `needs-auth` / `pending_user_auth` が出る場合はクライアント側で 1 回ログインが必要です。
Gemini 向けの `asana` / `notion` は、`/mcp auth` の互換性のため OAuth エンドポイントをサーバー定義に明示して反映します。
`asana` の endpoint はクライアント別に管理し、Claude は `https://mcp.asana.com/v2/mcp`、Gemini は `https://mcp.asana.com/mcp` を使用します。
`box` は callback ベースではなく、`https://mcp.box.com` の HTTP MCP として `claude/gemini` に登録します。
`make mcp` は `ok-mcp-toggle` の入口（管理対象表示）として利用できます。
`llm-agents` 自動更新のログは `~/.local/state/nix-home/llm-agents-auto-update.launchd.log` に出力されます。
システム側の変更（nix-darwin）は必要時に `make switch` で手動適用します。

`athenai` コマンドは `ATHENAI_REPO`（既定: `~/ghq/github.com/athenai-dev/athenai`）を参照し、
`bun run --cwd "$ATHENAI_REPO" src/cli/index.ts` をラップします。

注: `Terminal.app` のテーマ適用処理（import / defaults / フォント同期）は
`make init` 時のみ試行し、`make switch` では実行しません。
GUI セッションが無い実行（ヘッドレス VM など）では、
`make init` 時でも `Terminal.app` へのテーマ適用は自動でスキップされます。
明示的にスキップする場合は `NIX_HOME_SKIP_TERMINAL_THEME=1 make init` を使います。
GUI セッションが有効なら `Terminal.app` 起動有無に依存せず試行し、
`Terminal.app` が起動中なら既存ウィンドウの設定も `Hanabi` に同期します。
`Hanabi` プロファイルの import が確認できない場合は、既定設定更新をスキップしてログに案内を出します。
Ghostty 自動起動を抑止する場合は `NIX_HOME_OPEN_GHOSTTY=0 make init` を使います。

## 仕様管理

- `AGENTS.md`
- `.litespec/README.md`
- `.litespec/SPEC.md`
- `.litespec/specs/`
- `.litespec/adr/`

## シークレット環境変数の追加

`sops` 管理の環境変数は、対話スクリプトで追加できます。

```bash
make secret
```

例: `VSCE_PAT` を追加すると、以下が自動更新されます。

- `secrets/secrets.yaml`（暗号化された値）
- `modules/home/sops.nix`（`secrets.<key>` と `sops-env.sh` の `export`）

`secrets` 側のキー名は既定で環境変数名から自動生成されます（例: `VSCE_PAT` -> `vsce-pat`）。
値入力は表示ありです（確認のため再入力あり）。

最後に `make switch` まで同じ対話の中で実行できます。
