# ADR 0005: Makefile ターゲット追加とホスト名分離

- Status: Accepted
- Date: 2026-02-11

## Context

- `make init` 以外の日常操作（ビルド、適用、更新、MCP 設定）に対応する Makefile ターゲットが存在しなかった。
- `darwinConfigurations` のキーが `default` 固定で、ホスト名に応じた flake ターゲット切り替えができなかった。
- 複数マシン対応の前提として、ホスト固有設定の分離が必要だった。

## Decision

### ホスト名分離

- `hosts/darwin/default.nix` からホスト名設定（`networking.hostName`）を削除し、汎用ベース設定にする。
- ホスト固有設定は `hosts/darwin/<hostname>.nix` として分離し、`default.nix` を `imports` する。
- `flake.nix` の既存ロジック（`readDir` で `.nix` ファイルを列挙）はそのまま活用する。

### Makefile ターゲット

- `darwin-rebuild` を直接使用する（bootstrap 後は `nix run nix-darwin --` 不要）。
- ホスト名解決は `hostname -s` で取得し、対応する `.nix` ファイルの有無で `TARGET` を決定する。
- `build` は sudo 不要（システム適用しないため）。`switch` は sudo 必須。
- `NIX_HOME_USERNAME` を明示的に渡す（sudo が環境変数をストリップするため）。
- `--impure` は `builtins.getEnv` で `NIX_HOME_USERNAME` を読むために必要。
- `update` は `build` → `switch` の順で実行（検証方針「switch 前に build」に準拠）。
- `mcp` は sops-env.sh から環境変数を読み込んだ上で3スクリプトを `;` で連結（1つが失敗しても残りを実行）。

### MCP スクリプトのガード

- 各 MCP セットアップスクリプトの冒頭に `command -v` ガードを追加し、対象コマンドが未導入の場合は `exit 0` でスキップする。
- `make mcp` を安全に実行でき、未導入のツールがあっても残りの設定が継続される。

## Alternatives Considered

1. **`nix run nix-darwin --` を使用**: bootstrap 前の初期化時には必要だが、`init.sh` 実行後は `darwin-rebuild` がパスに入っているため不要。シンプルさを優先。
2. **ホスト名設定を `flake.nix` 内で管理**: ホスト固有設定が増えた場合にスケールしない。`.nix` ファイル分離の方が拡張性が高い。
3. **`mcp` ターゲットで `&&` 連結**: 1つのスクリプトが失敗すると残りが実行されない。各スクリプトは独立しているため `;` 連結が適切。

## Consequences

- `make build` / `make switch` / `make update` で日常操作が簡潔に実行できる。
- `make mcp` で AI CLI の MCP 設定を一括セットアップできる。
- 新しいホストの追加は `hosts/darwin/<hostname>.nix` の作成のみで完結する。
- MCP スクリプトは対象コマンドが未導入でも安全にスキップする。
