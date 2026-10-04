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
