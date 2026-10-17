"""Parametric fuselages."""

from collections.abc import Sequence

import bmesh

from kit import common

# (y, half_width, z_top, z_bottom) from tail to nose.
Station = tuple[float, float, float, float]


def _ring(st: Station) -> list[tuple[float, float, float]]:
    y, hw, top, bot = st
    mid = (top + bot) * 0.5 + 0.08
    return [
        (-hw * 0.5, y, top),
        (hw * 0.5, y, top),
        (hw, y, mid),
        (hw * 0.55, y, bot),
        (-hw * 0.55, y, bot),
        (-hw, y, mid),
    ]


def add_fuselage(bm: bmesh.types.BMesh, stations: Sequence[Station]) -> None:
    """Hexagonal-section fuselage lofted through `stations`."""
    common.add_loft(bm, [_ring(s) for s in stations])


def profile(stations: Sequence[Station], y: float) -> tuple[float, float, float]:
    """Linearly interpolated (half_width, z_top, z_bottom) of the fuselage at `y`."""
    ordered = sorted(stations)
    if y <= ordered[0][0]:
        return ordered[0][1:]
    for a, b in zip(ordered, ordered[1:]):
        if a[0] <= y <= b[0]:
            t = (y - a[0]) / (b[0] - a[0])
            return tuple(a[i] + (b[i] - a[i]) * t for i in (1, 2, 3))
    return ordered[-1][1:]
