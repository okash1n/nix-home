#!/usr/bin/env python3
"""Initialize a new skill with stricter defaults for local nix-home workflow."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import unicodedata
from pathlib import Path

from generate_openai_yaml import write_openai_yaml

MAX_SKILL_NAME_LENGTH = 64
ALLOWED_RESOURCES = {"scripts", "references", "assets"}
DEFAULT_COMPATIBILITY = "claude,codex,gemini"

DEFAULT_DESCRIPTION = (
    "[TODO: Explain what this skill does and exactly when to use it. "
    "Include trigger conditions and representative tasks.]"
)

BODY_TEMPLATE = """# {title}

## Overview

[TODO: Summarize the purpose in 1-2 sentences]

## Trigger Examples

- [TODO: Example user request 1]
- [TODO: Example user request 2]

## Workflow

1. [TODO: Step 1]
2. [TODO: Step 2]
3. [TODO: Step 3]

## Agent Compatibility

- `compatibility` は `claude,codex,gemini` にする。
- 特定エージェント専用の処理だけに依存しない。
- 専用処理が必要な場合は代替手順を併記する。

## Resources

- `scripts/`: [TODO]
- `references/`: [TODO]
- `assets/`: [TODO]
"""

EXAMPLE_SCRIPT = """#!/usr/bin/env python3
\"\"\"Example script for the skill. Replace with real logic.\"\"\"


def main() -> int:
    print("Replace this example script with production logic")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
"""

EXAMPLE_REFERENCE = """# Reference

