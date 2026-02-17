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

## 検証コマンド

```bash
scripts/quick_validate.py <skill-dir>
skills-ref validate <skill-dir>  # 利用可能な場合
```
