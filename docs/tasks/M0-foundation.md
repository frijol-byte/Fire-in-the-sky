# M0 — Foundation

**Goal:** every pipeline works before any gameplay exists: the Godot project, tests, lint, CI
builds the owner can download, the Blender generator, model import and screenshots.
**Exit:** the owner downloads a Windows build that shows a script-generated ship rotating in
space, cycling through its upgrade-tier visuals, with a version number on screen.

Card format: **Size** S ≈ small session, M ≈ full session, L ≈ consider splitting.

---

### M0-T1 · Repo skeleton & cloud bootstrap
- **Size:** S · **Depends on:** — · **Read:** `03-tech-architecture.md` §2, §9
- **Do:**
  - Create the folder layout from architecture §2 (use `.gitkeep` for empty folders).
  - `.godot-version` containing `4.7.2` (verify it's still the latest 4.x stable with
    `git ls-remote --tags https://github.com/godotengine/godot.git`).
  - `.gitignore` (`game/.godot/`, `build/`, `tools/blender/.venv/`, `__pycache__/`, `*.blend1`).
    Note: Godot 4 `*.import` sidecar files **are** committed.
  - `.gitattributes`: `* text=auto eol=lf`; binary for `*.glb *.png *.jpg *.ogg *.wav *.ttf *.otf *.exr *.hdr`.
  - `LICENSE`: "Copyright (c) 2026 the project owner. All rights reserved." (decision D9).
  - `game/assets/licenses.csv` with header
    `path,source_url,author,license,attribution,date_added` and an empty `CREDITS.md`.
  - `.github/pull_request_template.md` using the template in `CLAUDE.md`.
  - `tools/cloud/setup.sh`: **idempotent** and safe to re-run. Steps:
    1. apt: `xvfb mesa-vulkan-drivers libvulkan1 libgl1 libxi6 libxrandr2 libxcursor1 libxinerama1 unzip`.
    2. Download Godot `<ver>-stable` Linux x86_64 from GitHub releases into `~/.local/godot/`,
       symlink to `~/.local/bin/godot`. **If the download is blocked**, print a clear message
       naming the hosts to allowlist (`github.com`, `objects.githubusercontent.com`,
       `release-assets.githubusercontent.com`) and continue without failing.
    3. `uv venv -p python3.13 tools/blender/.venv` + install `tools/blender/requirements.txt`
       (`bpy==5.2.2`, `pillow`).
    4. `pip install` `tools/requirements.txt` (gdtoolkit pinned for Godot 4).
    5. Print a summary table: Godot ✅/❌, bpy ✅/❌, Xvfb ✅/❌, gdtoolkit ✅/❌.
- **Acceptance:** `setup.sh` runs twice in a row without errors, and the summary shows bpy,
  Xvfb and gdtoolkit ✅.
- **Owner check:** the PR description includes plain steps for setting the environment's
  setup script to `bash tools/cloud/setup.sh` and for the network allowlist (see `06` §2).

### M0-T2 · Godot project bootstrap
- **Size:** M · **Depends on:** T1 · **Read:** architecture §1, §4, GDD §5
- **Do:**
  - `game/project.godot`: name "Fire in the Sky"; **Mobile** rendering method; **Jolt**
    physics; physics ticks 60; window 1920×1080, stretch `canvas_items` + `expand`; GDScript
    warnings: untyped declarations = **error**, unsafe property/method access = warning.
  - Autoload stubs with typed APIs and doc comments: `Events`, `Game`, `Log`, `Settings`,
    `Content`, `InputRouter`, `GameState`, `SaveSystem`, `Audio`. They can be mostly
    empty, but must have no errors.
  - InputMap actions for every verb in GDD §5 with the default gamepad + keyboard/mouse
    bindings.
  - `game/core/boot/boot.tscn`: dark background, a "FIRE IN THE SKY" title and a version
    label read from `res://version.txt` (or "dev" if missing). `Log` writes to `user://logs/`.
- **Acceptance:** `godot --headless --path game --import` and a 120-frame headless run of
  the boot scene produce **zero** errors or warnings.

