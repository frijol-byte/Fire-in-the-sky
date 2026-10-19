# 01 — Game Design Document

> Working title: **Fire in the Sky**. Status: vertical-slice design. All numbers are starting
> values, to be tuned through playtests. Lore names are placeholders (see `05-lore-primer.md`).

## 1. Pitch

A single-player space combat and trading game in the spirit of *Galaxy on Fire 2*, with the
flight feel and atmosphere of *Everspace*. You're a freelance pilot in a vivid, lived-in
galaxy: you fly tight Newtonian-lite dogfights, trade between stations, and grow one ship from
a battered starter into a customized warship. Meanwhile something silent is putting out stars
at the edge of known space. Bosses are fights you remember: carriers you dismantle piece by
piece, rival aces, and things that shouldn't exist.

PC first (gamepad-first controls), then Android.

## 2. Design pillars

Every feature should serve at least one pillar. When two ideas conflict, the higher pillar wins.

1. **Dogfights that feel great.** Responsive Newtonian-lite flight, clear feedback, readable
   enemies, skill expression through drift, boost and positioning. If flight isn't fun in an
   empty asteroid field, nothing else matters.
2. **Bosses you remember.** Every boss and mini-boss has a *mechanic* that forces a change of
   tactics. A boss is never just a bigger health bar.
3. **Atmosphere.** Gorgeous skies, a distinct palette for each system, adaptive music, and
   space that feels lived-in (traffic, patrols, convoys, chatter).
4. **Satisfying growth.** The GoF2 loop of earning, upgrading and seeing your ship physically
   change, with no grind walls.
5. **Real challenge, by choice.** Difficulty changes enemy behavior and boss mechanics, not
   just numbers. Dangerous systems are harder and pay better. Hardcore permadeath is
   available for those who want it.

### Anti-goals (what we will not do)

