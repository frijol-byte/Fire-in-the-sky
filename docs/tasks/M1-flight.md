# M1 — Flight

**Goal:** design pillar #1, part one. Flying with nothing to shoot is already fun.
**Exit:** owner playtest: "Flying around the asteroid field is fun." Feel is tuned with the
in-game overlay, and the chosen values are saved into the ship data.

---

### M1-T1 · Input layer & ShipControls
- **Size:** M · **Depends on:** M0 · **Read:** GDD §5, architecture §5.9
- **Do:**
  - `ShipControls` (RefCounted, typed fields): `thrust: Vector3` (x strafe, y vertical,
    z forward, each −1..1), `rotate: Vector3` (pitch, yaw, roll −1..1), `boost: bool`,
    `fa_off: bool`, `fire_primary: bool`, `fire_secondary: bool`, `device: int`,
    `target_cmd: int`, `interact: bool`.
  - `InputRouter`: builds `ShipControls` from the InputMap each physics tick. Radial
    deadzone, a response curve (exponent setting), invert-Y setting, and live device
    detection (gamepad vs keyboard/mouse) emitting `Events.input_device_changed`.
  - Mouse flight: a virtual joystick from screen center (deadzone ring, max radius),
    pitch/yaw proportional to offset.
  - Glyph lookup API (`InputRouter.glyph_for(action)`) returning text placeholders for now
    ("RT", "LMB").
  - Unit tests: deadzone/curve math, and mouse virtual-stick mapping.
- **Acceptance:** tests pass, and a debug scene prints controls live (shot in the PR).
- **Notes from the M0 gate:**
  - `InputRouter` already tracks `last_device` in `_input`; extend that rather than adding a
    second detector. Add the typed `input_device_changed` signal to `autoload/events.gd`.
  - Bind `thrust_up/down` on the gamepad (GDD §5 gives them no button yet; pick one and list
    it under "Design questions"), then delete their exemption in
    `game/tests/unit/test_input_router.gd`. Pitch/yaw stay exempt from keyboard events
    (the mouse virtual stick steers them).
  - Glyph texts ("RT", "LMB") are player-facing: put them in `strings.csv` (`GLYPH_*` keys).
    `validate_data.py` now rejects string literals assigned to `.text`.

### M1-T2 · Ship physics core (FA on)
- **Size:** L · **Depends on:** T1 · **Read:** GDD §4, architecture §5.1
- **Do:**
  - `ShipDef` resource: mass, per-axis linear thrust (fwd, rev, lateral, vertical), per-axis
    angular acceleration, max speed, max angular rates, FA gains, energy/boost params, model
    path, slots (placeholder).
  - `Ship` scene: `RigidBody3D` (custom integrator) + `FlightController`. With FA on, a PD
    controller drives the velocity toward the commanded velocity (throttle × max speed in
    local axes) and the angular velocity toward the commanded rates, with thrust and torque
    clamped per axis.
  - `data/ships/kestrel.tres` using GDD §4.4 light-fighter values.
  - **Sim tests** (`tests/sim/flight_*`): reaches max speed within ±3%, stops from max speed
    within the expected time (from thrust/mass ±10%), the turn rate matches the max, no
    oscillation (overshoot < 5%), and the same inputs give the same results (determinism).
- **Acceptance:** sims pass, and a shot sequence (a ship doing a turn) is in the PR.
- **Notes from the M0 gate:**
  - An instanced ship `.glb` contains a `Collision` StaticBody3D with a convex hull (see
    `core/import/model_import_rules.gd`). The `Ship` must move that `CollisionShape3D` under
    its own `RigidBody3D` and free the StaticBody3D, or Jolt sees a static body inside the ship.
  - Put `ShipDef` in `data/defs/ship_def.gd`. `Content` is a stub with `register`/`get_def`;
    add a loader that scans `res://data/` and a `Content.ship(id)` helper, with a unit test.
  - Sims are fast now (`check.sh` runs gdUnit with `--fixed-fps 60`, ~50x real time), so run
    full stop-from-max-speed scenarios, not shortened ones. Copy
    `tests/sim/test_physics_stepping.gd` for the determinism test.
  - Add the `Ship` scene and any debug scene to `tests/smoke/scenes.txt`.

