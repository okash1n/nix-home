#!/usr/bin/env python3
"""Strict skill validator for ok-skill-creator.

This validator is intentionally stricter than the baseline quick validator:
- Supports both SKILL.md and skill.md
- Validates frontmatter fields against Agent Skills spec keys
- Validates name rules with Unicode-aware checks
- Validates directory-name == skill-name
- Validates description and compatibility length constraints
- Optionally runs `skills-ref validate` when available
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import unicodedata
from datetime import date
from pathlib import Path

MAX_SKILL_NAME_LENGTH = 64
MAX_DESCRIPTION_LENGTH = 1024
MAX_COMPATIBILITY_LENGTH = 500
REQUIRED_COMPAT_AGENTS = ("claude", "codex", "gemini")
DEFAULT_SOURCE_MANIFEST_PATH = "references/source-manifest.json"
ALLOWED_SOURCE_KINDS = {"git", "web", "local", "api", "other"}
ALLOWED_FIELDS = {
    "name",
    "description",
    "license",
    "compatibility",
    "metadata",
    "allowed-tools",
}
ULID_PATTERN = re.compile(r"^[0-9A-HJKMNP-TV-Z]{26}$")


def find_skill_md(skill_dir: Path) -> Path | None:
    for name in ("SKILL.md", "skill.md"):
        candidate = skill_dir / name
        if candidate.exists():
            return candidate
    return None


def parse_scalar(value: str) -> object:
    v = value.strip()
    if not v:
        return ""

    if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
        return v[1:-1]

    lower = v.lower()
    if lower == "true":
        return True
    if lower == "false":
        return False

    try:
        if "." in v:
            return float(v)
        return int(v)
    except ValueError:
        return v


def parse_simple_yaml_mapping(text: str) -> dict:
    data: dict[str, object] = {}
    current_parent: str | None = None

    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue

        if line.startswith("  "):
            if current_parent != "metadata":
                raise ValueError(f"Unsupported nested field format: {raw_line}")
            nested = line[2:]
            if ":" not in nested:
                raise ValueError(f"Invalid nested mapping line: {raw_line}")
            key, value = nested.split(":", 1)
            key = key.strip()
            if not key:
                raise ValueError(f"Empty nested key in line: {raw_line}")
            metadata = data.setdefault("metadata", {})
            if not isinstance(metadata, dict):
                raise ValueError("metadata must be a mapping")
            metadata[key] = parse_scalar(value)
            continue

        if ":" not in line:
            raise ValueError(f"Invalid frontmatter line: {raw_line}")

        key, value = line.split(":", 1)
        key = key.strip()
        if not key:
            raise ValueError(f"Empty key in line: {raw_line}")

        parsed_value = parse_scalar(value)
        data[key] = parsed_value
        current_parent = key if parsed_value == "" else None
        if key == "metadata" and parsed_value == "":
            data[key] = {}
            current_parent = "metadata"

    return data


def parse_frontmatter(content: str) -> tuple[dict, str]:
    if not content.startswith("---"):
        raise ValueError("SKILL.md must start with YAML frontmatter (---)")

    parts = content.split("---", 2)
    if len(parts) < 3:
        raise ValueError("YAML frontmatter is not properly closed with ---")

    frontmatter_text = parts[1]
    body = parts[2].strip()

    metadata = parse_simple_yaml_mapping(frontmatter_text)
    return metadata, body


def validate_name(name: object, skill_dir: Path) -> list[str]:
    errors: list[str] = []
    if not isinstance(name, str) or not name.strip():
        return ["Field 'name' must be a non-empty string"]

    normalized_name = unicodedata.normalize("NFKC", name.strip())

    if len(normalized_name) > MAX_SKILL_NAME_LENGTH:
        errors.append(
            f"Skill name '{normalized_name}' exceeds {MAX_SKILL_NAME_LENGTH} characters"
        )

    if normalized_name != normalized_name.lower():
        errors.append("Skill name must be lowercase")

    if normalized_name.startswith("-") or normalized_name.endswith("-"):
        errors.append("Skill name cannot start or end with '-'" )

    if "--" in normalized_name:
        errors.append("Skill name cannot contain consecutive hyphens")

    if not all(ch.isalnum() or ch == "-" for ch in normalized_name):
        errors.append("Skill name may contain only alnum characters and hyphens")

    dir_name = unicodedata.normalize("NFKC", skill_dir.name)
    if dir_name != normalized_name:
        errors.append(
            f"Directory name '{skill_dir.name}' must match skill name '{normalized_name}'"
        )

    return errors


def validate_description(description: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(description, str) or not description.strip():
        return ["Field 'description' must be a non-empty string"]

    if len(description.strip()) > MAX_DESCRIPTION_LENGTH:
        errors.append(
            f"Description exceeds {MAX_DESCRIPTION_LENGTH} characters"
        )
    return errors


def validate_compatibility(compatibility: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(compatibility, str):
        return ["Field 'compatibility' must be a string"]

    normalized = compatibility.strip()
    if not normalized:
        return ["Field 'compatibility' must not be empty"]

    if len(normalized) > MAX_COMPATIBILITY_LENGTH:
        errors.append(
            f"Compatibility exceeds {MAX_COMPATIBILITY_LENGTH} characters"
        )

    lowered = normalized.lower()
    missing = [agent for agent in REQUIRED_COMPAT_AGENTS if agent not in lowered]
    if missing:
        errors.append(
            "Field 'compatibility' must include all of: "
            + ", ".join(REQUIRED_COMPAT_AGENTS)
            + f" (missing: {', '.join(missing)})"
        )
    return errors


def validate_metadata_field(metadata: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(metadata, dict):
        return ["Field 'metadata' must be a mapping"]

    for key, value in metadata.items():
        if not isinstance(key, (str, int, float, bool)):
            errors.append("metadata keys must be scalar values")
        if not isinstance(value, (str, int, float, bool)):
            errors.append("metadata values must be scalar values")
    return errors


def resolve_skill_relative_path(skill_dir: Path, raw_path: str) -> Path:
    relative = Path(raw_path)
    if relative.is_absolute():
        raise ValueError("source manifest path must be relative")

    skill_root = skill_dir.resolve()
    target = (skill_dir / relative).resolve()
    try:
        target.relative_to(skill_root)
    except ValueError as exc:
        raise ValueError("source manifest path must stay inside the skill directory") from exc
    return target


def parse_bool_setting(value: object, field_name: str) -> tuple[bool, str | None]:
    if isinstance(value, bool):
        return value, None

    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered == "true":
            return True, None
        if lowered == "false":
            return False, None

    return False, f"metadata.{field_name} must be true or false"


def is_iso_date(value: object) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    try:
        date.fromisoformat(value.strip())
    except ValueError:
        return False
    return True


def validate_source_entry(entry: object, index: int) -> list[str]:
    errors: list[str] = []
    prefix = f"source-manifest.sources[{index}]"
    if not isinstance(entry, dict):
        return [f"{prefix} must be an object"]

    required_fields = ("id", "kind", "uri", "snapshot", "retrieved_at")
    for field_name in required_fields:
        value = entry.get(field_name)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{prefix}.{field_name} must be a non-empty string")

    kind = entry.get("kind")
    if isinstance(kind, str) and kind.strip() and kind not in ALLOWED_SOURCE_KINDS:
        allowed = ", ".join(sorted(ALLOWED_SOURCE_KINDS))
        errors.append(f"{prefix}.kind must be one of: {allowed}")

    if not is_iso_date(entry.get("retrieved_at")):
        errors.append(f"{prefix}.retrieved_at must be ISO date (YYYY-MM-DD)")

    kb_refs = entry.get("kb_refs")
    if kb_refs is not None:
        if not isinstance(kb_refs, list):
            errors.append(f"{prefix}.kb_refs must be a list when provided")
        else:
            for item_index, kb_ref in enumerate(kb_refs):
                if not isinstance(kb_ref, str) or not kb_ref.strip():
                    errors.append(f"{prefix}.kb_refs[{item_index}] must be a non-empty string")
                    continue
                if not ULID_PATTERN.match(kb_ref.strip()):
                    errors.append(
                        f"{prefix}.kb_refs[{item_index}] must be a ULID-like identifier"
                    )

    return errors


def validate_source_manifest(
    skill_dir: Path,
    metadata: dict[str, object] | None,
) -> list[str]:
    errors: list[str] = []
    metadata_map = metadata if isinstance(metadata, dict) else {}

    source_manifest_value = metadata_map.get("source_manifest")
    source_manifest_required_value = metadata_map.get("source_manifest_required", False)
    source_manifest_required, required_error = parse_bool_setting(
        source_manifest_required_value,
        "source_manifest_required",
    )
    if required_error:
        errors.append(required_error)
        return errors

    manifest_rel_path: str | None = None
    if source_manifest_value is not None:
        if not isinstance(source_manifest_value, str) or not source_manifest_value.strip():
            errors.append("metadata.source_manifest must be a non-empty string path")
            return errors
        manifest_rel_path = source_manifest_value.strip()

    default_manifest = skill_dir / DEFAULT_SOURCE_MANIFEST_PATH
    if manifest_rel_path is None and default_manifest.exists():
        manifest_rel_path = DEFAULT_SOURCE_MANIFEST_PATH

    if source_manifest_required and manifest_rel_path is None:
        errors.append(
            "metadata.source_manifest_required=true requires metadata.source_manifest"
        )
        return errors

    if manifest_rel_path is None:
        return errors

    try:
        manifest_path = resolve_skill_relative_path(skill_dir, manifest_rel_path)
    except ValueError as exc:
        errors.append(str(exc))
        return errors

    if not manifest_path.exists():
        errors.append(f"source manifest not found: {manifest_rel_path}")
        return errors
    if not manifest_path.is_file():
        errors.append(f"source manifest is not a file: {manifest_rel_path}")
        return errors

    try:
        manifest_data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"source manifest is not valid JSON: {exc}")
        return errors

    if not isinstance(manifest_data, dict):
        errors.append("source manifest root must be an object")
        return errors

    version = manifest_data.get("version")
    if not isinstance(version, int) or version <= 0:
        errors.append("source manifest 'version' must be a positive integer")

    generated_at = manifest_data.get("generated_at")
    if generated_at is not None and not is_iso_date(generated_at):
        errors.append("source manifest 'generated_at' must be ISO date (YYYY-MM-DD)")

    sources = manifest_data.get("sources")
    if not isinstance(sources, list) or not sources:
        errors.append("source manifest 'sources' must be a non-empty list")
        return errors

    for index, entry in enumerate(sources):
        errors.extend(validate_source_entry(entry, index))

    return errors


def validate_frontmatter(metadata: dict, skill_dir: Path) -> list[str]:
    errors: list[str] = []

    extra_fields = set(metadata.keys()) - ALLOWED_FIELDS
    if extra_fields:
        errors.append(
            "Unexpected frontmatter fields: "
            + ", ".join(sorted(extra_fields))
            + ". Allowed: "
            + ", ".join(sorted(ALLOWED_FIELDS))
        )

    if "name" not in metadata:
        errors.append("Missing required field: name")
    else:
        errors.extend(validate_name(metadata["name"], skill_dir))

    if "description" not in metadata:
        errors.append("Missing required field: description")
    else:
        errors.extend(validate_description(metadata["description"]))

    if "compatibility" not in metadata:
        errors.append("Missing required field: compatibility")
    else:
        errors.extend(validate_compatibility(metadata["compatibility"]))

    metadata_map = metadata.get("metadata")
    if "metadata" in metadata:
        errors.extend(validate_metadata_field(metadata_map))

    if isinstance(metadata_map, dict):
        errors.extend(validate_source_manifest(skill_dir, metadata_map))
    else:
        errors.extend(validate_source_manifest(skill_dir, None))

    return errors


def run_skills_ref_if_available(skill_dir: Path) -> list[str]:
    if shutil.which("skills-ref") is None:
        return []

    result = subprocess.run(
        ["skills-ref", "validate", str(skill_dir)],
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode == 0:
        return []

    message = result.stderr.strip() or result.stdout.strip() or "skills-ref validate failed"
    return [f"skills-ref: {message}"]


def validate_skill(skill_dir: Path, with_skills_ref: bool = True) -> list[str]:
    errors: list[str] = []

    if not skill_dir.exists():
        return [f"Path does not exist: {skill_dir}"]
    if not skill_dir.is_dir():
        return [f"Not a directory: {skill_dir}"]

    skill_md = find_skill_md(skill_dir)
    if skill_md is None:
        return ["Missing required file: SKILL.md (or skill.md)"]

    try:
        content = skill_md.read_text(encoding="utf-8")
        metadata, body = parse_frontmatter(content)
    except Exception as exc:  # noqa: BLE001
        return [str(exc)]

    errors.extend(validate_frontmatter(metadata, skill_dir))

    if not body.strip():
        errors.append("SKILL.md body is empty")

    if with_skills_ref:
        errors.extend(run_skills_ref_if_available(skill_dir))

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate one or more skill directories")
    parser.add_argument("paths", nargs="+", help="Skill directory path(s)")
    parser.add_argument(
        "--no-skills-ref",
        action="store_true",
        help="Skip optional skills-ref validation",
    )
    args = parser.parse_args()

    had_errors = False

    for raw_path in args.paths:
        skill_dir = Path(raw_path).expanduser().resolve()
        errors = validate_skill(skill_dir, with_skills_ref=not args.no_skills_ref)
        if errors:
            had_errors = True
            print(f"[FAIL] {skill_dir}")
            for err in errors:
                print(f"  - {err}")
        else:
            print(f"[PASS] {skill_dir}")

    return 1 if had_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
