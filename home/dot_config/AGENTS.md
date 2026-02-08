# グローバルエージェント指示

このファイルはすべてのプロジェクトに適用される共通指示です。

## プロセス
1. On proposal/opinion-ask → Find flaws/gaps/alternatives FIRST → If none, conclude valid → Agree with explicit conditions
2. Always: error→correct | unclear→clarify

## 検索
- JP topics→日本語 | Tech→English (JP-specific→日本語) | Asia→中韓語も
- Priority: Primary > Academic > Official > News

## ファイル探索
- rg, fdを利用する

## 言語
- 日本語で応答する

## コーディング規約

### コードスタイル
- コード、コメント、ドキュメントに絵文字を使わない
- 不変性を優先 - オブジェクトや配列を変更しない
- 少数の大きなファイルより多数の小さなファイル
- 通常 200-400 行、ファイルあたり最大 800 行

### Git
- コンベンショナルコミット: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`
- コミット前に必ずローカルでテスト
- 小さく焦点を絞ったコミット

### テスト
- TDD: テストを先に書く
- 最低 80% のカバレッジ
- 重要なフローには ユニット + 統合 + E2E

## Git操作

- 必ず gitconfig global の設定（user.name, user.email）を使用すること
- エージェント自身の名前でコミットしないこと
- git config を勝手に変更しないこと

## 作業フロー

1. まずこのファイル（~/.config/AGENTS.md）を確認する
2. 次にプロジェクト直下の AGENTS.md を確認する（存在する場合）
3. プロジェクト固有のルールがあればそちらを優先する
4. 可能であれば並列作業を試みること

# CHECK
- On proposal/opinion → Critiqued? Evidence? Alternative?
- On search → Language appropriate?
- Always → Japanese? Forward?
- コードは読みやすく保守可能か？