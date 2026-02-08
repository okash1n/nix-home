# 003-unmanaged-files-check

## 目的

- Nix (home-manager) で管理されていない dotfiles を検出し、管理漏れを把握できるようにする。
- 意図的に管理外としているファイル（ランタイムデータ、認証情報など）を ignore できるようにする。

## ユーザーストーリー

- dotfiles を Nix で管理している利用者として、管理漏れのファイルを定期的に確認したい。
- 新しいツールを導入した後、設定ファイルが Nix 管理に含まれているか確認したい。
- ランタイムデータや認証情報は検出対象から除外したい。

## スコープ

- `$HOME` 直下の dotfiles（`.` 始まり）の未管理ファイル検出
- `$HOME/.config` 配下の未管理ファイル検出
- ignore パターンによる除外機能
- `make check-unmanaged` での実行

## 非スコープ

- 自動的な Nix 管理への追加
- CI/CD での自動検証
- 検出結果のレポート出力

## 機能要件

### FR-001 未管理ファイル検出

- `scripts/check-unmanaged.sh` で未管理ファイルを検出する。
- home-manager 管理下のファイル（`/nix/store/` へのシンボリックリンク）は除外する。
- 検査対象は以下の2箇所とする:
  - `$HOME` 直下の dotfiles（`.` で始まるファイル・シンボリックリンク、depth=1）
  - `$HOME/.config` 配下すべて
- `Pictures`, `Documents` などの非 dotfiles ディレクトリは検査対象外とする。
- `make check-unmanaged` で実行可能にする。

### FR-002 ignore 機能

- `scripts/.unmanaged-ignore` で ignore パターンを定義する。
- glob パターン形式で指定可能にする。
- `#` で始まる行はコメントとして扱う。
- 空行は無視する。

### FR-003 デフォルト ignore パターン

- ランタイム・キャッシュ系（history, cache, tmp, log）を除外する。
- 認証・シークレット系（auth.json, oauth, credentials, token, key, pem）を除外する。
- Nix 管理ディレクトリ（.nix-profile, .nix-defexpr）を除外する。
- $HOME 直下のランタイム系（.zsh_sessions, .viminfo, .claude.json, .vscode, .npm, .local）を除外する。
- Nix 管理の dotfiles（.gitconfig）を除外する。
- Claude Code のランタイムデータ（projects, todos, plugins, debug, file-history, shell-snapshots）を除外する。
- Codex のランタイムデータ（sessions, skills, config.toml, models_cache.json）を除外する。
- Gemini のランタイムデータ（settings.json, state.json, installation_id）を除外する。
- home.activation で管理しているファイル（hanabi テーマ関連）を除外する。
- macOS システムファイル（.DS_Store, .localized, .CFUserTextEncoding）を除外する。

### FR-004 出力

- 未管理ファイルを黄色で表示する。
- サマリーで未管理ファイル数と ignore されたファイル数を表示する。
- 未管理ファイルがある場合、ignore ファイルへの追加を促すヒントを表示する。

## 非機能要件

- パフォーマンス: nix-home でインストールされるツール（fd, rg）を活用する。
- 可読性: ignore パターンはカテゴリごとにコメントで整理する。
- 保守性: 新ツール導入時に ignore パターンを追加しやすい構造にする。

## 受け入れ条件（DoD）

- `make check-unmanaged` が正常終了する。
- Nix 管理下のファイル（例: `~/.config/AGENTS.md`）が検出されない。
- ignore パターンにマッチするファイルが検出されない。
- 本当に未管理のファイル（例: `~/.config/karabiner/karabiner.json`）が検出される。
- `Pictures`, `Documents` などの非 dotfiles ディレクトリは検査されない。

## 依存・前提

- `fd` コマンドが利用可能（nix-home でインストール済み）。
- home-manager で管理されているファイルは `/nix/store/` へのシンボリックリンクになっている。

## テスト観点

- 正常系: 未管理ファイルが正しく検出される。
- 正常系: Nix 管理ファイルが除外される。
- 正常系: ignore パターンにマッチするファイルが除外される。
- 異常系: 存在しないディレクトリを指定した場合にエラーにならない。

## 実装メモ

- bash の `[[ "$file" == $pattern ]]` で glob パターンマッチングを行う。
- `set -euo pipefail` を使用しているため、算術演算は `$((x + 1))` 形式を使用。
- home.activation で配置されるファイル（hanabi テーマ等）は symlink ではないため ignore で対応。
