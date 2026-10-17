"""Swept wings, fins and gun pods (all authored on the +X side; mirror with solid_pair)."""

import bmesh

from kit import common


def add_swept_wing(
    bm: bmesh.types.BMesh,
    root_x: float,
    tip_x: float,
    root_le: float,
    root_te: float,
    tip_le: float,
    tip_te: float,
    root_z: float,
    tip_z: float,
    root_thick: float,
    tip_thick: float,
) -> None:
    """Planform wing: leading/trailing edge Y at root and tip, centre-line Z and thickness."""

    def ring(x: float, le: float, te: float, z: float, t: float):
        h = t * 0.5
        return [(x, le, z + h * 0.6), (x, te, z + h), (x, te, z - h), (x, le, z - h * 0.6)]

    common.add_loft(
        bm,
        [
            ring(root_x, root_le, root_te, root_z, root_thick),
            ring(tip_x, tip_le, tip_te, tip_z, tip_thick),
        ],
    )


def add_fin(
    bm: bmesh.types.BMesh,
    base_x: float,
    base_front: float,
    base_back: float,
    base_z: float,
    top_x: float,
    top_front: float,
    top_back: float,
    top_z: float,
    thick: float,
) -> None:
    """Canted vertical fin from a root chord to a tip chord."""
    h = thick * 0.5

    def ring(x: float, front: float, back: float, z: float, tt: float):
        return [(x - tt, front, z), (x + tt, front, z), (x + tt, back, z), (x - tt, back, z)]

    common.add_loft(
        bm,
        [ring(base_x, base_front, base_back, base_z, h), ring(top_x, top_front, top_back, top_z, h * 0.6)],
    )


def add_gun_pod(
    bm: bmesh.types.BMesh, x: float, y_back: float, y_front: float, z: float, radius: float
) -> None:
    """Pod body plus a thinner barrel; the muzzle sits at `y_front`."""
    body = (y_front - y_back) * 0.55
    common.add_cylinder(bm, radius * 1.5, body, (x, y_back + body * 0.5, z), "Y", segments=8)
    barrel = (y_front - y_back) - body
    common.add_cylinder(bm, radius, barrel, (x, y_back + body + barrel * 0.5, z), "Y", segments=6)
