# M4 — World, Travel & Stations

**Goal:** a real place: two star systems, cruise travel with interdictions, a jumpgate,
docking, station menus, traffic, saving, and death rules.
**Exit:** owner playtest: "I can travel between two systems, dock, save, quit and load, and
space feels alive."

> Rolling plan: the M3 review gate refines these cards before work starts.

---

### M4-T1 · World data model & save system
- **Size:** L · **Depends on:** M3 · **Read:** architecture §5.4, §5.7
- `SystemDef`, `ZoneDef`, `StationDef`, `JumpgateDef`. `GameState` (profile, wallet, ship
  state, location, world state). `SaveSystem` with versioned JSON, migrations, 3 slots, and
  autosave.
- **Acceptance:** unit tests: a save round-trip is lossless, migrating a v1 fixture to
  current works, and a corrupt save is rejected gracefully.

### M4-T2 · Zone loading
- **Size:** M · **Depends on:** T1
- Load/unload one zone at a time, with a loading screen and a background loader. Zones are
  scenes or procedural recipes. Bounds assert (10 km).
- **Acceptance:** a smoke test loads every zone. Memory after 20 zone swaps stays within 10%
  of the first load.

### M4-T3 · Cruise drive & interdiction
- **Size:** L · **Depends on:** T2 · **Read:** GDD §12.1
- Select a destination (HUD markers / system map stub), mass-lock check, spool (3 s), a
  cruise tunnel scene (5–15 s) with an interdiction roll from danger → a deep-space
  encounter zone (ambush, distress call, convoy under attack), then drop near the target.
- **Acceptance:** a unit test of the interdiction probability table. Shots of the tunnel.

### M4-T4 · Jumpgates
- **Size:** S · **Depends on:** T3
- A gate model (Blender recipe), an activation sequence, a jump VFX, and a system transition.
- **Acceptance:** a smoke test jumps both ways.

### M4-T5 · Stations (space side) & auto-dock
- **Size:** L · **Depends on:** T2 · **Read:** GDD §13, art bible §2–3
- A human station modular kit (Blender recipes: core, ring, docking bay, habitat, antenna
  arrays) → 3 variants. Docking range trigger, an auto-dock cinematic (spline path + camera),
  a no-fire zone, and defense turrets that engage hostiles.
- **Acceptance:** previews of the 3 variants. A sim: auto-dock completes from any approach
  direction without collisions.

### M4-T6 · Station screen shell
- **Size:** L · **Depends on:** T5 · **Read:** GDD §13, art bible §7
- A hangar view scene (ship on a pad, slow orbit camera, CC0 HDRI lighting), and a
  controller-first menu framework with service tabs (Market, Equipment, Hangar, Workshop,
  Shipyard, Bar, Repair, Save) as placeholders. Repair & rearm works. Autosave on dock.
- **Acceptance:** the menu is navigable by gamepad only (an automated focus-walk test).
  Shots in the PR.

### M4-T7 · System & galaxy maps, nav markers
- **Size:** M · **Depends on:** T3
- A system map (zones, danger, owner faction, traffic hints) for selecting the cruise
  destination, a galaxy map (2 systems + gate link), and HUD nav markers.
- **Acceptance:** shots, and a focus-walk test.

### M4-T8 · Traffic simulation & random events
- **Size:** L · **Depends on:** T2, M3-T6 · **Read:** GDD §12.2
- An abstract system-level traffic sim (traders, patrols, convoys moving between zones), with
  spawns when a zone loads, NPC traders docking and undocking, patrols that help the player
  against pirates, distress calls, and radio chatter.
- **Acceptance:** a 1-hour headless sim: no traffic leaks, and every zone sees traffic within
  N minutes.

### M4-T9 · Block out the 2 slice systems
- **Size:** L · **Depends on:** T4–T8 · **Read:** GDD §12.3
- Haldane + Ilu'Vash with all the zones from the GDD table. Sky palettes per system
  (shader params), asteroid fields, the pirate hideout, and placeholder zones for the Silent
  Wreck and the boss arena.
- **Acceptance:** a shot of every zone in the PR (a contact sheet).

### M4-T10 · Insurance death & Hardcore saves
- **Size:** M · **Depends on:** T1, T6 · **Read:** GDD §11
- Insurance: respawn docked at the last station, lose cargo, pay a fee. The Hardcore flag on
  a new game: ironman saving, a save delete on death, and a run summary screen.
- **Acceptance:** unit tests for both paths. Hardcore can't reload after death.

---

## M4 playtest checklist
- [ ] Is cruising between zones quick enough? Are interdictions exciting or annoying?
- [ ] Is docking satisfying? Is the station menu easy with a gamepad?
- [ ] Does space feel alive (traffic, patrols, chatter)?
- [ ] Do both systems look distinct and beautiful?
- [ ] Save, quit, load: is everything where you left it?
- [ ] Die once: are the insurance rules clear and fair?
