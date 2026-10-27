# M3 — AI Depth, Elites & Difficulty

**Goal:** fix GoF2's predictable AI and lack of challenge. Fights vary, elites force a change
of tactics, and difficulty changes *behavior*.
**Exit:** owner playtest: "Fights feel different from each other; Hard is hard; elites are
memorable."

> Rolling plan: the M2 review gate refines these cards before work starts.

---

### M3-T1 · AI roles
- **Size:** M · **Depends on:** M2 · **Read:** GDD §8.1
- Interceptor, Fighter, Gunship (turret, holds position), Bomber (torpedo runs on the
  player's escort or target), Support (repairs/shields allies). Each role is an
  `AIProfileDef` + loadout + behavior weights. Placeholder pirate gunship + bomber models.
- **Acceptance:** a sim per role shows its signature behavior (e.g. the gunship keeps within
  its range band, the support stays behind allies).
- **Notes from the M2 gate:**
  - Build on `AIPilot` (`ai/ai_pilot.gd`): a child of the `Ship` that writes `ship.controls` each tick, nothing else.
    Behaviors are scored by the pure `AIUtility.scores()` and picked by `AIUtility.select()`; steering maths is in
    `AIMath`. A role is an `AIProfileDef` (`data/ai/`) plus loadout fields on its `ShipDef`; add role weights to
    `AIProfileDef` and feed them into the scores rather than branching on a role name in the pilot.
  - Two pirate ships exist (`pirate_fighter`, `pirate_interceptor`; recipes `tools/blender/recipes/ships/pirate_*.py`).
    New ships go into `FlightSim.SHIP_IDS` (`PIRATE_SHIP_IDS`), so every flight sim runs on them, and their
    `.glb.import` needs the post-import script (`validate_data.py` checks it).
  - Rock colliders exist only around the **player's** ship (`RockColliders`, 32 bodies). An AI far from the player
    sees no rocks and cannot hit them; a gunship holding a position at range needs that fixed or accepted.
  - `AIPilot` holds its guns below 12% energy (`AIMath.hold_fire`); without it energy weapons starve. Keep that for
    every role.
  - `ai_pilot.gd` is ~590 lines. Put new role behaviors in their own scripts (e.g. one `Plan` builder per behavior)
    instead of growing it further.

### M3-T2 · Squad tactics & barks
- **Size:** L · **Depends on:** T1 · **Read:** GDD §8.2
- A `Squad` with a leader and wingmen: formation flight, a shared focus target, and tactics
  (flank, pincer, bait-and-switch, regroup when shields drop, call reinforcements when
  losing). Barks that telegraph intent.
- **Acceptance:** sims: a 3-ship squad's attack angles are spread (not all chasing from
  behind), and regroup triggers correctly. Shots in the PR.
- **Notes from the M2 gate:**
  - Regroup and Flee (architecture 5.3) were left out of M2: add them as `AIUtility.Behavior` values with scores and tests.
  - `AIPilot.forced_target` is how something outside the pilot picks its target (the M2 encounter uses it to send
    every pirate at the player). A `Squad`'s focus target should set it, not reach into the pilot's state.
  - Barks exist: `BarkDirector` (`ai/`) listens to `Events.ai_behavior_changed` and picks `BARK_<BEHAVIOR>_<n>` lines
    from `data/combat/barks.tres` (`BarkDef`, chances per behavior, callsigns), shown on the HUD's `CommsStrip`. Add
    the new tactics as more keys and chances there; intent barks ("flanking left") need a new event, since they
    are not behavior changes.

### M3-T3 · Railgun, Plasma, Torpedo, devices, turrets
- **Size:** L · **Depends on:** M2 · **Read:** GDD §7.2
- Railgun (charge, hitscan), Plasma Caster, Torpedo (can be shot down), devices (Shield
  Booster, EMP Pulse, Repair Nanites), and an auto-turret for ships with a turret slot. All
  defined as data.
