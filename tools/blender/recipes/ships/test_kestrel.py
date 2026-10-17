"""test_kestrel: placeholder light fighter (~14 m) used to prove the Blender pipeline.

Brief: role = light fighter. Silhouette keywords = dart, swept delta wings, twin tail fins,
needle nose. Faction cues (Solar Concord stand-in) = light-grey hull, navy trim, blue-white
engines. Size = 14 m long, ~10 m span (12.6 m with T3 wing extensions).

Tiers: T1 armor plates, T2 extra engine pods on the wings, T3 wing extensions + nose cannon
(adds primary socket 2). T0ONLY_stock_cowl is the plain dorsal cowling hidden once upgraded.
"""

import math

from kit import cockpits, common, engines, greebles, hulls, wings

ID = "test_kestrel"
CATEGORY = "ships"
TRIANGLE_BUDGET = (3000, 8000)  # art bible 3.3: fighter, including tier parts

# (y, half_width, z_top, z_bottom), tail to nose.
STATIONS: list[hulls.Station] = [
    (-6.0, 1.20, 0.95, -0.85),
    (-3.5, 1.45, 1.05, -0.80),
    (-0.5, 1.15, 0.95, -0.65),
    (2.5, 0.75, 0.65, -0.45),
    (5.0, 0.45, 0.40, -0.28),
    (7.0, 0.10, 0.14, -0.10),
]
WING = dict(
    root_x=1.0, tip_x=5.0, root_le=0.5, root_te=-4.6, tip_le=-2.2, tip_te=-4.1,
    root_z=-0.15, tip_z=0.0, root_thick=0.30, tip_thick=0.08,
)  # fmt: skip


def _top(y: float) -> float:
    return hulls.profile(STATIONS, y)[1]


def _wing_z(x: float) -> float:
    t = (x - WING["root_x"]) / (WING["tip_x"] - WING["root_x"])
    return WING["root_z"] + (WING["tip_z"] - WING["root_z"]) * t


def _wing_le(x: float) -> float:
    t = (x - WING["root_x"]) / (WING["tip_x"] - WING["root_x"])
    return WING["root_le"] + (WING["tip_le"] - WING["root_le"]) * t


