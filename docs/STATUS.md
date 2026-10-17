# STATUS

> Every session updates this file. Keep it short. It's the owner's dashboard and the next
> session's briefing.

## Now
- **Phase:** M0 — Foundation, in progress.
- **What to start next:** any ⬜ task in the table below whose "Depends on" tasks are all ✅.
  Tasks that are ready at the same time can run in parallel sessions.
- **Owner actions waiting:**
  1. Read `docs/05-lore-primer.md` and `docs/00-decisions.md` "Defaults" whenever
     convenient (needed before M6/M7).

## Milestones

| # | Milestone | State | Review | Playtest release |
|---|---|---|---|---|
| M0 | Foundation | 🔨 in progress | — | — |
| M1 | Flight | ⬜ | — | — |
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
| M0-T4 | CI: tests + downloadable builds | T3 | ⬜ | |
| M0-T5 | Screenshot harness | T2 | ✅ | #4 |
| M0-T6 | Blender generator pipeline v0 | T1 | ✅ | #3 |
| M0-T7 | Godot model import & tier display | T3, T5, T6 | ⬜ | |
| M0-T8 | Owner guides | T4 | ⬜ | |

States: ⬜ not started · 🔨 in progress · 👀 PR open · ✅ merged · ⛔ blocked

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
- Planning-session check (2026-10-17), on `main` after PRs #2 and #3: `setup.sh` gives all ✅;
  `--import` and a 120-frame boot run print no errors or warnings; gdformat/gdlint are clean;
  the 16 Blender tests pass; rebuilding test_kestrel is byte-identical to the committed `.glb`
  and manifest. The yellow bar floating beside the ship in the 3/4 preview views is the 2 m
  scale bar (preview only, not in the `.glb`). M0-T7's dependencies were corrected to T3 + T5
  + T6, since its tests need gdUnit4 and its screenshot needs shot scenes.

## Release notes
_(Filled per milestone; release.yml copies the matching section.)_
