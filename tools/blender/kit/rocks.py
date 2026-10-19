"""Lumpy low-poly rocks (asteroids). Deterministic: every rock is a function of its seed."""

import math
import random

import bmesh
import bpy
from mathutils import Vector

import materials
from kit import common


def add_rock(
    bm: bmesh.types.BMesh,
    radius: float,
    seed: int,
    stretch: tuple[float, float, float] = (1.0, 1.0, 1.0),
    lumpiness: float = 0.3,
    craters: int = 3,
    subdivisions: int = 3,
) -> None:
    """An icosphere pushed in and out by a few random sine waves, dented by `craters`, then
    stretched along its axes. Units are metres; `radius` is the mean radius before `stretch`."""
    rng = random.Random(seed)
    geom = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    waves = []
    for _ in range(7):
        direction = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
        if direction.length < 0.1:
            direction = Vector((1.0, 0.0, 0.0))
        waves.append((direction.normalized(), rng.uniform(2.0, 7.0), rng.uniform(0, math.tau)))
    dents = [
        (Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized(),
         rng.uniform(0.35, 0.6), rng.uniform(0.12, 0.25))
        for _ in range(craters)
    ]  # fmt: skip
    for v in geom["verts"]:
        unit = v.co.normalized()
        bump = sum(math.sin(unit.dot(d) * freq + phase) for d, freq, phase in waves) / len(waves)
        scale = 1.0 + lumpiness * bump + rng.uniform(-0.07, 0.07)
        for centre, width, depth in dents:
            angle = math.acos(max(-1.0, min(1.0, unit.dot(centre))))
            if angle < width:
                scale -= depth * (0.5 + 0.5 * math.cos(angle / width * math.pi))
        v.co = Vector(
            (
                unit.x * scale * radius * stretch[0],
                unit.y * scale * radius * stretch[1],
                unit.z * scale * radius * stretch[2],
            )
        )


def rock(name: str, bm: bmesh.types.BMesh, material: str = "ROCK") -> bpy.types.Object:
    """Finish a bmesh into a flat-shaded object linked to the scene (faceted rock look)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    mesh.materials.append(materials.get(material))
    obj = bpy.data.objects.new(name, mesh)
    common._link(obj)  # noqa: SLF001
    return obj
