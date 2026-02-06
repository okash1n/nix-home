# nix-home

Nix 前提で macOS シェル環境を一発復旧するための個人用設定リポジトリです。

## 前提

- macOS (Apple Silicon)
- Xcode Command Line Tools が導入済み
- GitHub SSH 鍵が登録済み（`ssh -T git@github.com` が成功）
- `git@github.com:okash1n/dracula-pro.git` にアクセス可能

## 初期化コマンド

```bash
make init
# または
./init.sh
```

`init.sh` は以下を実行します。

- Xcode CLT / GitHub SSH の preflight チェック
- `dracula-pro` private repository の取得または更新（`~/ghq/github.com/okash1n/dracula-pro`）
- `nix-darwin` + `home-manager` の適用
- 既存 dotfile 衝突時の自動バックアップ（`*.hm-bak`）
- Nix Store の自動 GC / 最適化設定の適用（容量増加を抑制）
- 過去 Nix installer の `*.backup-before-nix` 衝突を自動退避して継続

## 反映される主な設定

- `zsh` / `powerlevel10k`
- CLI: `git` `curl` `jq` `fzf` `ghq` `awk` `grep` `sed` `codex` `claude` `gemini`
- `git` グローバル設定（`user.name` / `user.email` / global ignore）
- `Ghostty` 本体と `~/.config/ghostty/config`（HackGen + Dracula Pro 配色）
- フォント: HackGen NF / LINE Seed JP / IBM Plex Sans JP / IBM Plex Mono
- `Terminal.app` の `Dracula Pro` 既定プロファイル設定
- Nix Store の自動メンテナンス（GC / optimise）

注: GUI セッションが無い実行（ヘッドレス VM など）では、
`Terminal.app` へのテーマ適用は自動でスキップされます。
明示的にスキップする場合は `NIX_HOME_SKIP_TERMINAL_THEME=1 make init` を使います。
`Terminal.app` のテーマ適用処理（import / defaults / フォント同期）は、
GUI セッションが有効なら `Terminal.app` 起動有無に依存せず試行します。
`Dracula Pro` プロファイルの import が確認できない場合は、既定設定更新をスキップしてログに案内を出します。

## 仕様管理

- `AGENTS.md`
- `.litespec/README.md`
- `.litespec/SPEC.md`
- `.litespec/adr/`
