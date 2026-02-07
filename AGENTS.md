# AGENTS.md - AI Agent Guidelines

このリポジトリで作業する人・AIエージェント向けのガイドラインです。
このファイルは「固定セクション」と「プロジェクト追記セクション」に分かれます。

## 固定セクション（この見出しから下はテンプレ既定）

以下は Lite Spec テンプレートの共通運用ルールです。
運用を安定させるため、このセクションは原則として維持してください。

## 基本ルール

- 仕様の入口は [`.litespec/SPEC.md`](.litespec/SPEC.md) を最優先する
- [`.litespec/SPEC.md`](.litespec/SPEC.md) は概要とリンクを管理する（詳細は分割）
- 詳細仕様は [`.litespec/specs/`](.litespec/specs/) に機能単位で記述する
- 仕様に影響する変更は [`.litespec/SPEC.md`](.litespec/SPEC.md) と関連する詳細仕様を更新する
- 重要な技術判断は [`.litespec/adr/`](.litespec/adr/) に記録する
- 不明点や矛盾があれば作業前に質問する

## 作業フロー

1. [`.litespec/SPEC.md`](.litespec/SPEC.md) を読む
2. 対象機能の詳細仕様（[`.litespec/specs/`](.litespec/specs/)）を読む
3. 仕様に不足があれば追記/提案する
4. 実装する
5. テスト/検証する
6. 変更点を [`.litespec/SPEC.md`](.litespec/SPEC.md) / [`.litespec/specs/`](.litespec/specs/) / [`.litespec/adr/`](.litespec/adr/) に反映する

## ドキュメント方針

- ドキュメントは日本語で書く
- 仕様・判断・運用ルールの3点を揃える

---

## プロジェクト追記セクション（ここから下に自由追記）

### 実装方針

- macOS (Apple Silicon) を優先して実装・検証する。
- 初期導線は `init.sh` と `make init` を維持する。
- `zsh` と `powerlevel10k` の再現性を優先する。
- GUI アプリ自動化は段階導入し、v1 で無理に広げない。
- 破壊的操作（既存設定削除、強制リセット）はユーザー合意なしで行わない。

### 検証方針

- 可能な限り `switch` 前に `build` で検証する。
- 検証コマンドと結果の要点を記録する。
- 実機への適用が必要な場合は、影響範囲を明示してから実施する。
- GUI 検証用の Tart VM は、ホストの通常ターミナルから `tart run` で起動する（Codex 実行セッションからは起動しない）。
- `tart ip` は起動コマンドではないため、`tart run` 実行後の確認用途でのみ使う。
- 見た目・操作感の確認は VM の GUI 画面内で行い、SSH 実行結果を代替にしない。

### 運用メモ

- `make init` は再実行可能（冪等）を維持する。
- 既存ファイル衝突時はバックアップ方針（`*.hm-bak`）を優先する。
