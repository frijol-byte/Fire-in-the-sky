# 02 — Bosses, Mini-Bosses & Secret Encounters

Boss fights are design pillar #2 and the main fix for GoF2's weak spots (no challenge, no
unique bosses). This file covers the rules every boss follows and the full catalog. The slice
builds the systems plus three encounters. Everything else is backlog, already designed so it
reuses those systems.

## 1. Boss design rules

1. **One core mechanic per boss**, stated in a single sentence. It must force a change in how
   the player flies or fits their ship. A boss is never just a bigger health bar.
2. **Telegraph everything.** Every big attack has a visual and an audio wind-up (charging
   glow, comms bark, warning ring). Deaths should feel fair.
3. **Phases.** 2–3 phases, marked on the boss health bar. Each phase adds or changes a
   mechanic.
4. **Counterplay through loadout.** Each boss has at least one gear choice that makes it
   easier (e.g. kinetic weapons against armored subsystems, flares against missile spam), but
   is still beatable with any reasonable fit.
5. **Arenas matter.** Cover (asteroids, wrecks), hazards, and room to drift.
6. **Difficulty changes mechanics**, not just HP: Easy removes or slows one mechanic, Hard
   adds one.
7. **Rewards tie to the mechanic.** Beating the drone carrier gives you a drone device
   blueprint. Rewards are unique, never just credits.
8. **Retry friendly.** A checkpoint at the arena entrance (not in Hardcore). Boss bounties can
   be re-attempted.
9. **Testable.** Every boss has a headless "bot fight" sim that runs each phase transition
   and checks for no softlocks (see `03-tech-architecture.md`).

## 2. Shared boss systems (built in the slice)

| System | Used by |
|---|---|
| **Subsystems**: targetable parts with their own health and hitbox. Destroying one triggers effects (turret offline, shield down, engines crippled) | Capital ships, carrier, dreadnought, cruiser |
| **Phase controller**: health or event thresholds trigger phase scripts | All bosses |
| **Boss HUD**: named health bar with phase ticks, subsystem list, warning callouts | All bosses |
| **Telegraph library**: charge glows, warning rings, comms barks, audio stingers | All bosses |
| **Elite modifiers**: stackable behavior/stat packages on any ship | Mini-bosses, ace wingmen |
| **Arena controller**: boundaries, hazards, spawns, checkpoint, music state | All bosses |

## 3. Catalog

### 3.1 ★ Drone-Shielded Carrier: "Cinder Matriarch" (SLICE BOSS)
*Owner's example: "a carrier with drones that constantly shield it".*

- **Core mechanic:** the carrier can't be hurt while its shield drones are linked to it. Kill
  the drones, and stop their relaunch, to open a damage window.
- **Where:** finale of the slice's bounty chain in Ilu'Vash. Re-attemptable as a high-tier
  bounty.
- **Arena:** a debris field around a ruined Ithari relay. Wrecks give cover from flak.

| Phase | What happens | Counterplay |
|---|---|---|
| 1. Bulwark (100%) | 6 shield drones orbit, each projecting a visible beam to the carrier, which is invulnerable while any link is up. Two **hangar bay** subsystems relaunch a drone every 20 s. Flak turrets punish anyone hovering nearby | Kill drones with fast energy weapons. Destroy the armored hangar bays (kinetic/torpedoes) to stop relaunches. Use wrecks as cover from flak |
| 2. Exposed (shield down) | **Reactor vents** open on the dorsal hull (weak point). A pirate fighter wing launches. Point defense ramps up. At 50% reactor HP, the remaining drones turn kamikaze | Strafing runs on the vents, using drift to keep the guns on target. Flares and boost to dodge the kamikazes |
| 3. Flight (≤ 25%) | The carrier spools its jump drive: a **90 s timer**. Engine subsystems become targetable | Finish the reactor, **or** destroy the engines to strand it (no timer, but the turrets go berserk). If it escapes, the bounty fails |

- **Easy:** 4 drones, 30 s relaunch, longer timer. **Hard:** drones repair each other while
  linked, and flak tracks better.
- **Reward:** *Drone Bay* device blueprint (a support drone for the player), Shipwright
  Schematic for the heavy fighter, and a lot of credits.

