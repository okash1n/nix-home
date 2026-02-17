---
name: ok-git
description: git config global を前提に、日常的な Git 操作（状況確認・ブランチ作成・安全コミット・同期）を実行する。ユーザーが「コミットして」「ブランチ切って」「pushして」「差分見て」などを依頼したときに使う。git config は変更せず既存設定を利用する。
compatibility: claude,codex,gemini
---

# OK Git

## 目的

Git 日常作業を安全に高速化する。  
この skill は `git config` を変更せず、既存の global 設定を使って操作する。

## トリガー例

- 「この変更をコミットして push して」
- 「作業ブランチ切って進めて」
- 「今の状態と差分を見て」
- 「rebase pull して同期して」

## 絶対ルール

- `git config --global` / `--local` / `--system` を変更しない。
- `git commit --author` を使わない。
- コミットメッセージに `Co-Authored-By` を入れない。
- 破壊的操作（`reset --hard`、履歴改変 push など）はユーザー明示指示がない限り行わない。

## 標準フロー

### 1. 状態確認

```bash
scripts/git_ops.sh inspect
```

以下を確認する:

- 現在ブランチ
- 変更状況（`git status -sb`）
- remote
- global / effective の `user.name`, `user.email`

### 2. ブランチ作成（必要時）

```bash
scripts/git_ops.sh start-branch --name <branch-name> --base main
```

- 既存ブランチ名との衝突を検出して停止する。
- `--base` を省略すると現在ブランチから作成する。

### 3. 安全コミット

全変更をまとめてコミット:

```bash
scripts/git_ops.sh commit --all --message "<日本語メッセージ>"
```

対象ファイルだけコミット:

```bash
scripts/git_ops.sh commit --paths "path/a,path/b" --message "<日本語メッセージ>"
```

ルール:

- コミット時は global `user.name` / `user.email` を明示的に使用する。
- `Co-Authored-By` を含むメッセージは拒否する。

### 4. 同期（pull/push）

rebase pull:

```bash
scripts/git_ops.sh sync
```

rebase pull + push:

```bash
scripts/git_ops.sh sync --push
```

## 失敗時の対処

- コンフリクト時は自動解決しない。競合ファイルを提示してユーザー確認後に進める。
- global identity が未設定の場合は停止し、設定状況を報告する（設定変更は行わない）。

## 実装補助

- 統合スクリプト: `scripts/git_ops.sh`
