# M2 — Combat Core

**Goal:** design pillar #1, part two. Shooting, getting shot and destroying things feels
great and reads clearly.
**Exit:** owner playtest: "A 1v3 against pirates is fun and readable."

---

### M2-T1 · Damage model & Durability
- **Size:** M · **Depends on:** M1 · **Read:** GDD §7.1, architecture §5.2
- **Do:**
  - `DamageInfo` (amount, type enum Energy/Kinetic/Explosive/Ion, source, hit_point,
    subsystem id).
  - `Durability` component: shield → armor → hull layers, type multipliers from the GDD
    table **as data** (`DamageTable` resource), shield regen after a delay, `Events.ship_damaged`
    and `Events.ship_destroyed`. Ion disables devices/missiles for X s through a status
    effect.
  - Unit tests: every type × layer multiplier, overflow from shield into armor into hull,
    regen delay, and that Ion does no hull damage.
- **Acceptance:** tests pass.
- **Notes from the M1 gate:**
  - Make `Durability` a child node of `Ship` like `PowerSystem` (`ships/power_system.gd`): `Ship`
    ticks it from `_integrate_forces` and exposes it with a getter (`ship.durability()`). Its
    numbers go in `ShipDef` (new "Durability" group, validated in `problems()`) for all three ships.
  - Rock bumps hurt nothing yet (M1-T5). Leave it that way unless the GDD says otherwise; if you
    add collision damage, it goes through `Durability.apply` like everything else.
  - `bug_report.gd`'s `ship_state()` should gain shield/armor/hull so F12 dumps show them.

### M2-T2 · Weapons framework + Pulse Laser + Autocannon
- **Size:** L · **Depends on:** T1 · **Read:** GDD §7.2, architecture §5.2
- **Do:**
  - `WeaponDef` (type, damage, rate, projectile speed, range, spread, energy cost, heat per
    shot, heat capacity, cool rate, VFX/SFX refs).
  - `WeaponSystem`: mounts weapons on `SOCKET_primary_*`, fires in groups, handles energy
    and heat, overheat lockout. Slight gimbal (≤ 3°) toward the lead point when a target is
    locked (gamepad only, set by difficulty later).
  - A pooled `Projectile` manager with shape-cast movement and `Durability.apply`.
  - Pulse Laser + Autocannon defs. Muzzle flash, tracer and impact VFX v0 (shield-hit
    ripple, armor sparks). CC0 SFX.
  - Target dummies in the flight arena (static and moving on rails).
  - Tests: projectile hits a moving dummy at the expected time, heat/overheat, energy draw,
    pool reuse with no leaks after 10 k shots (sim).
- **Acceptance:** tests pass, and a shot sequence of firing at a dummy is in the PR.
- **Notes from the M1 gate:**
  - **Physics layers.** Everything is on layer 1 today, and the chase camera's clearance ray
    (`CameraRig.clearance_mask`) hits layer 1, ignoring only the player's ship. Introduce a layer
    plan here (e.g. 1 world/rocks/gates, 2 ships, 3 dummies/targets) in one place (a constants
    script under `core/`), set the camera mask to the world only, and have projectile shape casts
    query world + ships. Otherwise an enemy behind you yanks the camera in.
  - **Physics interpolation is on.** A pooled projectile (or anything) that is teleported when it
    is reused must call `reset_physics_interpolation()` after moving, or it draws a streak from
    its old position for one frame. Anything drawn from `_process` that follows a ship reads
    `get_global_transform_interpolated()` (architecture §5.1).
  - Weapons spend energy only through `PowerSystem.request` (all or nothing); read the trigger
    from `ship.controls.fire_primary` / `fire_secondary`. Hardpoints:
    `ship.model.get_sockets(&"primary")` is already tier-aware (`SOCKET_primary_2` only at T3).
  - Put the dummies in `data/arenas/flight_test.tres` (`ArenaDef`), not in code, and keep
    `FlightTest.spawn_player()` working for the switcher.
  - **Fire buttons (owner decision, 2026-10-25, see M1-F1):** RT/LT are now throttle/brake. Bind
    `fire_primary` to **A** and `fire_secondary` to **X** on the gamepad, and remove their exemption in
    `test_input_router.gd`. Boost is on A today: move it (L3 click is the suggested home; cruise drive,
    also on L3, has no gameplay until M4) and list the choice under "Design questions". Target-nearest
    leaves X in M2-T3.

