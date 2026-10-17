"""Unit tests for tools/ci/release_notes.py. Run: python3 -m unittest discover -s tools/tests"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ci"))
import release_notes  # noqa: E402

STATUS = """# STATUS

## Notes for the next session
### v9.9.9
Not a release note.

## Release notes
_(Filled per milestone.)_

### M0 Foundation (v0.1.0, playtest-m0)
Boots and shows the title.

- item one

### M1 Flight (v0.2.0)
You can fly.

## Something after
text
"""


class ReleaseNotesTest(unittest.TestCase):
    def test_matches_version_tag(self) -> None:
        self.assertEqual(
            release_notes.extract(STATUS, "v0.1.0"), "Boots and shows the title.\n\n- item one"
        )

    def test_matches_playtest_tag_in_same_heading(self) -> None:
        self.assertIn("Boots", release_notes.extract(STATUS, "playtest-m0") or "")

    def test_stops_at_next_subsection(self) -> None:
        self.assertEqual(release_notes.extract(STATUS, "v0.2.0"), "You can fly.")

    def test_tag_must_be_a_whole_word(self) -> None:
        self.assertIsNone(release_notes.extract(STATUS, "v0.1"))
        self.assertIsNone(release_notes.extract(STATUS, "v0.2.00"))

    def test_ignores_subsections_outside_release_notes(self) -> None:
        self.assertIsNone(release_notes.extract(STATUS, "v9.9.9"))

    def test_missing_section_or_tag(self) -> None:
        self.assertIsNone(release_notes.extract("# nothing\n", "v1"))
        self.assertIsNone(release_notes.extract(STATUS, "v3.0.0"))


if __name__ == "__main__":
    unittest.main()
