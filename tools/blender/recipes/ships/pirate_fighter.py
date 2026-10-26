"""pirate_fighter: placeholder Cinder Clans raider (~16 m), a kit-bashed gun platform.

Brief: role = pirate fighter. Silhouette keywords = lopsided wedge, one long wing and one stub,
bolted scrap plates, nose spikes, a single big engine with a small one hung off the side.
Faction cues (Cinder Clans, art bible 2) = rust-red hull, black scrap plates, hazard stripes,
dirty-orange engines. Size = 16 m long, ~11 m span. Deliberately asymmetric: no part is mirrored,
so it never reads as a Concord ship even at 1 km.

No upgrade tiers: pirates are not refitted. Sockets: two primary (one pod on each wing, unequal),
one secondary, two engines and a cockpit camera.
"""

import math

from kit import cockpits, common, engines, greebles, hulls, wings

ID = "pirate_fighter"
CATEGORY = "ships"
TRIANGLE_BUDGET = (1500, 8000)  # art bible 3.3: fighter
PALETTE = {
    "PAINT_PRIMARY": "8A3B24",
    "PAINT_SECONDARY": "1A1614",
    "METAL_BARE": "6E625A",
    "EMISSIVE_ENGINE": "FF8A33",
}
INFO = [
    "Placeholder pirate fighter",
    "Cinder Clans: rust hull, black scrap plates",
    "Length 16 m   Span 11 m   (asymmetric)",
    "Budget: fighter 3-8k (art bible 3.3)",
    "Sockets: 2 primary, 1 secondary,",
    "         2 engine, cockpit camera",
    "Tiers: none",
    "Scale bar in views = 2 m",
    "Nose = +Y (Godot -Z)",
]

# (y, half_width, z_top, z_bottom), tail to nose.
STATIONS: list[hulls.Station] = [
    (-7.0, 1.55, 1.15, -1.00),
    (-4.0, 1.95, 1.35, -1.05),
    (-0.5, 1.65, 1.15, -0.85),
    (3.0, 1.15, 0.85, -0.60),
    (6.0, 0.65, 0.55, -0.38),
    (8.2, 0.25, 0.30, -0.20),
]
# The long wing (starboard) and the stub (port, authored with negative X).
WING_R = dict(
    root_x=1.4, tip_x=5.6, root_le=1.0, root_te=-5.2, tip_le=-2.6, tip_te=-5.0,
    root_z=-0.20, tip_z=0.05, root_thick=0.38, tip_thick=0.10,
)  # fmt: skip
WING_L = dict(
    root_x=-1.4, tip_x=-3.7, root_le=0.4, root_te=-4.6, tip_le=-1.6, tip_te=-4.2,
    root_z=-0.20, tip_z=-0.05, root_thick=0.34, tip_thick=0.12,
)  # fmt: skip


def _top(y: float) -> float:
    return hulls.profile(STATIONS, y)[1]


def _wing_z(wing: dict, x: float) -> float:
    t = (x - wing["root_x"]) / (wing["tip_x"] - wing["root_x"])
    return wing["root_z"] + (wing["tip_z"] - wing["root_z"]) * t


