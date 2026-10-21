"""Unit tests for the Blender pipeline. Run with the bpy venv:

  tools/blender/.venv/bin/python -m unittest discover -s tools/blender/tests -t tools/blender
"""

import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
BLENDER_DIR = HERE.parent
sys.path.insert(0, str(BLENDER_DIR))

import bpy  # noqa: E402

import build  # noqa: E402
import manifest  # noqa: E402
import materials  # noqa: E402
from kit import common  # noqa: E402

KESTREL = BLENDER_DIR / "recipes" / "ships" / "kestrel.py"
CANOPY = BLENDER_DIR / "recipes" / "props" / "canopy_human_light.py"


def build_kestrel():
    recipe = build.load_recipe(KESTREL)
    common.clear_scene()
    recipe.build()
    return recipe, manifest.collect(recipe)


def read_glb_json(path: Path) -> dict:
    raw = path.read_bytes()
    magic, _version, _length = struct.unpack("<4sII", raw[:12])
    assert magic == b"glTF"
    chunk_len, chunk_type = struct.unpack("<I4s", raw[12:20])
    assert chunk_type == b"JSON"
    return json.loads(raw[20 : 20 + chunk_len])


class NamingTests(unittest.TestCase):
    def test_valid_and_invalid_names(self):
        good = [
            "hull", "wing_L", "T1_armor_plate_R", "T3_nose_cannon", "T0ONLY_stock_cowl",
            "SUB_shield_gen", "hull-colonly", "SOCKET_primary_0", "SOCKET_cockpit_cam_0",
        ]  # fmt: skip
        bad = ["Hull", "wing.001", "T4_x", "SOCKET_laser_0", "SOCKET_primary", "T1_", "a b"]
        for n in good:
            self.assertTrue(any(r.match(n) for r in common.NAME_RULES), n)
        for n in bad:
            self.assertFalse(any(r.match(n) for r in common.NAME_RULES), n)

    def test_validate_names_rejects_duplicates_suffix(self):
        common.clear_scene()
        bm = common.new_bm()
        common.add_box(bm, (1, 1, 1), (0, 0, 0))
        common.solid("hull", bm, "PAINT_PRIMARY")
        bm = common.new_bm()
        common.add_box(bm, (1, 1, 1), (0, 0, 0))
        common.solid("hull", bm, "PAINT_PRIMARY")  # Blender renames it hull.001
        with self.assertRaises(ValueError):
            common.validate_names(bpy.data.objects)


class TierRuleTests(unittest.TestCase):
    def test_visible_at_tier(self):
        v = common.visible_at_tier
        self.assertTrue(v("hull", 0))
        self.assertFalse(v("T1_armor_plate_L", 0))
        self.assertTrue(v("T1_armor_plate_L", 1))
        self.assertTrue(v("T2_engine_pod_R", 3))
        self.assertFalse(v("T3_nose_cannon", 2))
        self.assertTrue(v("T0ONLY_stock_cowl", 0))
        self.assertFalse(v("T0ONLY_stock_cowl", 1))
        self.assertFalse(v("hull-colonly", 3))


class KitTests(unittest.TestCase):
    def test_mirror_is_symmetric(self):
        common.clear_scene()
        bm = common.new_bm()
        common.add_box(bm, (1, 2, 0.5), (3, 1, 0), rot=(0.1, 0.2, 0.3))
        right, left = common.solid_pair("fin", bm, "PAINT_PRIMARY")
        self.assertEqual(len(right.data.vertices), len(left.data.vertices))
        r = sorted((round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)) for v in right.data.vertices)
        l = sorted((round(-v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)) for v in left.data.vertices)  # noqa: E741
        self.assertEqual(r, l)

    def test_unknown_socket_kind_and_material_rejected(self):
        common.clear_scene()
        with self.assertRaises(ValueError):
            common.socket("laser", 0, (0, 0, 0))
        with self.assertRaises(KeyError):
            materials.get("SHINY_RED")

    def test_collision_hull_is_convex_and_named(self):
        common.clear_scene()
        bm = common.new_bm()
        common.add_box(bm, (2, 2, 2), (0, 0, 0))
        src = common.solid("hull", bm, "PAINT_PRIMARY", bevel=0.0)
        hull = common.add_collision_hull("hull", [src])
        self.assertEqual(hull.name, "hull-colonly")
        self.assertEqual(common.triangle_count(hull), 12)


class KestrelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe, cls.data = build_kestrel()

    def test_names_valid(self):
        common.validate_names(bpy.data.objects)

    def test_triangle_budget(self):
        lo, hi = self.recipe.TRIANGLE_BUDGET
        self.assertTrue(lo <= self.data["triangles"]["total"] <= hi, self.data["triangles"])

    def test_size_is_a_light_fighter(self):
        size = self.data["bounds"]["T0"]["size"]
        self.assertAlmostEqual(size[1], 14.0, delta=0.6)  # ~14 m long
        self.assertTrue(8.0 < size[0] < 12.0)
        self.assertGreater(self.data["bounds"]["all_tiers"]["size"][0], size[0])  # T3 widens

    def test_sockets(self):
        counts: dict[str, int] = {}
        for s in self.data["sockets"]:
            counts[s["kind"]] = counts.get(s["kind"], 0) + 1
        self.assertEqual(counts["primary"], 3)  # 2 base + 1 at T3
        self.assertEqual(counts["secondary"], 1)
        self.assertEqual(counts["engine"], 2)
        self.assertEqual(counts["cockpit_cam"], 1)
        extra = next(s for s in self.data["sockets"] if s["name"] == "SOCKET_primary_2")
        self.assertEqual(extra["min_tier"], 3)
        for s in self.data["sockets"]:
            if s["kind"] != "primary" or s["index"] < 2:
                self.assertEqual(s["min_tier"], 0)
        # Left/right pairs are mirrored.
        p0 = next(s for s in self.data["sockets"] if s["name"] == "SOCKET_primary_0")
        p1 = next(s for s in self.data["sockets"] if s["name"] == "SOCKET_primary_1")
        self.assertEqual(p0["location"][0], -p1["location"][0])

    def test_tier_parts_and_growth(self):
        tp = self.data["tier_parts"]
        for t in ("T1", "T2", "T3", "T0ONLY"):
            self.assertTrue(tp[t], t)
        by_tier = self.data["triangles"]["by_tier"]
        self.assertLess(by_tier["T0"], by_tier["T1"])
        self.assertLess(by_tier["T1"], by_tier["T2"])
        self.assertLess(by_tier["T2"], by_tier["T3"])

    def test_has_collision_hull(self):
        self.assertEqual(self.data["collision"], ["hull-colonly"])

    def test_materials_are_roles_only(self):
        for o in common.mesh_objects():
            for slot in o.material_slots:
                self.assertIn(slot.material.name, materials.ROLES)

    def test_build_is_deterministic(self):
        _recipe, again = build_kestrel()
        self.assertEqual(json.dumps(self.data, sort_keys=True), json.dumps(again, sort_keys=True))

    def test_committed_manifest_matches(self):
        committed = build.MODELS / "ships" / "kestrel.manifest.json"
        self.assertTrue(committed.exists(), "run tools/blender/build.py --all and commit")
        self.assertEqual(json.loads(committed.read_text()), json.loads(json.dumps(self.data)))


# id: (length range in m, primary sockets, secondary, turret, engines). GDD 4.4 / 19.
HEAVY_SHIPS = {
    "bulwark": ((16.0, 20.0), 3, 2, 0, 2),
    "drayman": ((32.0, 38.0), 3, 1, 2, 4),
}


def build_ship(ship_id: str):
    return build_prop(BLENDER_DIR / "recipes" / "ships" / f"{ship_id}.py")


class ShipRosterTests(unittest.TestCase):
    """The heavy fighter and the armed freighter (M1-T7), by the rules every ship follows."""

    def test_names_budget_and_role_materials(self):
        for ship_id in HEAVY_SHIPS:
            with self.subTest(ship=ship_id):
                recipe, data = build_ship(ship_id)
                common.validate_names(bpy.data.objects)
                self.assertEqual((recipe.ID, recipe.CATEGORY), (ship_id, "ships"))
                lo, hi = recipe.TRIANGLE_BUDGET
                self.assertTrue(lo <= data["triangles"]["total"] <= hi, data["triangles"])
                for obj in common.mesh_objects():
                    for slot in obj.material_slots:
                        self.assertIn(slot.material.name, materials.ROLES)

    def test_size_sockets_and_tiers(self):
        for ship_id, (length, primary, secondary, turret, engine) in HEAVY_SHIPS.items():
            with self.subTest(ship=ship_id):
                _recipe, data = build_ship(ship_id)
                size = data["bounds"]["T0"]["size"]
                self.assertTrue(length[0] <= size[1] <= length[1], size)
                counts: dict[str, int] = {}
                for sock in data["sockets"]:
                    counts[sock["kind"]] = counts.get(sock["kind"], 0) + 1
                self.assertEqual(counts["primary"], primary)  # 2 base + 1 at T3
                self.assertEqual(counts.get("secondary", 0), secondary)
                self.assertEqual(counts.get("turret", 0), turret)
                self.assertEqual(counts["engine"], engine)
                self.assertEqual(counts["cockpit_cam"], 1)
                extra = next(s for s in data["sockets"] if s["name"] == "SOCKET_primary_2")
                self.assertEqual(extra["min_tier"], 3)
                for tier in ("T1", "T2", "T3", "T0ONLY"):
                    self.assertTrue(data["tier_parts"][tier], tier)
                by_tier = data["triangles"]["by_tier"]
                self.assertLess(by_tier["T0"], by_tier["T1"])
                self.assertLess(by_tier["T1"], by_tier["T2"])
                self.assertLess(by_tier["T2"], by_tier["T3"])
                self.assertEqual(len(data["collision"]), 1)

    def test_build_is_deterministic_and_committed_manifest_matches(self):
        for ship_id in HEAVY_SHIPS:
            with self.subTest(ship=ship_id):
                _recipe, data = build_ship(ship_id)
                _recipe, again = build_ship(ship_id)
                self.assertEqual(json.dumps(data, sort_keys=True), json.dumps(again, sort_keys=True))
                committed = build.MODELS / "ships" / f"{ship_id}.manifest.json"
                self.assertTrue(committed.exists(), "run tools/blender/build.py --all and commit")
                self.assertEqual(json.loads(committed.read_text()), json.loads(json.dumps(data)))

    def test_the_ships_are_ordered_by_size(self):
        lengths = [
            build_prop(BLENDER_DIR / "recipes" / "ships" / f"{ship_id}.py")[1]["bounds"]["T0"]["size"][1]
            for ship_id in ("kestrel", "bulwark", "drayman")
        ]
        self.assertEqual(lengths, sorted(lengths))


