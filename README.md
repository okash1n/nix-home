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
- GUI セッションの初回適用後に `Ghostty` を自動起動
- 既存 dotfile 衝突時の自動バックアップ（`*.hm-bak`）
- Nix Store の自動 GC / 最適化設定の適用（容量増加を抑制）
- 過去 Nix installer の `*.backup-before-nix` 衝突を自動退避して継続

## 反映される主な設定

- `zsh`（既定プロンプト: `powerlevel10k` + `Hanabi` 配色、切替: `NIX_HOME_ZSH_PROMPT=hanabi`）
- `dotfiles` 由来の `zsh` aliases / functions（`fgh` を含む）
- CLI: `git` `curl` `wget` `jq` `fzf` `fd` `rg` `ghq` `awk` `grep` `sed` `tmux` `dust` `yazi` `node` `pnpm` `bun` `python3` `uv` `vim` `codex` `claude` `gemini`
- `git` グローバル設定（`user.name` / `user.email` / global ignore）
- `Ghostty` 本体（`/Applications/Nix Apps/Ghostty.app`）と `~/.config/ghostty/config`（HackGen + `theme = hanabi`）
- `VS Code` 本体（`/Applications/Nix Apps/Visual Studio Code.app`）と Marketplace 拡張 `okash1n.hanabi-theme-vscode`（`workbench.colorTheme = Hanabi`）
- フォント: HackGen NF / LINE Seed JP / IBM Plex Sans JP / IBM Plex Mono
- `Terminal.app` の `Hanabi` 既定プロファイル設定
- `Vim` の `colorscheme hanabi`（`~/.config/vim/colors/hanabi.vim` / `~/.config/vim/vimrc`）
- Nix Store の自動メンテナンス（GC / optimise）

注: GUI セッションが無い実行（ヘッドレス VM など）では、
`Terminal.app` へのテーマ適用は自動でスキップされます。
明示的にスキップする場合は `NIX_HOME_SKIP_TERMINAL_THEME=1 make init` を使います。
`Terminal.app` のテーマ適用処理（import / defaults / フォント同期）は、
GUI セッションが有効なら `Terminal.app` 起動有無に依存せず試行します。
`Terminal.app` が起動中なら、既存ウィンドウの設定も `Hanabi` に同期します。
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
