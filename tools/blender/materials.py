"""Role materials (art bible 3.2). Blender material *names* map to Godot shader materials in
the post-import script (M0-T7); the colors here are only a neutral stand-in for previews and
for the exported glTF. Never author a one-off material in a recipe: add a role here."""

import bpy

# name: (srgb hex, metallic, roughness, emission strength, alpha)
ROLES: dict[str, tuple[str, float, float, float, float]] = {
    "PAINT_PRIMARY": ("D6DCE6", 0.15, 0.45, 0.0, 1.0),
    "PAINT_SECONDARY": ("22407C", 0.15, 0.45, 0.0, 1.0),
    "METAL_BARE": ("A9B0BA", 0.9, 0.35, 0.0, 1.0),
    "METAL_DARK": ("2D3138", 0.8, 0.5, 0.0, 1.0),
    "GLASS": ("1C3550", 0.0, 0.05, 0.0, 0.45),
    "EMISSIVE_ENGINE": ("80CCFF", 0.0, 0.5, 8.0, 1.0),
    "EMISSIVE_LIGHT": ("FFE9B3", 0.0, 0.5, 5.0, 1.0),
    "CRYSTAL": ("BFFFF0", 0.0, 0.1, 0.5, 0.6),
    "ROCK": ("7A5F4A", 0.0, 0.95, 0.0, 1.0),
    "DECAL_HAZARD": ("E8B923", 0.0, 0.6, 0.0, 1.0),
}


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear(h: str) -> tuple[float, float, float, float]:
    r, g, b = (int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0)


def get(role: str) -> bpy.types.Material:
    """Return the shared material for a role, creating it on first use."""
    if role not in ROLES:
        raise KeyError(f"unknown material role '{role}' (known: {sorted(ROLES)})")
    mat = bpy.data.materials.get(role)
    if mat is not None:
        return mat
    hex_color, metallic, roughness, emission, alpha = ROLES[role]
    color = hex_to_linear(hex_color)
    mat = bpy.data.materials.new(role)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = color
    return mat
