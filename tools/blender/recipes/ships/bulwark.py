"""bulwark: placeholder heavy fighter (~18 m), a Solar Concord line-of-battle brawler.

Brief: role = heavy fighter. Silhouette keywords = blunt arrowhead, broad shoulders, layered
armor, twin fat engines, forward-set gun pods. Faction cues (Solar Concord) = white/light grey
hull, navy plates, gold trim, blue-white engines. Size = 18 m long, ~11 m span (14 m with T3
wing extensions). Heavier and squarer than the Kestrel dart so that the two read apart at a
glance from 200 m.

Tiers: T1 shoulder and nose armor plates, T2 booster pods on the dorsal shoulders, T3 wing
extensions with missile racks plus a nose cannon (adds primary socket 2).
T0ONLY_stock_cowl is the plain dorsal cowling hidden once upgraded.
"""

import math

from kit import cockpits, common, engines, greebles, hulls, wings

ID = "bulwark"
CATEGORY = "ships"
TRIANGLE_BUDGET = (3000, 8000)  # art bible 3.3: fighter, including tier parts
PALETTE = {"PAINT_PRIMARY": "E4E7EC", "PAINT_SECONDARY": "1B3568", "METAL_BARE": "C9A24A"}
INFO = [
    "Placeholder heavy fighter",
    "Solar Concord: white hull, navy plates",
    "Length 18 m   Span T0 11 m / T3 14 m",
    "Budget: fighter 3-8k (art bible 3.3)",
    "Sockets: 2 primary (+1 at T3), 2 secondary,",
    "         2 engine, cockpit camera",
    "Tiers: T1 shoulder + nose armor",
    "       T2 dorsal booster pods",
    "       T3 wing extensions + nose cannon",
    "Scale bar in views = 2 m",
    "Nose = +Y (Godot -Z)",
]

