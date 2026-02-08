# ADR 0003: CLAUDE.md を AGENTS.md から分離

- Status: Accepted
- Date: 2026-02-08

## Context

- Claude Code 固有の指示（Jina Reader によるWebページ取得等）を追加する必要が生じた。
- 現状は `home/dot_config/AGENTS.md` 1ファイルが全AI CLI に同一内容で配布されている。
- Claude Code は `~/.config/claude/CLAUDE.md` のみを読み、`~/.config/AGENTS.md` は読まない。
- Claude 固有の指示を codex / gemini に配布するのは不適切。

## Decision

Nix の `builtins.readFile` でビルド時に AGENTS.md（共通）+ CLAUDE.md（Claude固有）を結合する。

```nix
home.file.".config/claude/CLAUDE.md".text =
  builtins.readFile ../../home/dot_config/AGENTS.md + "\n\n" +
  builtins.readFile ../../home/dot_config/claude/CLAUDE.md;
```

- 共通ルールは `home/dot_config/AGENTS.md` に残す（codex/gemini と共有）
- Claude 固有ルールは `home/dot_config/claude/CLAUDE.md` に分離する
- Nix ビルド時に結合されるため、AGENTS.md の変更も自動的に反映される

## Alternatives Considered

1. **CLAUDE.md に共通ルールを手動複製**: 重複が発生し保守性が悪い。
2. **CLAUDE.md から AGENTS.md を参照する指示を書く**: Claude Code は `~/.config/AGENTS.md` を自動で読まないため不可。
3. **activation script で結合**: Nix の宣言的管理から外れる。

## Consequences

- Claude Code だけに固有の指示を追加可能になる。
- 将来 codex / gemini にも固有指示が必要になった場合、同じパターンで対応できる。
- `.source` から `.text` への変更により、CLAUDE.md の Nix store パスが AGENTS.md と異なるものになる（意図された動作）。
