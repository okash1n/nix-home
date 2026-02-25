# Agent Skills 仕様チェックリスト

## Frontmatter

必須:

- `name`（1-64文字、lowercase、先頭末尾ハイフン不可、`--` 不可）
- `description`（1-1024文字）
- `compatibility`（この運用では `claude,codex,gemini` を必須）

任意:

- `license`
- `metadata`（mapping）
- `allowed-tools`（experimental）

## 命名

- ディレクトリ名と `name` は一致させる。
- クライアントが許容する場合は Unicode lowercase alnum + hyphen を使える。

## ファイル

- `SKILL.md` は必須。
- `scripts/` `references/` `assets/` は任意。
- 外部根拠を使う skill では `references/source-manifest.json` を推奨。

## 実装方式

- 公式CLI / SDK / 直接HTTP を比較して選定理由を残す。
- 公式CLIを使う場合は Nix 経由で導入する（`ok-search` + `ok-install`）。
- ユーザーに直接CLI/スクリプト実行を要求しない。
- 実行主体がエージェントであることを `User Interaction Contract` で明記する。
- 状態変更系の操作は実行前確認を必須にし、確認ターン後にのみ実行する。

## 検証コマンド

```bash
scripts/quick_validate.py <skill-dir>
skills-ref validate <skill-dir>  # 利用可能な場合
```
