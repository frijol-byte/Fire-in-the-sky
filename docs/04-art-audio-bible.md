# 04 — Art & Audio Bible

**Style: stylized clean PBR.** Crisp hard-surface shapes with bevelled edges, simple
role-based materials, and strong lighting, bloom and colorful skies doing the heavy lifting.
The style plays to what AI-scripted Blender does well (clean geometric forms, modular
kit-bashing, procedural materials) and avoids what it does poorly (organic sculpting,
hand-painted textures).

## 1. Visual principles

1. **Silhouette first.** Every ship role must be recognisable as a silhouette at 1 km. Fighters
   are wedges/darts, gunships are blocky, bombers are wide and heavy, freighters are long
   spines with pods, capital ships are layered slabs.
2. **Faction reads from 3 cues:** shape language, paint palette, engine glow color.
3. **Big shapes, medium detail, small greebles** (roughly 60/30/10). No noise for its own sake.
4. **Lighting sells it.** One strong key light (the system's star), colored rim and fill from
   the nebula, bloom on emissives. Every system has its own palette (§5).
5. **Readability beats realism** in combat: hostiles always get red outline/brackets, and
   projectiles are bright and saturated.

## 2. Faction design languages (placeholders)

| Faction | Shape language | Palette | Engine glow |
|---|---|---|---|
| Solar Concord (navy) | Clean, symmetric, angular wedges, layered armor plates | White/light grey + navy blue + gold trim | Blue-white |
| Meridian Guild (traders) | Bulky, utilitarian, cargo pods, exposed frames | Industrial yellow/orange stripes + gunmetal | Warm yellow |
| Cinder Clans (pirates) | **Asymmetric kit-bash** of human parts, bolted scrap plates, spikes | Rust red, black, hazard stripes, scorch decals | Dirty orange |
| Ithari (alien 1) | **Faceted crystal** forms, radial/tri-symmetry, translucent fins | Pearl white + teal/violet emissive veins | Violet |
| The Hush (mystery) | Smooth impossible geometry: boolean-cut spheres, floating shards | Obsidian black + hairline white light | None (silent) |
| Alien race 2 (backlog) | Brutalist slabs, heavy and armored | Bone + oxide green | Green |

Pirates reuse human kit parts (cheap), and the Ithari faceted look is ideal for procedural
generation.

## 3. Blender pipeline (scripted, the source of truth)

```
tools/blender/
├─ requirements.txt          # bpy==5.2.x (Python 3.13)
├─ build.py                  # CLI: build all | one recipe; export + previews
├─ kit/                      # reusable part generators (Python functions)
│  ├─ hulls.py  wings.py  engines.py  cockpits.py  turrets.py
│  ├─ greebles.py  panels.py  crystal.py (Ithari facets)  station.py
│  └─ common.py              # bevel/weighted-normals, sockets, collision, LOD helpers
├─ materials.py              # role materials (see §3.2)
└─ recipes/
   ├─ ships/<id>.py          # composes kit parts; defines tiers T0–T3 parts
   ├─ stations/<id>.py
   └─ props/<id>.py          # asteroids, drones, wrecks, jumpgate, debris
```

- Run in cloud sessions or CI: `tools/blender/.venv/bin/python tools/blender/build.py --recipe ships/kestrel`
- Output: `game/assets/models/<category>/<id>.glb` plus `docs/previews/<id>.png` (a contact
  sheet with a 3/4 view and front/side/top orthographic views, with a scale figure).
- **Blender MCP (optional, owner's PC):** for live visual iteration. Any change you like
  **must be written back into the recipe script** before the session ends. Models only made
  through MCP don't count.

### 3.1 Naming conventions (exported to Godot)

| Object name | Meaning in Godot |
|---|---|
| `hull`, `wing_L`, … | Normal mesh parts |
| `SOCKET_<kind>_<n>` (Empty) | Becomes `Marker3D`. Kinds: `primary`, `secondary`, `turret`, `engine`, `cockpit_cam`, `dock`, `vfx` |
| `T1_*`, `T2_*`, `T3_*` | Upgrade-tier visual parts. Shown when the ship tier ≥ N |
| `T0ONLY_*` | Parts hidden once upgraded (e.g. a stock nose replaced at T3) |
| `SUB_<name>` | Subsystem mesh. Gets a hitbox and a subsystem component |
| `*-colonly` | Collision-only convex hull (Godot import hint) |
| `LOD` | Godot auto-generates LODs on import; no manual LOD meshes |

Conventions fixed by M0-T6 (`tools/blender/kit/common.py` enforces the names):
- **Axes:** nose = Blender +Y, up = +Z, starboard = +X (glTF export is Y-up, so the nose points
  to Godot -Z). Parts are authored with transforms baked in; mirrored pairs end in `_L`/`_R`.
- **Sockets:** a socket's +Y axis (Godot -Z) is the fire/exhaust direction, so engine sockets are
  turned 180° about Z. Each carries glTF extras `kind`, `index`, `min_tier` (the tier at which
  the socket exists, normally 0).
- **Tiers:** `T#_` parts show at ship tier >= #; `T0ONLY_` parts show only at tier 0.
- **Collision:** one `<name>-colonly` convex hull of the base hull, wings and fins.
What Godot makes of those names (M0-T7; `game/core/import/model_import_rules.gd`, applied by the
post-import hook `model_post_import.gd` that every model's `.glb.import` must name):
- `SOCKET_<kind>_<n>` → `Marker3D` with metadata `kind` (StringName), `index`, `min_tier`.
- `T<n>_*` → metadata `min_tier = n`; `T0ONLY_*` → metadata `max_tier = 0`;
  `SUB_<name>` → metadata `subsystem = <name>`. `ShipModel.set_tier()` toggles visibility.
- `PAINT_*` meshes get `paint = true` and the faction paint shader, whose `primary_color` /
  `secondary_color` are per-ship instance parameters (`ShipModel.set_paint()`).
- `<id>-colonly` → a `Collision` child (`StaticBody3D`) with a convex hull shape.
- Models under `models/ships/` get the `ShipModel` script on their root node.
- Each recipe writes `<id>.manifest.json` beside the `.glb` (triangles per tier, sockets, tier
  parts, bounds); CI fails if it differs from the committed one.

### 3.2 Materials (by role, not by texture)
Material **names** in Blender map to Godot shader materials through a post-import script:

| Blender material | Godot material |
|---|---|
| `PAINT_PRIMARY` / `PAINT_SECONDARY` | Faction paint shader (colors as parameters, so paint jobs are free) |
| `METAL_BARE` / `METAL_DARK` | Shared metal shader + CC0 trim-sheet detail normals |
| `GLASS` | Canopy/window shader |
| `EMISSIVE_ENGINE` / `EMISSIVE_LIGHT` | Glow materials (color from faction) |
| `CRYSTAL` | Ithari translucent faceted shader |
| `DECAL_*` | Hazard stripes, numbers, logos (atlas) |

Panel lines and edge wear come from the shader (triplanar panel noise plus curvature from
baked vertex colors), not hand-painted textures.

### 3.3 Budgets
| Asset | Triangles (LOD0) | Notes |
|---|---|---|
| Fighter | 3–8 k | Including tier parts |
| Freighter/gunship | 6–15 k | |
| Carrier boss | 30–60 k | Subsystems as separate meshes |
| Station | 30–80 k | Modular kit |
| Asteroid | 300–2 k | Several variants, MultiMesh |

### 3.4 Quality bar & review
For every new model, a session writes a short **brief** first (role, silhouette keywords,
faction cues, size), then generates it and **looks at the preview renders itself** (Claude
can read the PNGs) before opening the PR. The owner approves or comments using the previews
in the PR. Use "Changes requested: …" in plain words: "nose too long", "looks like a brick",
"more aggressive".

## 4. Cockpit
- **Minimal canopy frame + holographic HUD** (owner's choice). One canopy frame per faction
  × size class (slice: human light, human heavy/freighter, Ithari = 3 meshes).
- The HUD in cockpit view is the same HUD rendered on a curved holo plane, so there's no
  second HUD layout to maintain.

## 5. Environments & skies

| System | Palette | Key features |
|---|---|---|
| Haldane | Amber/orange nebula, blue-white star | Banded gas giant, ring dust, rusty asteroid belt |
| Ilu'Vash | Teal/violet nebula, white dwarf | Crystal asteroid fields, aurora-like "fire" flickers (mystery) |

- **Skies:** a procedural nebula sky shader (layered 3D noise, star fields, color ramps per
  system), **baked to a cubemap at zone load** for speed. Each zone can tilt or tint it.
- **Planets/gas giants:** shader spheres (bands, atmosphere rim) placed far away.
- **Space dust, distant traffic lights, and occasional comets** for life and sense of speed.
- CC0 HDRIs (Poly Haven) only for station hangar lighting.

## 6. VFX list (slice)
Engine glow + trails, space dust, boost FOV kick + streaks, muzzle flashes, projectile
tracers, shield-hit ripple (hex shader), armor sparks, hull fire/smoke on damaged ships,
explosions (layered flipbooks + light flash + debris chunks), missile smoke trails, flares,
EMP ring, cruise tunnel, jumpgate activation, docking lights, warp-in for reinforcements,
drone shield beams (boss), Hush "sky fire" flicker.

## 7. UI / HUD: minimal modern
- Flat, sparse, thin lines, generous spacing (in the spirit of Everspace 2 / No Man's Sky,
  but our own).
- **Fonts:** open-licensed (OFL), e.g. Inter for body text and a square sci-fi display face
  for headers. Their licenses go into `licenses.csv`.
- **Colors:** white UI with faction accents. Hostile = red + diamond bracket, neutral =
  white + square, friendly = green + circle (**shape + color**, so it's colorblind-safe).
- **Controller-first navigation:** every menu fully usable with a gamepad, with visible focus
  states and button glyphs that switch live with the input device.
- **Scale:** designed at 1920×1080, safe-area aware, minimum text ~18 px at 1080p
  (phone-ready).
- HUD elements: reticle + lead indicator, target brackets + off-screen arrows, shield/armor/
  hull + energy bars, speed + FA/boost state, radar (3D disc or 2D compass, to be decided in
  M2), missile lock warnings, objective marker, comms panel, boss bar.

## 8. Audio direction

### 8.1 Sources & licensing
- **SFX:** CC0 only by default (Kenney, Freesound with the CC0 filter, OpenGameArt CC0).
  Royalty-free commercial packs only with the owner's approval.
- **Music:** licensed royalty-free or CC-BY tracks (credits required). Every track is
  logged in `licenses.csv` with its source URL, license and attribution text.
- Every third-party file gets a row in `game/assets/licenses.csv`, and CI checks this.
  `CREDITS.md` is generated from it.

### 8.2 Adaptive music (Godot `AudioStreamInteractive`)
States: **Explore** (per-system theme) → **Tension** (hostiles detected) → **Combat** →
**Boss** (per boss) → **Station** (calm hangar theme). Transitions happen on musical bars.
After combat ends, a short "victory sting" resolves back to Explore.

### 8.3 Mix & feel
- Buses: Master → Music, SFX (Weapons, Impacts, Engines, UI), Voice/Comms, Ambience.
- Doppler on fly-bys and projectiles. Engine pitch follows thrust. Boost "whoomph".
- Distinct impact sounds for shield vs armor vs hull hits (feedback pillar).
- Sound cues for missile lock (escalating beeps) and low shield.
- **Silence as a tool:** Hush encounters duck all sound to near silence.

## 9. Third-party asset rules
1. CC0 is preferred. CC-BY is OK for music with attribution. Nothing that forbids commercial
   use or adds non-commercial or share-alike terms.
2. Every asset gets a `licenses.csv` row: path, source URL, author, license, attribution text,
   date added.
3. Paid packs only with the owner's explicit approval, noted in the PR.
4. No assets ripped from or imitating GoF2, Everspace or any other game.
