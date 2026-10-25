# 03 — Technical Architecture

The rules here exist because **the owner doesn't read code**. The codebase has to stay
understandable to the next AI session, testable without a human, and recoverable when
something goes wrong. Favor boring, explicit and data-driven designs.

## 1. Stack

| Layer | Choice | Notes |
|---|---|---|
| Engine | Godot 4.x stable, version pinned in `.godot-version` (**4.7.2** at planning time) | The CI and the cloud setup script read this file |
| Language | GDScript, **statically typed** | Untyped declarations are errors (project setting) |
| Physics | Jolt, fixed 60 Hz physics ticks | Ships are `RigidBody3D` with a custom integrator |
| Renderer | Mobile renderer (Vulkan) on all platforms | PC gets higher quality presets |
| Tests | gdUnit4 (vendored in `game/addons/gdUnit4`; v6.2.x at planning time, pick the release matching the pinned Godot) | Run headless in CI and in cloud sessions |
| Lint/format | gdtoolkit (`gdlint`, `gdformat`) | Pinned in `tools/requirements.txt` |
| 3D assets | Blender 5.2 LTS as a Python module (`bpy` from PyPI) | Generators live in `tools/blender/` |
| CI | GitHub Actions | Godot install via `chickensoft-games/setup-godot` (GDScript build, `use-dotnet: false`) |

## 2. Repository layout

```
/
├─ CLAUDE.md                 # Rules for every AI session (read first)
├─ README.md
├─ .godot-version            # e.g. 4.x.y — single source of truth
├─ docs/                     # Design, plans, task cards, status, previews
│  └─ previews/              # Generated PNG renders of models (for owner review)
├─ game/                     # Godot project root (project.godot)
│  ├─ addons/                # gdUnit4 (vendored)
│  ├─ autoload/              # Singletons (see §4)
│  ├─ core/                  # Utilities: state machine, pools, math, rng, logging
│  ├─ data/                  # *.tres content: ships, items, factions, systems, missions…
│  │  └─ defs/               # Resource class scripts (ShipDef, WeaponDef, …)
│  ├─ ships/                 # Ship scene, flight controller, components
│  ├─ combat/                # Weapons, projectiles, damage, targeting, subsystems
│  ├─ ai/                    # Pilot AI, squad tactics, encounter director, boss scripts
│  ├─ world/                 # Systems, zones, cruise, jumpgates, stations, traffic
│  ├─ economy/               # Markets, inventory, upgrades, pricing
│  ├─ missions/              # Mission framework, generator, dialogue
│  ├─ ui/                    # HUD, menus, station screens, theme
│  ├─ vfx/  shaders/  audio/
│  ├─ assets/
│  │  ├─ models/             # GENERATED .glb from tools/blender — never hand-edit
│  │  ├─ textures/ audio/ fonts/   # third-party CC0/licensed + generated
│  │  └─ licenses.csv        # one row per third-party asset
│  ├─ localization/          # strings.csv → Godot translations
│  └─ tests/
│     ├─ unit/               # fast logic tests
│     ├─ sim/                # headless simulations (flight, AI, boss, economy)
│     └─ smoke/              # boot every scene N frames, fail on errors
├─ tools/
│  ├─ check.sh               # THE one command: format-check, lint, validate, tests, smoke
│  ├─ screenshot.sh          # renders scenes/sequences to PNG for AI/owner review
│  ├─ validate_data.py       # checks every .tres reference, loc key, license row
│  ├─ balance/               # economy & pacing sims, balance sheet export
│  ├─ blender/               # bpy kit + recipes + build.py (see art bible)
│  └─ cloud/setup.sh         # environment bootstrap for cloud sessions
└─ .github/workflows/        # ci.yml, assets.yml, release.yml
```

`docs/`, `tools/` and other non-game folders sit outside `game/`, so Godot never imports them.

## 3. Core principles

1. **Everything is reproducible from files.** No "click this in the editor" steps. Scenes
   (`.tscn`) and resources (`.tres`) are text, and generated models come from scripts.
2. **Data-driven content.** Ships, items, factions, systems, stations, missions, bosses and
   difficulty are all custom `Resource` classes saved as `.tres`. Adding a weapon means adding
   data, not code. Balancing means editing numbers.
3. **Composition over inheritance.** A ship is a body plus components.
4. **Player and AI are equal.** Both produce the same `ShipControls` struct each tick, which
   feeds the same flight model and weapons. AI can't cheat on physics, and the same tests
   cover both.
