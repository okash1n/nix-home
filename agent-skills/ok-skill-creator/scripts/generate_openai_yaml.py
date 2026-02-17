#!/usr/bin/env python3
"""Generate agents/openai.yaml with deterministic defaults."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ALLOWED_INTERFACE_KEYS = {
    "display_name",
    "short_description",
    "icon_small",
    "icon_large",
    "brand_color",
    "default_prompt",
}


def yaml_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{escaped}"'


def format_display_name(skill_name: str) -> str:
    words = [w for w in skill_name.split("-") if w]
    return " ".join(word.capitalize() for word in words)


def default_short_description(display_name: str) -> str:
    candidate = f"Create and refine {display_name} workflows"
    if len(candidate) > 64:
        candidate = f"Create and refine {display_name} skills"
    if len(candidate) > 64:
        candidate = f"{display_name} skill helper"
    if len(candidate) < 25:
        candidate = f"{candidate} with quality checks"
    return candidate[:64].rstrip()


def default_prompt(skill_name: str, display_name: str) -> str:
    return f"Use ${skill_name} to create a robust {display_name} skill."


def read_frontmatter_name(skill_dir: Path) -> str:
    for name in ("SKILL.md", "skill.md"):
        skill_md = skill_dir / name
        if not skill_md.exists():
            continue

        content = skill_md.read_text(encoding="utf-8")
        match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
        if not match:
            continue

        for line in match.group(1).splitlines():
            raw = line.rstrip()
            if not raw or raw.startswith("#") or raw.startswith(" "):
                continue
            if not raw.startswith("name:"):
                continue
            skill_name = raw.split(":", 1)[1].strip().strip('"').strip("'")
            if skill_name:
                return skill_name

    raise ValueError(f"Failed to read skill name from {skill_dir}")


def parse_interface_overrides(raw_overrides: list[str]) -> dict[str, str]:
    overrides: dict[str, str] = {}
    for item in raw_overrides:
        if "=" not in item:
            raise ValueError(f"Invalid --interface value: {item}")
        key, value = item.split("=", 1)
        key = key.strip()
        value = value.strip()
        if key not in ALLOWED_INTERFACE_KEYS:
            allowed = ", ".join(sorted(ALLOWED_INTERFACE_KEYS))
            raise ValueError(f"Unknown interface key: {key}. Allowed: {allowed}")
        overrides[key] = value
    return overrides


def write_openai_yaml(
    skill_dir: Path,
    skill_name: str,
    raw_overrides: list[str],
    allow_implicit_invocation: str | None = None,
) -> Path:
    overrides = parse_interface_overrides(raw_overrides)

    display_name = overrides.get("display_name") or format_display_name(skill_name)
    short_description = overrides.get("short_description") or default_short_description(display_name)
    prompt = overrides.get("default_prompt") or default_prompt(skill_name, display_name)

    if "$" + skill_name not in prompt:
        raise ValueError("default_prompt must explicitly mention the skill as $<skill-name>")

    if not (25 <= len(short_description) <= 64):
        raise ValueError(
            f"short_description must be 25-64 characters (got {len(short_description)})"
        )

    lines = [
        "interface:",
        f"  display_name: {yaml_quote(display_name)}",
        f"  short_description: {yaml_quote(short_description)}",
        f"  default_prompt: {yaml_quote(prompt)}",
    ]

    for key in ("icon_small", "icon_large", "brand_color"):
        value = overrides.get(key)
        if value:
            lines.append(f"  {key}: {yaml_quote(value)}")

    if allow_implicit_invocation is not None:
        flag = "true" if allow_implicit_invocation == "true" else "false"
        lines.append("")
        lines.append("policy:")
        lines.append(f"  allow_implicit_invocation: {flag}")

    agents_dir = skill_dir / "agents"
    agents_dir.mkdir(parents=True, exist_ok=True)
    output = agents_dir / "openai.yaml"
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate agents/openai.yaml")
    parser.add_argument("skill_dir", help="Skill directory")
    parser.add_argument("--name", help="Skill name override")
    parser.add_argument(
        "--interface",
        action="append",
        default=[],
        help="Interface override in key=value format",
    )
    parser.add_argument(
        "--allow-implicit-invocation",
        choices=["true", "false"],
        default=None,
        help="Optional policy.allow_implicit_invocation value",
    )
    args = parser.parse_args()

    skill_dir = Path(args.skill_dir).expanduser().resolve()
    if not skill_dir.exists() or not skill_dir.is_dir():
        raise SystemExit(f"[ERROR] Skill directory not found: {skill_dir}")

    try:
        skill_name = args.name or read_frontmatter_name(skill_dir)
        output = write_openai_yaml(
            skill_dir,
            skill_name,
            args.interface,
            allow_implicit_invocation=args.allow_implicit_invocation,
        )
    except Exception as exc:  # noqa: BLE001
        raise SystemExit(f"[ERROR] {exc}") from exc

    print(f"[OK] Created {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