### M1-T3 · Drift (FA off), boost & energy
- **Size:** M · **Depends on:** T2 · **Read:** GDD §4.2–4.3
- **Do:**
  - FA off (hold): no linear damping or velocity matching, so momentum is kept. Rotation
    stays assisted. When FA comes back on, excess speed blends down smoothly over ~1 s.
  - `PowerSystem`: capacitor, regen after a delay, a consumer API (`request(amount) -> bool`).
  - Boost: a thrust multiplier and a raised speed cap while held and powered. When energy
    runs out, boost stops with an audio/visual hook (`Events.boost_depleted`).
  - Sims: a drift turn keeps the velocity vector while the nose rotates 180°, boost raises
    the top speed to the boost max ±3%, and boost drains energy at the defined rate.
- **Acceptance:** sims pass.

### M1-T4 · Cameras: chase & cockpit
- **Size:** M · **Depends on:** T2, M0-T7 · **Read:** GDD §6, art bible §4
- **Do:**
  - Chase camera: offset behind and above, positional + rotational spring lag, an FOV kick
    on boost (+8°), and a small shake API (`CameraRig.shake(strength, duration)`). It avoids
    clipping by pulling in when geometry is between camera and ship.
  - Cockpit camera at `SOCKET_cockpit_cam`, with a minimal canopy-frame mesh (Blender recipe
    `recipes/props/canopy_human_light.py`). The HUD will later sit on a curved plane.
  - R3 / `V` toggles views with a short blend.
  - A free look (hold) on the right stick while the ship keeps flying (settings flag; off by
    default, because the right stick aims).
- **Acceptance:** shots of both views in the PR, and smoke tests pass.
- **Notes from the M0 gate:** `build.py` already handles any category
  (`--recipe props/canopy_human_light` → `game/assets/models/props/`). Every new `.glb` needs
  `import_script/path="res://core/import/model_post_import.gd"` in its `.glb.import`
  (`validate_data.py` enforces it); only `models/ships/` get the `ShipModel` script.

### M1-T5 · Flight arena & sense of speed
- **Size:** L · **Depends on:** T2, T4 · **Read:** art bible §5–6, GDD §4.5
- **Do:**
  - `world/arenas/flight_test.tscn`: a sky v0 (procedural nebula sky shader with a star
    field and amber palette, baked to a cubemap on load), a sun directional light with glow,
    and an asteroid field (MultiMesh of 2 k rocks from 4 generated asteroid variants
    `recipes/props/asteroid_*.py`, plus ~30 physical rocks near the player), and a few ring
    gates to fly through.
  - **Space dust** particles around the camera (velocity-stretched), engine glow + trail
    from `SOCKET_engine_*`, and boost streak lines.
  - Placeholder CC0 audio: engine hum (pitch/volume follow thrust), boost whoosh, wind-like
    dust hiss scaled by speed. Every file gets a `licenses.csv` row.
  - A collision response: bumping asteroids hurts nothing yet but bounces believably (Jolt).
- **Acceptance:** shots from the arena in the PR, and performance logged (avg frame time
  headless with lavapipe is informative only).
