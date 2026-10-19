"""canopy_human_light: minimal canopy frame for the cockpit view of Concord light ships.

Brief: role = the metal the pilot sees from inside a light fighter. Silhouette keywords =
two slim A-pillars, a thin roof header, a low dash cowl. Faction cues (Solar Concord) = dark
metal with one warm amber light strip. Size = about 2 m wide around the eye; this is not a ship,
it is a prop that the camera rig attaches to the cockpit camera.

Origin = the pilot's eye, which is where `SOCKET_cockpit_cam_0` of a ship sits. Nose = +Y (Godot
-Z), up = +Z. The frame leaves the middle of the view empty (the HUD sits on a curved plane
there later, art bible 4). There is no glass: a canopy pane would only dim the view.
"""

from mathutils import Vector

from kit import common

ID = "canopy_human_light"
CATEGORY = "props"
TRIANGLE_BUDGET = (100, 2000)
# build.py renders the view from the eye (plus a 3/4 view) instead of the ship contact sheet.
PREVIEW = "eye"
INFO = [
    "Cockpit canopy frame (prop)",
    "Origin = the pilot's eye",
    "Metal only, no glass",
    "Nose = +Y (Godot -Z)",
]


def strut(bm, a, b, thickness: float) -> None:
    """A square-section bar from point `a` to point `b`."""
    start, end = Vector(a), Vector(b)
    direction = end - start
    rot = Vector((0.0, 1.0, 0.0)).rotation_difference(direction.normalized()).to_euler("XYZ")
    common.add_box(bm, (thickness, direction.length, thickness), (start + end) * 0.5, tuple(rot))


def build() -> None:
    S = common.new_bm  # noqa: N806
    parts = []

    # A-pillars: from the dash corner up to the roof header, seen at the edges of the view.
    bm = S()
    strut(bm, (0.98, 1.65, -0.75), (0.62, 0.8, 0.62), 0.09)
    parts += common.solid_pair("a_pillar", bm, "METAL_DARK", bevel=0.012)

    # Roof header joining the pillar tops (just inside the top edge of the view).
    bm = S()
    strut(bm, (-0.62, 0.8, 0.62), (0.62, 0.8, 0.62), 0.08)
    parts.append(common.solid("header", bm, "METAL_DARK", bevel=0.012))

    # Side rails, roof rails and the rear bow: only seen when looking around.
    bm = S()
    strut(bm, (0.98, 1.65, -0.75), (0.95, -0.4, -0.35), 0.08)
    strut(bm, (0.62, 0.8, 0.62), (0.78, -0.4, 0.55), 0.07)
    strut(bm, (0.78, -0.4, 0.55), (0.95, -0.4, -0.35), 0.07)
    parts += common.solid_pair("rail", bm, "METAL_DARK", bevel=0.012)
    bm = S()
    strut(bm, (-0.78, -0.4, 0.55), (0.78, -0.4, 0.55), 0.07)
    parts.append(common.solid("rear_bow", bm, "METAL_DARK", bevel=0.012))

    # Dash cowl: a wedge across the bottom of the view, front edge ~25 degrees below the horizon.
    bm = S()
    common.add_loft(
        bm,
        [
            [(-1.05, y, -1.1), (1.05, y, -1.1), (1.0, y, top), (-1.0, y, top)]
            for y, top in ((0.4, -0.55), (1.2, -0.70), (1.7, -0.78))
        ],
    )
    parts.append(common.solid("dash", bm, "METAL_DARK", bevel=0.02))

    # One warm light strip along the dash's front edge.
    bm = S()
    common.add_box(bm, (1.5, 0.03, 0.02), (0.0, 1.66, -0.77))
    parts.append(common.solid("dash_light", bm, "EMISSIVE_LIGHT", bevel=0.0))
