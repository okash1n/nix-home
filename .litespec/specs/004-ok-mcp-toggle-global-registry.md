# 004-ok-mcp-toggle-registry

## 目的

- `ok-mcp-toggle` を、MCP 定義レジストリを中心に運用する管理ツールとして定義する。
- MCP を `global` と `project` の 2 スコープで扱えるようにする。
- 認証情報はホーム配下に保持し、プロジェクトローカルには設定宣言のみを配置する。

## ユーザーストーリー

- 利用者として、MCP の一覧（名前・スコープ・認証方式）を見たい。
- 利用者として、常時利用する MCP は global、有効化したい時だけ使う MCP は project で運用したい。
- 利用者として、OAuth を一度通した後は別プロジェクトでも再認証コストを下げたい。

## スコープ

- `ok-mcp-toggle` は以下コマンドを提供する:
  - `list`
  - `add`
  - `remove`
  - `enable`
  - `disable`
  - `status`
  - `preauth`
- 管理対象クライアントは `claude` / `gemini`。
- レジストリと状態を分離する:
  - `registry.json`（静的定義）
  - `state.json`（動的状態）
- スコープは `global` / `project` の両対応。

## 非スコープ

- `codex` の MCP 有効化/無効化管理。
- OAuth 秘密情報のプロジェクトローカル保存。
- 「どのプロジェクトで有効化したか」の履歴管理。

## 機能要件

### FR-001 レジストリ管理

- レジストリは JSON で管理する（例: `agent-skills/ok-mcp-toggle/config/registry.json`）。
- 各 MCP は少なくとも以下を持つ:
  - `name`
  - `scope`（`global` / `project`）
  - `auth`（`none` / `token` / `oauth`）
  - `default_enabled`
  - `clients_supported`
  - `env_requirements`
  - `description`

### FR-002 一覧表示

- `list` は以下を表示する:
  - `name`
  - `scope`
  - `auth`
  - `default_enabled`
  - `clients_supported`
  - `preauth_status`
  - `env_requirements`
  - `last_preauth_at`
  - `last_error`

### FR-003 global 有効化

- `enable` で `scope=global` MCP をユーザー設定へ反映できる。
- `--default` は `scope=global` かつ `default_enabled=true` を対象とする。

### FR-004 project 有効化

- `enable` で `scope=project` MCP をプロジェクト設定へ反映できる。
- プロジェクト root はカレントディレクトリ（必要時 `NIX_HOME_MCP_PROJECT_DIR` で上書き）。
- project 有効化時に、生成ファイルの ignore 先（`.gitignore` / `.git/info/exclude` / 追加しない）を対話で選べる。

### FR-005 remove

- `remove` は対象 MCP をレジストリから削除する。
- 同時に対象クライアントの設定（global/project 該当スコープ）を削除または無効化する。
- 認証情報（ホーム配下）は削除しない。

### FR-006 preauth

- `preauth` は MCP 選択 + クライアント選択に対応する。
- 認証方式ごとの扱い:
  - `none`: `ok`
  - `token`: 必須環境変数チェック後 `ok`
  - `oauth`: 完全自動化はせず、必要時 `pending_user_auth` を記録
- 結果は `state.json` に記録する。

### FR-007 add / remove の対話運用

- `add/remove/enable/disable/preauth` は対話モードを既定にする。
- 非対話引数は上級者向けに残す。
- `add` は preauth 失敗時に登録しない。

### FR-008 認証情報の再利用

- OAuth トークン等はホーム配下に保持し、project 間で再利用可能にする。
- project 有効化時は設定宣言のみプロジェクト配下へ作る。

## 非機能要件

- セキュリティ:
  - レジストリ/状態に秘密値を保存しない。
  - 認証情報はホーム配下の既存ストアを使用する。
- 可観測性:
  - クライアント別の成功/失敗理由を表示する。
- 保守性:
  - クライアント差異はアダプタ層に閉じ込める。

## 受け入れ条件（DoD）

- `list` で `scope` を含む統合表示ができる。
- `enable` が `global/project` の両スコープに反映できる。
- `remove` がレジストリ削除 + クライアント側削除/無効化を行う。
- `status` でクライアント別状態と preauth 状態を確認できる。
- `codex` へ設定書き込みしない。

