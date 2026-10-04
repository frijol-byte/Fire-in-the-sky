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
├─ ShipModel (instanced .glb; sockets → Marker3D; tier parts toggled by name)
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
- `ShipDef` holds the flight params, slots, base stats, upgrade tiers, model path and
  per-tier visual part names.
- `FlightController` runs in `_integrate_forces`: it computes the desired velocity and angular
  velocity from the controls, then a PD controller produces thrust clamped by per-axis
  limits. With FA off it skips linear damping.
- **Sim tests** check: time to stop from max speed, top speed reached, turn rates, drift
  keeps momentum, boost drains energy. All within tolerances defined in the `ShipDef`.

### 5.2 Combat
- **Projectiles** are pooled and moved with shape casts, not physics bodies. Hitscan is used
  for railguns.
- One `DamageInfo` struct (`amount`, `type`, `source`, `hit_point`, `subsystem`), and one
  function `Durability.apply(info)`, whose type multipliers are unit-tested.
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
software renderer is. Claude can view the PNGs to check its own visual work. If lavapipe
proves unreliable, the fallback is the Compatibility renderer for layout-only checks (to be
confirmed in M0-T5).

## 8. CI/CD (GitHub Actions)

| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml` | PR, push to `main` | Install the pinned Godot → `tools/check.sh` → export Windows + Linux → upload build artifacts (and screenshots) |
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