5. **One place for each rule.** Stat stacking, damage math and pricing each live in one
   tested function.
6. **Signals for decoupling.** A global `Events` bus carries cross-system notifications
   (`ship_destroyed`, `docked`, `mission_completed`…). Direct references are only for
   parent → child.
7. **No hidden globals beyond the autoloads listed below.**

## 4. Autoloads (singletons)

| Autoload | Responsibility |
|---|---|
| `Events` | Signal bus only, with no state |
| `Game` | Top-level flow (boot → menu → space ↔ station), pause, scene transitions |
| `GameState` | The current save's live data (player profile, wallet, cargo, rep, missions, world state) |
| `SaveSystem` | Serialize `GameState` ⇄ versioned JSON, migrations, slots, Hardcore deletion |
| `Settings` | User settings (graphics, audio, controls, accessibility), saved separately from game saves |
| `Content` | Loads and indexes all `*Def` resources by id (`Content.ship("kestrel")`) |
| `Audio` | Buses, SFX pooling, adaptive music state |
| `InputRouter` | Device detection, glyph set, rebinding, produces player `ShipControls` |
| `Log` | Structured logging and error capture (written to `user://logs` for bug reports) |

## 5. Key systems

### 5.1 Ship
```
Ship (RigidBody3D, custom_integrator = true)
├─ ShipModel (instanced .glb whose root has the `ShipModel` script; sockets → Marker3D;
│              tier parts toggled by name; see art bible 3.1)
├─ FlightController   # ShipControls + ShipDef → forces/torques (FA, drift, boost)
├─ PowerSystem        # energy capacitor, regen, consumers
├─ Durability         # shield/armor/hull, damage intake, regen
├─ WeaponSystem       # hardpoints from sockets, groups (primary/secondary/turret)
├─ DeviceSystem       # active abilities and cooldowns
├─ Targeting          # lock, lead calculation, subsystem cycling
├─ CargoHold
├─ Subsystems (optional, for capitals/bosses)
└─ Pilot              # PlayerPilot | AIPilot → produces ShipControls each tick
```
- `ShipModel` API (`game/ships/ship_model.gd`): `set_tier(tier)` / `tier`, `get_sockets(kind)` (only
  the sockets that exist at the current tier, ordered by index), `set_paint(primary, secondary)`.
  Instantiating a ship `.glb` gives you one directly. Add a new ship by building it with the Blender
  recipe pipeline and setting its `.glb.import` `import_script/path` (check.sh enforces this).
- `ShipDef` holds the flight params, slots, base stats, upgrade tiers, model path and
  per-tier visual part names.
- `FlightController` runs in `_integrate_forces`: it computes the desired velocity and angular
  velocity from the controls, then a PD controller produces thrust clamped by per-axis
  limits. With FA off it skips linear damping.
- Implemented so far (M1-T2, T3): `Ship` (`ships/ship.tscn`), `FlightController` (FA on and off,
  boost), `PowerSystem`, `ShipDef`/`Content`, `PlayerPilot`. The controller is velocity-error based: it
  closes `1 - exp(-gain*dt)` of the error each tick, clamped by per-axis thrust/mass, so it cannot
  overshoot. With FA off the sticks are plain thrust (momentum is kept, capped by `speed_cap`); with
  FA on, speed above the cap blends away in `fa_excess_bleed_time`. Boost drains `PowerSystem` and
  latches off when it runs dry (`Events.boost_depleted`).
