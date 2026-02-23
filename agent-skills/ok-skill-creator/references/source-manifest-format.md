# source-manifest 形式

`references/source-manifest.json` は、Skill 作成時に参照した外部ソースのスナップショットを残すためのファイル。

## 目的

- どの情報を根拠に Skill を作ったかを再現可能にする
- SDK 更新や API 仕様変更時に差分点を追いやすくする
- KB ノートとの対応関係を明示する

## 最小フォーマット

```json
{
  "version": 1,
  "generated_at": "2026-02-20",
  "sources": [
    {
      "id": "example-source",
      "kind": "web",
      "uri": "https://example.com/docs",
      "snapshot": "replace-with-commit-or-version",
      "retrieved_at": "2026-02-20",
      "kb_refs": [
        "01ARZ3NDEKTSV4RRFFQ69G5FAV"
      ],
      "evidence_path": "references/notes/example-source.md",
      "notes": "Optional short note."
    }
  ]
}
```

## 項目ルール

- `version`: 正の整数
- `generated_at`: `YYYY-MM-DD`
- `sources`: 1件以上
- `sources[].id`: 一意な識別子
- `sources[].kind`: `git|web|local|api|other`
- `sources[].uri`: ソース識別子（URL もしくはローカル識別）
- `sources[].snapshot`: commit hash / release version / schema version など
- `sources[].retrieved_at`: `YYYY-MM-DD`
- `sources[].kb_refs`: KBノートID（必要な場合）
- `sources[].evidence_path`: 任意。Skill配下の補助資料パス
- `sources[].notes`: 任意

## 運用

- 仕様更新を検知したら、`sources[]` の該当エントリを更新する
- 更新時は `snapshot` と `retrieved_at` を必ず同時に更新する
- 根拠をKBへ追加したら `kb_refs` に追記する
