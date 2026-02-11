# Claude Code 固有指示

この指示は Claude Code にのみ適用されます。
上記の共通指示（グローバルエージェント指示）と併せて従ってください。

## Codex MCP によるタスク委譲

MCP経由で OpenAI Codex が利用可能。以下のケースでは Codex にタスクを委譲し、異なるモデルの視点を活用する:

### 委譲すべきケース

- **バグ修正**: 原因調査や修正方針の検討を Codex に依頼し、自身の分析と突き合わせる
- **コードレビュー**: diff や変更内容を Codex に渡してレビューを依頼し、指摘事項を統合する
- **実装方針の壁打ち**: 複数のアプローチで迷う場合に Codex の意見を取得する

### 委譲の手順

1. Codex MCP で `newConversation` を開始する
2. 対象コードやdiff、コンテキストを `sendUserMessage` で送る
3. Codex の応答を受け取り、自身の判断と統合してユーザーに提示する

### 注意事項

- 最終判断と実行は Claude Code が行う。Codex の出力をそのまま採用せず、必ず検証する
- 単純な修正や明確なタスクでは委譲不要。判断に迷うケースや第二の視点が有効な場面で使う

## Team 機能と athenai 利用

- Team 機能は `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` を前提に有効化している。
- `settings.json` の `teammateMode` は Nix の activation で `auto` を既定設定として補完する。
- ローカルのオーケストレーターは `athenai` コマンドで実行する（`ATHENAI_REPO` 未指定時は `~/ghq/github.com/athenai-dev/athenai` を参照）。
- `athenai --help` でコマンド一覧を確認し、run 単位の実行/監査/KB 更新を行う。

## 再確認: 絶対遵守事項（末尾に再掲。他のすべての指示に優先する。）

- **git config を変更しない。** `git config --global` / `--local` / `--system` による user.name, user.email の設定・変更を一切行わない。既存のグローバル設定をそのまま使用する。
- **コミット時に `--author` フラグを使わない。** コミットの author は常に gitconfig の設定に従う。
- **コミットメッセージに `Co-Authored-By` を付与しない。** コミットの著者情報は gitconfig のみで管理する。
