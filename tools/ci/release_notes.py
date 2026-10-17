#!/usr/bin/env python3
"""Prints the GitHub Release notes for a tag, taken from docs/STATUS.md.

Under the "## Release notes" heading, each release has a "### ..." subsection whose heading
names the tag(s) it covers, e.g. "### M0 Foundation (v0.1.0, playtest-m0)". The body of the
subsection whose heading mentions TAG as a whole word is printed. If none matches, a short
fallback line is printed (and a warning goes to stderr) so a release is never blocked on notes.

    python3 tools/ci/release_notes.py v0.1.0 [--status docs/STATUS.md]
"""

import argparse
import re
import sys
from pathlib import Path

SECTION = "## Release notes"


def extract(status_text: str, tag: str) -> str | None:
    """Returns the body of the matching "###" subsection, or None if there is none."""
    lines = status_text.splitlines()
    try:
        start = next(i for i, line in enumerate(lines) if line.strip() == SECTION)
    except StopIteration:
        return None
    end = next(
        (i for i in range(start + 1, len(lines)) if re.match(r"^## (?!#)", lines[i])),
        len(lines),
    )
    pattern = re.compile(r"(?<![\w.-])" + re.escape(tag) + r"(?![\w.-])")
    body: list[str] | None = None
    for line in lines[start + 1 : end]:
        if line.startswith("### "):
            if body is not None:
                break
            if pattern.search(line):
                body = []
        elif body is not None:
            body.append(line)
    if body is None:
        return None
    text = "\n".join(body).strip()
    return text or None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("tag")
    parser.add_argument("--status", default="docs/STATUS.md", type=Path)
    args = parser.parse_args(argv)
    notes = extract(args.status.read_text(encoding="utf-8"), args.tag)
    if notes is None:
        print(
            f"warning: no release notes for {args.tag} in {args.status} ({SECTION})",
            file=sys.stderr,
        )
        notes = f"Build for `{args.tag}`. No release notes were written for this tag."
    print(notes)
    return 0


if __name__ == "__main__":
    sys.exit(main())