### 3.2 Elite variants (mini-bosses) (SLICE: 4 modifiers)
Named elites (e.g. *"Vex 'Ashjaw' Morrow"*, generated callsigns) are a normal ship plus
modifiers. Danger 2–3 gives 1 modifier, danger 4–5 gives 2. They have a distinct HUD frame,
a comms intro bark, and better drops (materials, sometimes blueprints).

| Modifier | Effect | Counterplay | Slice? |
|---|---|---|---|
| **Shielded** | Strong frontal shield, weak rear | Flank it with FA-off drift | ✅ |
| **Cloaking** | Cloaks when damaged, reappears behind you | Scanner pulse or EMP reveals it; watch for its shimmer | ✅ |
| **Mine-layer** | Drops proximity mines in its wake | Don't tail-chase; attack from the side | ✅ |
| **Regenerating** | Rapid hull regeneration unless it takes burst damage | Missiles, railgun charge shots, or an Ion hit to stop the regen | ✅ |
| Overcharged | Faster and more aggressive, berserk below 30% | Kite it, use defensive devices | Backlog |
| Swarm-caller | Periodically summons drones | Kill the caller first | Backlog |
| Reflective | Reflects energy weapons | Use kinetic weapons | Backlog |
| Juggernaut | Huge armor, slow, rams | Kinetic weapons/torpedoes, stay mobile | Backlog |

### 3.3 Secret encounter: "The Silent Wreck" (SLICE, mystery teaser)
- **Where:** an unmarked zone in Ilu'Vash, found by following a faint signal (a rumor in the
  bar plus a scanner ping).
- **What:** an impossible derelict made of black glass. When you scan it, the sky's
  "fire" flickers silently, and **echo copies of your own ship** (same loadout) materialize
  for 60 s. Survive or destroy them.
- **Why it works:** a mirror match tests the player's own build. It's cheap to make (it reuses
  the player ship, AI and modifiers) and very eerie with the right audio (sound cuts to near
  silence).
- **Reward:** Anomalous Fragment (a rare material) and a lore log. It plants the campaign
  mystery.

### 3.4 Ace Pilot Duel: "the Rival" (BACKLOG, campaign)
- **Core mechanic:** a 1v1 against a named ace in a unique ship who uses FA-off flips,
  decoys and taunts. At 50% they call two wingmen with modifiers. At 25% they overcharge (a
  speed burst with a telegraphed ram).
- Recurring across chapters. They learn (gain a new modifier each time they survive).

### 3.5 Attrition Cruiser: "the Grinder" (BACKLOG)
*Owner's example: "a Cruiser that constantly pelts you with rounds that slowly drain your
ship's shields and armor".*
- **Core mechanic:** a constant long-range bombardment that drains shields and armor
  everywhere in the arena. **Staying far away is slow death**, so you have to close the
  distance through an asteroid field, using rocks as cover from the barrage.
- Phases: break the forward battery (the drain stops in its firing arc), then the broadside
  turrets, then the reactor. Repair Nanites and shield boosters become key.

### 3.6 EMP Dreadnought: "the Silencer" (BACKLOG)
*Owner's example: "a capital ship that emanates EMPs that prevent torpedoes".*
- **Core mechanic:** periodic EMP pulses (with a visible charge-up ring) that fry missiles and
  torpedoes in flight and briefly disable devices. You have to **time your torpedo volleys to
  land between pulses**, or kill the EMP emitters (subsystems) first.
- Hard mode: the pulses also briefly disable flight assist.

### 3.7 Capital ship: subsystem siege (BACKLOG, campaign climax)
- Large warship with layered subsystems: point defense → shield generators → bridge. You lead
  an allied wing (simple squad commands: attack my target, defend me).

### 3.8 Mystery-threat entities (BACKLOG, late campaign)
- Non-ship encounters tied to "the Hush": a living derelict that rebuilds itself from debris,
  an anomaly that inverts your controls inside its radius, an entity only visible during the
  sky's "fire" flashes. Each one breaks a rule the player has learned.

## 4. Slice boss test checklist (for the M7 gate)
- [ ] Each phase can be completed by the bot-fight sim on Easy/Normal/Hard
- [ ] No invulnerability softlock (e.g. a drone stuck inside geometry still counts as killable)
- [ ] The escape timer works, and a failed bounty can be retried
- [ ] Every attack has a visual and audio telegraph
- [ ] Owner playtest: "Did the fight make you change tactics?" "Was any death unfair?"
