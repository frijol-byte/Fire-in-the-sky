"""Deterministic part helpers shared by every recipe.

Geometry is built in bmesh with all transforms baked into the vertices (objects always sit at
the origin with identity transform), so mirroring and bounds are trivial and the exported
files are reproducible. Ship axes in Blender: nose = +Y, up = +Z, starboard (right) = +X.
glTF export (+Y up) maps Blender +Y to Godot -Z, i.e. "forward" in Godot.
"""

import math
import re
from collections.abc import Iterable, Sequence

import bmesh
import bpy
from mathutils import Euler, Vector

import materials

Vec3 = Sequence[float]

SOCKET_KINDS = ("primary", "secondary", "turret", "engine", "cockpit_cam", "dock", "vfx")
# Naming rules from art bible 3.1. Plain part names are lowercase words, with an optional
# trailing _L / _R. Blender's ".001" duplicate suffix is always an error.
NAME_RULES = (
    re.compile(r"^SOCKET_(" + "|".join(SOCKET_KINDS) + r")_\d+$"),
    re.compile(r"^T[123]_[a-z][a-z0-9_]*(_[LR])?$"),
    re.compile(r"^T0ONLY_[a-z][a-z0-9_]*(_[LR])?$"),
    re.compile(r"^SUB_[a-z][a-z0-9_]*$"),
    re.compile(r"^[a-z][a-z0-9_]*-colonly$"),
    re.compile(r"^[a-z][a-z0-9_]*(_[LR])?$"),
)
TIER_RE = re.compile(r"^T([123])_")
MAX_TIER = 3


