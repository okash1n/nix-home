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
- 追加の品質ゲートを適用する:
  - Agent Skills 仕様に沿った frontmatter 検証
  - ディレクトリ名と skill 名の整合検証
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

作成先の既定値:

- `$NIX_HOME_AGENT_SKILLS_DIR` があればそれを使用
- 未設定なら `~/nix-home/agent-skills`

### 4. SKILL.md を仕様意識で記述する

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

### 5. 検証する

まずローカル厳密検証を実行:

```bash
scripts/quick_validate.py <path/to/skill>
```

`skills-ref` が使える場合は仕様検証も実行:

```bash
skills-ref validate <path/to/skill>
```

利用可能な検証がすべて通ってはじめて完成とする。

### 6. すぐ使いたい場合は同期する（任意）

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
- 検証スクリプトが通る
- リソースが最小限で実用的
- 不要ドキュメントを作っていない

## 参照

- Agent Skills 仕様チェック: `references/agentskills-spec-checklist.md`
- nix-home の運用メモ: `references/nix-home-agent-skills.md`