### M2-T3 · Targeting, lead indicator & aim assist
- **Size:** M · **Depends on:** T2 · **Read:** GDD §7.3
- **Do:**
  - `Targeting`: target the nearest hostile in the reticle cone, double-tap for nearest
    overall, cycle. Lock state, and loss of lock when out of range or occluded.
  - A pure `Lead.solve(shooter_pos, shooter_vel, target_pos, target_vel, projectile_speed)`
    with unit tests (stationary target, crossing target, unsolvable → fallback).
  - HUD: target brackets (with shape by stance), off-screen edge arrows, the lead indicator,
    and target info (name, distance, shield/armor/hull bars).
  - Aim assist (gamepad): magnetism (bend projectiles ≤ N° toward the lead point) and
    reticle friction (reduced right-stick sensitivity near targets). The strength comes
    from `Settings` and a `DifficultyDef` stub. Mouse gets none by default.
- **Acceptance:** tests pass, and shots of the targeting HUD are in the PR.
- **Notes from the M1 gate:**
  - `InputRouter` already produces `ShipControls.target_cmd` (`NEAREST_HOSTILE`, `NEAREST_ANY`
    on a double-tap within 18 ticks, `CYCLE_SUBSYSTEM`); consume it, don't re-detect taps.
  - Edge arrows: reuse `HudMath.marker_for` / `clamp_to_edge` (they already pin and flip
    off-screen and behind-camera points). Draw in `FlightHud` or a sibling `Control` using the
    same camera.
  - Reticle friction belongs in `InputRouter.look_input()` (the one place aim input is shaped).
    The mouse virtual stick adds up mouse motion while the cursor is captured
    (`InputRouter.mouse_offset()`); "mouse gets none by default" applies to it.
  - The "look at target" camera hold (GDD §6) was deferred from M1-T4 to here: add it to
    `CameraRig` (a static pose function + unit test, like `chase_pose_for`).
  - X becomes secondary fire in M2-T2 (owner decision). Give `target_nearest` (tap / double-tap) a new
    gamepad button and list it under "Design questions"; B is free since M1-F1, but the owner wants to
    keep the option of putting drift back there, so ask before using it.

### M2-T4 · Secondaries & countermeasures
- **Size:** M · **Depends on:** T3 · **Read:** GDD §7.2
- **Do:**
  - Homing Missile (hold to lock 1.2 s with escalating beeps, proportional navigation,
    limited turn rate, can be outrun with boost + drift), and a Rocket Pod (dumb-fire salvo).
    Ammo counts.
  - Countermeasure Flares device: a cooldown, decoy chance per missile, and flare VFX.
  - An incoming missile warning on the HUD + audio for the targeted player.
  - Sims: a missile hits a non-evading target, misses a target that boost-drifts
    perpendicular at the right moment, and flares decoy at the defined rate (statistical
    test, seeded).
- **Acceptance:** sims pass.
- **Done (2026-10-25, see `docs/STATUS.md`):** the arena's ship switcher moved to F2-F4, so the device buttons
  belong to the ship's devices.
- **Notes from the M1 gate:** device slots 1-3 (`ShipControls.device`, keys 1/2/3, D-pad) are
  used by the flight arena's **ship switcher** (`FlightTest._physics_process`). Flares are a
  device, so either keep devices out of `flight_test.tscn` or move the switcher off those buttons
  (e.g. into the F1 overlay) in this card. Don't let one press do both.

### M2-T5 · Basic AI pilot
- **Size:** L · **Depends on:** T3 · **Read:** GDD §8, architecture §5.3
- **Do:**
  - `AIPilot` (outputs `ShipControls`, nothing else) with a utility selector over behaviors:
    Pursue, AttackRun (approach, fire inside range when the lead is aligned, overshoot and
    loop back), BreakOff, Evade (jink + FA-off flip when locked or under fire), and
    UseDevice (flares when a missile is incoming).
  - Tunables in an `AIProfileDef` (reaction time, aim error, aggression, preferred range).
  - Sims: an AI vs a stationary dummy kills it in < 60 s, AI vs AI duels end with a winner
    in < 180 s with no errors, and the AI never collides with the arena's large asteroids more
    than N times per minute.
- **Acceptance:** sims pass, and a shot sequence of an AI dogfight is in the PR.
- **Notes from the M1 gate:**
  - `AIPilot` is a child node of the `Ship` that writes `ship.controls` in `_physics_process`,
    exactly like `ships/player_pilot.gd` (it runs before the physics step, so the value is used
    that tick). Never set velocities directly.
  - Read every speed, turn rate and duration from the ship's `ShipDef` (the M1 sims broke for the
    slow freighter until they did). Use `tests/sim/flight_sim.gd` for spawning and stepping, and
    parameterise over `FlightSim.SHIP_IDS` where it makes sense.
  - Jolt prints a harmless "job system exceeded the maximum number of jobs" warning when many
    bodies are created and freed fast in a sim; it does not fail gdUnit.

