# STATUS

> Every session updates this file. Keep it short. It's the owner's dashboard and the next
> session's briefing.

## Now
- **Phase:** Planning complete (2026-10-04). Next: **M0 — Foundation**.
- **Next task to start:** `M0-T5` (screenshot harness). T2, T3, T4 and T6 are in review.
- **Owner actions waiting:**
  1. After the M0-T4 PR is merged: turn on branch protection for `main` requiring the
     `check-and-build` check (clicks are in the M0-T4 PR description).
  2. Read `docs/05-lore-primer.md` and `docs/00-decisions.md` "Defaults" whenever
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
| M0-T3 | Test, lint & validation harness | 👀 | PR open |
| M0-T4 | CI: tests + downloadable builds | 👀 | PR open |
| M0-T5 | Screenshot harness | ⬜ | |
| M0-T6 | Blender generator pipeline v0 | 👀 | PR open |
| M0-T7 | Godot model import & tier display | ⬜ | |
| M0-T8 | Owner guides | ⬜ | |

T1 is merged. Parallel-safe: **T5** next (T4 is in review).

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
  - CI needs the full history (`fetch-depth: 0`) so `git describe` sees tags. If the repo has
    no tags the version is the short SHA.
  - Not verified here (no Actions runner in the session): the workflow YAML parses, but the
    setup-godot action, cache and uploads are exercised for the first time by the PR's own CI run.

## Release notes
_(Filled per milestone; release.yml copies the matching section.)_
