#!/usr/bin/env python3
"""Unit tests for jina_ops helpers."""

from __future__ import annotations

import importlib.util
import pathlib
import sys
import unittest
from unittest import mock


def _load_module():
    here = pathlib.Path(__file__).resolve().parent
    target = here / "jina_ops.py"
    spec = importlib.util.spec_from_file_location("jina_ops", target)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules["jina_ops"] = module
    spec.loader.exec_module(module)  # type: ignore[attr-defined]
    return module


jina_ops = _load_module()


class JinaOpsUnitTest(unittest.TestCase):
    def test_normalize_url_adds_scheme(self) -> None:
        self.assertEqual(
            jina_ops._normalize_url("example.com/path"),
            "https://example.com/path",
        )

    def test_normalize_doi(self) -> None:
        self.assertEqual(
            jina_ops._normalize_doi("https://doi.org/10.1000/xyz"),
            "10.1000/xyz",
        )

    def test_similarity_positive(self) -> None:
        score = jina_ops._similarity(
            "Attention is all you need",
            "Attention mechanism for transformers",
        )
        self.assertGreater(score, 0.2)

    def test_deduplicate_by_doi(self) -> None:
        first = {
            "key": "a2020",
            "type": "article",
            "title": "A paper",
            "authors": ["One"],
            "year": 2020,
            "doi": "10.1000/xyz",
            "source": "dblp",
            "bibtex": "",
        }
        second = {
            "key": "a2020s2",
            "type": "article",
            "title": "A paper",
            "authors": ["One", "Two"],
            "year": 2020,
            "doi": "https://doi.org/10.1000/xyz",
            "citations": 100,
            "source": "semanticscholar",
            "bibtex": "",
        }
        first["bibtex"] = jina_ops._make_bibtex(first)
        second["bibtex"] = jina_ops._make_bibtex(second)
        merged = jina_ops._deduplicate_bibtex([first, second])
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]["citations"], 100)

    def test_default_user_agent_added(self) -> None:
        headers = jina_ops._with_default_headers({"Accept": "application/json"})
        self.assertEqual(headers["User-Agent"], jina_ops.DEFAULT_USER_AGENT)

    def test_user_agent_env_override(self) -> None:
        with mock.patch.dict("os.environ", {jina_ops.USER_AGENT_ENV: "my-agent/1.0"}):
            headers = jina_ops._with_default_headers({})
        self.assertEqual(headers["User-Agent"], "my-agent/1.0")


if __name__ == "__main__":
    unittest.main()
