"""Small surface detail: panels, vents, antennae. Deterministic (no randomness)."""

import bmesh

from kit import common


def add_panel(
    bm: bmesh.types.BMesh, x: float, y: float, z: float, w: float, l: float, t: float = 0.05
) -> None:
    """Raised rectangular plate lying flat; z is the surface it sits on."""
    common.add_box(bm, (w, l, t), (x, y, z + t * 0.5))


def add_vent_row(
    bm: bmesh.types.BMesh, x: float, y0: float, z: float, count: int, pitch: float, w: float
) -> None:
    """Row of raised slats along Y."""
    for i in range(count):
        common.add_box(bm, (w, pitch * 0.45, 0.06), (x, y0 + i * pitch, z + 0.03))


def add_antenna(bm: bmesh.types.BMesh, x: float, y: float, z: float, length: float) -> None:
    """Thin mast with a small tip bead, pointing up."""
    common.add_cylinder(bm, 0.025, length, (x, y, z + length * 0.5), "Z", segments=5)
    common.add_box(bm, (0.08, 0.08, 0.08), (x, y, z + length))
