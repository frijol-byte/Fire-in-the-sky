"""drayman: placeholder armed freighter (~35 m), a Meridian Guild hauler with teeth.

Brief: role = armed freighter. Silhouette keywords = long exposed spine truss, blunt bridge at
the front, slung cargo pods, four stubby engines, a dorsal turret. Faction cues (Meridian Guild)
= gunmetal frame, industrial yellow/orange stripes, warm yellow engines. Size = 35 m long,
~13 m wide over the cargo pods. Built from boxes and cylinders on purpose: it should look
bolted together and utilitarian, nothing like the sleek Concord darts.

Tiers: T1 armor skirts on the cargo pods, T2 two extra engines on the spine, T3 a second turret
plus side guns (adds primary socket 2). T0ONLY_stock_beacon is the plain dorsal beacon hidden
once upgraded.
"""

import math

from kit import cockpits, common, engines, greebles, hulls

ID = "drayman"
CATEGORY = "ships"
TRIANGLE_BUDGET = (6000, 15000)  # art bible 3.3: freighter/gunship, including tier parts
PALETTE = {
    "PAINT_PRIMARY": "5A5F66",
    "PAINT_SECONDARY": "E2A11E",
    "EMISSIVE_ENGINE": "FFC266",
}
INFO = [
    "Placeholder armed freighter",
    "Meridian Guild: gunmetal, yellow stripes",
    "Length 35 m   Width ~13 m",
    "Budget: freighter 6-15k (art bible 3.3)",
    "Sockets: 2 primary (+1 at T3), 1 secondary,",
    "         1 turret (+1 at T3), 4 engine, cockpit",
    "Tiers: T1 cargo pod armor skirts",
    "       T2 two extra spine engines",
    "       T3 second turret + side guns",
    "Scale bar in views = 2 m",
    "Nose = +Y (Godot -Z)",
]

Y_TAIL, Y_NOSE = -17.0, 18.0
SPINE_TOP = 1.1
POD_Y = (-9.0, -3.0, 3.0)  # centres of the three cargo pod bays
POD_LEN = 5.2
POD_X = 4.6


def _spine_stations() -> list:
    # (y, half_width, z_top, z_bottom): a squat blocky core that narrows into the bridge.
    return [
        (-14.0, 2.1, 1.3, -1.3),
        (-10.0, 2.3, SPINE_TOP, -1.2),
        (2.0, 2.3, SPINE_TOP, -1.2),
        (8.0, 2.0, 1.2, -1.1),
        (12.0, 1.6, 1.5, -0.9),
        (15.0, 1.3, 1.5, -0.6),
    ]


def _cargo_pod(bm, x: float, y: float, length: float, radius: float, ribs: int) -> None:
    """A cylindrical pod with end caps, retaining rings and a frame cradle."""
    common.add_cylinder(bm, radius, length, (x, y, 0.0), "Y", segments=12)
    for i in range(ribs):
        yy = y - length / 2 + (i + 0.5) * length / ribs
        common.add_cylinder(bm, radius * 1.07, 0.18, (x, yy, 0.0), "Y", segments=12)


