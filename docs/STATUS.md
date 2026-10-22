# STATUS

> Every session updates this file. Keep it short. It's the owner's dashboard and the next
> session's briefing.

## Now
- **Phase:** M0 — Foundation: review gate ✅ clean (`docs/reviews/M0.md`); **owner playtest
  waiting**.
- **What to start next:** M1-T6 (`docs/tasks/M1-flight.md`) or M1-T7 once T5 is merged; M1-T1 to T4 are merged, M1-T5 is in review. M1 can run while
  the M0 playtest is pending; fixes from the playtest become cards first.
- **Owner actions waiting:**
  0. Merge the M0 review-gate PR (#9), then **publish the `playtest-M0` release** from
     GitHub's Releases page (`docs/guides/owner-quickstart.md` §5, "Publish a playtest
     release yourself"; sessions can't push tags). When the release run is green, download
     it, play, and tick the checklist at the bottom of `docs/tasks/M0-foundation.md`.
  1. M0-T4 is merged (#6): turn on branch protection for `main` requiring the
     `check-and-build` check (clicks are in the M0-T4 PR description).
  2. Read `docs/05-lore-primer.md` and `docs/00-decisions.md` "Defaults" whenever
     convenient (needed before M6/M7).

## Milestones

| # | Milestone | State | Review | Playtest release |
|---|---|---|---|---|
| M0 | Foundation | 🧪 playtest | ✅ [M0](reviews/M0.md) | `playtest-M0` |
| M1 | Flight | 🔨 | — | — |
| M2 | Combat core | ⬜ | — | — |
| M3 | AI depth & challenge | ⬜ | — | — |
| M4 | World & stations | ⬜ | — | — |
| M5 | Economy & upgrades | ⬜ | — | — |
| M6 | Factions & missions | ⬜ | — | — |
| M7 | Boss & secrets | ⬜ | — | — |
| M8 | Art & audio pass | ⬜ | — | — |
| M9 | Slice polish | ⬜ | — | — |

## Current milestone tasks (M0)

| Card | Title | Depends on | State | PR |
|---|---|---|---|---|
| M0-T1 | Repo skeleton & cloud bootstrap | — | ✅ | #1 |
| M0-T2 | Godot project bootstrap | T1 | ✅ | #2 |
| M0-T3 | Test, lint & validation harness | T2 | ✅ | #5 |
| M0-T4 | CI: tests + downloadable builds | T3 | ✅ | #6 |
| M0-T5 | Screenshot harness | T2 | ✅ | #4 |
| M0-T6 | Blender generator pipeline v0 | T1 | ✅ | #3 |
| M0-T7 | Godot model import & tier display | T3, T5, T6 | ✅ | #7 |
| M0-T8 | Owner guides | T4 | ✅ | #8 |

## M1 tasks (Flight)

| Card | Title | Depends on | State | PR |
|---|---|---|---|---|
| M1-T1 | Input layer & ShipControls | M0 | ✅ | #10 |
| M1-T2 | Ship physics core (FA on) | T1 | ✅ | #11 |
| M1-T3 | Drift (FA off), boost & energy | T2 | ✅ | #12 |
| M1-T4 | Cameras: chase & cockpit | T2, M0-T7 | ✅ | #13 |
| M1-T5 | Flight arena & sense of speed | T2, T4 | ✅ | #15 |
| M1-T6 | Flight HUD v0, tuning overlay & bug capture | T3 | ✅ | #14 |
| M1-T7 | Three ship profiles + ship switcher | T5 | 👀 | #16 |

States: ⬜ not started · 🔨 in progress · 👀 PR open · ✅ merged · ⛔ blocked · 🧪 owner playtest

**Editing this file (to avoid merge conflicts between parallel sessions):** change only your
own task's row, and add notes under your own `- <card id> (date):` bullet in "Notes for the
next session". When merging `main` into your branch, keep every row's most advanced state
and keep all notes bullets from both sides.

## Notes for the next session
- Planning research (2026-10-04): Godot **4.7.2** is the latest stable; gdUnit4 **v6.2.1**;
  `bpy` **5.2.2 LTS** installs from PyPI (Python 3.13) and was verified working headless here
  (generate → export .glb → Cycles render in ~4 s). godotengine.org and GitHub release
  downloads were **blocked** by the cloud network policy at planning time; `git clone` /
  `git ls-remote` to GitHub work.

- M0-T1 (2026-10-04): `bash tools/cloud/setup.sh` works in the cloud env: Godot 4.7.2 download
  from GitHub releases **succeeded** this time, so Godot is available locally (symlinked at
  `~/.local/bin/godot`; make sure `~/.local/bin` is on PATH). `gdtoolkit==4.5.0` is pinned.
  The script is idempotent and never fails on a blocked download.

- M0-T1 merged (PR #1) and the owner has allowlisted the Godot download hosts, so Godot works
  in cloud sessions (`bash tools/cloud/setup.sh`, then `export PATH=$HOME/.local/bin:$PATH`).
- M0-T2 (2026-10-17): `game/project.godot` + nine autoload stubs + `core/boot/boot.tscn`.
  Things the next session must know:
  - `godot --headless --path game --import` and a 120-frame run are clean (0 errors/warnings).
  - Every input action lives in project.godot and is listed in `InputRouter.ACTIONS`. Mouse
    steering (pitch/yaw) is not an action; `InputRouter` will do it in the flight task.
  - `game/assets/licenses.csv.import` forces the `keep` importer. Without it Godot imports the
    CSV as a translation and warns. Any new non-translation CSV under `game/` needs the same.
  - `game/localization/strings.csv` (+ generated `strings.en.translation`) exists with the two
    boot keys; T3 owns the full validator and should add gdUnit tests for `InputRouter.ACTIONS`
    (each has an event) and `Boot.read_version()` once gdUnit4 is vendored.
  - `Log.warn` writes to the log file only (not the engine's warning stream) so that the T3
    smoke test ("fail on any warning in the log") isn't tripped by expected conditions.
  - gdformat/gdlint pass at the default 100-char line length; T3 sets 110 in `gdlintrc`.
- M0-T6 (2026-10-17): Blender pipeline v0 is in. `bash tools/cloud/setup.sh` builds the venv;
  then `tools/blender/.venv/bin/python tools/blender/build.py --recipe ships/test_kestrel`
  (or `--all`, `--no-previews`). Outputs: `game/assets/models/ships/test_kestrel.glb` +
  `.manifest.json`, and the contact sheet `docs/previews/test_kestrel.png` (~20 s on 4 cores).
  Tests: `tools/blender/.venv/bin/python -m unittest discover -s tools/blender/tests -t tools/blender`.
  **M0-T3 must call that test command from `tools/check.sh`** (it doesn't exist yet), and
  M0-T7 should read these conventions (art bible §3.1): nose = Blender +Y (Godot -Z), a socket's
  +Y is its fire/exhaust direction, sockets carry glTF extras `kind`/`index`/`min_tier`
  (`min_tier` 3 on `SOCKET_primary_2`, which only exists on T3 ships), and `<id>-colonly` is the
  convex hull of the base hull, wings and fins only (tier parts don't change collision).
  `T0ONLY_*` is hidden at tier >= 1. The exported `.glb` is byte-identical between runs.
  `assets.yml` compares manifests (not `.glb` bytes) to the committed ones.

- M0-T3 (2026-10-17): `bash tools/check.sh [--quick]` is the one gate (gdformat, gdlint,
  validate_data, python tool tests, Blender pipeline tests, Godot import, gdUnit4 unit + sim,
  smoke); per-step logs in `build/check-logs/`. Things the next session must know:
  - gdUnit4 **v6.2.1** is vendored in `game/addons/gdUnit4` (its own `test/` dir removed) and
    enabled in `project.godot`. Run suites headless with `--ignoreHeadlessMode`; check.sh
    wraps this. gdUnit exit code must be 0 (it returns 101 for warnings such as orphan nodes).
  - New tests: `game/tests/unit/test_*.gd`; sims in `game/tests/sim/` (see `sim_helper.gd`:
    `SimHelper.step_physics` awaits N physics ticks, 60 Hz, so ~1 s per 60 ticks of real time).
    Long sims go in `game/tests/sim/long/`, which `--quick` skips.
  - Smoke: add every new scene to `game/tests/smoke/scenes.txt`. The runner uses an
    `OS.add_logger` catcher, so any `push_error`/`push_warning`/engine warning fails it. Run
    `godot --headless --path game --import` first on a fresh checkout (check.sh does) so the
    global class cache exists.
  - `tools/validate_data.py` (tests: `python3 -m unittest discover -s tools/tests`): licenses.csv
    paths are relative to `game/` (e.g. `assets/audio/x.ogg`); non-commercial/share-alike
    licenses are rejected; `tr("LITERAL")` keys must exist in `strings.csv`.
  - `gdlintrc` sets line length 110 and excludes `addons`; `gdformat` stays at its default 100.
  - Input tests exempt pitch/yaw from needing a keyboard event (mouse-steered) and
    `thrust_up/down` from needing a gamepad event (GDD gives them no button yet); the flight
    task should bind them and drop the exemptions in `test_input_router.gd`.
  - Godot writes `*.import` files next to imported assets (e.g. `test_kestrel.glb.import`);
    they are committed (Godot convention) so `check.sh` leaves the tree clean. Commit new ones.
- M0-T7 (2026-10-17): model import and tier display are in. Things the next session must know:
  - Every `.glb` under `game/assets/models/` needs `import_script/path="res://core/import/model_post_import.gd"`
    in its `.glb.import` (Godot has no per-folder default; `validate_data.py` fails otherwise). Set it for
    each new model, run `godot --headless --path game --import`, commit the `.import`.
  - The rules live in `core/import/model_import_rules.gd` (unit tested; the hook is a thin shell).
    Metadata names are in art bible 3.1. Role materials map to `game/shaders/materials/*.tres`
    (placeholders; edit those, no reimport needed). Faction paint is `shaders/faction_paint.gdshader`
    with per-ship *instance* uniforms `primary_color`/`secondary_color`, set by `ShipModel.set_paint()`.
  - Godot builds a trimesh from `-colonly`; the rules swap it for a convex hull (a trimesh can't sit on a
    `RigidBody3D`). The `Collision` StaticBody3D sits inside the model; the Ship scene (M1) should
    move/replace it with its own collision setup.
  - `ShipModel` is the script on the root of a ship `.glb`: `set_tier`, `get_sockets(kind)` (tier-aware),
    `set_paint`. Tier names are `TIER_NAME_0..3` in strings.csv (placeholders: Stock, Armored, Boosted,
    Elite).
  - Boot scene is now a 3D showcase (turntable Kestrel, tier changes every 3 s). Shot scenes:
    `boot_shot` (one PNG per tier), `kestrel_shot` (tier 3), `tiers_shot` (T0-T3 line-up).
  - Added gdUnit tests for `ShotDirector`'s static helpers (the T5 leftover).
  - Gotcha: Godot does not reimport a model when only the *post-import script* changes. After editing
    `core/import/*.gd` locally, delete `game/.godot/imported/<model>.glb-*` (CI starts clean, so it's fine).
  - `tools/tests/screenshot_test.sh` now checks the COMPAT stamp on a static UI scene
    (`tests/shots/harness_shot.tscn`); the boot scene rotates, so it can't be compared across renderers.
- M0-T5 (2026-10-17): screenshot harness is in (see architecture §7 for usage). Things the next
  session must know:
  - `bash tools/screenshot.sh --all` (or a scene name) → `build/screens/*.png`; read the PNGs.
    Add repeatable shots by copying a scene in `game/tests/shots/` (`ShotDirector` + `ShotDef`).
  - Godot silently falls back to OpenGL when Vulkan can't start; the script spots that in the
    log and watermarks PNGs "COMPAT". Movie Maker ignores `--resolution`: always 1920x1080.
  - `tools/check.sh` runs `tools/tests/screenshot_test.sh` (added at merge time, see below).
    gdUnit tests for `ShotDirector`'s static helpers (`manifest_path_from_args`,
    `shots_on_frame`, `last_frame`) are still missing; they're now part of M0-T7.
  - `screenshots.yml` runs on `game/**` changes and uploads the `screens` artifact. T4's
    `ci.yml` may fold it in later.
  - `kestrel_shot.tscn` shows every tier part at once (the glb has no tier switching yet);
    M0-T7 owns tier display and should update that scene.
  - `tools/requirements.txt` now also pins Pillow (used for the COMPAT stamp).
- Merge-time integration (2026-10-17, planning session), after PRs #4 and #5:
  - `tools/check.sh` now also runs the screenshot self-test as a `screenshots` step (skipped
    with `--quick`; fails if `xvfb-run` is missing, like a missing Godot does). **M0-T4's CI
    must install Xvfb + Mesa Vulkan** (see `.github/workflows/screenshots.yml`) before
    running `check.sh`, and can fold `screenshots.yml` into `ci.yml`.
  - `tools/screenshot.sh` now runs `godot --import` on every run. Before, it only imported a
    never-imported project, so a new `class_name` script (e.g. `ShotDef`) failed to parse
    when the `.godot/` cache already existed.
  - Verified on the merged result: full `check.sh` passes, including all 14 screenshot checks.
  - First CI run of `screenshots.yml` failed because `imgtool.py` ran under `python -I`, which
    hides a Pillow that pip put in the user site (GitHub runners are non-root). Fixed by
    dropping `-I` for it. The self-test's "watermarked" checks also passed when the image tool
    crashed; they now fail. **For M0-T4:** the runner has no `uv`, so `setup.sh` can't build the
    bpy venv there and `check.sh`'s "blender tests" step would be skipped; install uv in
    `ci.yml` (e.g. `astral-sh/setup-uv`) before running `setup.sh`.
- Planning-session check (2026-10-17), on `main` after PRs #2 and #3: `setup.sh` gives all ✅;
  `--import` and a 120-frame boot run print no errors or warnings; gdformat/gdlint are clean;
  the 16 Blender tests pass; rebuilding test_kestrel is byte-identical to the committed `.glb`
  and manifest. The yellow bar floating beside the ship in the 3/4 preview views is the 2 m
  scale bar (preview only, not in the `.glb`). M0-T7's dependencies were corrected to T3 + T5
  + T6, since its tests need gdUnit4 and its screenshot needs shot scenes.

- M0-T4 (2026-10-17): CI and builds. `game/export_presets.cfg` has "Windows Desktop" and
  "Linux" (x86_64, PCK embedded, no signing). `.github/workflows/ci.yml` (PR + push to `main`,
  single job `check-and-build`) runs `tools/check.sh`, then `bash tools/ci/export.sh`, then
  uploads `FireInTheSky-windows-<sha7>` / `FireInTheSky-linux-<sha7>`. `release.yml` (tags
  `v*`, `playtest-*`) does the same, zips, and creates a GitHub Release (`playtest-*` is marked
  pre-release). Things the next session must know:
  - `tools/ci/export.sh` is also runnable locally: it writes `game/version.txt` (git-ignored;
    `git describe --tags --always`), exports both presets to `build/export/`, then boots the
    Linux build headless for 120 frames and requires exit 0, no engine errors/warnings and the
    version in the boot log. Locally it needs the 4.7.2 export templates in
    `~/.local/share/godot/export_templates/4.7.2.stable/` (a 1.2 GB `.tpz` from the Godot
    GitHub release; extract just `version.txt`, `linux_release.x86_64`,
    `windows_release_x86_64*.exe`). `setup.sh` does not install them (too big for every session).
  - Release notes: add a `### <heading mentioning the tag>` subsection under "## Release
    notes" below, e.g. `### M0 Foundation (v0.1.0, playtest-m0)`.
    `tools/ci/release_notes.py <tag>` prints the matching body (whole-word match on the tag);
    with no match the release still publishes with a one-line fallback.
  - The export preset excludes `tests/*` and `addons/*` and includes `version.txt` via
    `include_filter`. A new non-resource runtime file type (json, txt, ...) needs adding to
    `include_filter` in **both** presets or it will be missing from builds.
  - Both workflows share `.github/actions/setup-build` (setup-godot with templates, Xvfb + Mesa
    lavapipe for check.sh's screenshot self-test, gdtoolkit/Pillow, bpy venv). On PRs the
    version/artifact suffix is the PR head's short SHA (Actions checks out a merge commit);
    `BUILD_VERSION=x bash tools/ci/export.sh` overrides the version.
  - CI needs the full history (`fetch-depth: 0`) so `git describe` sees tags. If the repo has
    no tags the version is the short SHA.
  - Not verified here (no Actions runner in the session): the workflow YAML parses, but the
    setup-godot action, cache and uploads are exercised for the first time by the PR's own CI run.

- M0-T8 (2026-10-17): docs only. `docs/guides/owner-quickstart.md` (sessions, PR review,
  artifacts, merge, releases, playtest report) and `docs/guides/blender-mcp-windows.md`
  (Blender 5.2 LTS + `mcp-for-blender` add-on, Claude Desktop/Code, write-back rule).
  Things the next session must know:
  - The MCP choice is `mcp-for-blender` (`ahujasid/blender-mcp`), taken from its README.
    Blender's own site was unreachable from the session, so Blender Lab's official MCP server
    (reported experimental, needs Blender 5.1+) is only mentioned, not documented. The owner
    hasn't tried the Windows steps yet; fix the guide from their first real attempt.
  - The quickstart mentions F12 bug capture and the pause-menu bug-report button, which arrive in
    M1; the guide says so. Update it if that card changes.

- M0 review gate (2026-10-18): clean; report in `docs/reviews/M0.md`. Things the next session
  must know:
  - `check.sh` runs gdUnit with `--fixed-fps 60`: one frame = one physics tick, no waiting on
    the wall clock (sims ~50x faster than real time). The "~1 s per 60 ticks" note under
    M0-T3 no longer applies.
  - `validate_data.py` now rejects hardcoded player-facing text: outside `game/tests/`, scene
    `text`/`tooltip_text`/`placeholder_text` must be empty or a `strings.csv` key, and scripts
    may not assign a string literal to them. Use `tr("KEY")`.
  - `screenshots.yml` is gone: `ci.yml` renders every shot scene after the build and uploads
    `screens-<sha7>`.
  - M1 cards have "Notes from the M0 gate" bullets; read them with the card.
  - Pushing a tag from a cloud session is rejected (only the session branch can be pushed).
    `release.yml` now also runs on `release: published` and uploads to an existing release,
    so the owner publishes playtest releases from the Releases page.

- M1-T1 (2026-10-18): `ShipControls` (`ships/ship_controls.gd`) and the new `InputRouter`.
  Things the next session must know:
  - Gameplay reads `InputRouter.controls` (rebuilt every physics tick, a fresh snapshot; autoloads
    tick before scene nodes, so a ship sees this tick's value). Tests and AI can call
    `InputRouter.build_controls()`. Conventions are in the `ShipControls` header: pitch +1 = nose
    up, yaw +1 = nose right, roll +1 = right wing down; thrust x strafe right, y up, z forward.
    `device` is the device slot 0..3 (D-pad); `interact`, `device` and `target_cmd` are true for
    one tick only. `target_cmd` is `ShipControls.Target`: a double-tap on `target_nearest` within
    18 ticks gives NEAREST_ANY.
  - Shaping: radial deadzone, then `pow(magnitude, exponent)`, then each axis clamped to -1..1 (so
    W+D on a keyboard is full thrust on both axes). It is one function chain
    (`shape_stick` / `shape_axis` / `mouse_stick`); reuse it, don't re-derive it.
  - Settings keys (`controls/stick_deadzone`, `curve_exponent`, `invert_y`, `mouse_flight`,
    `mouse_deadzone`, `mouse_radius`) are read with defaults from `Settings` each tick, so the
    options menu only has to set them. Mouse radii are fractions of viewport height.
  - The mouse stick is ignored until the mouse has moved at least once and while the last device
    was a gamepad. Nothing captures or hides the cursor yet; the flight scene decides that.
  - `Events.input_device_changed(device: int)` carries an `InputRouter.Device` value. Stick drift
    under 0.5 and key/button releases don't count as device changes.
  - Glyphs: `InputRouter.glyph_for(action, device = -1)`; text comes from `GLYPH_*` keys
    (keyboard key names come from Godot). Rebinding UI later should reuse it.
  - Debug scene `core/debug/input_debug.tscn` (in the smoke list); shot `input_debug_shot` renders a
    fixed sample.
  - Vertical thrust on the gamepad is bound to paddle buttons (see the PR's Design questions);
    the NO_GAMEPAD_YET exemption in `test_input_router.gd` is gone.
  - Static functions can't call `tr()`; use `TranslationServer.translate()` there.

- M1-T2 (2026-10-18): ship physics core with flight assist on. Things the next session must know:
  - **`ShipDef`** (`data/defs/ship_def.gd`, extends `ContentDef`) holds mass, per-axis thrust in
    newtons (acceleration = thrust / mass, see `accel_*()`), per-axis speed limits, turn rates and
    angular accelerations (degrees in the file, `*_rad()` helpers), FA gains, and the energy/boost
    params T3 will use (`boost_*`, `energy_*`, unused so far). `problems()` validates a def.
    `data/ships/kestrel.tres` uses the GDD 4.4 light-fighter numbers; it pointed at
    `test_kestrel.glb` until M1-T7 renamed it to `kestrel.glb`.
  - **`Content`** now scans `res://data/` for every `.tres` that is a `ContentDef` and indexes it by
    `kind()` + `id` (`Content.ship(id)`, `Content.ids(kind)`). Invalid defs are logged with
    `Log.error` and skipped, which fails the smoke test. Adding content needs no list to edit.
  - **`FlightController.compute()`** (`ships/flight_controller.gd`) is the single place that turns
    `ShipControls` + `ShipDef` + current local velocities into the next velocities. T3 should extend
    it (FA off, boost); don't add a second path. The sticks command a velocity (throttle x top
    speed per local axis, reverse and strafe have their own speed limits, the whole vector is
    limited to `max_speed`) and a turn rate. Each tick closes `1 - exp(-gain * dt)` of the error,
    clamped by thrust/mass (forward and reverse thrust differ) or angular accel per axis, so it can
    never overshoot.
  - **`Ship`** (`ships/ship.tscn`) is a `RigidBody3D` with `custom_integrator` (Jolt supports it:
    the body integrates position from the velocities we set in `_integrate_forces`), no gravity or
    damping, `can_sleep = false` and `continuous_cd`. It instances the def's model, moves the
    model's `Collision` shapes onto itself and frees the model's StaticBody3D. Set `ship.def` before
    adding it to the tree. A pilot (`PlayerPilot`, an AI, a test) writes `ship.controls` in its
    `_physics_process`, which runs before the physics step, so the value is used the same tick.
  - Sims: `tests/sim/flight_sim.gd` (`FlightSim.spawn/fly/snapshot`) is the helper; add ships to
    `SHIP_IDS` in `test_flight_linear.gd` (T7 parameterises over all three). Gotchas: the first
    physics frame of a gdUnit suite is not a full tick for a freshly added body (the determinism
    test warms up with one frame), and Jolt prints one harmless "job system exceeded the maximum
    number of jobs" warning while many bodies are created and freed in a fast sim; it does not
    fail the run.
  - Shot scenes render at 30 fps against 60 physics ticks (`--fixed-fps 30`), so shot frame N is
    physics tick 2N. `flight_turn_shot` (scripted turn, top-down) is the example. Exported node
    references (`@export var x: Node`) in hand-written `.tscn` shot scenes did not resolve for me;
    the driver uses `@onready` + `$"../Node"` instead.
  - Debug scene `core/debug/flight_debug.tscn`: fly the Kestrel with the mouse/gamepad through a
    field of pylons (rigid chase camera until T4; Esc quits). It is not reachable from the
    boot screen; run it with `godot --path game res://core/debug/flight_debug.tscn`.

- M1-T3 (2026-10-18): drift (FA off), boost and the energy capacitor. Things the next session must know:
  - **`PowerSystem`** (`ships/power_system.gd`, a child node of `Ship`): `energy`, `capacity`,
    `request(amount) -> bool` (all or nothing; a spend restarts the regen delay), `can_afford`,
    `fraction()`, `tick(dt)`. `Ship` ticks it from `_integrate_forces`; read it with `ship.power()`.
    Weapons and devices (M2) must spend through `request`.
  - **`FlightController.compute()`** gained a `boosting` argument and now handles FA off. With FA
    off the sticks are raw thrust (`stick x accel`, no damping); thrust cannot raise the speed past
    the cap (`speed_cap`: `max_speed`, or `boost_max_speed` while boosting) but speed already above
    it is kept. With FA on, speed above the cap is blended away by `limit_excess` (95% gone in
    `ShipDef.fa_excess_bleed_time`, 1 s), which ignores thrust limits on purpose ("smooth blend").
    That also applies when boost ends under FA, so the ship eases from 320 to 180 over ~1 s.
  - **Boost** is decided in `FlightController._update_boost` (instance state): held, not locked,
    and `energy >= boost_min_energy` to start; it drains `boost_energy_per_second * dt` through
    `PowerSystem.request`. Boosting forces full forward throttle and multiplies forward thrust by
    `boost_thrust_multiplier`. When a request fails the boost latches off until the button is
    released (no on/off stutter at an almost-empty capacitor) and `Events.boost_depleted(ship)`
    fires once. `ship.is_boosting()` is the state for HUD/VFX/audio. Pilot releasing the button does
    not emit it.
  - New `ShipDef` fields: `boost_min_energy` and `fa_excess_bleed_time` (in `kestrel.tres`; validated).
  - Sims: `tests/sim/test_flight_drift.gd`, `test_flight_boost.gd` (SHIP_IDS lists only the Kestrel;
    T7 adds the others). Unit: `test_power_system.gd`, `test_flight_controller_drift.gd`.
  - `flight_debug.tscn` now has a second readout line: energy, FA ON/OFF and BOOST. Controls: B /
    Shift = FA off, A / Space = boost.
- M1-T4 (2026-10-18): chase and cockpit cameras. Things the next session must know:
  - **`CameraRig`** (`ships/camera_rig.tscn`, `class_name CameraRig`) is a sibling of the ship:
    `rig.attach(ship)` once the ship is in the tree. It reads `ship.def` (new `ShipDef` "Camera"
    group: `chase_offset`, `chase_look_ahead`, `chase_position_lag`, `chase_rotation_lag`,
    `chase_speed_pullback`, `base_fov`, `boost_fov_kick`, `canopy_path`; validated by `problems()`)
    and updates in `_process`. Tests step it by hand: `rig.set_process(false)` then
    `rig.update(dt)` (see `tests/sim/test_camera_rig_sim.gd`). Each feel rule is a static function
    (`chase_pose_for`, `smooth_weight`, `clearance_step`, `boost_fov`, `shake_amplitude`,
    `free_look_basis`), unit tested. The T6 tuning overlay should edit the `ShipDef` camera fields.
  - **T3 hook (done at merge time):** the FOV kick follows `ship.is_boosting()` (boost held *and*
    powered), in `CameraRig._update_boost`, so it drops when the capacitor runs dry.
  - **Shake:** `rig.shake(strength 0..1, seconds)`; nothing calls it yet (collisions/damage will).
    The `camera/shake` setting (0..1, default 1) scales it for accessibility.
  - **Free look:** new `free_look` action (`Z`, gamepad Paddle 3 = button 18, see the PR's Design
    questions) and setting `camera/free_look` (default off). While held with the setting on,
    `InputRouter.build_controls()` gives the ship no pitch/yaw and the camera uses
    `InputRouter.free_look_vector()`. `InputRouter.look_input()` is the one place that shapes the aim
    input. `flight_debug.tscn` turns the setting on so it can be tried; the options menu (later)
    should expose it.
  - **Cockpit:** the exterior `ShipModel` is hidden while in cockpit view (the canopy prop is shown
    instead and stays fixed to the ship while free look/shake move the camera). Props need
    `import_script/path="res://core/import/model_post_import.gd"` like ships (done for
    `canopy_human_light.glb`). `build.py` recipes may set `PREVIEW = "eye"` and `INFO = [...]` to get
    the eye-view sheet instead of the ship contact sheet.
  - **Clearance mask:** the chase ray hits physics layer 1 (everything for now) and ignores only the
    player's ship. When M2+ adds other ships/projectiles, give world geometry its own layer and set
    `clearance_mask`, so an AI ship behind you doesn't pull the camera in.
  - **Not done / for later:** Godot's physics interpolation is off, so at render rates above 60 Hz
    the ship and camera step with the physics tick (M1-T5, "sense of speed", should decide whether
    to turn on `physics/common/physics_interpolation`). The "look at target" camera hold (GDD 6)
    waits for targeting (M2).
- M1-T5 (2026-10-19): flight arena, sky, rocks, speed effects and placeholder audio. Things the next session must know:
  - **Reaching it:** on the title screen press `interact` (G / gamepad Y) to fly `world/arenas/flight_test.tscn`
    (`Game.go_to_flight_test()`). Since the T6 merge the arena carries T6's flight HUD, `DevTools` (F1 tuning, F12 bug capture)
    and pause menu (Esc / Start; its Quit exits the game), plus its own gate counter and controls line. `spawn_player()` re-binds
    the HUD and tools to the new ship.
  - **`ArenaDef`** (`data/defs/arena_def.gd`, kind `arena`, `data/arenas/flight_test.tres`) holds sky palette, sun/fill/ambient/glow, the rock
    field, collider pool, gates and the start. Tune the look there. `FlightTest.spawn_player(ship_id)` spawns/respawns the player's ship
    (M1-T7's switcher calls it).
  - **Sky:** `SkyBaker` bakes `nebula_bake.gdshader` into a cubemap via six `SubViewport`s (needs a renderer; headless keeps a plain colour).
    The bake takes a frame or two, so shots must be at frame >= 6. `shaders/nebula_sky.gdshader` shows the cubemap.
  - **Rocks:** `RockField` (pure layout, seeded, clear lane along the course), `AsteroidField` (4 MultiMeshes), `RockColliders` (pool of 32 static
    bodies that follows the ship: every rock the player can reach is solid, not just ~30 fixed ones). Bounce comes from `rock_bounce` in the
    `ArenaDef`. Rocks/gates are physics layer 1 (the chase camera ray hits layer 1; move world geometry to its own layer when other ships exist).
  - **Models:** `props/asteroid_a..d` (320 tris each, flat shaded, new `ROCK` role material -> `shaders/materials/rock.tres`) and `props/ring_gate`
    (no collision hull; `RingGate` builds box colliders for the struts and a trigger for the opening).
  - **Speed effects:** `SpeedFx` (dust + boost streaks, one shader, wraps specks around the camera: not GPUParticles), `EngineFx` (child of every
    `Ship`: glow per `SOCKET_engine_*` + ribbon trail), `ShipAudio` (hum, hiss, whoosh). Sounds are synthesised by
    `tools/audio/make_placeholder_audio.py` (CC0, deterministic), imported as PCM WAV (`compress/mode=0`; loop flags are in the `.import`).
  - **Physics interpolation is now ON** (`project.godot`). `CameraRig` and `EngineFx` read `get_global_transform_interpolated()`; the rig and
    trail meshes switch interpolation off for themselves. Do the same for anything that follows a ship from `_process`.
  - **Shots/perf:** `arena_shot` (flight sequence) and `sky_shot` (all six cube faces + the sun). `ShotDirector` now frees the scene and waits
    3 frames before quitting (playing audio otherwise counts as a leaked resource and fails `screenshot.sh`). `bash tools/perf_arena.sh` prints
    frame-time/draw-call stats (software renderer, informative only).
  - Judge in the real build (software rendering differs): bloom around the sun and engines, the colour/brightness of the nebula, how dark rocks
    look on their shadowed side, dust/streak density and brightness, engine trail look, the audio (volumes, pitch range).
- M1-T6 (2026-10-19): flight HUD, tuning overlay, bug capture and a minimal pause menu. Things the next
  session must know:
  - **Add three scenes to every flight scene** (T5's `flight_test.tscn` must): `ui/hud/flight_hud.tscn`
    (inside a `CanvasLayer`; call `bind(ship)`), `ui/dev/dev_tools.tscn` (`bind(ship, rig)`) and
    `ui/pause/pause_menu.tscn`. `core/debug/flight_debug.tscn` shows the wiring. The old debug readout
    (and its `FLIGHT_DEBUG_*` strings and test) is gone; the HUD replaces it.
  - **HUD** (`FlightHud`, `HudMath`): the velocity marker is the flight-path marker (mint ring with wings), the
    nose is a white ring; off-screen or behind-the-camera markers pin to the screen edge, dimmed. It reads
    `ship.controls.fa_off`, `ship.is_boosting()`, `ship.power()` and `Events.boost_depleted` ("BOOST EMPTY"
    for 1.5 s). It only needs a camera, so the cockpit's holo plane can reuse it unchanged.
  - **Tuning overlay** (`ui/dev/tuning_overlay.gd`, params in `tuning_param.gd`): edits the *live* `ShipDef`
    resource. **Opening it pauses the game** (the sticks would otherwise fly the ship while navigating) and
    keeps the camera updating, so FOV/lag changes show at once. `Ship.refresh_from_def()` re-applies mass and
    the capacitor (`PowerSystem.retune`, which keeps the energy held); everything else is read every tick.
    Add a `TuningParam` row (plus `TUNE_*` strings) when a `ShipDef` field should be tunable. The def is shared
    by every ship of that id, which is fine for a dev tool. "Copy values" -> `TuningSnippet.save`.
  - **Hotkeys** (`DevHotkeys`, raw events, not InputMap actions): F1 / Select (on release, so it does not fire
    as the first half of the chord) toggles the overlay, F12 / Back + Start captures a bug report. `Select`
    is also bound to `system_map` (GDD); nothing listens to that yet, revisit when the system map exists.
  - **Bug capture** (`BugReport.capture`): `user://bug_reports/<timestamp>/` with `screenshot.png` (skipped on the
    headless renderer), `log.txt` (the last 200 lines from the new `Log.recent_lines` ring buffer, `LogRing`)
    and `state.json` (scene, version, renderer, input device, the ship's position/velocity/FA/boost/energy,
    all `Settings`). A toast shows the folder path for 7 s.
  - **Pause menu** (`PauseMenu`): Esc / Start pauses; Resume, Open bug report folder, Quit. Back + Start is
    ignored as a pause. This is a stand-in until the game-flow task builds the real menu.
  - Shot scene `hud_shot` (cruise, boost, drift turn, overlay open) with its driver; PNGs are in
    `docs/previews/m1-t6-*.png`.

- M1-T7 (2026-10-21): three player ships and the ship switcher. Things the next session must know:
  - **Ships:** `kestrel` (light fighter, Concord), `bulwark` (heavy fighter, Concord, 18 m) and `drayman` (armed
    freighter, Meridian, 35 m). Recipes in `tools/blender/recipes/ships/`, defs in `data/ships/`. `test_kestrel`
    is now `kestrel` everywhere (recipe, `.glb`, `.import`, manifest, preview, shots, tests). The speeds, accels and turn
    rates are the GDD 4.4 table; mass, thrust, reverse/strafe/vertical limits, energy and boost numbers beyond the
    table are placeholders chosen so the table holds (accel = thrust / mass) and boost can reach its top speed
    before the capacitor empties. Tune them in the overlay, then paste the values into a report.
  - **New `ShipDef` fields** `paint_primary` / `paint_secondary` (group "Look"); `Ship` applies them with
    `ShipModel.set_paint` when it builds the model, so each ship has its faction colours. Recipes may set `PALETTE`
    (role -> hex) to tint the Blender previews the same way (`materials.tint`), and `INFO` for the contact-sheet text.
  - **Switcher:** `ArenaDef.selectable_ship_ids` (max 3) maps device slots 1-3 (keys 1/2/3, D-pad up/right/down) to
    ships; `FlightTest._physics_process` reads `InputRouter.controls.device` and calls `spawn_player()`, which now removes
    the old ship from the tree at once. It respawns at the start of the course. The ship name and the slot glyphs are in
    the arena's top-left text.
  - **Sims:** `FlightSim.SHIP_IDS` / `ship_params()` feed gdUnit parameterised tests (`_test_parameters := ship_params()`);
    every `test_flight_*` sim runs once per ship, and `test_ship_roster_sim.gd` / `test_ship_roster.gd` check
    each ship's model, sockets, collision, paint, engine fx and both cameras. A test fails if a ship def is added without
    being listed in `FlightSim.SHIP_IDS`. Anything that depends on a ship's speed or duration must read it from the def
    (the drift and boost sims did not for the 40 deg/s freighter or its 6 s capacitor).
  - **Shots:** `roster_shot` (the three ships side by side) and `switcher_shot` (the arena with each ship); PNGs are in
    `docs/previews/m1-t7-*.png` next to the three contact sheets (`kestrel.png`, `bulwark.png`, `drayman.png`).
    `ShotDirector` moves its camera one frame late: a scene with one fixed viewpoint should place its own camera
    (see `roster_shot_driver.gd`), or take shots at least 3 frames after a camera move.
  - **Not done / for later:** engine glow colour is still blue-white for every ship (`EngineFx` constants; the Meridian
    freighter should be warm yellow), and the Drayman uses the Concord canopy prop in the cockpit view. Both are
    cosmetic and wait for the art pass or a card in M8.

## Release notes
_(Filled per milestone; release.yml copies the matching section.)_

### M0 Foundation (playtest-M0)
The first playable build. There's no gameplay yet: this checks that the whole pipeline
works, from script-generated ship to a Windows build.

- The boot screen shows the placeholder fighter turning slowly in space. Every 3 seconds it
  switches upgrade tier (Stock → Armored → Boosted → Elite), and the parts change: armour
  plates, then extra engine pods, then longer wings.
- The version number is in the bottom-left corner.
- Windows: unzip and run the `.exe`. SmartScreen warns because the game isn't signed: click
  **More info → Run anyway**. Close the window to quit.
- Playtest checklist: bottom of `docs/tasks/M0-foundation.md`.