# ---------------------------------------------------------------- scene / objects
def clear_scene() -> None:
    """Empty scene, no default cube/camera/light. Also drops orphaned data."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def new_bm() -> bmesh.types.BMesh:
    return bmesh.new()


def _link(obj: bpy.types.Object) -> None:
    bpy.context.scene.collection.objects.link(obj)


def solid(
    name: str,
    bm: bmesh.types.BMesh,
    material: str,
    bevel: float = 0.04,
    smooth_angle_deg: float = 35.0,
) -> bpy.types.Object:
    """Finish a bmesh into a bevelled, weighted-normal object linked to the scene.

    `bevel` is the width of a 1-segment bevel on edges sharper than `smooth_angle_deg`.
    """
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.materials.append(materials.get(material))
    obj = bpy.data.objects.new(name, mesh)
    _link(obj)
    if bevel > 0.0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(smooth_angle_deg)
        mod.harden_normals = False
    wn = obj.modifiers.new("weighted_normals", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    wn.weight = 50
    _apply_modifiers(obj)
    return obj


def _apply_modifiers(obj: bpy.types.Object) -> None:
    deps = bpy.context.evaluated_depsgraph_get()
    baked = bpy.data.meshes.new_from_object(obj.evaluated_get(deps))
    old = obj.data
    obj.modifiers.clear()
    baked.name = obj.name
    obj.data = baked
    bpy.data.meshes.remove(old)


def mirror_bm(bm: bmesh.types.BMesh) -> bmesh.types.BMesh:
    """Copy of `bm` mirrored across X = 0, with winding fixed."""
    out = bm.copy()
    for v in out.verts:
        v.co.x = -v.co.x
    bmesh.ops.reverse_faces(out, faces=out.faces)
    return out


def solid_pair(
    base: str,
    bm: bmesh.types.BMesh,
    material: str,
    bevel: float = 0.04,
) -> tuple[bpy.types.Object, bpy.types.Object]:
    """Author a part on the starboard (+X) side; returns (`<base>_R`, `<base>_L`)."""
    left = mirror_bm(bm)
    right = solid(f"{base}_R", bm, material, bevel)
    return right, solid(f"{base}_L", left, material, bevel)


# ---------------------------------------------------------------- primitives (bmesh)
def _rot_matrix(rot: Vec3):
    return Euler(rot, "XYZ").to_matrix().to_4x4()


def add_box(
    bm: bmesh.types.BMesh, size: Vec3, center: Vec3, rot: Vec3 = (0.0, 0.0, 0.0)
) -> None:
    """Axis-aligned box of `size` (x, y, z) at `center`, optionally rotated about its center."""
    verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    for v in verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bmesh.ops.transform(bm, matrix=_rot_matrix(rot), verts=verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=verts)


def add_cylinder(
    bm: bmesh.types.BMesh,
    radius: float,
    length: float,
    center: Vec3,
    axis: str = "Y",
    radius_end: float | None = None,
    segments: int = 8,
) -> None:
    """Cylinder/cone along `axis`; `radius` is at -axis end, `radius_end` at +axis end."""
    r2 = radius if radius_end is None else radius_end
    geom = bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=r2,
        depth=length,
    )
    verts = geom["verts"]
    rot = {"Z": (0, 0, 0), "Y": (-math.pi / 2, 0, 0), "X": (0, math.pi / 2, 0)}[axis]
    bmesh.ops.transform(bm, matrix=_rot_matrix(rot), verts=verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=verts)


def add_loft(bm: bmesh.types.BMesh, rings: Sequence[Sequence[Vec3]], cap: bool = True) -> None:
    """Closed solid through consecutive rings of 3D points (all rings the same length)."""
    count = len(rings[0])
    if any(len(r) != count for r in rings):
        raise ValueError("loft rings must all have the same number of points")
    made = [[bm.verts.new(Vector(p)) for p in ring] for ring in rings]
    for a, b in zip(made, made[1:]):
        for i in range(count):
            j = (i + 1) % count
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap:
        bm.faces.new(made[0])
        bm.faces.new(list(reversed(made[-1])))


# ---------------------------------------------------------------- sockets / collision
def socket(
    kind: str, n: int, loc: Vec3, rot: Vec3 = (0.0, 0.0, 0.0), min_tier: int = 0
) -> bpy.types.Object:
    """Empty named SOCKET_<kind>_<n>. Its +Y axis (Godot -Z) is the fire/exhaust direction.

    `min_tier` is exported as a custom property for sockets that only exist on upgraded
    ships (e.g. an extra primary at T3).
    """
    if kind not in SOCKET_KINDS:
        raise ValueError(f"unknown socket kind '{kind}'")
    obj = bpy.data.objects.new(f"SOCKET_{kind}_{n}", None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.4
    obj.location = Vector(loc)
    obj.rotation_euler = Euler(rot, "XYZ")
    obj["kind"] = kind
    obj["index"] = n
    obj["min_tier"] = min_tier
    _link(obj)
    return obj


def add_collision_hull(name: str, sources: Iterable[bpy.types.Object]) -> bpy.types.Object:
    """Convex hull of all `sources` meshes, named `<name>-colonly` (Godot import hint)."""
    pts = [v.co.copy() for o in sources for v in o.data.vertices]
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=verts)
    junk = {v for v in res["geom_interior"] + res["geom_unused"] if isinstance(v, bmesh.types.BMVert)}
    bmesh.ops.delete(bm, geom=list(junk), context="VERTS")
    bmesh.ops.dissolve_limit(
        bm, angle_limit=math.radians(4.0), verts=bm.verts, edges=bm.edges
    )
    bmesh.ops.triangulate(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(f"{name}-colonly")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(f"{name}-colonly", mesh)
    _link(obj)
    return obj


# ---------------------------------------------------------------- naming / tiers
def validate_names(objects: Iterable[bpy.types.Object]) -> None:
    """Raise ValueError listing every object whose name breaks the art bible 3.1 rules."""
    bad = []
    seen: set[str] = set()
    for o in objects:
        if o.name in seen or not any(r.match(o.name) for r in NAME_RULES):
            bad.append(o.name)
        seen.add(o.name)
    if bad:
        raise ValueError(f"invalid or duplicate object names: {sorted(set(bad))}")


def tier_of(name: str) -> int:
    """Lowest ship tier at which an object is shown (T1_ -> 1, others 0)."""
    m = TIER_RE.match(name)
    return int(m.group(1)) if m else 0


def visible_at_tier(name: str, tier: int) -> bool:
    """Visibility rule shared with the game: T#_ shows at tier >= #, T0ONLY_ only at tier 0,
    collision hulls never render."""
    if name.endswith("-colonly"):
        return False
    if name.startswith("T0ONLY_"):
        return tier == 0
    return tier >= tier_of(name)


def triangle_count(obj: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def mesh_objects() -> list[bpy.types.Object]:
    return sorted((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: o.name)
