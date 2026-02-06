# nix-home Lite Spec

このディレクトリは `nix-home` の仕様管理ファイルをまとめる領域です。

## 含まれるもの

- `.litespec/SPEC.md`: 仕様定義
- `.litespec/adr/`: 技術判断ログ
- `AGENTS.md`: 人・AI エージェント向け運用ルール（ルート）

## 開発フロー

1. `.litespec/SPEC.md` を更新
2. 必要なら `.litespec/adr/` に判断を記録
3. 実装
4. 検証（`build` ベース）
5. `.litespec/SPEC.md` と実装の整合を確認

## 検証方針（予定）

- ローカル macOS では `switch` 前に `build` を優先する
- 別ユーザーまたは VM で `make init` の通し確認を行う

## 追加の検証観点（MVP）

- `xcode-select -p` が成功すること
- `ssh -T git@github.com` が成功すること
- `~/ghq/github.com/okash1n/dracula-pro` が clone 済みであること
- `~/.config/ghostty/config` に HackGen と Dracula Pro の設定が入ること
- `defaults read com.apple.Terminal "Default Window Settings"` が `Dracula Pro` になること
