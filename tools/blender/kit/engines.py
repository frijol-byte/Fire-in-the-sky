"""Engine nacelles, nozzles and pods."""

import bmesh

from kit import common


def add_nacelle(
    bm: bmesh.types.BMesh, x: float, z: float, y_front: float, y_back: float, radius: float
) -> None:
    length = y_front - y_back
    common.add_cylinder(
        bm, radius, length, (x, y_back + length * 0.5, z), "Y", radius_end=radius * 1.1, segments=10
    )


def add_nozzle(
    bm: bmesh.types.BMesh, x: float, z: float, y_back: float, length: float, radius: float
) -> None:
    """Flared exhaust bell whose rim is at `y_back`."""
    common.add_cylinder(
        bm, radius * 0.8, length, (x, y_back + length * 0.5, z), "Y", radius_end=radius, segments=10
    )


def add_glow_disc(bm: bmesh.types.BMesh, x: float, z: float, y: float, radius: float) -> None:
    common.add_cylinder(bm, radius, 0.06, (x, y, z), "Y", segments=10)


def add_engine_pod(
    bm_body: bmesh.types.BMesh,
    bm_glow: bmesh.types.BMesh,
    x: float,
    z: float,
    y_front: float,
    y_back: float,
    radius: float,
) -> None:
    """Complete small engine (body + nozzle into bm_body, emissive disc into bm_glow)."""
    add_nacelle(bm_body, x, z, y_front, y_back, radius)
    add_nozzle(bm_body, x, z, y_back - 0.35, 0.35, radius * 0.9)
    add_glow_disc(bm_glow, x, z, y_back - 0.33, radius * 0.7)
