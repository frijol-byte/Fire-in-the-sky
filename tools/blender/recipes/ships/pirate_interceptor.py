"""pirate_interceptor: placeholder Cinder Clans dagger (~11 m), a fast hit-and-run skiff.

Brief: role = pirate interceptor. Silhouette keywords = needle with an outrigger, one long gun
boom, one wide wing, lashed-on scrap. Faction cues (Cinder Clans, art bible 2) = rust-red hull,
black scrap plates, hazard stripes, dirty-orange engines. Size = 11 m long, ~8 m span. Smaller
and thinner than the pirate fighter so the two read apart at 500 m. Asymmetric on purpose: the
gun boom is on the port side only and the engine pod hangs off the starboard wing.

No upgrade tiers. Sockets: two primary (boom tip and nose), one secondary, two engines and a
cockpit camera.
"""

import math

from kit import cockpits, common, engines, greebles, hulls, wings

ID = "pirate_interceptor"
CATEGORY = "ships"
TRIANGLE_BUDGET = (1000, 8000)  # art bible 3.3: fighter
PALETTE = {
    "PAINT_PRIMARY": "8A3B24",
    "PAINT_SECONDARY": "1A1614",
    "METAL_BARE": "6E625A",
    "EMISSIVE_ENGINE": "FF8A33",
}
INFO = [
    "Placeholder pirate interceptor",
    "Cinder Clans: rust hull, black scrap plates",
    "Length 11 m   Span 8 m   (asymmetric)",
    "Budget: fighter 3-8k (art bible 3.3)",
    "Sockets: 2 primary, 1 secondary,",
    "         2 engine, cockpit camera",
    "Tiers: none",
    "Scale bar in views = 2 m",
    "Nose = +Y (Godot -Z)",
]

# (y, half_width, z_top, z_bottom), tail to nose.
STATIONS: list[hulls.Station] = [
    (-4.8, 0.95, 0.80, -0.65),
    (-2.5, 1.15, 0.90, -0.70),
    (0.0, 0.85, 0.72, -0.50),
    (2.5, 0.52, 0.45, -0.30),
    (4.6, 0.16, 0.22, -0.14),
]
# One wide wing to starboard, a narrow stub to port.
WING_R = dict(
    root_x=0.9, tip_x=4.1, root_le=0.4, root_te=-3.6, tip_le=-1.8, tip_te=-3.4,
    root_z=-0.12, tip_z=0.0, root_thick=0.26, tip_thick=0.07,
)  # fmt: skip
WING_L = dict(
    root_x=-0.9, tip_x=-2.0, root_le=0.0, root_te=-3.2, tip_le=-1.0, tip_te=-3.0,
    root_z=-0.12, tip_z=-0.04, root_thick=0.22, tip_thick=0.08,
)  # fmt: skip
BOOM_X = -2.0


def _top(y: float) -> float:
    return hulls.profile(STATIONS, y)[1]


def _wing_z(wing: dict, x: float) -> float:
    t = (x - wing["root_x"]) / (wing["tip_x"] - wing["root_x"])
    return wing["root_z"] + (wing["tip_z"] - wing["root_z"]) * t


