# ADR 0015: VS Code 本体を Nix 管理対象外にし、設定/拡張のみ Nix 管理を維持する

- Status: Accepted
- Date: 2026-03-05

## Context

- 既存構成では `modules/darwin/base.nix` で `pkgs.vscode` を導入し、`/Applications/Nix Apps/Visual Studio Code.app` を生成していた。
- 一方で VS Code の設定/拡張管理は `modules/home/vscode.nix` に分離済みで、Home Manager のリンク管理と activation script により再現できている。
- 利用者要件として、アプリ本体は Nix 管理から外し、設定や拡張は現状どおり Nix 管理を継続したい。
- `pkgs.vscode` を外すだけだと `code` コマンドが PATH から消える可能性があり、拡張同期が停止する。

## Decision

- VS Code 本体バイナリの導入は Nix の責務から外す。
  - `modules/darwin/base.nix` の `environment.systemPackages` から `pkgs.vscode` を削除する。
  - VS Code のためだけに置いていた `allowUnfreePredicate` は削除する。
  - `flake.nix` の Home Manager 用 `allowUnfreePredicate` も削除する。
- `modules/home/vscode.nix` による設定/拡張管理は継続する。
- 拡張同期で使う VS Code CLI は次の優先順で解決する。
  - `command -v code`
  - `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`
  - `$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`
- CLI を解決できない場合は、拡張同期のみスキップして処理全体は継続する。

## Alternatives Considered

1. VS Code 本体も従来どおり Nix 管理する
   - 利点: 完全宣言管理を維持できる。
   - 欠点: 利用者要件（本体を Nix 管理から外す）を満たさない。
2. 設定/拡張も VS Code Sync に全面移行する
   - 利点: アプリ側の標準機能に寄せられる。
   - 欠点: Git での差分追跡・再現性が弱くなり、既存運用と整合しない。
3. `code` コマンドが無い場合は常に失敗にする
   - 利点: 不整合を早期検出できる。
   - 欠点: GUI アプリ導入直後や PATH 未設定時の運用耐性が下がる。

## Consequences

- VS Code 本体の更新・再インストールは利用者側運用（手動導入や Homebrew 等）になる。
- VS Code 設定ファイルと拡張リストの宣言管理は従来どおり継続できる。
- `code` コマンド未設定環境でも、標準インストールパスにアプリがあれば拡張同期が動作する。
