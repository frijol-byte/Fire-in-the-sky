# STATUS

> Every session updates this file. Keep it short. It's the owner's dashboard and the next
> session's briefing.

## Now
- **Phase:** Planning complete (2026-10-04). Next: **M0 — Foundation**.
- **Next task to start:** `M0-T3` (test/lint harness); `M0-T4` (CI) and `M0-T7` (model import)
  follow. T2, T5 and T6 are in review.
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

| Card | Title | State | PR |
|---|---|---|---|
| M0-T1 | Repo skeleton & cloud bootstrap | ✅ | PR #1 |
| M0-T2 | Godot project bootstrap | 👀 | PR open |
| M0-T3 | Test, lint & validation harness | ⬜ | |
| M0-T4 | CI: tests + downloadable builds | ⬜ | |
| M0-T5 | Screenshot harness | 👀 | PR open |
| M0-T6 | Blender generator pipeline v0 | 👀 | PR open |
| M0-T7 | Godot model import & tier display | ⬜ | |
| M0-T8 | Owner guides | ⬜ | |

T1 is merged. Parallel-safe: **T2 ∥ T6**. After T2: **T3 ∥ T5**.

States: ⬜ not started · 🔨 in progress · 👀 PR open · ✅ merged · ⛔ blocked

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

- M0-T5 (2026-10-17): screenshot harness is in (see architecture §7 for usage). Things the next
  session must know:
  - `bash tools/screenshot.sh --all` (or a scene name) → `build/screens/*.png`; read the PNGs.
    Add repeatable shots by copying a scene in `game/tests/shots/` (`ShotDirector` + `ShotDef`).
  - Godot silently falls back to OpenGL when Vulkan can't start; the script spots that in the
    log and watermarks PNGs "COMPAT". Movie Maker ignores `--resolution`: always 1920x1080.
  - **M0-T3 must call `bash tools/tests/screenshot_test.sh` from `tools/check.sh`** (it takes
    about a minute; it needs Godot + Xvfb, so skip with a message when they're missing).
    There are no gdUnit tests for `ShotDirector`'s static helpers yet because gdUnit4 isn't
    vendored; T3 should add them (`manifest_path_from_args`, `shots_on_frame`, `last_frame`).
  - `screenshots.yml` runs on `game/**` changes and uploads the `screens` artifact. T4's
    `ci.yml` may fold it in later.
  - `kestrel_shot.tscn` shows every tier part at once (the glb has no tier switching yet);
    M0-T7 owns tier display and should update that scene.
  - `tools/requirements.txt` now also pins Pillow (used for the COMPAT stamp).

## Release notes
_(Filled per milestone; release.yml copies the matching section.)_
