#!/usr/bin/env python3
"""Sync skills from source root into Claude/Codex/Gemini skill directories.

Safe behavior:
- Link only valid skills (directory containing SKILL.md or skill.md)
- Skip existing non-symlink targets
- Skip symlinks that point outside source root
- Remove stale symlinks that point inside source root but no longer exist in source
"""

from __future__ import annotations

import os
from pathlib import Path


def resolve_dir(path: str) -> Path:
    return Path(path).expanduser().resolve()


def has_skill_md(path: Path) -> bool:
    return (path / "SKILL.md").exists() or (path / "skill.md").exists()


def list_valid_skills(source_root: Path) -> dict[str, Path]:
    skills: dict[str, Path] = {}
    if not source_root.exists():
        return skills

    for item in sorted(source_root.iterdir(), key=lambda p: p.name):
        if not item.is_dir():
            continue
        if item.name.startswith("."):
            continue
        if not has_skill_md(item):
            print(f"[skip] invalid skill (SKILL.md missing): {item.name}")
            continue
        skills[item.name] = item.resolve()

    return skills


def safe_link(src: Path, dst: Path, source_root: Path) -> None:
    if dst.exists() and not dst.is_symlink():
        print(f"[skip] non-symlink target exists: {dst}")
        return

    if dst.is_symlink():
        current_target = dst.resolve(strict=False)
        if current_target != src and source_root not in current_target.parents and current_target != source_root:
            print(f"[skip] external symlink: {dst} -> {current_target}")
            return

    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.is_symlink() or dst.exists():
        dst.unlink()
    dst.symlink_to(src)
    print(f"[link] {dst} -> {src}")


def cleanup_stale_links(target_root: Path, source_root: Path, valid_names: set[str]) -> None:
    if not target_root.exists():
        return

    for candidate in target_root.iterdir():
        if not candidate.is_symlink():
            continue

        target = candidate.resolve(strict=False)
        if source_root not in target.parents and target != source_root:
            continue

        if candidate.name not in valid_names:
            candidate.unlink(missing_ok=True)
            print(f"[cleanup] removed stale link: {candidate}")


def main() -> int:
    source_root = resolve_dir(
        os.environ.get("NIX_HOME_AGENT_SKILLS_DIR", "~/nix-home/agent-skills")
    )

    claude_root = resolve_dir(
        os.environ.get("CLAUDE_SKILLS_DIR", os.path.join(os.environ.get("CLAUDE_CONFIG_DIR", "~/.config/claude"), "skills"))
    )
    codex_root = resolve_dir(
        os.environ.get("CODEX_SKILLS_DIR", os.path.join(os.environ.get("CODEX_HOME", "~/.config/codex"), "skills"))
    )
    gemini_root = resolve_dir(
        os.environ.get(
            "GEMINI_SKILLS_DIR",
            os.path.join(os.environ.get("GEMINI_CLI_HOME", "~/.config/gemini"), ".gemini", "skills"),
        )
    )

    source_root.mkdir(parents=True, exist_ok=True)
    claude_root.mkdir(parents=True, exist_ok=True)
    codex_root.mkdir(parents=True, exist_ok=True)
    gemini_root.mkdir(parents=True, exist_ok=True)

    valid_skills = list_valid_skills(source_root)
    valid_names = set(valid_skills.keys())

    for name, src in valid_skills.items():
        safe_link(src, claude_root / name, source_root)
        safe_link(src, codex_root / name, source_root)
        safe_link(src, gemini_root / name, source_root)

    cleanup_stale_links(claude_root, source_root, valid_names)
    cleanup_stale_links(codex_root, source_root, valid_names)
    cleanup_stale_links(gemini_root, source_root, valid_names)

    print("[ok] sync completed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