def build() -> None:
    S = common.new_bm  # noqa: N806
    parts = []

    # --- hull and the two unequal wings
    bm = S()
    hulls.add_fuselage(bm, STATIONS)
    parts.append(common.solid("hull", bm, "PAINT_PRIMARY"))

    bm = S()
    wings.add_swept_wing(bm, **WING_R)
    parts.append(common.solid("wing_R", bm, "PAINT_PRIMARY", bevel=0.03))
    bm = S()
    wings.add_swept_wing(bm, **WING_L)
    parts.append(common.solid("wing_L", bm, "PAINT_PRIMARY", bevel=0.03))

    # one tall fin on the starboard side, a broken stub on the port side
    bm = S()
    wings.add_fin(bm, 1.1, -3.4, -6.0, _top(-4.5) - 0.1, 1.7, -4.7, -6.2, _top(-4.5) + 2.1, 0.18)
    parts.append(common.solid("tail_fin_R", bm, "PAINT_PRIMARY", bevel=0.03))
    bm = S()
    wings.add_fin(bm, -1.1, -3.6, -5.8, _top(-4.5) - 0.1, -1.4, -4.2, -5.6, _top(-4.5) + 0.7, 0.18)
    parts.append(common.solid("tail_fin_L", bm, "PAINT_PRIMARY", bevel=0.03))

    # canopy, set off-centre by the dorsal armor slab
    glass, frame = S(), S()
    cockpits.add_canopy(
        glass, frame, [(0.6, 0.18, 0.1), (1.4, 0.45, 0.5), (2.6, 0.4, 0.42), (3.8, 0.18, 0.14)], _top, ribs=[1]
    )  # fmt: skip
    parts.append(common.solid("canopy_glass", glass, "GLASS", bevel=0.0))
    parts.append(common.solid("canopy_frame", frame, "METAL_DARK", bevel=0.015))

    # --- scrap: black plates bolted on at odd angles
    bm = S()
    common.add_box(bm, (1.5, 3.4, 0.16), (0.55, -2.6, _top(-2.6) + 0.14), rot=(0.0, math.radians(7), math.radians(4)))
    common.add_box(bm, (0.2, 2.8, 1.1), (1.75, -2.0, 0.1), rot=(0.0, 0.0, math.radians(-6)))
    common.add_box(bm, (0.2, 1.6, 0.9), (-1.55, 0.6, 0.15), rot=(0.0, 0.0, math.radians(9)))
    common.add_box(bm, (1.1, 1.3, 0.12), (-0.5, 4.3, _top(4.3) + 0.1), rot=(math.radians(-5), 0.0, math.radians(-12)))
    common.add_box(bm, (0.9, 1.6, 0.14), (3.2, -1.7, _wing_z(WING_R, 3.2) + 0.12), rot=(0.0, 0.0, math.radians(5)))
    parts.append(common.solid("scrap_plates", bm, "PAINT_SECONDARY", bevel=0.03))

    # hazard stripes on the stub wing and the dorsal slab
    bm = S()
    for x0 in (-2.0, -2.8):
        greebles.add_panel(bm, x0, -2.4 + (abs(x0) - 1.4) * 0.3, _wing_z(WING_L, x0) + 0.1, 0.4, 1.7)
    greebles.add_panel(bm, 0.55, -2.0, _top(-2.6) + 0.3, 1.2, 0.35, 0.03)
    parts.append(common.solid("hazard_stripes", bm, "DECAL_HAZARD", bevel=0.0))

    # nose spikes and a ram bar
    bm = S()
    common.add_cylinder(bm, 0.16, 1.9, (0.0, 8.0, 0.0), "Y", radius_end=0.02, segments=5)
    common.add_cylinder(bm, 0.1, 1.2, (0.75, 6.4, -0.1), "Y", radius_end=0.02, segments=5)
    common.add_cylinder(bm, 0.1, 1.0, (-0.7, 6.0, -0.15), "Y", radius_end=0.02, segments=5)
    parts.append(common.solid("spikes", bm, "METAL_BARE", bevel=0.0))

    # --- engines: a big one and a small one hung off the port side
    body, glow = S(), S()
    engines.add_nacelle(body, 0.55, -0.05, -3.2, -6.6, 0.62)
    engines.add_nozzle(body, 0.55, -0.05, -7.2, 0.62, 0.62)
    engines.add_glow_disc(glow, 0.55, -0.05, -7.18, 0.46)
    engines.add_engine_pod(body, glow, -1.9, -0.45, -2.6, -5.2, 0.3)
    common.add_box(body, (1.2, 0.35, 0.18), (-1.2, -3.6, -0.3), rot=(0.0, 0.0, math.radians(-14)))
    parts.append(common.solid("engine", body, "METAL_DARK", bevel=0.03))
    parts.append(common.solid("engine_glow", glow, "EMISSIVE_ENGINE", bevel=0.0))

    # --- weapons: a long gun pod on the long wing, a short one on the stub, a belly rail
    bm = S()
    wings.add_gun_pod(bm, 3.3, -2.2, 1.6, _wing_z(WING_R, 3.3) - 0.05, 0.11)
    parts.append(common.solid("gun_pod_R", bm, "METAL_DARK", bevel=0.015))
    bm = S()
    wings.add_gun_pod(bm, -2.5, -2.0, 0.6, _wing_z(WING_L, -2.5) - 0.05, 0.13)
    parts.append(common.solid("gun_pod_L", bm, "METAL_DARK", bevel=0.015))
    bm = S()
    common.add_box(bm, (0.22, 1.5, 0.22), (-0.35, 1.8, -0.62))
    parts.append(common.solid("missile_rail", bm, "METAL_DARK", bevel=0.02))

    # --- greebles: exposed frame, vents, a bristle of antennae, wing-tip lights
    bm = S()
    for y in (-5.5, -3.0, -0.5):
        common.add_box(bm, (3.0, 0.1, 0.1), (0.1, y, -0.95), rot=(0.0, 0.0, math.radians(3)))
    greebles.add_vent_row(bm, 0.0, -6.2, _top(-5.2) + 0.1, 4, 0.4, 0.45)
    parts.append(common.solid("frame", bm, "METAL_DARK", bevel=0.01))
    bm = S()
    greebles.add_antenna(bm, 1.2, -5.0, _top(-5.0) + 2.0, 0.9)
    greebles.add_antenna(bm, -0.8, -1.2, _top(-1.2) + 0.1, 1.2)
    greebles.add_antenna(bm, 5.4, -2.9, _wing_z(WING_R, 5.4) + 0.05, 0.6)
    parts.append(common.solid("antennae", bm, "METAL_BARE", bevel=0.0))
    bm = S()
    common.add_box(bm, (0.12, 0.3, 0.08), (5.5, -2.8, 0.05))
    parts.append(common.solid("wingtip_light", bm, "EMISSIVE_LIGHT", bevel=0.0))

    # --- sockets (nose = +Y; +Y of a socket is the fire / exhaust direction)
    common.socket("primary", 0, (3.3, 1.6, _wing_z(WING_R, 3.3) - 0.05))
    common.socket("primary", 1, (-2.5, 0.6, _wing_z(WING_L, -2.5) - 0.05))
    common.socket("secondary", 0, (-0.35, 2.7, -0.62))
    common.socket("engine", 0, (0.55, -7.25, -0.05), (0.0, 0.0, math.pi))
    common.socket("engine", 1, (-1.9, -5.9, -0.45), (0.0, 0.0, math.pi))
    common.socket("cockpit_cam", 0, (0.0, 1.5, _top(1.5) + 0.2))

    common.add_collision_hull(
        "hull", [p for p in parts if p.name in ("hull", "wing_R", "wing_L", "tail_fin_R", "tail_fin_L")]
    )