def build() -> None:
    S = common.new_bm  # noqa: N806
    parts = []

    # --- base hull and wings (T0)
    bm = S()
    hulls.add_fuselage(bm, STATIONS)
    parts.append(common.solid("hull", bm, "PAINT_PRIMARY"))

    bm = S()
    wings.add_swept_wing(bm, **WING)
    parts += common.solid_pair("wing", bm, "PAINT_PRIMARY", bevel=0.03)

    bm = S()
    wings.add_fin(bm, 1.0, -3.6, -5.9, _top(-4.5) - 0.1, 1.6, -4.5, -5.9, _top(-4.5) + 1.6, 0.16)
    parts += common.solid_pair("tail_fin", bm, "PAINT_PRIMARY", bevel=0.03)

    # navy dorsal spine and wing stripes
    bm = S()
    common.add_loft(
        bm,
        [
            [(-0.28, y, _top(y) + 0.02), (0.28, y, _top(y) + 0.02), (0.28, y, _top(y) + 0.1), (-0.28, y, _top(y) + 0.1)]
            for y in (-5.8, -3.0, -0.2)
        ],
    )  # fmt: skip
    parts.append(common.solid("spine", bm, "PAINT_SECONDARY", bevel=0.02))

    bm = S()
    for x0, x1 in ((1.6, 2.1), (3.2, 3.6)):
        xm = (x0 + x1) * 0.5
        greebles.add_panel(bm, xm, -3.2 + (xm - 1.0) * -0.15, _wing_z(xm) + 0.12, x1 - x0, 1.7)
    parts += common.solid_pair("wing_stripe", bm, "PAINT_SECONDARY", bevel=0.01)

    # canopy
    glass, frame = S(), S()
    cockpits.add_canopy(
        glass, frame, [(0.3, 0.2, 0.1), (1.1, 0.5, 0.5), (2.3, 0.42, 0.45), (3.7, 0.2, 0.15)], _top, ribs=[1, 2]
    )  # fmt: skip
    parts.append(common.solid("canopy_glass", glass, "GLASS", bevel=0.0))
    parts.append(common.solid("canopy_frame", frame, "METAL_DARK", bevel=0.015))

    # engines
    body, glow = S(), S()
    engines.add_nacelle(body, 0.75, -0.05, -3.0, -6.4, 0.5)
    engines.add_nozzle(body, 0.75, -0.05, -7.0, 0.65, 0.48)
    engines.add_glow_disc(glow, 0.75, -0.05, -6.98, 0.36)
    parts += common.solid_pair("engine", body, "METAL_DARK", bevel=0.03)
    parts += common.solid_pair("engine_glow", glow, "EMISSIVE_ENGINE", bevel=0.0)

    # weapons: wing gun pods (primary), belly missile rail (secondary)
    bm = S()
    wings.add_gun_pod(bm, 2.9, -2.4, 0.9, _wing_z(2.9) - 0.05, 0.1)
    parts += common.solid_pair("gun_pod", bm, "METAL_DARK", bevel=0.015)
    bm = S()
    common.add_box(bm, (0.22, 1.6, 0.22), (0.0, 1.6, -0.55))
    common.add_box(bm, (0.12, 0.5, 0.12), (0.0, 2.6, -0.5))
    parts.append(common.solid("missile_rail", bm, "METAL_DARK", bevel=0.02))

    # greebles
    bm = S()
    greebles.add_vent_row(bm, 0.0, -5.0, _top(-4.0) + 0.1, 5, 0.38, 0.4)
    greebles.add_panel(bm, 0.0, 2.2, _top(2.2) + 0.0, 0.5, 0.9, 0.04)
    parts.append(common.solid("vents", bm, "METAL_DARK", bevel=0.01))
    bm = S()
    greebles.add_antenna(bm, 1.6, -5.2, _top(-4.5) + 1.6, 0.7)
    parts += [common.solid("antenna", bm, "METAL_BARE", bevel=0.0)]
    bm = S()
    for sx in (-1.0, 1.0):
        common.add_box(bm, (0.12, 0.3, 0.08), (sx * 5.0, -2.45, 0.02))
    parts.append(common.solid("wingtip_lights", bm, "EMISSIVE_LIGHT", bevel=0.0))

    bm = S()
    greebles.add_panel(bm, 0.0, -1.6, _top(-1.6) + 0.1, 0.9, 1.1, 0.06)
    common.solid("T0ONLY_stock_cowl", bm, "PAINT_SECONDARY", bevel=0.02)

    # --- T1: armor plates over the flanks and dorsal spine
    bm = S()
    for y0, y1, z0, z1, x in ((-4.9, -2.3, -0.5, 0.55, 1.62), (-1.9, 0.9, -0.3, 0.5, 1.3), (1.3, 3.4, -0.2, 0.35, 0.85)):
        common.add_box(bm, (0.14, y1 - y0, z1 - z0), (x, (y0 + y1) / 2, (z0 + z1) / 2))
    common.solid_pair("T1_armor_plate", bm, "PAINT_SECONDARY", bevel=0.04)
    bm = S()
    for y0, y1 in ((-5.4, -3.4), (-3.1, -1.1)):
        common.add_box(bm, (1.0, y1 - y0, 0.14), (0.0, (y0 + y1) / 2, _top((y0 + y1) / 2) + 0.12))
    common.solid("T1_dorsal_armor", bm, "PAINT_SECONDARY", bevel=0.03)

    # --- T2: extra engine pods on the wing trailing edges
    body, glow = S(), S()
    engines.add_engine_pod(body, glow, 2.5, -0.05, -3.6, -5.5, 0.34)
    engines.add_engine_pod(body, glow, 3.7, 0.0, -3.5, -5.2, 0.28)
    common.add_box(body, (0.16, 1.4, 0.4), (3.1, -3.5, -0.06))
    common.solid_pair("T2_engine_pod", body, "METAL_DARK", bevel=0.025)
    common.solid_pair("T2_engine_pod_glow", glow, "EMISSIVE_ENGINE", bevel=0.0)

    # --- T3: wing extensions and a nose cannon with its own primary socket
    bm = S()
    wings.add_swept_wing(
        bm, 5.0, 6.4, -2.2, -4.1, -3.4, -4.1, 0.0, 0.08, 0.08, 0.05,
    )  # fmt: skip
    common.solid_pair("T3_wing_extension", bm, "PAINT_PRIMARY", bevel=0.02)
    bm = S()
    common.add_cylinder(bm, 0.11, 2.4, (0.0, 6.3, -0.2), "Y", segments=6)
    common.solid("T3_nose_cannon", bm, "METAL_DARK", bevel=0.01)

    # --- sockets (nose = +Y; +Y of a socket is the fire / exhaust direction)
    common.socket("primary", 0, (2.9, 0.9, _wing_z(2.9) - 0.05))
    common.socket("primary", 1, (-2.9, 0.9, _wing_z(2.9) - 0.05))
    common.socket("primary", 2, (0.0, 7.5, -0.2), min_tier=3)
    common.socket("secondary", 0, (0.0, 3.0, -0.5))
    common.socket("engine", 0, (0.75, -7.05, -0.05), (0.0, 0.0, math.pi))
    common.socket("engine", 1, (-0.75, -7.05, -0.05), (0.0, 0.0, math.pi))
    common.socket("cockpit_cam", 0, (0.0, 1.3, _top(1.3) + 0.2))

    common.add_collision_hull("hull", [p for p in parts if p.name in ("hull", "wing_R", "wing_L", "tail_fin_R", "tail_fin_L")])
