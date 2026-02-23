---
name: ok-skill-creator
description: agent-skills 配下で Claude/Codex/Gemini 互換の Agent Skill を作成・更新する。Skill の設計、実装、検証、リファクタ時に使う。Agent Skills 仕様準拠、frontmatter 検証強化、再利用スクリプト作成、~/nix-home/agent-skills 運用が必要な場合に使う。
compatibility: claude,codex,gemini
---

# OK Skill Creator

## 目的

`~/nix-home/agent-skills` で、Claude/Codex/Gemini の3エージェントから同じように使える Skill を作成・更新する。  
この skill はシステム側の `skill-creator` の有無を前提にしない。

## 必須要件

- 具体的な利用例を収集し、発火条件を明確化する。
- `scripts/` `references/` `assets/` を必要最小限で設計する。
- スクリプトで雛形生成し、検証を通してから仕上げる。
- 外部情報を使う skill では、根拠ソースを `references/source-manifest.json` に記録する。
- 実装方式は毎回比較して選ぶ（公式CLI / SDK / 直接HTTP）。固定しない。
- 公式CLIが最適な場合は Nix 経由で導入する（`ok-search` で attr 探索 → `ok-install` で導入）。
- 外部API系の skill は実装前に必ずプリフライト疎通を行う（実URL・実認証・最小リクエスト）。
- 追加の品質ゲートを適用する:
  - Agent Skills 仕様に沿った frontmatter 検証
  - ディレクトリ名と skill 名の整合検証
  - `source-manifest` を使う場合の JSON 構造検証
  - `skills-ref validate` が利用可能な場合の併用
- 3エージェント互換を必須にする:
  - frontmatter に `compatibility: claude,codex,gemini` を設定する
  - 特定エージェント専用の手順だけで完結させない
  - 専用手順が必要な場合は他エージェント向け代替手順を併記する
- この環境では skill 作成先を `~/nix-home/agent-skills` 優先にする。
- 各エージェントの `skills/` を直接編集せず、symlink 同期方式で扱う。

## 作業フロー

### 1. 意図を具体化する

この skill が発火すべきユーザー依頼を 2〜5 個集める。
要件が曖昧なら、トリガー条件が判定できるまで質問して確定する。

### 2. 構造と自由度を決める

まず主構造を 1 つ選ぶ:

- workflow-based
- task-based
- reference/guideline-based
- capability-based

次に、どこを deterministic にするか決める:

- 壊れやすい処理: `scripts/`
- 長文知識: `references/`
- 出力資産: `assets/`

### 3. 雛形を作成する

同梱スクリプトを使って初期化する:

```bash
scripts/init_skill.py <skill-name> [--path <dir>] [--resources scripts,references,assets]
```

外部情報を前提にする skill は manifest 付きで作る:

```bash
scripts/init_skill.py <skill-name> --with-source-manifest
```

作成先の既定値:

- `$NIX_HOME_AGENT_SKILLS_DIR` があればそれを使用
- 未設定なら `~/nix-home/agent-skills`

### 4. 根拠ソースを収集して記録する

外部情報を使う場合は、ツール依存にせず次を実施する:

- Git 公開情報: `ghq get` で取得し、commit/hash を記録
- Web 公開情報: プロジェクト規約に沿った取得手段で取得し、URL と取得日を記録
- 必要な抜粋・要約: KB に格納し、KBノートIDを記録

`references/source-manifest.json` には最低限これを残す:

- `id`
- `kind`（`git|web|local|api|other`）
- `uri`
- `snapshot`
- `retrieved_at`
- `kb_refs`（必要な場合）

### 5. 実装方式を選定する

次の順に候補を評価する:

1. 公式CLI
2. 公式SDK
3. 直接HTTP（`curl` や `fetch` など）

判定観点:

- 目的機能のカバー率
- 認証フローの実装難易度
- 失敗時の再試行・エラー分類のしやすさ
- 実装/保守コスト

実装開始前の必須プリフライト:

- 公式ドキュメント（一次情報）を確認する
- 実URLを使って最小の成功ケースを `curl` / 公式CLI / SDKサンプルで実行する
- 認証あり/なし、HTTPステータス、主要ヘッダ（例: `Authorization`, `User-Agent`）の要件を確認する
- 失敗する場合は「何が失敗するか」を先に特定し、実装で吸収するか運用制約として明記する

公式CLIを採用する場合の必須ルール:

- 直接グローバルインストールはしない
- `ok-search` で Nix attr を特定する
- `ok-install` で `~/nix-home` 経由で導入し、`make build` / `make switch` / `command -v` まで確認する
- Skill 本文には利用するCLIコマンドと失敗時分岐を明記する

### 6. SKILL.md を仕様意識で記述する

必須:

- `name`
- `description`
- `compatibility`（`claude,codex,gemini`）

任意（必要時のみ）:

- `license`
- `metadata`
- `allowed-tools`

方針:

- 必須項目は常に設定する
- 任意項目は運用価値がある場合のみ追加する
- 未定義キーは入れない
- 特定エージェント名を記載する場合は Claude/Codex/Gemini の3つを同時に扱う

### 7. 検証する

まずローカル厳密検証を実行:

```bash
scripts/quick_validate.py <path/to/skill>
```

`skills-ref` が使える場合は仕様検証も実行:

```bash
skills-ref validate <path/to/skill>
```

利用可能な検証がすべて通ってはじめて完成とする。

### 8. すぐ使いたい場合は同期する（任意）

`make switch` を待たずに即時反映したい場合:

```bash
scripts/sync_links.py
```

`~/nix-home/agent-skills` から次へ安全に symlink 同期する:

- `~/.config/claude/skills`
- `~/.config/codex/skills`
- `~/.config/gemini/.gemini/skills`

## 品質チェックリスト

- 発火条件が具体的で判定可能
- `SKILL.md` frontmatter が妥当で、ディレクトリ名と一致
- `compatibility: claude,codex,gemini` が入っている
- 外部情報を使う skill では `source-manifest` があり、検証を通る
- 公式CLI採用時は Nix 経由で導入され、再現手順が Skill に明記されている
- 外部API系の skill はプリフライト疎通の結果（成功/失敗条件）が Skill または references に記録されている
- 検証スクリプトが通る
- リソースが最小限で実用的
- 不要ドキュメントを作っていない

## 参照

- Agent Skills 仕様チェック: `references/agentskills-spec-checklist.md`
- nix-home の運用メモ: `references/nix-home-agent-skills.md`
- source-manifest 形式: `references/source-manifest-format.md`
- 実装方式の選定: `references/implementation-strategy.md`