- **Done (2026-10-26, see `docs/STATUS.md`):** `AIPilot` + `AIProfileDef` (rookie / standard / ace), sims and a dogfight
  shot sequence. Regroup and Flee are not part of this card (M3). In the arena, F5 calls in a hostile pilot.

### M2-T6 · Destruction, loot & insurance respawn (stub)
- **Size:** M · **Depends on:** T1, T5
- **Do:**
  - Ship destruction: an explosion (flash, flipbook, light, debris chunks from simple
    generated pieces), and the wreck fades.
  - Loot containers spawned from a `LootTableDef` (credits + placeholder materials). Tractor
    pickup when close (equipment slot later; always on for now).
  - Player death → a "Ship destroyed" screen → respawn at the arena start (the insurance
    rules come in M4). Credits/materials show in a debug wallet.
- **Acceptance:** smoke tests pass, and shots of an explosion sequence are in the PR.
- **Notes from the M1 gate:** respawning works like `FlightTest.spawn_player()`: take the old
  ship out of the tree at once (`remove_child` then `queue_free`), then re-bind the camera rig,
  HUD, `DevTools`, speed effects and audio to the new ship, and call `InputRouter.recenter_mouse()`.

- **Done (2026-10-26, see `docs/STATUS.md`):** `DestructionManager` (fireball shader + ring + light + debris + wreck),
  `LootTableDef` / `LootManager` / tractor pickup into a debug wallet in `GameState`, and the `DeathScreen` + arena
  respawn. The "flipbook" is a procedural fireball shader until the art pass (M8). Insurance rules wait for M4.

### M2-T7 · Combat HUD, feedback & encounter test
- **Size:** L · **Depends on:** T2–T6 · **Read:** GDD §7.4, art bible §6–7
- **Do:**
  - Player feedback: hit markers (with a different look for shield vs hull), damage-direction
    indicators, own shield/armor/hull + energy bars, a low-shield alarm, a kill confirmation,
    and camera shake on hits.
  - Placeholder **pirate fighter + interceptor** models: Cinder Clans kit-bash recipes
    (asymmetric, scrap plates) per art bible §2.
  - `world/arenas/combat_test.tscn`: waves of 1, then 2, then 3 pirates (a debug menu lets
    you pick the wave), with a respawn loop.
  - Radio barks v0 (text only on a comms strip): "Breaking left!", "He's on me!", 5 lines per
    behavior, through localization keys.
- **Acceptance:** shots of the HUD in combat in the PR, and all tests pass.
- **Notes from the M1 gate:**
  - `combat_test.tscn` must carry the three M1-T6 scenes (`ui/hud/flight_hud.tscn`,
    `ui/dev/dev_tools.tscn`, `ui/pause/pause_menu.tscn`); copy the wiring from `flight_test.tscn`.
  - Pirate ships are `ShipDef`s, so `test_ship_roster.gd` fails until their ids are in
    `FlightSim.SHIP_IDS`; that also runs every flight sim on them, which is what we want. Their
    `.glb.import` needs the post-import script (`validate_data.py` enforces it).
  - Camera shake on hits: `CameraRig.shake(strength, duration)` exists and is scaled by the
    `camera/shake` setting; nothing calls it yet.
  - Engine glow colour is a constant in `vfx/engine_fx.gd` (blue-white for every ship). Pirates
    should look different: move the colour into `ShipDef` (group "Look") here.

- **Done (2026-10-26, see `docs/STATUS.md`):** `FeedbackHud` / `HitFeedback` / `FeedbackMath`, pirate fighter and
  interceptor (`tools/blender/recipes/ships/pirate_*.py`, engine colour in `ShipDef`), the combat test arena
  (`CombatTest`, `EncounterDirector`, `WaveMenu` on F7) and radio barks (`BarkDirector`, `CommsStrip`).

---

## M2 review gate & playtest checklist
Play the combat test with a gamepad for ~25 minutes:
- [ ] Is shooting satisfying? (sound, hit feedback, explosions)
- [ ] Can you always tell where enemies are and who is shooting you?
- [ ] Does the lead indicator help? Is aim assist too strong or too weak?
- [ ] Are missiles worth using? Can you dodge them with drift and boost?
- [ ] Does the AI feel like pilots, or like drones?
- [ ] Is 1v3 tense but winnable?
- [ ] Laser vs autocannon: do they feel different?
