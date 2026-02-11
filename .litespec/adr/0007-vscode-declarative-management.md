# ADR 0007: VS Code 設定の宣言管理方式を Home Manager + activation に統一する

- Status: Accepted
- Date: 2026-02-11

## Context

- VS Code 設定（`settings.json` / `keybindings.json` / snippets）が手動管理で、再構築時に再現できなかった。
- 既存実装は activation script で `settings.json` の `workbench.colorTheme` のみを都度書き換えており、設定全体の宣言管理にはなっていなかった。
- 複数 OS で Settings Sync を使うと、`cmd` / `ctrl` 差分で keybind が崩れやすい。
- 一方で拡張機能は Marketplace 配布（Nix パッケージ未提供）も含むため、`programs.vscode.extensions` だけでは完結しない。

## Decision

- VS Code のユーザー設定ファイルは `home.file` で宣言的に配置する。
- 配置方式は `mkOutOfStoreSymlink` とし、リンク先を `~/nix-home/home/dot_config/vscode/` 配下に固定する。
  - `settings.json`
  - `keybindings.json`
  - `snippets/global.code-snippets`
- `keybindings.json` は空配列（`[]`）で固定し、OS 差分を生みやすい独自キーバインドを持ち込まない。
- 拡張機能リストは `home/dot_config/vscode/extensions.txt` を正本にする。
- activation script は `extensions.txt` の未導入分を `code --install-extension` で導入し、VS Code UI 側で追加された拡張を `extensions.txt` に取り込む（additive sync）。
- 既存の `hanabi-theme` モジュールにあった `settings.json` 書き換え処理は削除し、VS Code 専用モジュールへ責務分離する。

## Alternatives Considered

1. **`programs.vscode` に完全移行する**
   - 利点: Home Manager の標準機能に寄せられる。
   - 欠点: Marketplace 直配布拡張の管理に制約があり、現行要件（Hanabi 拡張含む）と相性が悪い。
2. **activation script のみで JSON を毎回パッチする**
   - 利点: 既存方式の延長で実装が早い。
   - 欠点: 宣言管理にならず、設定の全体像や差分追跡が困難。
3. **VS Code Sync に寄せる**
   - 利点: OS 間で設定共有が容易。
   - 欠点: `cmd` / `ctrl` 差分で keybind が崩れる問題を根本解決しない。

## Consequences

- VS Code 設定ファイルは Git 管理下で再現可能になり、再構築時の差分が明確になる。
- 独自 keybind を持たないことで、OS ごとの `cmd` / `ctrl` 差分による崩れを回避しやすい。
- 拡張機能は「宣言ファイル + 取り込み自動化」のハイブリッドで運用し、VS Code 側の追加を Git 管理へ反映できる。
- VS Code 側で削除した拡張を自動で `extensions.txt` から除去する運用は採用しない（削除は `extensions.txt` を直接編集する）。
- VS Code の UI から `settings.json` / `keybindings.json` を直接編集すると、`~/nix-home/home/dot_config/vscode/` 側に変更が反映される。