- **Camera (M1-T4):** `CameraRig` (`ships/camera_rig.tscn`) is a *sibling* of the player's `Ship`, never
  a child, and follows it with `attach(ship)`. It updates every rendered frame. Chase view: the
  camera sits at `ShipDef.chase_offset`, its position and rotation lag the ship by the `chase_*_lag`
  time constants, it drops back with speed, kicks the FOV by `boost_fov_kick` while `Ship.is_boosting()`, and
  ray-casts from the ship so geometry between them pulls it in (layer mask `clearance_mask`, layer 1).
  Cockpit view: the camera sits on the model's `SOCKET_cockpit_cam_0`, the exterior model hides and
  the `canopy_path` prop (Blender recipe `props/canopy_human_light`, origin = the pilot's eye) shows.
  `V`/R3 (`camera_toggle`) blends between the two in 0.35 s. `shake(strength, duration)` is the one
  shake entry point (scaled by the `camera/shake` setting). Free look is the `camera/free_look`
  setting plus the held `free_look` action: `InputRouter` then zeroes the ship's pitch/yaw and
  hands the stick to the camera (`free_look_vector()`).
- **Flight arena and sense of speed (M1-T5):** `world/arenas/flight_test.tscn` (`FlightTest`) builds
  a zone from one `ArenaDef` (`data/arenas/flight_test.tres`: sky, sun, rock field, gates, start).
  - *Sky:* `SkyBaker` paints a nebula + stars + sun into six `SubViewport`s with
    `shaders/nebula_bake.gdshader` when the arena loads, builds a `Cubemap` and shows it with
    `shaders/nebula_sky.gdshader`. Headless runs have no renderer, so they keep a plain background.
  - *Rocks:* `RockField` is the pure layout (seeded, with a clear lane along the course);
    `AsteroidField` draws it as one `MultiMeshInstance3D` per rock variant (`props/asteroid_a..d`);
    `RockColliders` keeps a pool of 32 static bodies on the rocks nearest the ship, so every rock the
    player can reach is solid (bounce comes from the pool's `PhysicsMaterial`, values in the `ArenaDef`).
  - *Speed effects:* `SpeedFx` scatters dust and boost streaks once; `shaders/space_dust.gdshader`
    keeps them in a box around the camera (wrapping) and stretches them along the ship's velocity.
    `EngineFx` (a child of every `Ship`) adds a glow on each engine socket and a world-space ribbon
    trail. `ShipAudio` plays the engine hum, speed hiss and boost whoosh (placeholder WAVs from
    `tools/audio/make_placeholder_audio.py`).
  - *Physics interpolation* is on (`physics/common/physics_interpolation`). Anything that reads a
    ship's transform in `_process` (camera, effects) must use `get_global_transform_interpolated()`.
- **Flight HUD & playtest tools (M1-T6):** `FlightHud` (`ui/hud/flight_hud.tscn`, `bind(ship)`) draws speed,
  FA/boost state, the energy bar, a nose ring and a flight-path marker where the ship is really going
  (`HudMath` holds the pure rules). `DevTools` (`ui/dev/dev_tools.tscn`, `bind(ship, rig)`) carries the
  tuning overlay (F1 / Select: a slider per flight field of the player's `ShipDef` plus camera lag and FOV,
  applied live, "Copy values" writes `user://tuning/<ship>.tres`) and bug capture (F12 / Back + Start:
  `BugReport` writes a screenshot, `Log.recent_lines(200)` and a JSON state dump to
  `user://bug_reports/<timestamp>/`). `PauseMenu` (`ui/pause/pause_menu.tscn`) pauses and opens that folder.
  Every flight scene adds these three scenes.
- **Sim tests** check: time to stop from max speed, top speed reached, turn rates, drift
  keeps momentum, boost drains energy. All within tolerances defined in the `ShipDef`.

### 5.2 Combat
- **Projectiles** are pooled and moved with shape casts, not physics bodies. Hitscan is used
  for railguns.
- One `DamageInfo` struct (`amount`, `type`, `source`, `hit_point`, `subsystem`), and one
  function `Durability.apply(info)`, whose type multipliers are unit-tested. The multipliers are
  data (`DamageTable`, `data/combat/damage_table.tres`); `Durability` is a child node of `Ship`
  (`ship.durability()`), and emits `Events.ship_damaged` / `Events.ship_destroyed`.
- **Lead calculation** is a pure function (unit-tested with moving targets).
- **Aim assist** lives in `InputRouter` → `ShipControls` (magnetism and friction), never in the
  weapons.

### 5.3 AI
- `AIPilot` runs a **utility AI** for picking behaviors (Pursue, AttackRun, BreakOff, Evade,
  Regroup, UseDevice, Flee). Each behavior outputs `ShipControls`.
- `Squad` coordinates a wing (roles, formation slots, focus target, tactics).
- `EncounterDirector` spends a threat budget (danger × difficulty) to compose and spawn
  encounters.
- `BossController` = phase machine + scripted events + arena controller.
- The difficulty profile (a `DifficultyDef` resource) feeds reaction time, aim error,
  aggression and mechanic flags.

### 5.4 World
- `SystemDef` → list of `ZoneDef`s (position on the system map, type, danger, scene or
  procedural recipe).
- Only **one zone is loaded at a time**. Cruise travel = unload → cruise tunnel scene (with
  an interdiction roll) → load. Zones are ≤ 8 km, so no floating-origin system is needed. A
  debug assert fires if anything goes beyond 10 km from the origin.
- `TrafficSim` (system level, abstract) tracks NPC groups between zones. When a zone loads,
  its current NPCs are spawned.
- Stations: the space-side scene (model, docking trigger, defense turrets, no-fire zone) and
  the `StationScreen` UI scene (hangar view + service menus).

### 5.5 Economy
- `MarketState` per station: stock per item, last update time. `Pricing.price()` is a pure,
  tested function. Catch-up happens lazily on visit.
- `Inventory` / `CargoHold`: typed item stacks, capacity checks.
- `StatCalculator.compute(ship_state)` → final stats. The **only** place stats are combined
  (base → tier → items → Mk/tuning → difficulty). Heavily unit-tested.
- Upgrade recipes (`UpgradeDef`) list costs (credits, materials, blueprint) and effects.

### 5.6 Missions & dialogue
- `MissionTemplate` + `MissionModifier` resources → `MissionGenerator` (seeded RNG) →
  `MissionInstance` (objectives graph, rewards, fail conditions, state saved in `GameState`).
- Objective types: GoTo, Destroy, DestroySubsystem, Escort, Deliver, Survive, Scan, Defend,
  Collect.
- Dialogue: data files with localization keys, speaker ids, choices, conditions and effects.
  Shown in the comms panel (in space) or the bar (in stations).

### 5.7 Save system
- `GameState` → `Dictionary` → JSON, with `"schema_version"`. `SaveSystem.migrate()` upgrades
  old saves step by step. **A save round-trip test runs for every schema change.**
- Autosave on dock. Hardcore: a single save per run, deleted on death.
- Files in `user://saves/` (Steam Cloud friendly later).

### 5.8 Localization
- All player-facing text is `tr("KEY")`. Keys live in `game/localization/strings.csv`.
- `tools/validate_data.py` fails CI if a UI scene or script has a hardcoded string literal
  in a Label/Button text, or if a key is missing.

### 5.9 Input
- An InputMap action per verb. `InputRouter` handles device switching (glyphs update live),
  deadzones and response curves, and rebinding saved in `Settings`.
- `ShipControls` is the only thing gameplay reads, which keeps a later touch layer cheap.
- Mouse flight is a virtual joystick around the screen centre (deadzone ring, max radius). Flight
  scenes capture the cursor, which then stays at the centre, so `InputRouter` adds up mouse motion
  into the stick instead (held at the max radius; recentred on a gamepad switch and on respawn via
  `recenter_mouse()`). The HUD draws the ring and a dot where the stick points.

## 6. Performance budgets

| Item | PC target | Android (later) target |
|---|---|---|
| Frame rate | 60 fps @ 1080p on a GTX 1060-class GPU | 30–60 fps on a mid-range 2023 phone |
| Active ships in combat | ≤ 14 + boss | ≤ 10 + boss |
| Draw calls (combat) | < 600 | < 250 |
| Fighter triangles (LOD0) | 3–8 k | same, with LODs |
| Capital/station triangles | 20–80 k | same, with LODs |
| Texture size | 1–2 K trim sheets | 1 K |
| Projectiles live | ≤ 400 pooled | ≤ 200 |

Asteroid fields use `MultiMeshInstance3D` plus a few physical rocks near the player. A
**perf smoke test** (M9) runs a heavy combat scene headless and reports frame-time stats.

## 7. Testing strategy

Tests are how the owner (a non-coder) can trust the work.

| Layer | What | Where | When |
|---|---|---|---|
| Format + lint | gdformat check, gdlint | `tools/check.sh` | Every commit (CI) |
| Data validation | `.tres` refs resolve, loc keys exist, asset licenses listed, ids unique | `tools/validate_data.py` | Every commit |
| Unit | Damage math, lead calc, pricing, stat stacking, upgrades, save round-trip, mission generator variety | `game/tests/unit` | Every commit |
| Sim | Flight response, AI vs AI dogfights, encounter budgets, boss bot fights, 10-hour economy run | `game/tests/sim` | Every commit (short), nightly (long) |
| Smoke | Boot every scene for 300 frames headless; any error or warning fails the run | `game/tests/smoke` | Every commit |
| Visual | Scripted camera shots → PNGs, attached to the PR for AI + owner review | `tools/screenshot.sh` | When a PR touches visuals |
| Playtest | Owner plays the build with the milestone's checklist | `docs/templates/playtest-report.md` | Each milestone gate |

### Visual capture
Godot's `--headless` mode doesn't render. `tools/screenshot.sh` instead runs Godot under
**Xvfb with Mesa's software Vulkan (lavapipe)**, using Godot's **Movie Maker mode**
(`--write-movie`, with a fixed fps) to capture frames deterministically, however slow the
software renderer is. Claude can view the PNGs to check its own visual work.

Confirmed in M0-T5: lavapipe works in the cloud container and in GitHub Actions (about 1 s
per scene plus ~5 s start-up). Movie Maker always records at the project's 1920×1080.

- `tools/screenshot.sh <scene> [--frames N] [--out prefix]` renders one scene; `--all`
  renders every scene in `game/tests/shots/`. PNGs land in `build/screens/` (git-ignored).
- **Shot scenes** live in `game/tests/shots/`. Each has a `ShotDirector` node and a list of
  `ShotDef` resources (label, frame, camera position, look-at point, fov). The director
  moves the camera on each frame, writes the frame list to a manifest, and quits when it's
  done; the script keeps only those frames as `<scene>_<label>.png`. To get a repeatable
  screenshot of anything new, copy `kestrel_shot.tscn` (3D) or `boot_shot.tscn` (UI), swap
  the content and edit the shots. Use frame numbers of 2 or more so the scene can settle.
- **Compatibility fallback:** if Vulkan can't start, Godot falls back to OpenGL by itself
  (or `--compat` forces it). The script detects this from Godot's log and stamps every PNG
  with a red **COMPAT** label. Compat renders are good for layout and not for lighting or
  materials.
- **Arena perf log:** `bash tools/perf_arena.sh` flies the flight arena on a script under lavapipe and
  prints average/p95/worst frame time, draw calls and triangles. Informative only (a software renderer
  says nothing about a GPU); first reading, M1-T5: ~68 ms/frame at 720p, 45 draw calls, 153 k triangles.
- Self-test: `bash tools/tests/screenshot_test.sh` (`check.sh` runs it). `ci.yml` renders every
  shot scene after the build and uploads them as the `screens-<sha7>` artifact.

## 8. CI/CD (GitHub Actions)

| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml` | PR, push to `main` | Install the pinned Godot → `tools/check.sh` → export Windows + Linux → upload build artifacts → render shot scenes → upload `screens-<sha7>` |
| `assets.yml` | Changes in `tools/blender/**` | Install `bpy` → run all generators → fail if the exported `.glb` files differ from the committed ones, or if any generator errors |
| `release.yml` | Tag `v*` or `playtest-*` | Export → zip → GitHub Release with notes from `docs/STATUS.md` |

The owner gets builds from the PR's **Checks → Artifacts** (each PR) or from **Releases**
(each milestone).

## 9. Cloud session environment

What I checked during planning (2026-10-04) in this cloud environment:

| Need | Status | Action |
|---|---|---|
| Blender (`bpy` 5.2.2 LTS from PyPI, Python 3.13) | ✅ Works: a test ship was generated, exported to .glb and rendered with Cycles CPU in ~4 s | `tools/cloud/setup.sh` creates the venv |
| apt packages (Xvfb, Mesa Vulkan) | ✅ archive.ubuntu.com is reachable | Installed by the setup script |
| Godot binary | ❌ **Blocked**: godotengine.org and GitHub release downloads are denied by the network policy | **Owner action:** in the cloud environment settings, set Network access to Custom and add `github.com`, `objects.githubusercontent.com` and `release-assets.githubusercontent.com` (keep the default package-manager list). Until then, sessions can only test through CI |
| gdUnit4 addon | ✅ `git clone` from GitHub works through the git proxy | Vendored into the repo in M0 |

## 10. Escape hatches
- If GDScript becomes a bottleneck (e.g. projectile or traffic sims), move that one system to
  a GDExtension (C++ or Rust) behind the same interface. This needs an Opus decision at a
  review gate.
- If Mobile-renderer visuals disappoint on PC, consider Forward+ for PC only. That's a
  review-gate decision, because it doubles visual QA.