def build() -> None:
    S = common.new_bm  # noqa: N806
    parts = []

    # --- exposed frame: the long central spine
    stations = _spine_stations()
    bm = S()
    hulls.add_fuselage(bm, stations)
    parts.append(common.solid("hull", bm, "PAINT_PRIMARY", bevel=0.06))

    # truss: two long lower rails and rungs out to the pods
    bm = S()
    for sx in (-1.0, 1.0):
        common.add_box(bm, (0.35, 31.0, 0.35), (sx * 2.0, -1.0, -1.45))
    for y in (-12.0, -6.0, 0.0, 6.0):
        common.add_box(bm, (2 * (POD_X - 0.4), 0.3, 0.3), (0.0, y, -0.2))
    parts.append(common.solid("frame", bm, "METAL_DARK", bevel=0.03))

    # cargo pods (three on each side), the yellow/orange paint is the cargo band
    bm, bands = S(), S()
    for y in POD_Y:
        _cargo_pod(bm, POD_X, y, POD_LEN, 1.7, 3)
        common.add_box(bands, (0.12, 0.8, 2.6), (POD_X + 1.62, y, 0.0))
    parts += common.solid_pair("cargo_pod", bm, "PAINT_PRIMARY", bevel=0.04)
    parts += common.solid_pair("cargo_band", bands, "PAINT_SECONDARY", bevel=0.02)

    # struts holding the pods
    bm = S()
    for y in POD_Y:
        common.add_box(bm, (POD_X - 2.0, 0.35, 0.35), (POD_X / 2 + 0.5, y, 0.4))
        common.add_box(bm, (POD_X - 2.0, 0.35, 0.35), (POD_X / 2 + 0.5, y, -0.6))
    parts += common.solid_pair("pod_strut", bm, "METAL_DARK", bevel=0.02)

    # hazard-striped spine band and bridge stripe
    bm = S()
    for y in (-12.5, -7.0, -1.5, 4.0):
        common.add_box(bm, (4.7, 1.6, 0.06), (0.0, y, SPINE_TOP + 0.03))
    parts.append(common.solid("spine_stripe", bm, "PAINT_SECONDARY", bevel=0.0))

    # bridge: raised blunt block with a wide window band
    bm = S()
    common.add_box(bm, (2.4, 4.2, 1.1), (0.0, 12.0, 1.9))
    parts.append(common.solid("bridge", bm, "PAINT_PRIMARY", bevel=0.05))
    glass, frame = S(), S()
    cockpits.add_canopy(
        glass,
        frame,
        [(12.6, 0.9, 0.3), (13.6, 1.0, 0.5), (14.6, 0.8, 0.3)],
        lambda y: 2.25,
        ribs=[1],
    )
    parts.append(common.solid("canopy_glass", glass, "GLASS", bevel=0.0))
    parts.append(common.solid("canopy_frame", frame, "METAL_DARK", bevel=0.02))

    # engines: four stubby nacelles in a 2x2 block at the tail, plus a heavy mounting plate
    bm, glow = S(), S()
    for x, z in ((1.2, 0.35), (-1.2, 0.35), (1.2, -0.65), (-1.2, -0.65)):
        engines.add_nacelle(bm, x, z, -13.0, -16.0, 0.75)
        engines.add_nozzle(bm, x, z, -16.9, 0.9, 0.7)
        engines.add_glow_disc(glow, x, z, -16.88, 0.52)
    common.add_box(bm, (3.9, 0.6, 3.2), (0.0, -13.0, -0.15))
    parts.append(common.solid("engine", bm, "METAL_DARK", bevel=0.04))
    parts.append(common.solid("engine_glow", glow, "EMISSIVE_ENGINE", bevel=0.0))

    # stabiliser vanes on the pods' rear (flat fins)
    bm = S()
    common.add_box(bm, (0.2, 3.0, 2.6), (POD_X + 1.2, -12.2, 1.1), (0.0, 0.0, 0.0))
    parts += common.solid_pair("tail_vane", bm, "PAINT_PRIMARY", bevel=0.03)

    # weapons: chin guns (primary), a belly missile rail (secondary), dorsal turret
    bm = S()
    for x in (0.9,):
        common.add_cylinder(bm, 0.28, 3.2, (x, 15.6, -0.9), "Y", segments=6)
        common.add_box(bm, (0.7, 1.4, 0.6), (x, 14.2, -0.8))
    parts += common.solid_pair("chin_gun", bm, "METAL_DARK", bevel=0.02)
    bm = S()
    common.add_box(bm, (0.35, 3.0, 0.35), (0.0, 7.0, -1.5))
    common.add_box(bm, (0.2, 0.8, 0.2), (0.0, 8.8, -1.45))
    parts.append(common.solid("missile_rail", bm, "METAL_DARK", bevel=0.02))
    bm = S()
    common.add_cylinder(bm, 0.8, 0.5, (0.0, -3.0, SPINE_TOP + 0.25), "Z", segments=10)
    common.add_box(bm, (0.9, 0.9, 0.5), (0.0, -3.0, SPINE_TOP + 0.75))
    common.add_cylinder(bm, 0.12, 1.8, (0.0, -1.9, SPINE_TOP + 0.8), "Y", segments=6)
    parts.append(common.solid("turret", bm, "METAL_DARK", bevel=0.02))

    # greebles: vents, antennas, nav lights, hull ribs
    bm = S()
    greebles.add_vent_row(bm, 0.0, 6.0, SPINE_TOP + 0.06, 5, 0.5, 1.4)
    for y in range(-14, 10, 2):
        common.add_box(bm, (4.7, 0.12, 0.1), (0.0, float(y) + 0.5, SPINE_TOP + 0.1))
    parts.append(common.solid("vents", bm, "METAL_DARK", bevel=0.01))
    bm = S()
    greebles.add_antenna(bm, 0.8, 9.5, 2.45, 2.0)
    greebles.add_antenna(bm, -1.2, 8.0, SPINE_TOP, 1.2)
    parts.append(common.solid("antenna", bm, "METAL_BARE", bevel=0.0))
    bm = S()
    for sx in (-1.0, 1.0):
        common.add_box(bm, (0.3, 0.3, 0.2), (sx * (POD_X + 1.9), 8.0, 0.0))
        common.add_box(bm, (0.3, 0.3, 0.2), (sx * (POD_X + 1.9), -13.0, 0.0))
    parts.append(common.solid("nav_lights", bm, "EMISSIVE_LIGHT", bevel=0.0))

    bm = S()
    common.add_box(bm, (1.0, 1.0, 0.5), (0.0, 0.0, SPINE_TOP + 0.25))
    common.add_cylinder(bm, 0.05, 1.0, (0.0, 0.0, SPINE_TOP + 1.0), "Z", segments=4)
    common.solid("T0ONLY_stock_beacon", bm, "PAINT_SECONDARY", bevel=0.02)

    # --- T1: armor skirts over the cargo pods
    bm = S()
    for y in POD_Y:
        common.add_box(bm, (0.16, POD_LEN - 1.4, 1.5), (POD_X + 1.82, y, 0.0))
        common.add_box(bm, (0.16, POD_LEN - 1.4, 1.1), (POD_X - 1.82, y, 0.0))
    common.solid_pair("T1_pod_armor", bm, "PAINT_SECONDARY", bevel=0.04)
    bm = S()
    common.add_box(bm, (2.6, 4.0, 0.16), (0.0, -8.0, SPINE_TOP + 0.8))
    common.add_box(bm, (2.4, 3.0, 0.16), (0.0, 5.0, SPINE_TOP + 0.8))
    common.solid("T1_spine_armor", bm, "PAINT_SECONDARY", bevel=0.04)

    # --- T2: two extra engines on the spine flanks
    body, glow = S(), S()
    engines.add_engine_pod(body, glow, 3.0, 0.9, -11.0, -14.5, 0.55)
    common.add_box(body, (1.0, 2.0, 0.5), (2.6, -12.5, 0.6))
    common.solid_pair("T2_spine_engine", body, "METAL_DARK", bevel=0.03)
    common.solid_pair("T2_spine_engine_glow", glow, "EMISSIVE_ENGINE", bevel=0.0)

    # --- T3: second turret and side guns with their own primary socket
    bm = S()
    common.add_cylinder(bm, 0.8, 0.5, (0.0, 5.0, SPINE_TOP + 0.55), "Z", segments=10)
    common.add_box(bm, (0.9, 0.9, 0.5), (0.0, 5.0, SPINE_TOP + 1.05))
    common.add_cylinder(bm, 0.12, 1.8, (0.0, 6.1, SPINE_TOP + 1.1), "Y", segments=6)
    common.solid("T3_turret_fore", bm, "METAL_DARK", bevel=0.02)
    bm = S()
    common.add_cylinder(bm, 0.2, 3.0, (POD_X + 0.6, 7.8, 1.3), "Y", segments=6)
    common.add_box(bm, (0.6, 1.4, 0.5), (POD_X + 0.6, 6.4, 1.3))
    common.solid_pair("T3_side_gun", bm, "METAL_DARK", bevel=0.02)

    # --- sockets (nose = +Y; +Y of a socket is the fire / exhaust direction)
    common.socket("primary", 0, (0.9, 17.3, -0.9))
    common.socket("primary", 1, (-0.9, 17.3, -0.9))
    common.socket("primary", 2, (0.0, 17.3, -0.9), min_tier=3)
    common.socket("secondary", 0, (0.0, 8.6, -1.5))
    common.socket("turret", 0, (0.0, -3.0, SPINE_TOP + 1.0))
    common.socket("turret", 1, (0.0, 5.0, SPINE_TOP + 1.3), min_tier=3)
    for i, (x, z) in enumerate(((1.2, 0.35), (-1.2, 0.35), (1.2, -0.65), (-1.2, -0.65))):
        common.socket("engine", i, (x, -17.4, z), (0.0, 0.0, math.pi))
    common.socket("cockpit_cam", 0, (0.0, 13.3, 2.5))

    common.add_collision_hull(
        "hull", [p for p in parts if p.name in ("hull", "cargo_pod_R", "cargo_pod_L", "bridge")]
    )
