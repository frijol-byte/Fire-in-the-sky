"""Model manifest: the diffable summary of an exported model (sockets, tiers, bounds, tris)."""


import bpy

from kit import common

DECIMALS = 4


def _r(x: float) -> float:
    v = round(x, DECIMALS)
    return 0.0 if v == 0 else v  # no "-0.0"


def _vec(v) -> list[float]:
    return [_r(c) for c in v]


def collect(recipe) -> dict:
    """Read the current Blender scene (call after recipe.build())."""
    meshes = [o for o in common.mesh_objects() if not o.name.endswith("-colonly")]
    tris_by_tier = {f"T{t}": 0 for t in range(common.MAX_TIER + 1)}
    parts = {}
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in meshes:
        n = common.triangle_count(o)
        parts[o.name] = {
            "triangles": n,
            "min_tier": common.tier_of(o.name),
            "hidden_when_upgraded": o.name.startswith("T0ONLY_"),
        }
        for t in range(common.MAX_TIER + 1):
            if common.visible_at_tier(o.name, t):
                tris_by_tier[f"T{t}"] += n
        for v in o.data.vertices:
            for i in range(3):
                lo[i] = min(lo[i], v.co[i])
                hi[i] = max(hi[i], v.co[i])

    sockets = []
    for o in sorted((o for o in bpy.data.objects if o.type == "EMPTY"), key=lambda o: o.name):
        sockets.append(
            {
                "name": o.name,
                "kind": o["kind"],
                "index": o["index"],
                "min_tier": o["min_tier"],
                "location": _vec(o.location),
                "rotation_euler": _vec(o.rotation_euler),
            }
        )
    colonly = [o.name for o in common.mesh_objects() if o.name.endswith("-colonly")]
    tier_parts = {
        f"T{t}": sorted(n for n in parts if common.tier_of(n) == t) for t in range(1, common.MAX_TIER + 1)
    }
    tier_parts["T0ONLY"] = sorted(n for n in parts if n.startswith("T0ONLY_"))
    # The T3 highest-tier mesh set is what bounds describe; T0 bounds are separate.
    t0 = [o for o in meshes if common.visible_at_tier(o.name, 0)]
    t0lo = [min(v.co[i] for o in t0 for v in o.data.vertices) for i in range(3)]
    t0hi = [max(v.co[i] for o in t0 for v in o.data.vertices) for i in range(3)]
    return {
        "id": recipe.ID,
        "category": recipe.CATEGORY,
        "triangles": {"total": sum(p["triangles"] for p in parts.values()), "by_tier": tris_by_tier},
        "bounds": {
            "all_tiers": {"min": _vec(lo), "max": _vec(hi), "size": _vec([h - l for h, l in zip(hi, lo)])},
            "T0": {"min": _vec(t0lo), "max": _vec(t0hi), "size": _vec([h - l for h, l in zip(t0hi, t0lo)])},
        },
        "axes": "Blender: nose +Y, up +Z, right +X. glTF export is Y-up (nose = Godot -Z).",
        "sockets": sockets,
        "tier_parts": tier_parts,
        "collision": colonly,
        "parts": dict(sorted(parts.items())),
    }


def info_lines(data: dict) -> list[str]:
    size = data["bounds"]["T0"]["size"]
    size3 = data["bounds"]["all_tiers"]["size"]
    tris = data["triangles"]
    return [
        "Placeholder light fighter",
        f"Length {size[1]:.1f} m   Span T0 {size[0]:.1f} m / T3 {size3[0]:.1f} m",
        f"Triangles (LOD0): T0 {tris['by_tier']['T0']}, T3 {tris['by_tier']['T3']}",
        "Budget: fighter 3-8k (art bible 3.3)",
        f"Sockets: {len(data['sockets'])}",
        "Tiers: T1 armor plates",
        "       T2 extra engine pods",
        "       T3 wing extensions + nose cannon",
        "Scale bar in views = 2 m",
        "Nose = +Y (Godot -Z)",
    ]
