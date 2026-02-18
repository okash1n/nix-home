---
name: ok-ui-check
description: playwright-cli と agent-browser を用途別に使い分けて UI チェックを実行する。探索的調査と再現性の高い回帰確認を同一ワークフローで扱いたいときに使う。
compatibility: claude,codex,gemini
---

# OK UI Check

## 目的

UI チェックの目的に応じて `playwright-cli` と `agent-browser` を使い分ける。  
参照スキルの内容は設計の参考にとどめ、この skill 単体で実行フローを完結させる。

## Trigger Examples

- 「UI崩れがないか確認して。必要ならスクショも残して」
- 「ログイン後の画面遷移をざっと調査して」
- 「回帰確認として再現性高くチェックして」
- 「playwright と agent-browser を使い分けて検証して」

## Tool Selection

- `agent-browser` を使う条件:
  - 探索的調査（`explore`）やログイン導線確認（`auth`）など、即時対話で進める確認
  - 要素参照（`@e1` など）を見ながら素早く試行錯誤したい
- `playwright-cli` を使う条件:
  - 回帰確認（`regression`）やネットワーク観測（`network`）など、再現性を重視する確認
  - スナップショット/トレース寄りの記録を残したい
- 判断に迷う場合:
  - まず `scripts/ui_check.sh choose --mode <mode>` で推奨ツールを確定する

## Workflow

1. 前提確認  
   `scripts/ui_check.sh doctor`
2. モードを決めてツール選択  
   `scripts/ui_check.sh choose --mode explore`  
   `scripts/ui_check.sh choose --mode regression`
3. 実行  
   `scripts/ui_check.sh run --mode <mode> --url <target-url> --agent-name <Codex|Claude|Gemini>`
4. 必要に応じて状態保存  
   `--state-file <path>` を付与して保存する
5. 結果報告  
   URL / 実行モード / 使用ツール / 主な所見 / 失敗時の再現手順を簡潔にまとめる

## Artifact Policy

- 保存先は固定: `~/ui-check/YYYYMMDD-Agent名-セッションID/`
- `YYYYMMDD` は日本時間（`Asia/Tokyo`）で生成する
- `Agent名` は `Codex` / `Claude` / `Gemini` を使用する
- `--session` 未指定時は会話セッションID（例: `CODEX_THREAD_ID`）を自動利用する
- セッションIDが検出できない場合は `default-session` を使う
- スクリーンショット名は `yyyymmddhhmm-<tool>.png`（例: `202602181245-playwright.png`）
- `auth` / `form` モードでは `state.json` を同フォルダ配下へ既定保存する

## Mode Examples

- 探索的チェック:
```bash
scripts/ui_check.sh run --mode explore --url https://example.com --agent-name Codex
```

- ログイン導線確認（状態保存あり）:
```bash
scripts/ui_check.sh run --mode auth --url https://example.com/login --agent-name Claude --session login-01
```

- 回帰チェック（再現性重視）:
```bash
scripts/ui_check.sh run --mode regression --tool playwright-cli --url https://example.com --agent-name Gemini
```

## Notes

- `playwright-cli` が無い場合は `npx -y @playwright/cli` にフォールバックする。
- `agent-browser` が無い場合は `npx -y agent-browser` にフォールバックする。
- 実行は常にヘッドレス前提（UI 非表示）で、ブラウザウィンドウを起動しない。
- 画面状態が変わったら要素参照を更新する（再 snapshot）。
- 参照先リポジトリへの依存は持たず、この skill 配下のスクリプトだけで完結する。

## Resources

- `scripts/ui_check.sh`: ツール選択と UI チェック実行
- `references/mode-matrix.md`: モード別の推奨ツールと実行観点