def build() -> None:
    S = common.new_bm  # noqa: N806
    parts = []

    # --- hull and wings
    bm = S()
    hulls.add_fuselage(bm, STATIONS)
    parts.append(common.solid("hull", bm, "PAINT_PRIMARY"))
    bm = S()
    wings.add_swept_wing(bm, **WING_R)
    parts.append(common.solid("wing_R", bm, "PAINT_PRIMARY", bevel=0.03))
    bm = S()
    wings.add_swept_wing(bm, **WING_L)
    parts.append(common.solid("wing_L", bm, "PAINT_PRIMARY", bevel=0.03))
    bm = S()
    wings.add_fin(bm, 0.3, -2.4, -4.2, _top(-3.0) - 0.1, 0.9, -3.2, -4.4, _top(-3.0) + 1.5, 0.12)
    parts.append(common.solid("tail_fin_R", bm, "PAINT_PRIMARY", bevel=0.02))

    # canopy
    glass, frame = S(), S()
    cockpits.add_canopy(
        glass, frame, [(0.3, 0.14, 0.08), (0.9, 0.32, 0.34), (1.9, 0.28, 0.3), (2.7, 0.12, 0.1)], _top, ribs=[1]
    )  # fmt: skip
    parts.append(common.solid("canopy_glass", glass, "GLASS", bevel=0.0))
    parts.append(common.solid("canopy_frame", frame, "METAL_DARK", bevel=0.012))

    # --- the long gun boom on the port side, with a strut back to the hull
    bm = S()
    wings.add_gun_pod(bm, BOOM_X, -2.6, 4.3, _wing_z(WING_L, BOOM_X) - 0.05, 0.1)
    common.add_box(bm, (1.2, 0.25, 0.14), (BOOM_X * 0.5, -0.4, -0.12), rot=(0.0, 0.0, math.radians(8)))
    parts.append(common.solid("gun_boom_L", bm, "METAL_DARK", bevel=0.015))
    # a short nose gun
    bm = S()
    common.add_cylinder(bm, 0.07, 1.4, (0.25, 4.6, -0.1), "Y", segments=6)
    parts.append(common.solid("nose_gun", bm, "METAL_DARK", bevel=0.01))
    # belly rail
    bm = S()
    common.add_box(bm, (0.18, 1.1, 0.18), (0.3, 1.0, -0.5))
    parts.append(common.solid("missile_rail", bm, "METAL_DARK", bevel=0.015))

    # --- scrap plates and hazard stripes
    bm = S()
    common.add_box(bm, (1.0, 2.4, 0.12), (-0.2, -1.4, _top(-1.4) + 0.1), rot=(0.0, math.radians(5), math.radians(-6)))
    common.add_box(bm, (0.14, 2.0, 0.7), (1.05, -2.0, 0.05), rot=(0.0, 0.0, math.radians(7)))
    common.add_box(bm, (0.7, 1.0, 0.1), (2.3, -1.6, _wing_z(WING_R, 2.3) + 0.1), rot=(0.0, 0.0, math.radians(-8)))
    parts.append(common.solid("scrap_plates", bm, "PAINT_SECONDARY", bevel=0.025))
    bm = S()
    for x0 in (1.7, 2.7):
        greebles.add_panel(bm, x0, -2.0 - (x0 - 1.0) * 0.2, _wing_z(WING_R, x0) + 0.08, 0.35, 1.3)
    parts.append(common.solid("hazard_stripes", bm, "DECAL_HAZARD", bevel=0.0))

    # one spike on the nose
    bm = S()
    common.add_cylinder(bm, 0.1, 1.3, (-0.15, 5.0, 0.0), "Y", radius_end=0.02, segments=5)
    parts.append(common.solid("spikes", bm, "METAL_BARE", bevel=0.0))

    # --- engines: one big nozzle on the hull, a small pod hung off the wide wing
    body, glow = S(), S()
    engines.add_nacelle(body, 0.0, -0.05, -2.4, -4.9, 0.5)
    engines.add_nozzle(body, 0.0, -0.05, -5.4, 0.5, 0.52)
    engines.add_glow_disc(glow, 0.0, -0.05, -5.38, 0.38)
    engines.add_engine_pod(body, glow, 3.0, -0.2, -2.2, -3.9, 0.26)
    parts.append(common.solid("engine", body, "METAL_DARK", bevel=0.03))
    parts.append(common.solid("engine_glow", glow, "EMISSIVE_ENGINE", bevel=0.0))

    # --- greebles
    bm = S()
    greebles.add_vent_row(bm, 0.0, -4.0, _top(-3.2) + 0.08, 3, 0.35, 0.34)
    greebles.add_antenna(bm, -0.5, -2.0, _top(-2.0) + 0.1, 1.0)
    parts.append(common.solid("vents", bm, "METAL_DARK", bevel=0.01))
    bm = S()
    greebles.add_antenna(bm, 3.9, -2.6, _wing_z(WING_R, 3.9) + 0.03, 0.5)
    parts.append(common.solid("antenna", bm, "METAL_BARE", bevel=0.0))

    # --- sockets
    common.socket("primary", 0, (BOOM_X, 4.3, _wing_z(WING_L, BOOM_X) - 0.05))
    common.socket("primary", 1, (0.25, 5.3, -0.1))
    common.socket("secondary", 0, (0.3, 1.6, -0.5))
    common.socket("engine", 0, (0.0, -5.45, -0.05), (0.0, 0.0, math.pi))
    common.socket("engine", 1, (3.0, -4.25, -0.2), (0.0, 0.0, math.pi))
    common.socket("cockpit_cam", 0, (0.0, 0.9, _top(0.9) + 0.15))

    common.add_collision_hull(
        "hull", [p for p in parts if p.name in ("hull", "wing_R", "wing_L", "tail_fin_R")]
    )