class PaletteTests(unittest.TestCase):
    def test_tint_changes_only_the_preview_colour_of_a_role(self):
        common.clear_scene()
        other = materials.get("PAINT_SECONDARY")
        before = tuple(other.diffuse_color)
        materials.tint("PAINT_PRIMARY", "FF0000")
        mat = materials.get("PAINT_PRIMARY")
        self.assertAlmostEqual(mat.diffuse_color[0], 1.0, places=3)
        self.assertAlmostEqual(mat.diffuse_color[1], 0.0, places=3)
        self.assertEqual(tuple(other.diffuse_color), before)

    def test_tint_keeps_emission_on_emissive_roles_only(self):
        common.clear_scene()
        materials.tint("EMISSIVE_ENGINE", "FFC266")
        glow = materials.get("EMISSIVE_ENGINE").node_tree.nodes["Principled BSDF"]
        self.assertAlmostEqual(glow.inputs["Emission Color"].default_value[0], 1.0, places=3)
        self.assertGreater(glow.inputs["Emission Strength"].default_value, 0.0)

    def test_tint_rejects_unknown_roles(self):
        with self.assertRaises(KeyError):
            materials.tint("PAINT_NEON", "FF00FF")

    def test_recipes_only_tint_known_roles(self):
        for path in (BLENDER_DIR / "recipes" / "ships").glob("*.py"):
            recipe = build.load_recipe(path)
            for role in getattr(recipe, "PALETTE", {}):
                self.assertIn(role, materials.ROLES, path.stem)


class ExportTests(unittest.TestCase):
    def test_glb_contents(self):
        _recipe, data = build_kestrel()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "k.glb"
            build.export_glb(path)
            gltf = read_glb_json(path)
        names = {n["name"] for n in gltf["nodes"]}
        for part in ("hull", "wing_L", "T1_armor_plate_R", "T3_nose_cannon", "T0ONLY_stock_cowl", "hull-colonly"):
            self.assertIn(part, names)
        for s in data["sockets"]:
            self.assertIn(s["name"], names)
        mats = {m["name"] for m in gltf["materials"]}
        self.assertTrue(mats <= set(materials.ROLES), mats)
        sock = next(n for n in gltf["nodes"] if n["name"] == "SOCKET_primary_2")
        self.assertEqual(sock["extras"]["min_tier"], 3)
        self.assertEqual(sock["extras"]["kind"], "primary")


class CanopyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe = build.load_recipe(CANOPY)
        common.clear_scene()
        cls.recipe.build()
        cls.data = manifest.collect(cls.recipe)

    def test_names_valid_and_in_the_props_category(self):
        common.validate_names(bpy.data.objects)
        self.assertEqual(self.recipe.CATEGORY, "props")

    def test_triangle_budget(self):
        lo, hi = self.recipe.TRIANGLE_BUDGET
        self.assertTrue(lo <= self.data["triangles"]["total"] <= hi)

    def test_is_modelled_around_the_eye(self):
        # The eye (origin) is inside the frame's width, below its roof and above the dash, and the
        # whole canopy lies ahead of or just behind it (nose = +Y).
        bounds = self.data["bounds"]["all_tiers"]
        self.assertLess(bounds["min"][0], -0.5)
        self.assertGreater(bounds["max"][0], 0.5)
        self.assertGreater(bounds["max"][2], 0.3)
        self.assertLess(bounds["min"][2], -0.3)
        self.assertGreater(bounds["max"][1], 1.0)
        self.assertLess(bounds["size"][0], 3.0)

    def test_materials_are_roles_only_and_nothing_is_collidable(self):
        self.assertEqual(self.data["collision"], [])
        for obj in common.mesh_objects():
            for slot in obj.data.materials:
                self.assertIn(slot.name, materials.ROLES)

    def test_committed_manifest_matches(self):
        committed = build.MODELS / "props" / "canopy_human_light.manifest.json"
        self.assertTrue(committed.exists(), "run tools/blender/build.py --all and commit")
        self.assertEqual(json.loads(committed.read_text()), json.loads(json.dumps(self.data)))


ASTEROIDS = [BLENDER_DIR / "recipes" / "props" / f"asteroid_{v}.py" for v in "abcd"]
RING_GATE = BLENDER_DIR / "recipes" / "props" / "ring_gate.py"


def build_prop(path: Path):
    recipe = build.load_recipe(path)
    common.clear_scene()
    recipe.build()
    return recipe, manifest.collect(recipe)


class PropTestsMixin:
    """Checks every prop recipe must pass; subclasses set `paths`."""

    paths: list[Path] = []

    def test_names_valid_and_in_the_props_category(self):
        for path in self.paths:
            with self.subTest(recipe=path.stem):
                recipe, _data = build_prop(path)
                common.validate_names(bpy.data.objects)
                self.assertEqual(recipe.CATEGORY, "props")
                self.assertEqual(recipe.ID, path.stem)

    def test_triangle_budget_and_role_materials(self):
        for path in self.paths:
            with self.subTest(recipe=path.stem):
                recipe, data = build_prop(path)
                lo, hi = recipe.TRIANGLE_BUDGET
                self.assertTrue(lo <= data["triangles"]["total"] <= hi, data["triangles"])
                for obj in common.mesh_objects():
                    for slot in obj.data.materials:
                        self.assertIn(slot.name, materials.ROLES)

    def test_build_is_deterministic(self):
        for path in self.paths:
            with self.subTest(recipe=path.stem):
                _recipe, first = build_prop(path)
                _recipe, second = build_prop(path)
                self.assertEqual(json.loads(json.dumps(first)), json.loads(json.dumps(second)))

    def test_committed_manifest_matches(self):
        for path in self.paths:
            with self.subTest(recipe=path.stem):
                _recipe, data = build_prop(path)
                committed = build.MODELS / "props" / f"{path.stem}.manifest.json"
                self.assertTrue(committed.exists(), "run tools/blender/build.py --all and commit")
                self.assertEqual(json.loads(committed.read_text()), json.loads(json.dumps(data)))


class AsteroidTests(PropTestsMixin, unittest.TestCase):
    paths = ASTEROIDS

    def test_every_rock_has_a_convex_collision_hull(self):
        for path in self.paths:
            with self.subTest(recipe=path.stem):
                _recipe, data = build_prop(path)
                self.assertEqual(data["collision"], ["rock-colonly"])
                hull = bpy.data.objects["rock-colonly"]
                self.assertTrue(all(p.normal.length > 0.99 for p in hull.data.polygons))

    def test_rocks_are_about_five_metres_in_radius_and_differ(self):
        sizes = []
        for path in self.paths:
            _recipe, data = build_prop(path)
            size = data["bounds"]["all_tiers"]["size"]
            sizes.append(tuple(size))
            self.assertTrue(4.0 <= max(size) / 2.0 <= 9.0, size)
        self.assertEqual(len(set(sizes)), len(self.paths), "variants must differ in shape")


class RingGateTests(PropTestsMixin, unittest.TestCase):
    paths = [RING_GATE]

    def test_the_opening_is_sixty_metres_and_faces_the_flight_axis(self):
        _recipe, data = build_prop(RING_GATE)
        size = data["bounds"]["all_tiers"]["size"]
        # Blender: the ring lies in XZ (Godot XY); the flight axis Y (Godot Z) is the shallow one.
        self.assertGreater(size[0], 66.0)
        self.assertGreater(size[2], 66.0)
        self.assertLess(size[1], 12.0)

    def test_the_ring_is_not_collidable_by_hull(self):
        # A convex hull of a ring would fill the opening; the game builds strut colliders instead.
        _recipe, data = build_prop(RING_GATE)
        self.assertEqual(data["collision"], [])


if __name__ == "__main__":
    unittest.main()
