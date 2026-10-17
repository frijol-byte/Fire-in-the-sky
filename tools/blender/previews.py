"""Contact-sheet renderer: 3/4 view per tier T0-T3 plus front/side/top orthographic views,
neutral studio lighting, Cycles CPU at low samples, with a 2 m scale bar."""

import math
import os
import tempfile

import bpy
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFont

from kit import common

PANEL_W, PANEL_H = 560, 420
SAMPLES = 40
SCALE_BAR_M = 2.0
BG_TOP, BG_BOTTOM = (34, 40, 54), (14, 17, 24)
LABEL = (225, 232, 245)


def _bounds() -> tuple[Vector, Vector]:
    """World-space min/max over every mesh that is visible at the highest tier."""
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in common.mesh_objects():
        if o.name.endswith("-colonly"):
            continue
        for v in o.data.vertices:
            for i in range(3):
                lo[i] = min(lo[i], v.co[i])
                hi[i] = max(hi[i], v.co[i])
    return lo, hi


def _setup_scene() -> bpy.types.Object:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = PANEL_W, PANEL_H
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"

    world = bpy.data.worlds.new("studio")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.32, 0.36, 0.45, 1.0)
    bg.inputs["Strength"].default_value = 0.55
    scene.world = world

    def light(kind: str, name: str, energy: float, loc, color=(1, 1, 1), size=0.0):
        data = bpy.data.lights.new(name, kind)
        data.energy = energy
        data.color = color
        if kind == "SUN":
            data.angle = math.radians(8)
        else:
            data.size = size
        obj = bpy.data.objects.new(name, data)
        obj.location = loc
        direction = Vector((0, 0, 0)) - Vector(loc)
        obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        bpy.context.scene.collection.objects.link(obj)

    light("SUN", "key", 4.5, (14, -18, 22), (1.0, 0.96, 0.9))
    light("AREA", "fill", 900, (-16, -6, 6), (0.65, 0.75, 1.0), 12)
    light("AREA", "rim", 1200, (-8, 18, 10), (0.9, 0.95, 1.0), 8)

    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def _scale_bar_object(lo: Vector, hi: Vector) -> bpy.types.Object:
    """A 2 m bar in the 3/4 views, laid on the ground plane to the ship's right."""
    c = common

    bm = c.new_bm()
    c.add_box(bm, (SCALE_BAR_M, 0.12, 0.12), (0, 0, 0))
    bar = c.solid("scale_bar", bm, "DECAL_HAZARD", bevel=0.0)
    bar.location = Vector((lo.x - 1.2 - SCALE_BAR_M / 2, (lo.y + hi.y) / 2 - 3.0, lo.z - 0.2))
    return bar


def _frame(cam, pos: Vector, target: Vector, ortho: float | None, radius: float, up_top=False):
    cam.location = pos
    if up_top:
        cam.rotation_euler = (0, 0, 0)
    else:
        cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
    data = cam.data
    if ortho is not None:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    else:
        data.type = "PERSP"
        data.lens = 70
        data.sensor_width = 36


def _render(path: str) -> Image.Image:
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return Image.open(path).convert("RGBA")


def _set_tier(tier: int) -> None:
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name != "scale_bar":
            o.hide_render = not common.visible_at_tier(o.name, tier)


def _backdrop() -> Image.Image:
    img = Image.new("RGB", (PANEL_W, PANEL_H))
    px = img.load()
    for y in range(PANEL_H):
        t = y / (PANEL_H - 1)
        row = tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3))
        for x in range(PANEL_W):
            px[x, y] = row
    return img


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    return ImageFont.load_default(size=size)


def _draw_scale_bar(draw: ImageDraw.ImageDraw, px_per_m: float, label_font) -> None:
    x0, y0 = 22, PANEL_H - 26
    x1 = x0 + SCALE_BAR_M * px_per_m
    draw.line([(x0, y0), (x1, y0)], fill=(232, 185, 35), width=3)
    for x in (x0, x1):
        draw.line([(x, y0 - 6), (x, y0 + 6)], fill=(232, 185, 35), width=2)
    draw.text((x1 + 8, y0 - 9), "2 m", fill=(232, 185, 35), font=label_font)


def render_contact_sheet(out_path: str, title: str, info_lines: list[str]) -> None:
    cam = _setup_scene()
    lo, hi = _bounds()
    center = (lo + hi) * 0.5
    radius = (hi - lo).length * 0.5
    size = hi - lo
    fov = 2 * math.atan(18 / 70)  # sensor 36 mm, 70 mm lens
    dist = radius / math.sin(fov / 2) * 0.78
    ortho = max(size.x, size.y, size.z) * 1.12 * (PANEL_W / PANEL_H)

    azimuth, elevation = math.radians(38), math.radians(22)
    dir_to_cam = Vector(
        (math.sin(azimuth) * math.cos(elevation), math.cos(azimuth) * math.cos(elevation), math.sin(elevation))
    )
    bar = _scale_bar_object(lo, hi)
    panels: list[tuple[str, Image.Image]] = []
    tmp = tempfile.mkdtemp()
    for tier in range(common.MAX_TIER + 1):
        _set_tier(tier)
        bar.hide_render = False
        _frame(cam, center + dir_to_cam * dist, center, None, radius)
        panels.append((f"T{tier}", _render(os.path.join(tmp, f"t{tier}.png"))))

    _set_tier(common.MAX_TIER)
    bar.hide_render = True
    ortho_views = (
        ("FRONT", Vector((0, 1, 0)), False),
        ("SIDE", Vector((1, 0, 0)), False),
        ("TOP", Vector((0, 0, 1)), True),
    )
    px_per_m = PANEL_W / ortho
    for name, d, top in ortho_views:
        _frame(cam, center + d * dist, center, ortho, radius, up_top=top)
        panels.append((f"{name} (T3)", _render(os.path.join(tmp, f"{name}.png"))))

    cols, rows = 4, 2
    title_h = 46
    sheet = Image.new("RGB", (cols * PANEL_W, rows * PANEL_H + title_h), (10, 12, 18))
    big, small = _font(26), _font(20)
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 9), title, fill=LABEL, font=big)
    for i, (label, img) in enumerate(panels):
        x, y = (i % cols) * PANEL_W, (i // cols) * PANEL_H + title_h
        tile = _backdrop()
        tile.paste(img, (0, 0), img)
        tdraw = ImageDraw.Draw(tile)
        tdraw.text((14, 10), label, fill=LABEL, font=small)
        if i >= common.MAX_TIER + 1:
            _draw_scale_bar(tdraw, px_per_m, small)
        sheet.paste(tile, (x, y))
    # 8th tile: info text
    info = _backdrop()
    idraw = ImageDraw.Draw(info)
    for n, line in enumerate(info_lines):
        idraw.text((18, 18 + n * 28), line, fill=LABEL, font=small)
    sheet.paste(info, (3 * PANEL_W, PANEL_H + title_h))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path, optimize=True)
