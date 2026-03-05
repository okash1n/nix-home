# ADR 0012: 夜間更新ジョブの旧設計（legacy）

- Status: Superseded
- Date: 2026-02-18
- Superseded Date: 2026-03-04
- Superseded By: launchd 定期更新を廃止し、`make update` 中心の手動更新運用へ移行

## Context

- 以前は外部依存の更新頻度が高く、手動更新だけでは AI CLI の追従が遅れやすかった。
- `make update` 実行時にまとめて更新する運用では、反映タイミングが利用者依存だった。
- `make switch` / `make init` 後に launchd 未登録が残らないよう、自己修復可能な登録フローが必要だった。

## Decision

- 専用の更新スクリプトと登録スクリプトを用意し、夜間に定期実行する方式を採用した。
- launchd の `StartCalendarInterval` は 2 本（`06:00` / `18:00`）で構成した。
- Home Manager activation で登録チェックを実行し、`switch` / `init` 時に再同期するようにした。
- system 設定の適用（`darwin-rebuild switch`）は手動運用に分離した。

## Consequences

- 当時は更新と Home Manager 適用を 1 日 2 回自動試行できた。
- 一方で、運用とトラブルシュートの複雑性が増えた。

## Superseded Notes

- 2026-03-04 に旧定期更新スクリプトと旧登録スクリプトは削除された。
- 旧 launchd agent の import と呼び出しは削除された。
