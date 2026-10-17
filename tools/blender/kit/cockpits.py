"""Canopy glass and frame."""

from collections.abc import Callable

import bmesh

from kit import common


def _bubble_ring(y: float, base_z: float, half_w: float, height: float, grow: float = 1.0):
    w, h = half_w * grow, height * grow
    return [
        (-w, y, base_z),
        (w, y, base_z),
        (w * 0.8, y, base_z + h * 0.7),
        (w * 0.4, y, base_z + h),
        (-w * 0.4, y, base_z + h),
        (-w * 0.8, y, base_z + h * 0.7),
    ]


def add_canopy(
    glass: bmesh.types.BMesh,
    frame: bmesh.types.BMesh,
    sections: list[tuple[float, float, float]],
    top_at: Callable[[float], float],
    ribs: list[int],
) -> None:
    """Glass bubble through `sections` (y, half_width, height) sitting on the hull top, with
    thin frame ribs at the section indexes in `ribs` and a sill rail on each side."""
    rings = [_bubble_ring(y, top_at(y) - 0.12, w, h) for y, w, h in sections]
    common.add_loft(glass, rings)
    for i in ribs:
        y, w, h = sections[i]
        base = top_at(y) - 0.12
        common.add_loft(
            frame,
            [
                _bubble_ring(y - 0.06, base - 0.02, w, h, 1.06),
                _bubble_ring(y + 0.06, base - 0.02, w, h, 1.06),
            ],
        )
    y0, y1 = sections[0][0], sections[-1][0]
    mid = sections[len(sections) // 2]
    for sx in (-1.0, 1.0):
        common.add_box(
            frame,
            (0.08, y1 - y0, 0.1),
            (sx * mid[1] * 0.98, (y0 + y1) * 0.5, top_at((y0 + y1) * 0.5) - 0.1),
        )
