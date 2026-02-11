# ADR 0006: XDG系AI CLI環境変数のシェルフォールバック導入

- Status: Accepted
- Date: 2026-02-11

## Context

- AI CLI（Claude Code / Codex / Gemini）の設定ディレクトリは `environment.variables` で `~/.config/*` に寄せている。
- ただし macOS では、親プロセスから `__NIX_DARWIN_SET_ENVIRONMENT_DONE=1` だけが継承されるケース（VS Code 統合ターミナル等）がある。
- この状態では `/etc/zshenv` / `/etc/bashrc` が `set-environment` をスキップし、`CODEX_HOME` などの値が未設定になりうる。
- 結果として `~/.claude` / `~/.codex` / `~/.gemini` にフォールバック作成され、XDG統一方針が崩れる。

## Decision

- 既存の `environment.variables` は維持する。
- GUI 起動経路の安定化として `launchd.user.envVariables` に同等の値を設定する。
- `launchd` 側は `$HOME` が展開されないため、`/Users/${username}/...` の絶対パスを使う。
- `launchd.user.envVariables` を使うため、`system.primaryUser` を `username` に設定する。
- さらにシェル側の保険として、`~/.zshenv` と `~/.bashrc` に以下のフォールバック export を追加する（既存値がある場合は上書きしない）。

```sh
: "${CLAUDE_CONFIG_DIR:=$HOME/.config/claude}"
: "${CODEX_HOME:=$HOME/.config/codex}"
: "${GEMINI_CLI_HOME:=$HOME/.config/gemini}"
: "${VIMINIT:=source $HOME/.config/vim/vimrc}"
export CLAUDE_CONFIG_DIR CODEX_HOME GEMINI_CLI_HOME VIMINIT
```

## Consequences

- `__NIX_DARWIN_SET_ENVIRONMENT_DONE` の継承状態に依存せず、zsh/bash から同じ設定値を取得できる。
- VS Code 統合ターミナルなどでも `~/.config/*` が優先され、`~/.claude` / `~/.codex` / `~/.gemini` の再生成リスクが下がる。
- 環境変数定義が複数レイヤー（system / launchd / shell）に分散するため、変更時の更新箇所は増える。

## Alternatives Considered

1. **`environment.variables` のみ運用する**: 既知の継承パターンで欠落するため却下。
2. **旧ディレクトリ（`~/.claude` 等）をシンボリックリンク固定する**: 互換性は高いが、ホーム直下を整理したい要件に反するため採用しない。
3. **各CLI実行ラッパーで都度 export する**: 呼び出し経路漏れが発生しやすく、保守性が低いため採用しない。