### M0-T3 · Test, lint & validation harness
- **Size:** M · **Depends on:** T2 · **Read:** architecture §7
- **Do:**
  - Vendor **gdUnit4** (the release matching Godot 4.7; v6.2.x at planning time) into
    `game/addons/gdUnit4` via `git clone --depth 1 --branch <tag>`, and enable the plugin.
  - Example tests: one unit test (`game/tests/unit/`), and one sim-test pattern
    (`game/tests/sim/`) showing how to step physics N ticks headless deterministically.
  - **Smoke runner** (`game/tests/smoke/`): loads every scene listed in
    `game/tests/smoke/scenes.txt`, runs 300 frames each, and fails on any error or warning in
    the log.
  - `tools/requirements.txt` (gdtoolkit pinned) and `gdlintrc` (line length 110, Godot 4 rules).
  - `tools/validate_data.py`: checks that `licenses.csv` has the right columns and every
    listed file exists, that every file under `game/assets/{textures,audio,fonts}` is
    listed, that every `ext_resource` path in `.tres/.tscn` exists, and that localization
    keys used with `tr("…")` exist in `strings.csv` (create the CSV with `en` column).
  - `tools/check.sh`: runs gdformat `--check`, gdlint, validate_data, gdUnit4 (unit + sim),
    then smoke. Prints a PASS/FAIL table and exits non-zero on failure. Supports
    `--quick` (skips long sims).
- **Acceptance:** `check.sh` passes. The PR shows (in its description) that a deliberately
  failing test makes `check.sh` fail; that change is reverted before merge.

### M0-T4 · CI: tests + downloadable builds
- **Size:** M · **Depends on:** T3 · **Read:** architecture §8
- **Do:**
  - `game/export_presets.cfg` with "Windows Desktop" (x86_64) and "Linux" (x86_64) presets
    (no code signing, no rcedit icon for now).
  - `.github/workflows/ci.yml` on PR and push to `main`: checkout (with tags) → read
    `.godot-version` → `chickensoft-games/setup-godot@v2` (`use-dotnet: false`,
    `include-templates: true`) → install gdtoolkit → `tools/check.sh` → write
    `game/version.txt` from `git describe --tags --always` → export both presets → upload
    artifacts `FireInTheSky-windows-<shortsha>` and `FireInTheSky-linux-<shortsha>`.
  - `.github/workflows/release.yml` on tags `v*` and `playtest-*`: the same build, zipped,
    then a GitHub Release with the release notes taken from the matching `docs/STATUS.md`
    section.
  - Cache the Godot install.
- **Acceptance:** CI is green on the PR and the Windows artifact downloads and runs (the
  session can't run Windows, so test the Linux export headless for 120 frames in CI as a
  proxy).
- **Owner check:** download the Windows artifact from the PR's Checks tab, run it (accepting
  the SmartScreen warning) and see the title + version. Then turn on branch protection for
  `main` requiring the CI check (the PR description gives the clicks).

### M0-T5 · Screenshot harness
- **Size:** M · **Depends on:** T2 · **Read:** architecture §7 "Visual capture"
- **Do:**
  - `tools/screenshot.sh <scene.tscn> [--frames N] [--out build/screens/<name>]` runs Godot
    under `xvfb-run` with Mesa **lavapipe** (`VK_ICD_FILENAMES` → lvp ICD) using Movie Maker
    mode (`--write-movie <out>.png --fixed-fps 30 --quit-after N`). Keep the requested frames
    and delete the rest.
  - **Shot scenes:** `game/tests/shots/` holds scenes with a `ShotDirector` node that lists
    camera transforms and frame numbers to capture. This is how later tasks take repeatable
    screenshots of gameplay.
  - If Vulkan fails, retry automatically with `--rendering-method gl_compatibility` and add
    a "COMPAT" watermark to the PNG.
  - CI: when `game/**` changes, render the shot scenes and upload `screens` as an artifact.
- **Acceptance:** the boot scene renders to PNG both locally and in CI. The session opens and
  describes the PNG in the PR.

