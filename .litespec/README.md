# nix-home Lite Spec 運用ガイド

`.litespec/` は、仕様・技術判断・運用ルールを軽量に管理するためのディレクトリです。

## ファイルの役割

- `.litespec/SPEC.md`: 全体仕様のインデックス（概要とリンク）
- `.litespec/specs/`: 機能単位の詳細仕様
- `.litespec/adr/`: 重要な技術判断の記録
- `AGENTS.md`: 人と AI エージェント向けの作業ルール（リポジトリ直下）
- `README.md`: プロジェクト全体の説明（リポジトリ直下）

## 運用フロー

1. 作業前に `.litespec/SPEC.md` を確認する
2. 対象機能の `.litespec/specs/*.md` を確認する
3. 仕様に影響する変更では `SPEC.md` と関連する詳細仕様を更新する
4. 重要な判断は `.litespec/adr/` に記録する
5. 実装後に仕様と実装の乖離がないか確認する

## nix-home での検証方針

- ローカル macOS では `switch` 前に `build` を優先する
- 別ユーザーまたは VM で `make init` の通し確認を行う
- テーマ/フォント適用は GUI セッション上で確認する
- GUI 検証用 VM は、ホストの通常ターミナルから `tart run` で起動する
- `tart ip` は起動コマンドではなく、起動後の接続確認用途として使う
- GUI 検証では SSH 実行結果を代替にせず、VM 画面内で見た目を確認する

## 追加の検証観点（MVP）

- `xcode-select -p` が成功すること
- `ssh -T git@github.com` が成功すること
- `~/ghq/github.com/hanabi-works/hanabi-theme` が clone 済みであること
- `~/.config/ghostty/themes/hanabi` が存在すること
- `~/.config/ghostty/config` に HackGen と `theme = hanabi` の設定が入ること
- `defaults read com.apple.Terminal "Default Window Settings"` が `Hanabi` になること
- `osascript -e 'tell application \"Terminal\" to font name of settings set \"Hanabi\"'` が HackGen 系名称を返すこと
- `~/.vim/colors/hanabi.vim` が存在すること
- `grep -n \"colorscheme hanabi\" ~/.vimrc` が成功すること
- `command -v code` が成功すること
- `code --list-extensions | grep -n \"^okash1n\\.hanabi-theme-vscode$\"` が成功すること
- `~/.config/zsh/hanabi.p10k.zsh` が存在すること（p10k 利用時の配色上書き）

## テンプレート利用時の注意

- `.litespec/SPEC.md` は全体方針のインデックスとして保つ
- 詳細は `.litespec/specs/` に分割し、`SPEC.md` からリンクする
- 仕様変更時は実装前に `SPEC.md` と該当詳細仕様を更新する
