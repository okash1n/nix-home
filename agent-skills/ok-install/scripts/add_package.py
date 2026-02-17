#!/usr/bin/env python3
"""Add one package attribute into nix-home modules/home/base.nix safely."""

from __future__ import annotations

import argparse
from pathlib import Path


PKGS_START = "home.packages = (with pkgs; ["
LLM_START = "]) ++ (with pkgs.llm-agents; ["


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


def detect_indent(block_lines: list[str]) -> str:
    for line in block_lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        return line[: len(line) - len(line.lstrip())]
    return "    "


def has_attr(block_lines: list[str], attr: str) -> bool:
    for line in block_lines:
        code = line.split("#", 1)[0].strip()
        if code == attr:
            return True
    return False


def add_attr(content: str, attr: str, group: str) -> tuple[str, bool]:
    lines = content.splitlines(keepends=True)
    start, end = find_block(lines, group)
    block = lines[start + 1 : end]

    if has_attr(block, attr):
        return content, False

    indent = detect_indent(block)
    lines.insert(end, f"{indent}{attr}\n")
    return "".join(lines), True


def resolve_target_file(repo: Path, file_arg: str | None) -> Path:
    if file_arg:
        return Path(file_arg).expanduser().resolve()
    return (repo / "modules/home/base.nix").resolve()


def main() -> int:
    parser = argparse.ArgumentParser(description="Add package attr to nix-home base.nix")
    parser.add_argument("--attr", required=True, help="Nix attribute name, e.g. caddy")
    parser.add_argument(
        "--group",
        choices=["pkgs", "llm-agents"],
        default="pkgs",
        help="Target package group in base.nix",
    )
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
        "--dry-run",
        action="store_true",
        help="Do not write changes, only report",
    )
    args = parser.parse_args()

    repo = Path(args.repo).expanduser().resolve()
    target = resolve_target_file(repo, args.file)

    if not target.exists():
        raise SystemExit(f"[ERROR] Target file not found: {target}")

    original = target.read_text(encoding="utf-8")
    updated, changed = add_attr(original, args.attr, args.group)

    if changed and not args.dry_run:
        target.write_text(updated, encoding="utf-8")

    status = "CHANGED" if changed else "UNCHANGED"
    print(f"[{status}] group={args.group} attr={args.attr} file={target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