- Copy-paste side missions (GoF2's weak spot). Missions are templates × modifiers with
  anti-repetition rules.
- Rarity-colored random loot. Items are upgraded deliberately, not gambled for.
- Walkable interiors, multiplayer, or open-ended crafting trees.
- Grind walls: no required purchase should need more than ~20 minutes of repeating one activity.
- Anything copied from GoF2's or Everspace's IP (names, races, ships, plot).

## 3. Core loop

```
        ┌──────────────── Station ────────────────┐
        │ sell cargo/loot · buy goods · take jobs │
        │ buy/upgrade gear & ship · repair · save │
        └───────┬──────────────────────────▲──────┘
                │ undock                    │ dock (autosave)
                ▼                           │
   cruise to a point of interest ──► fight / trade run / bounty / secret
                │                           ▲
                └── interdiction! ──────────┘ (random encounter in deep space)
```

- **Moment to moment (seconds):** fly, aim, drift, boost, manage energy, dodge missiles.
- **Session (10–30 min):** take 1–3 jobs or a trade route, fight along the way, return,
  upgrade.
- **Long term (hours):** better ship tiers, Mk upgrades, reputation with the alien faction,
  bounty chains that lead to bosses, the mystery.

## 4. Flight model

Everspace-style Newtonian-lite. **The player and AI use exactly the same flight physics.**

### 4.1 Axes & forces
- 6 axes of movement (6DOF): forward/reverse thrust, lateral strafe, vertical strafe, pitch,
  yaw, roll.
- Each ship has separate thrust limits per linear axis (forward is strongest), and angular
  acceleration limits per rotation axis.
- Mass is real: heavier ships accelerate and turn slower.

### 4.2 Flight assist (FA)
- **FA on (default):** the flight computer fires thrusters to make the ship's velocity match
  what the sticks ask for (the throttle sets the target forward speed, strafe sets lateral
  velocity). Releasing the sticks brings the ship to a controlled stop. Rotation is damped,
  so the ship stops turning when the stick is released.
- **FA off (hold button):** linear damping turns off. The ship keeps its momentum while you
  rotate freely, which allows drift turns, strafing runs and flipping to shoot behind you.
  Rotation stays assisted (it's too hard on a gamepad otherwise).
- **Speed limiter:** with FA on, speed is capped at the ship's cruise-combat max. With FA off
  you can exceed it only through boost momentum, and FA bleeds the excess off smoothly when
  re-enabled.

### 4.3 Boost & energy
- A single **energy capacitor** powers boost, energy weapons and devices. This creates the
  core combat decision: chase, shoot, or shield-boost?
- Boost multiplies forward thrust and raises the speed cap while held. It drains energy fast.
- Energy regenerates after a short delay once you stop spending it.

### 4.4 Starting values (to tune in M1)

| Ship class | Max speed (FA) | Boost max | Fwd accel | Strafe accel | Pitch/yaw | Roll |
|---|---|---|---|---|---|---|
| Light fighter | 180 m/s | 320 m/s | 60 m/s² | 35 m/s² | 90°/s | 150°/s |
| Heavy fighter | 140 m/s | 260 m/s | 45 m/s² | 28 m/s² | 65°/s | 110°/s |
| Armed freighter | 110 m/s | 200 m/s | 30 m/s² | 18 m/s² | 40°/s | 70°/s |

Scale: 1 unit = 1 metre. Fighters are 12–20 m long, freighters ~35 m, carriers ~400 m,
stations 600–1500 m.

### 4.5 Sense of speed (critical for feel)
Space dust particles streaming past, engine trails, FOV kick on boost, light camera lag and
shake, and Doppler on engine sounds. These are part of the flight model, not polish.

## 5. Controls

Gamepad-first. The layout is a twin-stick scheme that maps directly onto a future mobile
virtual-stick layout. Everything is rebindable.

| Input (Xbox naming) | Action |
|---|---|
| Left stick | Thrust forward/back (Y), strafe left/right (X) |
| Right stick | Pitch / yaw (aim) |
| LB / RB | Roll left / right |
| RT | Fire primary weapons |
| LT | Fire secondary (hold to lock missiles) |
| A | Boost (hold) |
| B | Flight assist off (hold to drift) |
| X | Target: nearest hostile in reticle; double-tap = nearest overall |
| Y | Interact / dock / pick up (context) |
| D-pad ↑/→/↓/← | Devices 1–3, cycle subsystem target |
| L3 | Cruise drive (toward selected destination) |
| R3 | Camera: chase ↔ cockpit |
| Paddle 3 / `Z` (hold) | Free look: the right stick turns the camera while the ship keeps flying (settings flag, off by default) |
| Start / Select | Pause menu / system map |

**Mouse + keyboard:** the mouse steers a virtual joystick from screen center (pitch/yaw),
WASD thrusts and strafes, R/F move vertically, Q/E roll, left/right mouse buttons fire,
Space boosts, Shift holds FA off, T targets.

**Touch (Android, post-slice):** left virtual stick = thrust/strafe, right drag = aim, and
on-screen buttons for fire, boost and drift. Aim assist is stronger on touch.

## 6. Camera
- **Chase cam (default):** sits behind and above the ship, with spring lag, an FOV kick on
  boost, and a look-ahead toward the target when locked. It never clips through station
  geometry.
- **Cockpit cam:** a minimal canopy frame (one per faction × size class) with a holographic
  HUD.
- Optional "look at target" hold (keeps the camera tracking the locked target).
- **Free look** (hold, off by default in settings): the aim stick turns the camera instead of the
  ship. Camera shake can be scaled or turned off in settings.

## 7. Combat

### 7.1 Damage layers
Damage hits **Shield → Armor → Hull**. Shields regenerate after 4 s without damage. Armor
only repairs at stations or with repair devices. Hull at 0 means the ship is destroyed.

| Damage type | vs Shield | vs Armor | vs Hull | Notes |
|---|---|---|---|---|
| Energy | ×1.5 | ×0.75 | ×1.0 | Lasers, plasma. Uses energy |
| Kinetic | ×0.75 | ×1.5 | ×1.0 | Autocannons, railguns. Builds heat |
| Explosive | ×1.0 | ×1.0 | ×1.25 | Missiles, torpedoes, mines. Splash damage |
| Ion/EMP | ×2.0 | ×0.25 | ×0 | Little damage. Disables devices, missiles and turrets briefly |

### 7.2 Weapons in the slice

**Primaries** (fixed hardpoints with slight gimbal on gamepad):
| Weapon | Type | Role |
|---|---|---|
| Pulse Laser | Energy | All-rounder, fast projectiles, moderate energy use |
| Autocannon | Kinetic | High rate of fire, spread, overheats |
| Railgun | Kinetic | Charge-up shot, huge damage, rewards precision |
| Plasma Caster | Energy | Short range, slow bolts, heavy damage |

**Secondaries** (ammo bought at stations):
| Weapon | Role |
|---|---|
| Homing Missile | Hold to lock (1.2 s), tracks the target; flares or EMP defeat it |
| Rocket Pod | Dumb-fire salvo, great against slow targets |
| Torpedo | Slow, huge damage against capital ships. It can be shot down (this sets up future EMP/point-defense bosses) |

**Devices** (active abilities with cooldowns): Shield Booster, Countermeasure Flares, EMP
Pulse (short range), Repair Nanites. **Turrets** (on ships with a turret slot): auto-fire at
the locked target or the nearest threat.

### 7.3 Targeting & aim help
- Lock-on cycles targets. The **lead indicator** shows where to shoot. Off-screen targets get
  edge arrows.
- **Aim assist (gamepad/touch):** light bullet magnetism plus reticle "friction" near targets.
  Its strength is set by difficulty and an accessibility slider. Mouse gets none by default.
- **Subsystem targeting:** on capital ships, D-pad cycles subsystems (turrets, shield
  generators, engines, hangars).

### 7.4 Feedback (pillar 1)
Hit markers, a shield-impact ripple on the target, damage-direction indicators, a distinct
sound for shield/armor/hull hits, a low-shield alarm, and a kill confirmation with a short
slow-motion tick on the last enemy (optional setting).

## 8. Enemies & AI

### 8.1 Roles
| Role | Behavior |
|---|---|
| Interceptor | Fast, fragile, harasses, peels off to chase the player |
| Fighter | Standard dogfighter, makes attack runs |
| Gunship | Slow, turreted, holds position, punishes tail-chasing |
| Bomber | Targets the player's escort or the station, fires torpedoes |
| Support | Repairs or shields allies. **Kill it first** |

### 8.2 Tactics (fixing GoF2's predictable AI)
- Wings have a leader and wingmen: flanking, pincers, bait and switch, and focus fire on the
  weakest target.
- They react to the player: evade (jink, FA-off flip, flares) when locked, retreat to regroup
  when shields are down, call reinforcements when losing.
- Enemies use the same toolset as the player (drift, boost, devices).
- Radio barks telegraph intent ("Breaking left!", "He's on me!"), which is also the
  atmosphere pillar.

### 8.3 Elites (mini-bosses)
Named elites spawn with **modifiers** that change how you fight them (catalog in
`02-bosses.md`). They have a distinct HUD frame and drop materials and sometimes blueprints.

## 9. Bosses

See **`02-bosses.md`**. The slice ships one full boss (the Drone-Shielded Carrier), the elite
modifier system, and one secret mystery encounter.

## 10. Difficulty & challenge

| Setting | Changes |
|---|---|
| Easy | Slower AI reactions, less accuracy, less aggression, strong aim assist, simplified boss mechanics (e.g. fewer drones) |
| Normal | Baseline |
| Hard | Faster, more accurate and more coordinated AI. Elites spawn more. Bosses gain extra mechanics (e.g. drones heal each other) |
| **Hardcore** (save flag, any difficulty ≥ Normal) | Permadeath: the save is deleted when you die. Ironman saving only |

**Danger rating (1–5)** for each system, zone or contract scales enemy count, enemy tier,
elite chance and modifier count, along with rewards. The player always sees the rating
before committing (HUD, mission board, system map).

## 11. Death
- **Default: insurance.** Respawn docked at the last station visited. You lose your cargo and
  any uncollected loot, and pay an insurance fee (a % of the ship's value). The ship and
  fitted gear are returned. No progress is lost beyond the cargo.
- **Hardcore:** game over, save deleted, and a run summary screen.

## 12. World structure

### 12.1 Systems & zones
- The galaxy is made of **star systems** connected by **jumpgates**.
- Each system contains **zones** (points of interest): stations, asteroid fields, pirate
  hideouts, derelicts, anomalies, gates. Each zone is a free-flight space up to **8 km**
  across.
- **Cruise drive:** select a zone on the HUD or system map, then the drive spools (3 s) and a
  cruise tunnel effect plays (5–15 s depending on distance) before arrival. You can't cruise
  while hostiles are near ("mass-locked").
- **Interdiction:** during cruise, there's a danger-based chance of being pulled out into a
  deep-space encounter zone (pirate ambush, distress call, convoy under attack, rare secret).
- Zones keep Godot's coordinates small. See `00-decisions.md` D2.

### 12.2 Living space (fixing "empty systems")
- NPC traders fly between stations within a zone. Patrols sweep zones. Convoys arrive and
  leave via the gates.
- A system-level traffic simulation decides who is where, so a zone you arrive at already has
  traffic.
- Radio chatter, station announcements, distress calls and random events.

### 12.3 Slice map
| System | Theme | Zones |
|---|---|---|
| **Haldane** (human frontier) | Warm amber nebula, gas giant | Haldane Prime (trade hub station), Fort Kessel (military outpost), Rook's Yard (mining station + shipyard), Tallow Belt (asteroid field), a pirate hideout, the jumpgate |
| **Ilu'Vash** (alien border) | Teal/violet nebula, crystal fields | Ithari waystation, Shard Reef (crystal asteroid field), the Silent Wreck (secret), carrier boss arena, the jumpgate |

## 13. Stations
Fly within range and press Y to auto-dock (a cinematic camera plays). Inside, menu screens
appear over a 3D hangar view with your ship on the pad.

| Service | Notes |
|---|---|
| Market | Buy/sell commodities and materials. Shows price trend vs. regional average |
| Equipment | Buy/sell weapons, devices, equipment and ammo |
| Hangar | Fit your loadout, compare stats |
| Workshop | Item Mk upgrades and tuning (§15.2) |
| Shipyard | Buy ships, ship tier upgrades (§15.3). Only at some stations |
| Bar | Mission board, bounty board, rumors (lore hints), NPC contacts |
| Repair & rearm | One button, priced |
| Save | Manual save (autosave also runs on every dock) |

Station type (trade hub, military, mining, alien) decides which services exist and what the
market produces and consumes.

## 14. Economy

### 14.1 Currencies & goods
- **Credits:** the money.
- **Commodities:** trade goods (~10 in the slice: Food Rations, Water Ice, Medical Supplies,
  Raw Ore, Refined Metals, Electronics, Fuel Cells, Luxury Goods, Ithari Glass, Ithari Spice).
- **Materials:** upgrade ingredients (6 in the slice: Scrap Alloy, Power Cells, Polymer
  Fiber, Quantum Circuits, Ithari Crystal, Anomalous Fragment). Materials are **also
  tradeable**, which ties trading to upgrading.
- **Blueprints:** unlock higher upgrade tiers. They come from elites, bosses, secrets,
  reputation rewards, and rarely from shops.

### 14.2 Markets
- Each station produces and consumes certain goods. Price follows stock vs. a target level:
  `price = base × clamp(1 + k × (target − stock) / target, 0.5, 2.0)`.
- Stock drifts back toward equilibrium over time. Player sales and purchases move the stock,
  so dumping 200 units crashes the price (no infinite exploits).
- Market events (shortages, surpluses, blockades) are announced in the bar or news.
- Markets update lazily: they catch up on elapsed time when you visit (cheap to run).

### 14.3 Pacing targets (slice)
| Milestone | Target play time |
|---|---|
| First item upgrade | 10–15 min |
| First ship tier upgrade | 20–30 min |
| Second ship bought | 60–90 min |
| Boss bounty available | ~2.5 h |
| Slice "complete" (boss beaten, one ship at T3) | 3–5 h |

Balance sims (in `tools/`) check these targets automatically (see `03-tech-architecture.md`).

## 15. Loadout & upgrades

### 15.1 GoF2 slots
Each ship defines its slot counts:

| Slot | Holds | Typical count |
|---|---|---|
| Primary | Primary weapons | 1–4 |
| Secondary | Missiles / rockets / torpedoes | 1–2 |
| Turret | Auto-turret | 0–1 |
| Device | Active abilities | 1–3 |
| Equipment | Passive: shield generator, armor plating, thruster tuning, capacitor, cargo extension, scanner, tractor beam | 2–6 |
| Cargo | Capacity in units | 20–200 |

### 15.2 Item upgrades (Everspace-style tuning, no rarity)
- Every weapon, device and equipment item has **Mk I → Mk V** levels (slice: Mk I–III).
- Each Mk raises the item's base stats.
- At **Mk II and Mk III** you pick one of two **tuning mods**. Example, Pulse Laser Mk II:
  *Focused Lens* (+20% damage, −10% fire rate) **or** *Rapid Cycler* (+25% fire rate, +15%
  energy use).
- Tuning can be swapped later at a Workshop for a small fee, to encourage experimenting.
- Cost: credits + materials. **Mk III and up need the item's blueprint.**

### 15.3 Ship upgrades (stats + slots + visuals)
- Each ship has **upgrade tiers T0 → T5** (slice: T0–T3), done at a Shipyard.
- Each tier gives a **stat package** (hull, armor, thrust, turn rate, energy, cargo), **may add
  a slot**, and **visibly changes the ship** (e.g. T1 bolt-on armor plates, T2 extra engine
  pods, T3 wing extensions with an extra hardpoint, sensor array, trim paint).
- Cost: credits + materials. **T2 and up need the ship's Shipwright Schematic** (a
  blueprint).
- An early favorite ship stays viable for a long time. Later ships start with higher ceilings.

### 15.4 Stat stacking order
`ship base → ship tier → equipment → item Mk & tuning → difficulty modifiers`
(This is implemented in one place and unit-tested. See tech architecture.)

## 16. Factions & reputation

| Faction (placeholder) | Slice stance | Notes |
|---|---|---|
| Solar Concord (human government/navy) | Friendly | Patrols, military station, bounty contracts |
| Meridian Guild (human traders) | Friendly | Trade hubs, delivery/escort jobs |
| Cinder Clans (pirates) | Hostile | Main enemies. Their warlord owns the carrier boss |
| **Ithari** (alien race 1) | **Neutral, reputation-based** | Crystal-tech. Their station allows docking only at reputation ≥ "Tolerated" |

- Reputation runs from −100 to +100 per faction, in bands: Hostile < −50 ≤ Wary < −10 ≤
  Tolerated < 25 ≤ Respected < 60 ≤ Honored.
- **Ithari start at Wary (−15).** You raise reputation by killing pirates in Ithari space,
  answering Ithari distress calls, and doing jobs from their comm buoy. Docking needs
  Tolerated, the Ithari ship needs Respected, and Ithari blueprints need Honored.
- Attacking Ithari ships drops reputation sharply, and their patrols turn hostile.

## 17. Missions

### 17.1 Mission board (fixing repetition)
Missions are **templates × modifiers × locations × text variants**.

**Templates (slice):** Bounty, Escort, Delivery, Clear Zone, Salvage Recovery, Defend Outpost.

**Modifiers (slice):** Elite Target, Reinforcements, Time Limit, Ion Storm (radar limited to
2 km), Ambush En Route, Fragile Cargo (fail if hull damage > X), Bonus Objective (e.g.
destroy a subsystem), Silent Running (avoid patrol scans).

**Anti-repetition rules:** a station never shows the same template + modifier combination
twice in a row. Each template has ≥ 3 briefing text variants and ≥ 3 location variants.
Rewards scale with danger. The board refreshes on a timer.

### 17.2 Bounty chains
A chain is 3 linked bounties: a lieutenant, then their intel, then a boss bounty. The slice
has one chain, ending at the Carrier.

### 17.3 Scripted missions
Story missions use the same objective system plus dialogue, triggers, scripted spawns and
camera moments. The slice uses it for a short **tutorial prologue** (D4), and the
post-slice campaign reuses it.

## 18. Saving
- Autosave on dock. Manual save at stations. 3 regular slots plus Hardcore slots.
- Saves are JSON with a schema version and migration steps, so old saves keep working after
  updates.
- File-based, ready for Steam Cloud later.

## 19. Vertical slice: exact content

| Category | Content |
|---|---|
| Systems | 2 (Haldane, Ilu'Vash), 1 jumpgate link, ~10 zones total |
| Stations | 3 human (trade hub, military, mining + shipyard), 1 Ithari |
| Player ships | 3 human (light fighter, heavy fighter, armed freighter) + 1 Ithari (reputation-gated), each with T0–T3 visuals |
| Enemy ships | Pirate interceptor, fighter, gunship, bomber (kit-bashed from human parts), Ithari patrol, Carrier boss + shield drones |
| NPC traffic | Concord patrol fighter, Meridian freighter |
| Weapons/devices | 4 primaries, 3 secondaries, 4 devices, 1 turret, ~7 equipment types, Mk I–III with tuning |
| Economy | ~10 commodities, 6 materials, ~12 blueprints |
| Missions | 6 templates, 8 modifiers, 1 bounty chain, 3-mission prologue |
| Bosses | Drone-Shielded Carrier, 4 elite modifiers, Silent Wreck secret encounter |
| Difficulty | Easy / Normal / Hard + Hardcore, danger ratings 1–5 |
| Audio | Adaptive music (explore/tension/combat/boss/station), full SFX set |
| Platforms | Windows + Linux builds, gamepad + mouse/keyboard |

## 20. Out of scope for the slice (backlog)
The campaign beyond the prologue, the second alien race, minor species, mining, Android
build, ace duel / attrition cruiser / EMP dreadnought bosses, mystery entity fights, ship tiers
T4–T5 and items Mk IV–V, the hidden shipyard, owning several ships, other languages, Steam
integration.
