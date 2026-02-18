# Mode Matrix

`ok-ui-check` では、目的ごとに実行モードを選ぶ。

## 推奨マッピング

- `smoke` / `explore`:
  - 推奨ツール: `agent-browser`
  - 目的: 探索的に素早く確認し、要素参照を使って次アクションを決める
- `auth` / `form`:
  - 推奨ツール: `agent-browser`
  - 目的: フォーム入力やログイン導線を対話的に検証する
- `regression`:
  - 推奨ツール: `playwright-cli`
  - 目的: 再現性を重視した UI 回帰確認を行う
- `network`:
  - 推奨ツール: `playwright-cli`
  - 目的: console / network の観測を含めた確認を行う
- `trace` / `capture`:
  - 推奨ツール: `playwright-cli`
  - 目的: trace/snapshot を中心に記録を残す

## 実行前チェック

- `scripts/ui_check.sh doctor` が通る
- 対象 URL が決まっている
- `Agent名`（Codex/Claude/Gemini）を明示するか、自動判定結果を確認する
- 必要ならセッションIDを決める（並列検証の衝突回避）

## Artifact 保存規約

- すべて `~/ui-check/YYYYMMDD-Agent名-セッションID/` 配下へ保存する
- 日付は JST（Asia/Tokyo）
- セッションIDは会話ID（`CODEX_THREAD_ID` など）を優先し、同一会話では同じフォルダを使う
- 明示的に切り替えたい場合のみ `--session` を指定する
- screenshot は `yyyymmddhhmm-<tool>.png`（例: `202602181245-playwright.png`）で保存する
- `auth` / `form` モードの state は既定で同フォルダの `state.json`

## 実行ポリシー

- 常にヘッドレス（UI非表示）で実行する
- `--headed` は使わない
- `CI=1` と `PLAYWRIGHT_HEADLESS=1` を付与して起動する

## 結果報告テンプレート

- 対象 URL:
- 実行モード:
- 使用ツール:
- 観測結果（成功/失敗）:
- 失敗時の再現手順:
- 追加調査が必要な点:
