"""ring_gate: a flight gate to fly through (flight arena).

Brief: role = a waypoint ring that makes speed and steering readable. Silhouette keywords =
big octagonal ring, chunky struts, a glowing inner rim. Faction cues = neutral (dark metal with
amber lights). Size = 60 m across the opening, 6 m deep. The ring lies in the XZ plane, so the
hole faces the Y axis (Godot Z): a ship flying through it flies along the ring's axis.
"""

import math

from mathutils import Vector

from kit import common

ID = "ring_gate"
CATEGORY = "props"
TRIANGLE_BUDGET = (200, 4000)
SEGMENTS = 12
OUTER = 34.0
INNER = 30.0
DEPTH = 6.0


def _point(angle: float, radius: float, y: float) -> tuple[float, float, float]:
    return (math.cos(angle) * radius, y, math.sin(angle) * radius)


def build() -> None:
    S = common.new_bm  # noqa: N806
    step = math.tau / SEGMENTS
    # Chunky dark struts: one trapezoid block per segment, the gap between them left open.
    bm = S()
    for i in range(SEGMENTS):
        a0, a1 = i * step + step * 0.06, (i + 1) * step - step * 0.06
        rings = [
            [_point(a, r, y) for a, r in ((a0, INNER), (a1, INNER), (a1, OUTER), (a0, OUTER))]
            for y in (-DEPTH * 0.5, DEPTH * 0.5)
        ]
        common.add_loft(bm, rings)
    common.solid("frame", bm, "METAL_DARK", bevel=0.2)

    # The glowing rim: a thin lit band on the inside of each strut.
    bm = S()
    for i in range(SEGMENTS):
        a0, a1 = i * step + step * 0.14, (i + 1) * step - step * 0.14
        rings = [
            [_point(a, r, y) for a, r in ((a0, INNER - 0.5), (a1, INNER - 0.5), (a1, INNER), (a0, INNER))]
            for y in (-DEPTH * 0.3, DEPTH * 0.3)
        ]
        common.add_loft(bm, rings)
    common.solid("rim_light", bm, "EMISSIVE_LIGHT", bevel=0.0)

    # Small hazard-coloured pylons at the four compass points.
    bm = S()
    for i in range(0, SEGMENTS, SEGMENTS // 4):
        a = i * step
        centre = Vector(_point(a, OUTER + 1.5, 0.0))
        common.add_box(bm, (3.0, DEPTH * 1.4, 3.0), tuple(centre))
    common.solid("marker", bm, "DECAL_HAZARD", bevel=0.1)
