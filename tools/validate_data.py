#!/usr/bin/env python3
"""Static validation of game data. Stdlib only. Exits non-zero if anything is wrong.

Checks:
  1. game/assets/licenses.csv has the right columns, every listed file exists, no listed
     license is non-commercial or share-alike, and every file under
     game/assets/{textures,audio,fonts} is listed.
  2. Every ext_resource path in .tres/.tscn files exists.
  3. Every literal key used with tr("KEY") in .gd/.tscn/.tres files exists in
     game/localization/strings.csv (which needs a `keys` and an `en` column).
  4. Every scene in game/tests/smoke/scenes.txt exists.

Usage: python3 tools/validate_data.py [--root <repo root>]
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

LICENSE_COLUMNS = ["path", "source_url", "author", "license", "attribution", "date_added"]
ASSET_DIRS = ["textures", "audio", "fonts"]
# Files Godot or git create next to assets; they are never assets themselves.
IGNORED_SUFFIXES = {".import", ".uid"}
IGNORED_NAMES = {".gitkeep"}
SKIP_DIRS = {".godot", "addons", ".git"}
# Licenses the art bible (section 9) forbids: non-commercial or share-alike.
FORBIDDEN_LICENSE = re.compile(r"(^|[-_ ])(NC|SA)([-_ ]|$)", re.IGNORECASE)
EXT_RESOURCE = re.compile(r'^\[ext_resource\b.*?\bpath="(res://[^"]+)"', re.MULTILINE)
TR_CALL = re.compile(r'\btr\(\s*&?"([^"]+)"')


def game_files(game: Path, suffixes: set[str]) -> list[Path]:
    """All files under `game` with one of `suffixes`, skipping addons and caches."""
    found = []
    for path in sorted(game.rglob("*")):
        if not path.is_file() or path.suffix not in suffixes:
            continue
        if SKIP_DIRS.intersection(path.relative_to(game).parts):
            continue
        found.append(path)
    return found


def normalize_asset_path(raw: str) -> str:
    """licenses.csv paths are relative to game/; tolerate a leading res://."""
    return raw.strip().removeprefix("res://")


def check_licenses(game: Path) -> list[str]:
    errors: list[str] = []
    csv_path = game / "assets" / "licenses.csv"
    if not csv_path.exists():
        return [f"{csv_path}: missing"]
    with csv_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != LICENSE_COLUMNS:
            return [f"licenses.csv: columns must be {LICENSE_COLUMNS}, got {reader.fieldnames}"]
        rows = list(reader)
    listed: set[str] = set()
    for number, row in enumerate(rows, start=2):
        rel = normalize_asset_path(row["path"])
        listed.add(rel)
        if not (game / rel).is_file():
            errors.append(f"licenses.csv:{number}: listed file does not exist: {rel}")
        license_name = row["license"].strip()
        if not license_name:
            errors.append(f"licenses.csv:{number}: {rel} has no license")
        elif FORBIDDEN_LICENSE.search(license_name):
            errors.append(f"licenses.csv:{number}: {rel} has a forbidden license: {license_name}")
    for directory in ASSET_DIRS:
        base = game / "assets" / directory
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.name in IGNORED_NAMES:
                continue
            if path.suffix in IGNORED_SUFFIXES:
                continue
            rel = path.relative_to(game).as_posix()
            if rel not in listed:
                errors.append(f"{rel}: not listed in game/assets/licenses.csv")
    return errors


def check_ext_resources(game: Path) -> list[str]:
    errors: list[str] = []
    for path in game_files(game, {".tres", ".tscn"}):
        text = path.read_text(encoding="utf-8")
        for match in EXT_RESOURCE.finditer(text):
            target = match.group(1).removeprefix("res://")
            if not (game / target).exists():
                rel = path.relative_to(game).as_posix()
                errors.append(f"{rel}: ext_resource does not exist: res://{target}")
    return errors


def load_loc_keys(game: Path) -> tuple[set[str], list[str]]:
    csv_path = game / "localization" / "strings.csv"
    if not csv_path.exists():
        return set(), [f"{csv_path}: missing"]
    errors: list[str] = []
    keys: set[str] = set()
    with csv_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        fields = reader.fieldnames or []
        if fields[:1] != ["keys"] or "en" not in fields:
            return set(), ["strings.csv: first column must be `keys` and an `en` column is required"]
        for number, row in enumerate(reader, start=2):
            key = (row["keys"] or "").strip()
            if not key:
                continue
            if key in keys:
                errors.append(f"strings.csv:{number}: duplicate key {key}")
            keys.add(key)
            if not (row["en"] or "").strip():
                errors.append(f"strings.csv:{number}: key {key} has an empty `en` text")
    return keys, errors


def check_localization(game: Path) -> list[str]:
    keys, errors = load_loc_keys(game)
    if not keys and errors:
        return errors
    for path in game_files(game, {".gd", ".tscn", ".tres"}):
        text = path.read_text(encoding="utf-8")
        for number, line in enumerate(text.splitlines(), start=1):
            if line.lstrip().startswith("#"):
                continue
            for match in TR_CALL.finditer(line):
                if match.group(1) not in keys:
                    rel = path.relative_to(game).as_posix()
                    errors.append(f"{rel}:{number}: localization key not in strings.csv: {match.group(1)}")
    return errors


def check_smoke_scenes(game: Path) -> list[str]:
    errors: list[str] = []
    listing = game / "tests" / "smoke" / "scenes.txt"
    if not listing.exists():
        return [f"{listing}: missing"]
    for line in listing.read_text(encoding="utf-8").splitlines():
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        if not entry.startswith("res://") or not (game / entry.removeprefix("res://")).is_file():
            errors.append(f"smoke/scenes.txt: scene does not exist: {entry}")
    return errors


CHECKS = [
    ("licenses", check_licenses),
    ("ext_resources", check_ext_resources),
    ("localization", check_localization),
    ("smoke scenes", check_smoke_scenes),
]


def validate(root: Path) -> list[str]:
    game = root / "game"
    errors: list[str] = []
    for _name, check in CHECKS:
        errors.extend(check(game))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    errors = validate(args.root)
    for error in errors:
        print(f"validate_data: {error}")
    if errors:
        print(f"validate_data: FAILED with {len(errors)} problem(s)")
        return 1
    print(f"validate_data: OK ({', '.join(name for name, _ in CHECKS)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