- **Acceptance:** unit tests and sims per weapon/device, and every item has VFX/SFX v0.
- **Notes from the M2 gate:**
  - Weapons are `WeaponDef`s fired by `WeaponSystem` through `WeaponMount` (rate and heat) into the pooled
    `ProjectileManager`. A **hitscan railgun** needs a new path (one ray per shot through `SweepCaster`'s mask
    `PhysicsLayers.PROJECTILE_MASK`, then `Durability.apply`) with its own visual; don't fake it with a very fast projectile.
  - Missiles are pooled records in `MissileManager`, not bodies, so a **torpedo that can be shot down** needs
    projectiles to test against torpedoes as well as bodies (a sphere check per torpedo in `ProjectileManager._advance`), or
    a small pooled body on `PhysicsLayers.TARGETS`. Decide and write it into architecture §5.2.
  - Devices: `DeviceDef.Effect` + `DeviceSystem` (slots 1-3, cooldowns; `device_1` is D-pad up / key 1). An EMP can
    reuse the ion status (`Durability.devices_disabled()`), which already blocks devices and secondaries.
  - Any damage change goes through `Durability.apply` and the `DamageTable` (`data/combat/damage_table.tres`).
  - Never use `Packed*Array` exports in a def: they came out empty in exported builds twice in M2. Use typed `Array[...]`.

### M3-T4 · Elite modifiers (mini-bosses)
- **Size:** L · **Depends on:** T1, T3 · **Read:** `02-bosses.md` §3.2
- An `EliteModifierDef` system (stackable stat + behavior packages) with **Shielded, Cloaking,
  Mine-layer, Regenerating**. A callsign generator, an elite HUD frame + comms intro, and
  better loot tables.
- **Acceptance:** a sim per modifier shows the counterplay works (e.g. a flanking attacker
  beats Shielded faster than a head-on one). Shots of each elite.
- **Notes from the M2 gate:** callsigns already exist (`BarkDef.callsign_keys`, used by `EncounterDirector`); grow
  that into the generator. Loot tables are `LootTableDef` (`data/loot/`), dropped by `DestructionManager` from
  `ShipDef.loot_table_id`. The target panel (`TargetHud`) is where an elite frame goes.

### M3-T5 · Difficulty & danger rating
- **Size:** M · **Depends on:** T1 · **Read:** GDD §10
- `DifficultyDef` for Easy/Normal/Hard (reaction, aim error, aggression, aim assist, damage
  taken, elite chance, boss mechanic flags), plus a danger rating 1–5 scaling the encounter
  budget, tiers and modifier count. A settings menu entry.
- **Acceptance:** a sim shows the AI win rate vs a reference bot increases from Easy → Hard.
- **Notes from the M2 gate:**
  - `DifficultyDef` (`data/difficulty/{easy,normal,hard}.tres`) is a stub with only `aim_assist_scale`; the setting
    `game/difficulty` picks one (`AimAssist`). Grow that def; don't add a second one.
  - "Damage taken" must be applied inside `Durability.apply` (the one damage function), not by the weapons.
  - Reaction time, aim error and aggression already live in `AIProfileDef` (rookie / standard / ace): difficulty
    should pick or scale profiles, not duplicate the fields.
  - There is no options menu yet (that is M8-T7). For "a settings menu entry", add a minimal difficulty picker to
    the pause menu or the title screen; don't start the full options menu here.

### M3-T6 · Encounter director
- **Size:** M · **Depends on:** T1, T4, T5 · **Read:** architecture §5.3
- Builds encounters from a threat budget (danger × difficulty): picks roles, squads and
  elites, warps them in with VFX, and adds reinforcements mid-fight. A debug panel shows
  the budget.
- **Acceptance:** unit tests show budgets are respected and composition varies across seeds.
  The combat arena uses the director.
- **Notes from the M2 gate:** an `EncounterDirector` already exists (`combat/encounter_director.gd`, M2-T7): it runs
  fixed waves from an `EncounterDef`/`WaveDef` (`data/encounters/combat_test.tres`), spawns pirates around the player
  (`EncounterMath`) and restarts the wave on respawn. **Extend it** with the budget composer (a pure, unit-tested
  function that turns budget + seed into a `WaveDef`) rather than writing a second director, and keep the combat test's
  F7 wave menu working. Move it to `ai/` (architecture §2) when you touch it.

---

## M3 playtest checklist
- [ ] Do fights at danger 1 vs 3 vs 5 feel different?
- [ ] Do enemy squads feel coordinated?
- [ ] Is each elite modifier understandable *and* fun to counter?
- [ ] Easy / Normal / Hard: is each one right for its name?
- [ ] Which new weapon/device is your favorite? Which is useless?
