#!/usr/bin/env python3
"""Search installed package attrs in nix-home modules/home/base.nix."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


PKGS_START = "home.packages = (with pkgs; ["
LLM_START = "]) ++ (with pkgs.llm-agents; ["
ATTR_PATTERN = re.compile(r"^[A-Za-z0-9._+-]+$")


def find_block(lines: list[str], group: str) -> tuple[int, int]:
    if group == "pkgs":
        start = next((i for i, line in enumerate(lines) if PKGS_START in line), -1)
        if start < 0:
            raise ValueError(f"Could not find block start: {PKGS_START}")
        end = next((i for i in range(start + 1, len(lines)) if LLM_START in lines[i]), -1)
        if end < 0:
            raise ValueError(f"Could not find block end: {LLM_START}")
        return start, end

    start = next((i for i, line in enumerate(lines) if LLM_START in line), -1)
    if start < 0:
        raise ValueError(f"Could not find block start: {LLM_START}")

    end = -1
    for i in range(start + 1, len(lines)):
        if lines[i].strip() == "]);":
            end = i
            break
    if end < 0:
        raise ValueError("Could not find llm-agents block end: ]);")
    return start, end


def extract_attrs(lines: list[str], group: str) -> list[str]:
    start, end = find_block(lines, group)
    attrs: list[str] = []
    for line in lines[start + 1 : end]:
        code = line.split("#", 1)[0].strip()
        if not code:
            continue
        if ATTR_PATTERN.fullmatch(code):
            attrs.append(code)
    return attrs


def resolve_target_file(repo: Path, file_arg: str | None) -> Path:
    if file_arg:
        return Path(file_arg).expanduser().resolve()
    return (repo / "modules/home/base.nix").resolve()


def contains_query(value: str, query: str) -> bool:
    return query.lower() in value.lower()


def main() -> int:
    parser = argparse.ArgumentParser(description="Search installed attrs in nix-home base.nix")
    parser.add_argument("--query", required=True, help="Keyword to search")
    parser.add_argument(
        "--repo",
        default="~/nix-home",
        help="Path to nix-home repository (default: ~/nix-home)",
    )
    parser.add_argument(
        "--file",
        default=None,
        help="Optional explicit file path (overrides --repo target)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print JSON output",
    )
    args = parser.parse_args()

    repo = Path(args.repo).expanduser().resolve()
    target = resolve_target_file(repo, args.file)

    if not target.exists():
        raise SystemExit(f"[ERROR] Target file not found: {target}")

    lines = target.read_text(encoding="utf-8").splitlines()
    pkgs = extract_attrs(lines, "pkgs")
    llm = extract_attrs(lines, "llm-agents")

    result = {
        "query": args.query,
        "file": str(target),
        "pkgs": [attr for attr in pkgs if contains_query(attr, args.query)],
        "llm_agents": [attr for attr in llm if contains_query(attr, args.query)],
    }

    if args.json:
        print(json.dumps(result, ensure_ascii=False))
        return 0

    print(f"[query] {args.query}")
    print("[installed] pkgs")
    if result["pkgs"]:
        for attr in result["pkgs"]:
            print(f"  - {attr}")
    else:
        print("  (no match)")

    print("[installed] llm-agents")
    if result["llm_agents"]:
        for attr in result["llm_agents"]:
            print(f"  - {attr}")
    else:
        print("  (no match)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
