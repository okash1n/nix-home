#!/usr/bin/env python3
"""Jina utility operations without MCP.

Supported operations:
- read-url
- parallel-read-url
- search-arxiv
- search-ssrn
- search-bibtex
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import sys
from dataclasses import dataclass
from typing import Any
from urllib import error as urlerror
from urllib import parse as urlparse
from urllib import request as urlrequest

R_JINA_API = "https://r.jina.ai/"
SVIP_JINA_API = "https://svip.jina.ai/"
DBLP_API = "https://dblp.org/search/publ/api"
SEMANTIC_SCHOLAR_API = "https://api.semanticscholar.org/graph/v1/paper/search"
DEFAULT_USER_AGENT = "ok-jina-skill/0.1"
USER_AGENT_ENV = "JINA_USER_AGENT"


class JinaOpsError(Exception):
    """Expected operational error."""


@dataclass(frozen=True)
class CliResult:
    payload: dict[str, Any]
    exit_code: int = 0


def _read_api_key(required: bool) -> str | None:
    token = os.environ.get("JINA_API_KEY")
    token = token.strip() if token else ""
    if required and not token:
        raise JinaOpsError(
            "JINA_API_KEY is required for this operation. "
            "Export JINA_API_KEY and retry."
        )
    return token or None


def _with_default_headers(headers: dict[str, str] | None = None) -> dict[str, str]:
    resolved = dict(headers or {})
    has_user_agent = any(key.lower() == "user-agent" for key in resolved)
    if has_user_agent:
        return resolved
    candidate = os.environ.get(USER_AGENT_ENV, "").strip()
    resolved["User-Agent"] = candidate or DEFAULT_USER_AGENT
    return resolved


def _http_json(
    url: str,
    *,
    method: str = "POST",
    headers: dict[str, str] | None = None,
    payload: dict[str, Any] | None = None,
    timeout: float = 30.0,
) -> dict[str, Any]:
    encoded_payload = None
    if payload is not None:
        encoded_payload = json.dumps(payload).encode("utf-8")
    req = urlrequest.Request(
        url=url,
        data=encoded_payload,
        headers=_with_default_headers(headers),
        method=method,
    )
    try:
        with urlrequest.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            body = raw.decode("utf-8")
            return json.loads(body) if body else {}
    except urlerror.HTTPError as exc:
        details = ""
        try:
            raw = exc.read().decode("utf-8")
            details = raw.strip()
        except Exception:  # noqa: BLE001
            details = ""
        message = f"HTTP {exc.code} {exc.reason}"
        if details:
            message = f"{message}: {details}"
        raise JinaOpsError(message) from exc
    except urlerror.URLError as exc:
        raise JinaOpsError(f"Network error: {exc.reason}") from exc
    except TimeoutError as exc:
        raise JinaOpsError("Request timeout") from exc
    except json.JSONDecodeError as exc:
        raise JinaOpsError("Failed to parse JSON response") from exc


def _normalize_url(text: str) -> str:
    candidate = text.strip()
    if not candidate:
        raise JinaOpsError("URL is empty")
    if not re.match(r"^https?://", candidate, flags=re.IGNORECASE):
        candidate = f"https://{candidate}"
    parsed = urlparse.urlparse(candidate)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise JinaOpsError(f"Invalid URL: {text}")
    return candidate


def _read_url(
    url: str,
    *,
    with_all_links: bool,
    with_all_images: bool,
    timeout: float,
) -> dict[str, Any]:
    normalized_url = _normalize_url(url)
    token = _read_api_key(required=False)
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Md-Link-Style": "discarded",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if with_all_links:
        headers["X-With-Links-Summary"] = "all"
    if with_all_images:
        headers["X-With-Images-Summary"] = "true"
    else:
        headers["X-Retain-Images"] = "none"

    data = _http_json(
        R_JINA_API,
        method="POST",
        headers=headers,
        payload={"url": normalized_url},
        timeout=timeout,
    )
    blob = data.get("data")
    if not isinstance(blob, dict):
        raise JinaOpsError("Unexpected response format: missing data object")

    structured: dict[str, Any] = {
        "url": blob.get("url", normalized_url),
        "title": blob.get("title", ""),
        "content": blob.get("content", ""),
    }
    if with_all_links and isinstance(blob.get("links"), list):
        links: list[dict[str, str]] = []
        for item in blob["links"]:
            if isinstance(item, list) and len(item) >= 2:
                links.append(
                    {
                        "anchorText": str(item[0]),
                        "url": str(item[1]),
                    }
                )
        structured["links"] = links
    if with_all_images and isinstance(blob.get("images"), list):
        structured["images"] = blob["images"]
    return structured


def _cmd_read_url(args: argparse.Namespace) -> CliResult:
    result = _read_url(
        args.url,
        with_all_links=args.with_all_links,
        with_all_images=args.with_all_images,
        timeout=args.timeout,
    )
    return CliResult(payload={"result": result})


def _cmd_parallel_read_url(args: argparse.Namespace) -> CliResult:
    unique_urls: list[str] = []
    seen: set[str] = set()
    for raw in args.url:
        normalized = _normalize_url(raw)
        if normalized in seen:
            continue
        seen.add(normalized)
        unique_urls.append(normalized)
    if not unique_urls:
        raise JinaOpsError("At least one URL is required")

    results: list[dict[str, Any]] = []
    max_workers = min(len(unique_urls), 5)
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_map = {
            executor.submit(
                _read_url,
                url,
                with_all_links=args.with_all_links,
                with_all_images=args.with_all_images,
                timeout=args.timeout,
            ): url
            for url in unique_urls
        }
        for future in concurrent.futures.as_completed(future_map, timeout=args.timeout):
            url = future_map[future]
            try:
                results.append({"url": url, "success": True, "result": future.result()})
            except Exception as exc:  # noqa: BLE001
                results.append({"url": url, "success": False, "error": str(exc)})
    results.sort(key=lambda item: item["url"])
    return CliResult(payload={"results": results})


def _search_domain(
    *,
    query: str,
    domain: str,
    num: int,
    tbs: str | None,
    timeout: float,
) -> dict[str, Any]:
    token = _read_api_key(required=True)
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
    }
    payload: dict[str, Any] = {
        "q": query,
        "domain": domain,
        "num": num,
    }
    if tbs:
        payload["tbs"] = tbs
    data = _http_json(
        SVIP_JINA_API,
        method="POST",
        headers=headers,
        payload=payload,
        timeout=timeout,
    )
    return {
        "query": query,
        "domain": domain,
        "results": data.get("results", []),
    }


def _cmd_search_arxiv(args: argparse.Namespace) -> CliResult:
    return CliResult(
        payload=_search_domain(
            query=args.query,
            domain="arxiv",
            num=args.num,
            tbs=args.tbs,
            timeout=args.timeout,
        )
    )


def _cmd_search_ssrn(args: argparse.Namespace) -> CliResult:
    return CliResult(
        payload=_search_domain(
            query=args.query,
            domain="ssrn",
            num=args.num,
            tbs=args.tbs,
            timeout=args.timeout,
        )
    )


def _generate_key(title: str, year: int | None) -> str:
    words = re.split(r"\s+", title.lower().strip())
    first = re.sub(r"[^a-z0-9]", "", words[0]) if words else "unknown"
    return f"{first or 'unknown'}{year or ''}"


def _escape_bibtex(text: str) -> str:
    return (
        text.replace("&", r"\&")
        .replace("%", r"\%")
        .replace("_", r"\_")
        .replace("$", r"\$")
        .replace("#", r"\#")
    )


def _format_authors(authors: list[str]) -> str:
    return " and ".join(authors)


def _make_bibtex(entry: dict[str, Any]) -> str:
    fields: list[str] = []
    if entry.get("title"):
        fields.append(f"  title = {{{_escape_bibtex(entry['title'])}}}")
    if entry.get("authors"):
        fields.append(f"  author = {{{_format_authors(entry['authors'])}}}")
    if entry.get("year"):
        fields.append(f"  year = {{{entry['year']}}}")
    if entry.get("venue"):
        venue_field = "booktitle" if entry.get("type") == "inproceedings" else "journal"
        fields.append(f"  {venue_field} = {{{_escape_bibtex(entry['venue'])}}}")
    if entry.get("volume"):
        fields.append(f"  volume = {{{entry['volume']}}}")
    if entry.get("number"):
        fields.append(f"  number = {{{entry['number']}}}")
    if entry.get("pages"):
        fields.append(f"  pages = {{{entry['pages']}}}")
    if entry.get("doi"):
        fields.append(f"  doi = {{{entry['doi']}}}")
    if entry.get("url"):
        fields.append(f"  url = {{{entry['url']}}}")
    if entry.get("arxiv_id"):
        fields.append(f"  eprint = {{{entry['arxiv_id']}}}")
        fields.append("  archivePrefix = {arXiv}")
    ref_type = entry.get("type", "misc")
    ref_key = entry.get("key", _generate_key(entry.get("title", "unknown"), entry.get("year")))
    return f"@{ref_type}{{{ref_key},\n" + ",\n".join(fields) + "\n}"


def _normalize_doi(doi: str) -> str:
    return re.sub(r"^doi:", "", re.sub(r"^https?://doi.org/", "", doi.lower())).strip()


def _similarity(a: str, b: str) -> float:
    words_a = {w for w in re.split(r"\s+", a.lower()) if len(w) > 2}
    words_b = {w for w in re.split(r"\s+", b.lower()) if len(w) > 2}
    if not words_a or not words_b:
        return 0.0
    inter = len(words_a.intersection(words_b))
    return inter / max(len(words_a), len(words_b))


def _merge_entries(target: dict[str, Any], source: dict[str, Any]) -> None:
    if source.get("abstract") and (
        not target.get("abstract") or len(source["abstract"]) > len(target["abstract"])
    ):
        target["abstract"] = source["abstract"]
    if source.get("citations") and (
        not target.get("citations") or source["citations"] > target["citations"]
    ):
        target["citations"] = source["citations"]
    for field in ("doi", "arxiv_id", "url", "volume", "pages", "number"):
        if not target.get(field) and source.get(field):
            target[field] = source[field]
    target["bibtex"] = _make_bibtex(target)


def _search_dblp(query: str, *, num: int, year: int | None, author: str | None, timeout: float) -> list[dict[str, Any]]:
    full_query = f"{query} {author}".strip() if author else query
    params = urlparse.urlencode(
        {
            "q": full_query,
            "format": "json",
            "h": str(min(num * 2, 100)),
        }
    )
    data = _http_json(f"{DBLP_API}?{params}", method="GET", timeout=timeout)
    hits = (((data.get("result") or {}).get("hits") or {}).get("hit")) or []
    results: list[dict[str, Any]] = []
    for hit in hits:
        info = hit.get("info") if isinstance(hit, dict) else None
        if not isinstance(info, dict):
            continue
        pub_year = None
        if info.get("year"):
            try:
                pub_year = int(str(info["year"]))
            except ValueError:
                pub_year = None
        if year and pub_year and pub_year < year:
            continue
        raw_authors = ((info.get("authors") or {}).get("author")) if isinstance(info.get("authors"), dict) else None
        authors: list[str] = []
        if isinstance(raw_authors, list):
            for a in raw_authors:
                if isinstance(a, str):
                    authors.append(a)
                elif isinstance(a, dict):
                    authors.append(str(a.get("text") or a.get("_") or "").strip())
        elif isinstance(raw_authors, str):
            authors.append(raw_authors)
        entry_type = "misc"
        if info.get("type") == "Conference and Workshop Papers":
            entry_type = "inproceedings"
        elif info.get("type") == "Journal Articles":
            entry_type = "article"
        elif info.get("type") == "Books and Theses":
            entry_type = "book"
        entry = {
            "type": entry_type,
            "title": str(info.get("title", "")).rstrip("."),
            "authors": [a for a in authors if a],
            "year": pub_year,
            "venue": info.get("venue"),
            "volume": info.get("volume"),
            "number": info.get("number"),
            "pages": info.get("pages"),
            "doi": info.get("doi"),
            "url": info.get("ee") or info.get("url"),
            "source": "dblp",
        }
        entry["key"] = _generate_key(entry["title"], entry["year"])
        entry["bibtex"] = _make_bibtex(entry)
        results.append(entry)
        if len(results) >= num:
            break
    return results


def _search_semantic_scholar(
    query: str,
    *,
    num: int,
    year: int | None,
    timeout: float,
) -> list[dict[str, Any]]:
    params = {
        "query": query,
        "limit": str(min(num * 2, 100)),
        "fields": "title,authors,year,venue,externalIds,abstract,citationCount,url",
    }
    if year:
        params["year"] = f"{year}-"
    data = _http_json(
        f"{SEMANTIC_SCHOLAR_API}?{urlparse.urlencode(params)}",
        method="GET",
        timeout=timeout,
    )
    papers = data.get("data", [])
    results: list[dict[str, Any]] = []
    for paper in papers:
        if not isinstance(paper, dict) or not paper.get("title"):
            continue
        authors = [a.get("name") for a in paper.get("authors", []) if isinstance(a, dict) and a.get("name")]
        external = paper.get("externalIds", {}) if isinstance(paper.get("externalIds"), dict) else {}
        venue_text = str(paper.get("venue") or "")
        entry_type = "inproceedings" if "conference" in venue_text.lower() else "article"
        entry = {
            "type": entry_type,
            "title": paper["title"],
            "authors": authors,
            "year": paper.get("year"),
            "venue": paper.get("venue"),
            "doi": external.get("DOI"),
            "arxiv_id": external.get("ArXiv"),
            "url": paper.get("url"),
            "abstract": paper.get("abstract"),
            "citations": paper.get("citationCount"),
            "source": "semanticscholar",
        }
        entry["key"] = _generate_key(entry["title"], entry.get("year"))
        entry["bibtex"] = _make_bibtex(entry)
        results.append(entry)
        if len(results) >= num:
            break
    return results


def _deduplicate_bibtex(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    seen: dict[str, dict[str, Any]] = {}
    seen_doi: dict[str, str] = {}
    seen_arxiv: dict[str, str] = {}
    for entry in entries:
        doi = entry.get("doi")
        if isinstance(doi, str) and doi.strip():
            normalized = _normalize_doi(doi)
            if normalized in seen_doi:
                _merge_entries(seen[seen_doi[normalized]], entry)
                continue
            seen_doi[normalized] = entry["key"]
        arxiv_id = entry.get("arxiv_id")
        if isinstance(arxiv_id, str) and arxiv_id.strip():
            normalized = re.sub(r"v\d+$", "", arxiv_id)
            if normalized in seen_arxiv:
                _merge_entries(seen[seen_arxiv[normalized]], entry)
                continue
            seen_arxiv[normalized] = entry["key"]
        duplicate_key = None
        for key, existing in seen.items():
            if entry.get("year") == existing.get("year") and _similarity(
                str(entry.get("title", "")),
                str(existing.get("title", "")),
            ) > 0.85:
                duplicate_key = key
                break
        if duplicate_key:
            _merge_entries(seen[duplicate_key], entry)
            continue
        seen[entry["key"]] = entry
    result = list(seen.values())
    result.sort(key=lambda x: (-(int(x.get("year") or 0)), str(x.get("title") or "")))
    return result


def _cmd_search_bibtex(args: argparse.Namespace) -> CliResult:
    dblp = _search_dblp(
        args.query,
        num=args.num,
        year=args.year,
        author=args.author,
        timeout=args.timeout,
    )
    s2 = _search_semantic_scholar(
        args.query,
        num=args.num,
        year=args.year,
        timeout=args.timeout,
    )
    merged = _deduplicate_bibtex(dblp + s2)[: args.num]
    return CliResult(payload={"query": args.query, "results": merged})


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Jina operations without MCP")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output")
    subparsers = parser.add_subparsers(dest="command", required=True)

    read = subparsers.add_parser("read-url", help="Extract readable content from one URL")
    read.add_argument("--url", required=True, help="Target URL")
    read.add_argument("--with-all-links", action="store_true")
    read.add_argument("--with-all-images", action="store_true")
    read.add_argument("--timeout", type=float, default=30.0)
    read.set_defaults(handler=_cmd_read_url)

    parallel_read = subparsers.add_parser(
        "parallel-read-url",
        help="Read multiple URLs in parallel",
    )
    parallel_read.add_argument("--url", action="append", required=True, help="Target URL (repeatable)")
    parallel_read.add_argument("--with-all-links", action="store_true")
    parallel_read.add_argument("--with-all-images", action="store_true")
    parallel_read.add_argument("--timeout", type=float, default=30.0)
    parallel_read.set_defaults(handler=_cmd_parallel_read_url)

    arxiv = subparsers.add_parser("search-arxiv", help="Search arXiv papers via Jina Search API")
    arxiv.add_argument("--query", required=True)
    arxiv.add_argument("--num", type=int, default=30)
    arxiv.add_argument("--tbs", default=None)
    arxiv.add_argument("--timeout", type=float, default=30.0)
    arxiv.set_defaults(handler=_cmd_search_arxiv)

    ssrn = subparsers.add_parser("search-ssrn", help="Search SSRN papers via Jina Search API")
    ssrn.add_argument("--query", required=True)
    ssrn.add_argument("--num", type=int, default=30)
    ssrn.add_argument("--tbs", default=None)
    ssrn.add_argument("--timeout", type=float, default=30.0)
    ssrn.set_defaults(handler=_cmd_search_ssrn)

    bibtex = subparsers.add_parser("search-bibtex", help="Search BibTeX entries (DBLP + Semantic Scholar)")
    bibtex.add_argument("--query", required=True)
    bibtex.add_argument("--num", type=int, default=10)
    bibtex.add_argument("--year", type=int, default=None)
    bibtex.add_argument("--author", default=None)
    bibtex.add_argument("--timeout", type=float, default=30.0)
    bibtex.set_defaults(handler=_cmd_search_bibtex)

    return parser


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()
    try:
        result: CliResult = args.handler(args)
    except JinaOpsError as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    except concurrent.futures.TimeoutError:
        print(json.dumps({"error": "parallel operation timeout"}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001
        print(json.dumps({"error": f"unexpected error: {exc}"}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1

    if args.pretty:
        print(json.dumps(result.payload, ensure_ascii=False, indent=2))
    else:
        print(json.dumps(result.payload, ensure_ascii=False))
    return result.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
