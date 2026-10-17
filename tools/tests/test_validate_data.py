"""Unit tests for tools/validate_data.py. Run: python3 -m unittest discover -s tools/tests"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import validate_data  # noqa: E402

HEADER = "path,source_url,author,license,attribution,date_added\n"


class ValidateDataTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.game = self.root / "game"
        self.write("assets/licenses.csv", HEADER)
        self.write("localization/strings.csv", "keys,en\nHELLO,Hello\n")
        self.write("tests/smoke/scenes.txt", "# scenes\nres://a.tscn\n")
        self.write("a.tscn", "[gd_scene format=3]\n")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write(self, rel: str, text: str) -> None:
        path = self.game / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def test_clean_tree_passes(self) -> None:
        self.assertEqual(validate_data.validate(self.root), [])

    def test_wrong_license_columns(self) -> None:
        self.write("assets/licenses.csv", "path,license\n")
        self.assertIn("columns must be", validate_data.validate(self.root)[0])

    def test_listed_file_must_exist(self) -> None:
        self.write("assets/licenses.csv", HEADER + "assets/audio/x.ogg,u,a,CC0,,2026-01-01\n")
        self.assertTrue(any("does not exist" in e for e in validate_data.validate(self.root)))

    def test_unlisted_asset_is_flagged(self) -> None:
        self.write("assets/textures/t.png", "x")
        self.write("assets/textures/t.png.import", "x")
        errors = validate_data.validate(self.root)
        self.assertEqual(errors, ["assets/textures/t.png: not listed in game/assets/licenses.csv"])

    def test_listed_asset_passes(self) -> None:
        self.write("assets/textures/t.png", "x")
        self.write("assets/licenses.csv", HEADER + "assets/textures/t.png,u,a,CC0,,2026-01-01\n")
        self.assertEqual(validate_data.validate(self.root), [])

    def test_non_commercial_and_share_alike_are_rejected(self) -> None:
        for name in ("CC-BY-NC-4.0", "CC-BY-SA-4.0", "CC BY-NC"):
            self.write("assets/textures/t.png", "x")
            row = f"assets/textures/t.png,u,a,{name},,2026-01-01\n"
            self.write("assets/licenses.csv", HEADER + row)
            errors = validate_data.validate(self.root)
            self.assertTrue(any("forbidden license" in e for e in errors), name)

    def test_cc_by_is_allowed(self) -> None:
        self.write("assets/textures/t.png", "x")
        self.write("assets/licenses.csv", HEADER + "assets/textures/t.png,u,a,CC-BY-4.0,x,d\n")
        self.assertEqual(validate_data.validate(self.root), [])

    def test_missing_ext_resource(self) -> None:
        self.write("b.tscn", '[ext_resource type="Script" path="res://nope.gd" id="1"]\n')
        errors = validate_data.validate(self.root)
        self.assertEqual(errors, ["b.tscn: ext_resource does not exist: res://nope.gd"])

    def test_existing_ext_resource_passes(self) -> None:
        self.write("s.gd", "extends Node\n")
        self.write("b.tscn", '[ext_resource type="Script" path="res://s.gd" id="1"]\n')
        self.assertEqual(validate_data.validate(self.root), [])

    def test_unknown_loc_key(self) -> None:
        self.write("s.gd", 'extends Node\nvar t = tr("NOPE")\n')
        errors = validate_data.validate(self.root)
        self.assertEqual(errors, ["s.gd:2: localization key not in strings.csv: NOPE"])

    def test_known_loc_key_and_comments_pass(self) -> None:
        self.write("s.gd", 'extends Node\nvar t = tr("HELLO")\n# tr("COMMENTED_OUT")\n')
        self.assertEqual(validate_data.validate(self.root), [])

    def test_strings_csv_needs_en_column(self) -> None:
        self.write("localization/strings.csv", "keys,de\nHELLO,Hallo\n")
        self.assertIn("`en` column", validate_data.validate(self.root)[0])

    def test_duplicate_and_empty_loc_entries(self) -> None:
        self.write("localization/strings.csv", "keys,en\nA,x\nA,y\nB,\n")
        errors = validate_data.validate(self.root)
        self.assertTrue(any("duplicate key A" in e for e in errors))
        self.assertTrue(any("key B has an empty" in e for e in errors))

    def test_smoke_scene_must_exist(self) -> None:
        self.write("tests/smoke/scenes.txt", "res://missing.tscn\n")
        errors = validate_data.validate(self.root)
        self.assertEqual(errors, ["smoke/scenes.txt: scene does not exist: res://missing.tscn"])

    def test_model_import_needs_the_post_import_script(self) -> None:
        self.write("assets/models/ships/x.glb", "glTF")
        errors = validate_data.validate(self.root)
        self.assertEqual(len(errors), 1)
        self.assertIn("no .import file", errors[0])
        self.write("assets/models/ships/x.glb.import", '[params]\nimport_script/path=""\n')
        errors = validate_data.validate(self.root)
        self.assertEqual(len(errors), 1)
        self.assertIn("needs import_script/path", errors[0])

    def test_model_import_with_the_script_passes(self) -> None:
        self.write("assets/models/ships/x.glb", "glTF")
        self.write(
            "assets/models/ships/x.glb.import",
            f'[params]\nimport_script/path="{validate_data.MODEL_IMPORT_SCRIPT}"\n',
        )
        self.assertEqual(validate_data.validate(self.root), [])


if __name__ == "__main__":
    unittest.main()
