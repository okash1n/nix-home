# Claude Code 固有指示

この指示は Claude Code にのみ適用されます。
上記の共通指示（グローバルエージェント指示）と併せて従ってください。

## Webページ取得

Webページの内容をマークダウンとして取得する場合、以下の優先順位で取得する:

1. **Jina Reader（優先）**: `curl -H "Authorization: Bearer $JINA_API_KEY" https://r.jina.ai/<URL>`
2. **WebFetch（フォールバック）**: Jina Reader が失敗した場合に使用

### 注意事項

- GitHub のコンテンツは `gh` CLI を優先する
- OSS の実装調査は `ghq get` でリポジトリを取得してソースを直接読む
- `JINA_API_KEY` 環境変数が未設定の場合は、APIキーなしの `r.jina.ai` を使用する（レート制限: 100 RPM）