- **Notes from the M0 gate:**
  - Asteroid `.glb`s need the post-import script in their `.glb.import` too (see T4's note).
  - `licenses.csv` paths are relative to `game/` (`assets/audio/engine_hum.ogg`), and each
    audio file needs a row and a `CREDITS.md` line. CC0 only, if possible (art bible §9).
  - Lavapipe renders glow and particles differently from a real GPU; say so in the PR and
    ask the owner to judge effects in the build artifact.
  - Add `flight_test.tscn` to `tests/smoke/scenes.txt` and make a shot scene for it.

### M1-T6 · Flight HUD v0, tuning overlay & bug capture
- **Size:** M · **Depends on:** T3 · **Read:** art bible §7
- **Do:**
  - HUD v0 (minimal modern style): speed (m/s), a velocity-vector marker (where you're
    actually going vs. where the nose points, which matters with drift), FA ON/OFF state,
    energy bar, boost state.
  - **Tuning overlay** (Select/F1): sliders for every `ShipDef` flight param plus camera lag
    and FOV, applied live. "Copy values" writes a `.tres` snippet to
    `user://tuning/<ship>.tres` and shows the file path (the owner pastes it into a playtest
    report).
  - **F12 / Back+Start bug capture:** a screenshot, the last 200 log lines, and a JSON state
    dump (scene, ship, position, velocity, settings) into `user://bug_reports/<timestamp>/`.
    The pause menu has an "Open bug report folder" button.
- **Acceptance:** shot of the HUD and overlay in the PR, and a unit test for the
  tuning-snippet writer.
- **Notes from the M0 gate:**
  - `Log` truncates `user://logs/session.log` on every launch and keeps no history in memory.
    Add a ring buffer of the last 200 lines to `Log` (unit-tested) for the bug capture.
  - Every HUD/overlay label goes through `strings.csv` (`validate_data.py` enforces it).
    Numbers formatted into a translated pattern are fine (`tr("HUD_SPEED") % speed`).
  - `docs/guides/owner-quickstart.md` already describes F12 and the pause-menu button. Update
    it if the controls or folder change.

### M1-T7 · Three ship profiles + ship switcher
- **Size:** M · **Depends on:** T5 · **Read:** GDD §4.4, §19, art bible §2–3
- **Do:**
  - Blender recipes for placeholder **heavy fighter** (`bulwark`, ~18 m) and **armed
    freighter** (`drayman`, ~35 m), with sockets and tier parts per M0-T6 conventions. Rename
    `test_kestrel` → `kestrel`. Concord/Meridian shape cues per art bible §2.
  - `data/ships/bulwark.tres`, `drayman.tres` with the GDD §4.4 values.
  - In the flight arena: a ship switcher on D-pad (or 1/2/3 keys) that respawns the player in
    the selected ship.
  - Sims from T2/T3 parameterised over all 3 ships.
- **Acceptance:** sims pass for all ships. A contact sheet of all three ships is in the PR.
- **Notes from the M0 gate:** the rename touches the recipe, the `.glb` + `.glb.import` +
  manifest, `docs/previews/test_kestrel.png`, `core/boot/boot.tscn`, the shot scenes
  (`kestrel_shot`, `tiers_shot`), `tests/unit/test_ship_model.gd`,
  `tools/blender/build.py`'s usage text and `tools/blender/tests/test_pipeline.py`
  (`grep -rn test_kestrel`). If a ship gets a 4th tier, `ShipModel.MAX_TIER` and its
  `@export_range(0, 3)` change together.

---

## M1 review gate & playtest checklist
Play the flight arena with a gamepad for ~20 minutes, then answer:
- [ ] Does turning feel responsive, or floaty/twitchy? (Use the overlay to fix it, then "Copy values")
- [ ] Is drifting with FA off fun? Can you flip around and keep flying the same direction?
- [ ] Does boost feel powerful? Does running out of energy feel fair?
- [ ] Do the three ships feel clearly different?
- [ ] Do you feel the speed? (dust, trails, FOV)
- [ ] Chase vs cockpit: is either uncomfortable?
- [ ] Anything confusing about the HUD?
- [ ] (Optional, 5 min) Mouse + keyboard: does the mouse steer smoothly? The dot near the
      center shows how far you are steering.
- Paste the copied tuning values into the report.
