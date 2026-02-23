# Jina MCP Parity Notes

## Scope

This skill targets the same filtered Jina MCP tool set currently configured in nix-home:

- `read_url`
- `parallel_read_url`
- `search_arxiv`
- `search_ssrn`
- `search_bibtex`

Excluded in current MCP filter:

- `search_web`
- `search_images`
- `capture_screenshot_url`
- `search_jina_blog`

## Source Mapping

- Tool catalog and key requirements: `README.md` in `jina-ai/MCP`
- Read behavior: `src/utils/read.ts`
- arXiv/SSRN behavior: `src/utils/search.ts`
- BibTeX behavior: `src/utils/bibtex.ts`
- Local filter baseline: `scripts/setup-codex-mcp.sh` in this repository

## API Mapping Used by This Skill

- `read-url` / `parallel-read-url`
  - Endpoint: `POST https://r.jina.ai/`
  - Headers: `X-Md-Link-Style`, `X-With-Links-Summary`, `X-With-Images-Summary`, `X-Retain-Images`
- `search-arxiv`
  - Endpoint: `POST https://svip.jina.ai/`
  - Payload core: `{"q": "...", "domain": "arxiv", "num": ...}`
- `search-ssrn`
  - Endpoint: `POST https://svip.jina.ai/`
  - Payload core: `{"q": "...", "domain": "ssrn", "num": ...}`
- `search-bibtex`
  - Provider 1: `https://dblp.org/search/publ/api`
  - Provider 2: `https://api.semanticscholar.org/graph/v1/paper/search`
  - Local dedup strategy: DOI/arXiv/title similarity

## Notes

- `gh` CLI fetch was attempted first for GitHub content, but API access was unavailable in this runtime.
- Fallback fetch used `mcp__jina__read_url` against official GitHub/RAW URLs.