### M0-T6 · Blender generator pipeline v0
- **Size:** L (may split: kit+build / previews+manifest) · **Depends on:** T1 · **Read:** art bible §2–3
- **Do:**
  - `tools/blender/requirements.txt` (`bpy==5.2.2`, `pillow`).
  - `kit/common.py`: deterministic part helpers (bevelled box/wedge/cylinder, mirror,
    weighted normals, apply transforms), `socket(kind, n, loc, rot)`, an auto convex-hull
    collision `-colonly`, and naming validation.
  - `kit/hulls.py`, `wings.py`, `engines.py`, `cockpits.py` (canopy frame), `greebles.py`
    (panels, vents, antennae): parametric functions, not hardcoded meshes.
  - `materials.py`: role materials from art bible §3.2.
  - `recipes/ships/test_kestrel.py`: an ~14 m light fighter with sockets (2 primary, 1
    secondary, 2 engine, cockpit_cam) and tier parts `T1_` (armor plates), `T2_` (extra
    engine pods), `T3_` (wing extensions + an extra primary socket).
  - `build.py`: `--recipe <path>` / `--all`. Exports to `game/assets/models/ships/<id>.glb`,
    writes `<id>.manifest.json` (triangle count, sockets, tier parts, bounds), and renders
    `docs/previews/<id>.png`, a contact sheet: 3/4 view per tier T0–T3 + front/side/top
    orthographic views, Cycles CPU at low samples, neutral studio lighting, a 2 m scale bar.
  - `.github/workflows/assets.yml`: on changes in `tools/blender/**`, rebuild everything and
    fail if any generator errors or a manifest differs from the committed one.
- **Acceptance:** the session looks at the contact sheet and confirms it reads as a small
  fighter, with tiers visibly different. The triangle count is within budget (art bible
  §3.3).
- **Owner check:** look at `docs/previews/test_kestrel.png` in the PR. It's a placeholder;
  just say whether the direction (shape language) feels right.

### M0-T7 · Godot model import & tier display
- **Size:** M · **Depends on:** T3 (gdUnit4 for its tests), T5 (shot scenes), T6 · **Read:** art bible §3.1–3.2, architecture §5.1, art bible §3.1 "Conventions fixed by M0-T6"
- **Do:**
  - A post-import script for `game/assets/models/**`: role materials → Godot materials
    (placeholder faction paint shader with `primary_color`/`secondary_color` params),
    `SOCKET_*` → `Marker3D` with `kind`/`index` metadata, `T#_`/`T0ONLY_` parts tagged, `SUB_*`
    metadata, `-colonly` collision kept.
  - `ShipModel` script: `set_tier(tier: int)`, `get_sockets(kind: StringName) -> Array[Marker3D]`.
  - Update the boot scene: test_kestrel slowly rotating against a simple dark-blue sky with a
    key light, changing tier every 3 s, with the tier name shown in a label.
  - Unit tests: socket discovery and tier visibility.
  - Add a shot scene for the boot view, and include the screenshot in the PR.
  - Update `game/tests/shots/kestrel_shot.tscn` so it shows one tier per shot (T0 and T3 at
    least). Today it shows every tier part at once.
  - Left over from M0-T5: gdUnit tests for `ShotDirector`'s static helpers
    (`manifest_path_from_args`, `shots_on_frame`, `last_frame`).
- **Acceptance:** tests pass. The screenshot shows the ship lit and textured with role
  materials.

### M0-T8 · Owner guides (docs only)
- **Size:** S · **Depends on:** T4 · **Read:** `06-ai-workflow.md`
- **Do:**
  - `docs/guides/owner-quickstart.md`: step-by-step (with exact button names) for starting a
    cloud session on this repo with Sonnet, sending the kickoff prompt, finding a PR's
    screenshots and build artifact, merging, finding Releases, and filing a playtest report.
  - `docs/guides/blender-mcp-windows.md`: installing Blender 5.2 LTS on Windows, choosing and
    installing a Blender MCP server/add-on (research the currently recommended, maintained
    option and say which and why), connecting it to Claude Desktop or Claude Code on Windows,
    a first test prompt, the **write-back-to-recipe rule**, and troubleshooting.
- **Acceptance:** the guides are understandable by a non-programmer, with no step that says
  "just configure X" without saying how.

---

## M0 review gate & playtest checklist
- [ ] Opus gate run (`06` §5), `docs/reviews/M0.md` written, `playtest-M0` release published
- [ ] The Windows build starts on the owner's PC
- [ ] The ship rotates and changes visibly through T0 → T3
- [ ] The version number is visible
- [ ] The owner's opinion on the placeholder shape language: ________
