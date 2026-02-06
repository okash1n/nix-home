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

## 反映される主な設定

- `zsh` / `powerlevel10k`
- CLI: `git` `curl` `jq` `fzf` `ghq` `awk` `grep` `sed` `codex` `claude` `gemini`
- フォント: HackGen NF / LINE Seed JP / IBM Plex Sans JP / IBM Plex Mono
- `Ghostty` 設定（HackGen + Dracula Pro 配色）
- `Terminal.app` の `Dracula Pro` 既定プロファイル設定

## 仕様管理

- `AGENTS.md`
- `.litespec/README.md`
- `.litespec/SPEC.md`
- `.litespec/adr/`
