# AGENTS.md - AI Agent Guidelines

このリポジトリで作業する人・AIエージェント向けの運用ルールです。

## 基本方針

- 仕様は `.litespec/SPEC.md` を最優先する。
- 仕様に影響する変更は、実装前に `.litespec/SPEC.md` を更新する。
- 重要な技術判断は `.litespec/adr/` に記録する。
- ドキュメントとコミットメッセージは日本語で記述する。

## 作業フロー

1. `.litespec/SPEC.md` の該当箇所を確認する。
2. 仕様変更が必要なら先に `.litespec/SPEC.md` を編集する。
3. 実装する。
4. `build` ベースで検証する。
5. `.litespec/SPEC.md` / `.litespec/README.md` / `.litespec/adr/` と実装の整合を確認する。

## 実装ルール

- まずは macOS (Apple Silicon) を優先して実装する。
- 初期導線は `init.sh` と `make init` を維持する。
- `zsh` と `powerlevel10k` の再現性を優先する。
- GUI アプリ自動化は v1 で無理に広げない。
- 破壊的操作（既存設定削除、強制リセット）はユーザー合意なしで行わない。

## 検証ルール

- 可能な限り `switch` 前に `build` で検証する。
- 検証コマンドと結果の要点を記録する。
- 実機への適用が必要な場合は、影響範囲を明示してから実施する。
