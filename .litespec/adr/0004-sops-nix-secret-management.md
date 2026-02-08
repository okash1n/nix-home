# ADR 0004: sops-nix によるシークレット管理の導入

- Status: Accepted
- Date: 2026-02-08

## Context

- JINA_API_KEY 等のシークレットを Nix 管理下で安全に扱う必要がある。
- 今後 GitHub PAT、OpenAI/Anthropic API キー等も増える見込み。
- 複数マシン間で同じ暗号化ファイルを共有し、各マシンの SSH キーで復号したい。
- シークレットを Git リポジトリにコミットしつつ、平文では保存しない仕組みが必要。

## Decision

sops-nix の home-manager モジュールを使用し、ユーザーレベルでシークレットを管理する。

### 構成

- **暗号化方式**: age（SSH ED25519 キーから変換）
- **暗号化ファイル**: `secrets/secrets.yaml`（sops で暗号化、Git 管理）
- **暗号化ルール**: `.sops.yaml` で age 公開鍵を指定
- **復号タイミング**: macOS では launchd agent (`org.nix-community.home.sops-nix`) がログイン時に復号
- **シークレット配置先**: `~/.config/sops-nix/secrets/`（RAM disk 上）
- **環境変数の配布**: sops templates で `sops-env.sh` を生成し `.zshenv` から source

### 鍵の管理

- `sops.age.sshKeyPaths` に SSH ED25519 鍵（パスフレーズなし）を指定
- sops-nix が SSH 鍵から age 鍵を自動変換して復号に使用
- 新マシン追加時は `ssh-to-age` で公開鍵を取得し `.sops.yaml` に追加後 `sops updatekeys` を実行

## Alternatives Considered

1. **agenix**: sops-nix と類似だが、sops の方がエコシステムが広く YAML/JSON/dotenv 等の複数フォーマットに対応。
2. **環境変数を直接 Nix で管理**: 平文が Nix store に残るためセキュリティ上不適切。
3. **1Password CLI / Bitwarden CLI**: 外部サービスへの依存が増え、オフライン環境で使えない。
4. **git-crypt**: ファイル単位の暗号化のみで、キーごとの個別管理ができない。

## Consequences

- シークレットを Git にコミットしても安全に管理できる。
- 新しいシークレットの追加は `secrets/secrets.yaml` への追記と `sops.nix` へのエントリ追加で完結する。
- 新マシンの追加時にはブートストラップ手順（`validateSopsFiles = false` での初回ビルド、鍵登録、`sops updatekeys`）が必要。
- `~/.zshenv` で sops テンプレートを source するため、全シェルセッションで環境変数が利用可能。