# (y, half_width, z_top, z_bottom), tail to nose.
STATIONS: list[hulls.Station] = [
    (-8.0, 1.90, 1.35, -1.05),
    (-5.0, 2.45, 1.60, -1.20),
    (-1.0, 2.25, 1.50, -1.00),
    (3.0, 2.00, 1.25, -0.95),
    (6.0, 1.50, 0.95, -0.70),
    (8.2, 0.85, 0.58, -0.42),
    (9.0, 0.40, 0.32, -0.26),
]
WING = dict(
    root_x=2.1, tip_x=5.6, root_le=2.4, root_te=-6.6, tip_le=-1.2, tip_te=-5.4,
    root_z=-0.20, tip_z=0.05, root_thick=0.72, tip_thick=0.2,
)  # fmt: skip
GUN_X = 3.4


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
    parts += common.solid_pair("wing", bm, "PAINT_PRIMARY", bevel=0.04)

    # twin fins, canted outward
    bm = S()
    wings.add_fin(bm, 1.9, -5.0, -8.0, _top(-6.5) - 0.15, 3.0, -6.4, -8.0, _top(-6.5) + 2.2, 0.22)
    parts += common.solid_pair("tail_fin", bm, "PAINT_PRIMARY", bevel=0.04)

    # navy layered shoulder plates (the base armor look) and a spine
    bm = S()
    for y0, y1, x, z0, z1 in ((-6.5, -2.5, 2.22, -0.7, 0.95), (-2.2, 1.8, 1.95, -0.6, 0.8)):
        common.add_box(bm, (0.2, y1 - y0, z1 - z0), (x, (y0 + y1) / 2, (z0 + z1) / 2))
    parts += common.solid_pair("shoulder_plate", bm, "PAINT_SECONDARY", bevel=0.05)

    bm = S()
    common.add_loft(
        bm,
        [
            [(-0.4, y, _top(y) + 0.02), (0.4, y, _top(y) + 0.02), (0.4, y, _top(y) + 0.14), (-0.4, y, _top(y) + 0.14)]
            for y in (-7.4, -4.0, -0.6)
        ],
    )  # fmt: skip
    parts.append(common.solid("spine", bm, "PAINT_SECONDARY", bevel=0.03))

    # gold trim: a thin strake along each wing root and a nose band
    bm = S()
    common.add_box(bm, (2.2, 0.16, 0.06), (3.3, _wing_le(3.3) - 0.5, _wing_z(3.3) + 0.34))
    parts += common.solid_pair("trim_strake", bm, "METAL_BARE", bevel=0.01)
    bm = S()
    common.add_loft(
        bm,
        [
            [(-0.9, y, 0.8), (0.9, y, 0.8), (0.9, y, 0.88), (-0.9, y, 0.88)]
            for y in (4.4, 4.7)
        ],
    )  # fmt: skip
    parts.append(common.solid("trim_band", bm, "METAL_BARE", bevel=0.0))

    # canopy
    glass, frame = S(), S()
    cockpits.add_canopy(
        glass, frame, [(0.8, 0.3, 0.2), (1.8, 0.7, 0.62), (3.2, 0.62, 0.55), (4.8, 0.3, 0.2)], _top, ribs=[1, 2]
    )  # fmt: skip
    parts.append(common.solid("canopy_glass", glass, "GLASS", bevel=0.0))
    parts.append(common.solid("canopy_frame", frame, "METAL_DARK", bevel=0.02))

    # engines: two fat nacelles flanking the spine
    body, glow = S(), S()
    engines.add_nacelle(body, 1.45, -0.05, -3.2, -7.4, 0.8)
    engines.add_nozzle(body, 1.45, -0.05, -8.2, 0.85, 0.72)
    engines.add_glow_disc(glow, 1.45, -0.05, -8.18, 0.55)
    parts += common.solid_pair("engine", body, "METAL_DARK", bevel=0.04)
    parts += common.solid_pair("engine_glow", glow, "EMISSIVE_ENGINE", bevel=0.0)

    # weapons: forward-set wing gun pods (primary), belly missile rails (secondary)
    bm = S()
    wings.add_gun_pod(bm, GUN_X, -2.2, 2.2, _wing_z(GUN_X) - 0.1, 0.16)
    parts += common.solid_pair("gun_pod", bm, "METAL_DARK", bevel=0.02)
    bm = S()
    for x in (0.9, 1.7):
        common.add_box(bm, (0.2, 2.2, 0.24), (x, 1.2, -0.95))
        common.add_box(bm, (0.12, 0.6, 0.12), (x, 2.5, -0.9))
    parts += common.solid_pair("missile_rail", bm, "METAL_DARK", bevel=0.02)

    # greebles
    bm = S()
    greebles.add_vent_row(bm, 0.0, -7.0, _top(-6.0) + 0.16, 6, 0.42, 0.55)
    greebles.add_panel(bm, 0.0, 2.6, _top(2.6) + 0.0, 0.7, 1.2, 0.05)
    parts.append(common.solid("vents", bm, "METAL_DARK", bevel=0.01))
    bm = S()
    greebles.add_antenna(bm, 2.5, -6.7, _top(-6.5) + 2.2, 0.9)
    parts += [common.solid("antenna", bm, "METAL_BARE", bevel=0.0)]
    bm = S()
    for sx in (-1.0, 1.0):
        common.add_box(bm, (0.16, 0.4, 0.1), (sx * 5.6, -1.4, 0.1))
    parts.append(common.solid("wingtip_lights", bm, "EMISSIVE_LIGHT", bevel=0.0))

    bm = S()
    greebles.add_panel(bm, 0.0, -2.2, _top(-2.2) + 0.1, 1.2, 1.4, 0.07)
    common.solid("T0ONLY_stock_cowl", bm, "PAINT_SECONDARY", bevel=0.03)

    # --- T1: extra layered armor on the shoulders, dorsal deck and nose
    bm = S()
    for y0, y1, z0, z1, x in ((-6.2, -3.0, 0.4, 1.0, 2.3), (-2.6, 0.6, 0.3, 0.85, 2.0), (1.6, 4.4, -0.1, 0.5, 1.2)):
        common.add_box(bm, (0.18, y1 - y0, z1 - z0), (x + 0.12, (y0 + y1) / 2, (z0 + z1) / 2))
    common.solid_pair("T1_shoulder_armor", bm, "PAINT_SECONDARY", bevel=0.05)
    bm = S()
    for y0, y1 in ((-7.4, -4.6), (-4.2, -1.8)):
        common.add_box(bm, (1.5, y1 - y0, 0.16), (0.0, (y0 + y1) / 2, _top((y0 + y1) / 2) + 0.2))
    common.solid("T1_dorsal_armor", bm, "PAINT_SECONDARY", bevel=0.04)
    bm = S()
    common.add_loft(
        bm,
        [
            [(-0.8, y, 0.05), (0.8, y, 0.05), (0.55, y, 0.62), (-0.55, y, 0.62)]
            for y in (5.0, 7.0)
        ],
    )  # fmt: skip
    common.solid("T1_nose_wedge", bm, "PAINT_SECONDARY", bevel=0.03)

    # --- T2: a booster pod on each dorsal shoulder
    body, glow = S(), S()
    engines.add_engine_pod(body, glow, 2.1, _top(-5.5) + 0.7, -3.4, -6.4, 0.42)
    common.add_box(body, (0.4, 1.6, 0.5), (2.1, -4.0, _top(-5.5) + 0.25))
    common.solid_pair("T2_booster_pod", body, "METAL_DARK", bevel=0.03)
    common.solid_pair("T2_booster_pod_glow", glow, "EMISSIVE_ENGINE", bevel=0.0)

    # --- T3: wing extensions carrying missile racks, and a nose cannon with its own socket
    bm = S()
    wings.add_swept_wing(
        bm, 5.6, 7.0, -1.2, -5.4, -0.6, -5.0, 0.05, 0.08, 0.2, 0.12,
    )  # fmt: skip
    common.solid_pair("T3_wing_extension", bm, "PAINT_PRIMARY", bevel=0.03)
    bm = S()
    common.add_box(bm, (0.18, 1.6, 0.18), (6.5, -2.0, -0.12))
    common.add_box(bm, (0.1, 0.5, 0.1), (6.5, -0.9, -0.12))
    common.solid_pair("T3_wing_rack", bm, "METAL_DARK", bevel=0.015)
    bm = S()
    common.add_cylinder(bm, 0.15, 3.0, (0.0, 8.8, -0.1), "Y", segments=6)
    common.solid("T3_nose_cannon", bm, "METAL_DARK", bevel=0.01)

    # --- sockets (nose = +Y; +Y of a socket is the fire / exhaust direction)
    common.socket("primary", 0, (GUN_X, 2.2, _wing_z(GUN_X) - 0.1))
    common.socket("primary", 1, (-GUN_X, 2.2, _wing_z(GUN_X) - 0.1))
    common.socket("primary", 2, (0.0, 10.3, -0.1), min_tier=3)
    common.socket("secondary", 0, (0.9, 2.8, -0.9))
    common.socket("secondary", 1, (-0.9, 2.8, -0.9))
    common.socket("engine", 0, (1.45, -8.25, -0.05), (0.0, 0.0, math.pi))
    common.socket("engine", 1, (-1.45, -8.25, -0.05), (0.0, 0.0, math.pi))
    common.socket("cockpit_cam", 0, (0.0, 1.8, _top(1.8) + 0.3))

    common.add_collision_hull(
        "hull", [p for p in parts if p.name in ("hull", "wing_R", "wing_L", "tail_fin_R", "tail_fin_L")]
    )