Replace this placeholder with detailed reference information used by the skill.
"""

EXAMPLE_ASSET_TEXT = "Replace this placeholder with real asset files if needed.\n"


def normalize_skill_name(raw: str) -> str:
    raw = unicodedata.normalize("NFKC", raw.strip())
    out: list[str] = []
    last_hyphen = False
    for ch in raw.lower():
        if ch.isalnum():
            out.append(ch)
            last_hyphen = False
        else:
            if not last_hyphen:
                out.append("-")
                last_hyphen = True
    return "".join(out).strip("-")


def validate_skill_name(name: str) -> None:
    if not name:
        raise ValueError("Skill name must include at least one alnum character")
    if len(name) > MAX_SKILL_NAME_LENGTH:
        raise ValueError(f"Skill name must be <= {MAX_SKILL_NAME_LENGTH} characters")
    if name != name.lower():
        raise ValueError("Skill name must be lowercase")
    if name.startswith("-") or name.endswith("-"):
        raise ValueError("Skill name cannot start/end with '-'" )
    if "--" in name:
        raise ValueError("Skill name cannot contain consecutive hyphens")
    if not all(ch.isalnum() or ch == "-" for ch in name):
        raise ValueError("Skill name can contain only alnum characters and '-'" )


def parse_resources(raw_resources: str) -> list[str]:
    if not raw_resources:
        return []
    parts = [p.strip() for p in raw_resources.split(",") if p.strip()]
    invalid = [p for p in parts if p not in ALLOWED_RESOURCES]
    if invalid:
        allowed = ", ".join(sorted(ALLOWED_RESOURCES))
        raise ValueError(f"Unknown resource(s): {', '.join(invalid)}. Allowed: {allowed}")

    deduped: list[str] = []
    seen: set[str] = set()
    for item in parts:
        if item in seen:
            continue
        seen.add(item)
        deduped.append(item)
    return deduped


def parse_key_values(values: list[str], label: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for item in values:
        if "=" not in item:
            raise ValueError(f"Invalid --{label} value '{item}'. Expected key=value")
        key, val = item.split("=", 1)
        key = key.strip()
        val = val.strip()
        if not key:
            raise ValueError(f"Invalid --{label} value '{item}'. Empty key")
        result[key] = val
    return result


def title_case(skill_name: str) -> str:
    return " ".join(word.capitalize() for word in skill_name.split("-"))


def default_output_root() -> Path:
    env_path = os.environ.get("NIX_HOME_AGENT_SKILLS_DIR")
    if env_path:
        return Path(env_path).expanduser()
    return Path("~/nix-home/agent-skills").expanduser()


def create_frontmatter(
    skill_name: str,
    description: str,
    license_name: str | None,
    compatibility: str,
    allowed_tools: str | None,
    metadata: dict[str, str],
) -> dict:
    frontmatter: dict = {
        "name": skill_name,
        "description": description,
        "compatibility": compatibility,
    }
    if license_name:
        frontmatter["license"] = license_name
    if allowed_tools:
        frontmatter["allowed-tools"] = allowed_tools
    if metadata:
        frontmatter["metadata"] = metadata
    return frontmatter


def yaml_scalar(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)

    text = str(value)
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    return f"\"{escaped}\""


def dump_frontmatter(frontmatter: dict) -> str:
    lines: list[str] = []

    for key, value in frontmatter.items():
        if isinstance(value, dict):
            lines.append(f"{key}:")
            for nested_key, nested_value in value.items():
                lines.append(f"  {nested_key}: {yaml_scalar(nested_value)}")
        else:
            lines.append(f"{key}: {yaml_scalar(value)}")

    return "\n".join(lines)


def write_skill_md(skill_dir: Path, frontmatter: dict, title: str) -> Path:
    fm_text = dump_frontmatter(frontmatter).rstrip()
    body = BODY_TEMPLATE.format(title=title)
    content = f"---\n{fm_text}\n---\n\n{body}"
    skill_md = skill_dir / "SKILL.md"
    skill_md.write_text(content, encoding="utf-8")
    return skill_md


def create_resource_dirs(skill_dir: Path, resources: list[str], examples: bool) -> None:
    for resource in resources:
        target = skill_dir / resource
        target.mkdir(parents=True, exist_ok=True)
        if not examples:
            continue
        if resource == "scripts":
            example = target / "example.py"
            example.write_text(EXAMPLE_SCRIPT, encoding="utf-8")
            example.chmod(0o755)
        elif resource == "references":
            (target / "reference.md").write_text(EXAMPLE_REFERENCE, encoding="utf-8")
        elif resource == "assets":
            (target / "example.txt").write_text(EXAMPLE_ASSET_TEXT, encoding="utf-8")


def run_quick_validate(skill_dir: Path) -> bool:
    validator = Path(__file__).with_name("quick_validate.py")
    if not validator.exists():
        print("[WARN] quick_validate.py not found; skipped post-init validation")
        return True

    result = subprocess.run(
        [sys.executable, str(validator), str(skill_dir)],
        check=False,
    )
    return result.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Initialize a new skill")
    parser.add_argument("skill_name", help="Skill name (will be normalized)")
    parser.add_argument(
        "--path",
        default=str(default_output_root()),
        help="Output root directory (default: $NIX_HOME_AGENT_SKILLS_DIR or ~/nix-home/agent-skills)",
    )
    parser.add_argument(
        "--resources",
        default="",
        help="Comma-separated resource dirs: scripts,references,assets",
    )
    parser.add_argument(
        "--examples",
        action="store_true",
        help="Create example files for selected resources",
    )
    parser.add_argument(
        "--description",
        default=DEFAULT_DESCRIPTION,
        help="Frontmatter description",
    )
    parser.add_argument("--license", dest="license_name", default=None)
    parser.add_argument(
        "--compatibility",
        default=DEFAULT_COMPATIBILITY,
        help=f"Frontmatter compatibility (default: {DEFAULT_COMPATIBILITY})",
    )
    parser.add_argument("--allowed-tools", default=None)
    parser.add_argument(
        "--metadata",
        action="append",
        default=[],
        help="Metadata entry in key=value format (repeatable)",
    )
    parser.add_argument(
        "--interface",
        action="append",
        default=[],
        help="openai.yaml interface override key=value (repeatable)",
    )
    parser.add_argument(
        "--no-openai-yaml",
        action="store_true",
        help="Skip agents/openai.yaml generation",
    )
    args = parser.parse_args()

    try:
        skill_name = normalize_skill_name(args.skill_name)
        validate_skill_name(skill_name)
        resources = parse_resources(args.resources)
        metadata = parse_key_values(args.metadata, "metadata")
    except ValueError as exc:
        print(f"[ERROR] {exc}")
        return 1

    output_root = Path(args.path).expanduser().resolve()
    skill_dir = output_root / skill_name

    compatibility = args.compatibility.strip()
    if not compatibility:
        print("[ERROR] --compatibility must not be empty")
        return 1

    if skill_dir.exists():
        print(f"[ERROR] Skill directory already exists: {skill_dir}")
        return 1

    skill_dir.mkdir(parents=True, exist_ok=False)

    frontmatter = create_frontmatter(
        skill_name=skill_name,
        description=args.description,
        license_name=args.license_name,
        compatibility=compatibility,
        allowed_tools=args.allowed_tools,
        metadata=metadata,
    )
    skill_md = write_skill_md(skill_dir, frontmatter, title_case(skill_name))
    create_resource_dirs(skill_dir, resources, args.examples)

    if not args.no_openai_yaml:
        try:
            openai_yaml = write_openai_yaml(
                skill_dir,
                skill_name,
                args.interface,
            )
            print(f"[OK] Created {openai_yaml}")
        except Exception as exc:  # noqa: BLE001
            print(f"[ERROR] Failed to generate openai.yaml: {exc}")
            return 1

    print(f"[OK] Created {skill_md}")

    valid = run_quick_validate(skill_dir)
    if not valid:
        print("[WARN] Validation failed. Fix issues before using this skill.")
        return 1

    print(f"[OK] Skill initialized successfully: {skill_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
