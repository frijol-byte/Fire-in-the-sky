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
| Light fighter | 180 m/s | 320 m/s | 60 m/s² | 110 m/s² | 90°/s | 150°/s |
| Heavy fighter | 140 m/s | 260 m/s | 45 m/s² | 78 m/s² | 65°/s | 110°/s |
| Armed freighter | 110 m/s | 200 m/s | 30 m/s² | 54 m/s² | 40°/s | 70°/s |

Strafe accel covers the side and up/down thrusters (M1-F1: about 3x the first values, so they
respond quickly and stop crisply instead of floating). Each ship's `strafe_response_time` is the
checked target: full strafe or vertical thrust reaches 90% of its speed limit, and stops again,
within 0.85 s (light), 0.95 s (heavy) or 1.05 s (freighter). Turning, not thrusters, stays the main
way to change direction.

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
| RT (analog) | Throttle forward |
| LT (analog) | Brake / reverse (RT and LT held together cancel) |
| Left stick | Strafe left/right (X), thrust up/down (Y, stick up = ship up) |
| Right stick | Pitch / yaw (aim) |
| LB / RB | Roll left / right |
| A | Fire primary weapons (hold) |
| B | Unbound for now (flight assist off / drift keeps its action and the `Shift` key; the owner will give it a gamepad button or trigger later) |
| X | Fire secondary weapon (hold to lock missiles) |
| Y | Target: tap = nearest hostile (cycles to the next one on a repeat tap), double-tap = nearest of any side. Also interact / dock / pick up (context; no gameplay before M4, so the two share the button for now) |
| D-pad ↑/→/↓/← | Devices 1–3 (↑ = Countermeasure Flares), cycle subsystem target (M7). The flight test arena's ship switcher is on the keys F2 / F3 / F4 (a temporary demo stand-in) |
| L3 | Boost (hold). Cruise drive (toward the selected destination) shares it until M4, when it gets its own input |
| R3 | Camera: chase ↔ cockpit |
| Paddle 4 / `B` (hold) | Look at target: the camera keeps the selected target in view while the ship keeps flying |
| Paddle 3 / `Z` (hold) | Free look: the right stick turns the camera while the ship keeps flying (settings flag, off by default) |
| Start / Select | Pause menu / system map |

**Mouse + keyboard:** the mouse steers a virtual joystick from screen center (pitch/yaw),
WASD thrusts and strafes, R/F move vertically, Q/E roll, left/right mouse buttons fire,
Space boosts, Shift holds FA off, T targets (tap / double-tap), B holds look-at-target.

**Touch (Android, post-slice):** left virtual stick = thrust/strafe, right drag = aim, and
on-screen buttons for fire, boost and drift. Aim assist is stronger on touch.

## 6. Camera
- **Chase cam (default):** sits behind and above the ship, with spring lag, an FOV kick on
  boost, and a look-ahead toward the target when locked. It never clips through station
  geometry.
- **Cockpit cam:** a minimal canopy frame (one per faction × size class) with a holographic
  HUD.
- "Look at target" hold (`look_at_target`): while held, the camera swings round the ship to keep the
  selected target in view (limited like free look: 150 degrees of yaw, 60 of pitch). It does nothing
  without a target, and free look wins if both are held.
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

**Primary starting values (M2-T2; retuned after the owner's first M2 playtest: laser energy ÷5, both guns' damage ×2.
The numbers live in `data/weapons/*.tres`).**
Per gun; a ship fires every mounted gun together (two on the Kestrel, Bulwark and Drayman, three at tier 3).

| | Pulse Laser | Autocannon |
|---|---|---|
| Damage per shot (type) | 16 (Energy) | 8 (Kinetic) |
| Rate | 4 / s (the two guns alternate) | 12 / s |
| Shot speed, range | 520 m/s, 900 m | 380 m/s, 650 m |
| Spread | none | 1.4° |
| Cost | 0.4 energy per shot (1.6 / s per gun, 3.2 / s for a pair: a full 100 lasts ~30 s of firing) | 3 heat per shot; overheats at 100, cools 14 / s, fires again at 40 |
| Fitted to | Kestrel | Bulwark, Drayman |

Against a Kestrel (100 shield / 60 armor / 80 hull) a perfectly aimed pair of lasers takes about 1.8 s, a pair of
autocannons about 1.5 s but with spread and a roughly 4.5 s overheat limit. Both guns converge on a point 300-350 m
ahead, so their shots cross on the reticle.

**Secondary starting values (M2-T4, to tune in the M2 playtest; the numbers live in
`data/secondaries/*.tres` and `data/devices/flares.tres`).**

| | Homing Missile | Rocket Pod |
|---|---|---|
| Fitted to | Kestrel, Drayman | Bulwark |
| Fire | Hold the secondary button on a locked target, release to launch | Press (or hold) to fire a salvo of 6 |
| Damage (type) | 55 (Explosive), blast radius 16 m, 35% at the edge | 14 per rocket (Explosive), blast radius 7 m, 40% at the edge |
| Ammo, cooldown | 6, 1.5 s | 24 rockets, 1.5 s after a salvo |
| Speed | launches at the ship's velocity + 120 m/s, accelerates to 290 m/s | launches at +220 m/s, accelerates to 420 m/s, 2 s of flight |
| Guidance | Proportional navigation (gain 4), turns at most 55 deg/s, steers after 0.35 s, seeker sees 110 deg either side of its nose, self-destructs after 8 s | none (spread 1.2 deg) |
| Fuse | Contact, or within 12 m of its target after 40 m of flight | Contact |

- **Lock-on:** a target must be the selected, locked target (7.3), within 20 degrees of the nose and 1200 m.
  The lock builds in 1.2 s with beeps that speed up and rise in pitch, then a lock tone; the HUD ring
  around the target fills up and says LOCK. Release while locked to launch. Release early, lose the
  target, run out of ammo or take an ion hit and nothing launches. Lock lost drains faster than it builds.
- **Beating a missile:** it tops out at 290 m/s, below the Kestrel's boost (320 m/s), so **boosting straight
  away outruns it** (it burns out after 8 s). Crossing its path late enough with a **boost-drift** (flight
  assist off, nose turned across, boost) beats its turn rate: it flies past, loses the target out of its seeker
  view, and goes off harmlessly. Flares are the answer when you cannot out-fly it.
- **Blast:** every ship or drone near the blast takes damage through `Durability.apply`, strongest at
  the centre; the ship that fired is never hurt by its own blast.
- **Incoming-missile warning:** while a homing missile is steering at the player, the HUD shows a flashing
  MISSILE INCOMING banner with the distance, a marker on the missile (an arrow on the screen edge if it is out
  of view) and an alarm that beeps faster the closer it is. A missile fooled by a flare stops counting.
- **Countermeasure Flares** (device slot 1: key **1** or D-pad up; slots 2 and 3 are key 2 / D-pad right and key 3 / D-pad down): throws 4 flares, 8 s cooldown, no
  energy. Every missile that is hunting the ship and within 700 m is rolled **once** per use: 65% of them
  chase a flare instead (a flare burns for 4 s; when it goes out, or the target is destroyed, the missile
  flies on unguided). Missiles launched after the flares are out are not helped by them. An ion hit disables
  devices and missile launchers for its duration.

**Devices** (active abilities with cooldowns): Shield Booster, Countermeasure Flares, EMP
Pulse (short range), Repair Nanites. **Turrets** (on ships with a turret slot): auto-fire at
the locked target or the nearest threat.

### 7.3 Targeting & aim help
- **Selecting** (`target_nearest`): a tap picks the nearest **hostile** inside the reticle cone (15°
  around the nose; if none is in the cone, the nearest hostile at all). Tapping again cycles to the
  next hostile further away, wrapping to the nearest. A **double-tap** (within 0.3 s) picks the nearest
  target of **any** side (neutral and friendly too). Targets hidden behind a rock cannot be picked.
- **Lock:** the selected target is *locked* while it is within 1500 m and in line of sight. Out of range
  or behind a rock the lock is lost (the bracket fades and the panel says why); after 2 s without it
  the target is dropped. A destroyed target is dropped at once. Aim assist and the lead indicator only
  work on a locked target. The numbers are in `data/combat/targeting_default.tres`.
- **HUD:** every target in range has a small marker, and the selected one has brackets whose **shape**
  tells whose side it is on (square corners = hostile, round arcs = neutral, diamond = friendly; colour
  agrees: red, yellow, green). Hostile targets you cannot see get **edge arrows** (the six nearest),
  the selected target always has one. The **lead indicator** (a small ring) shows where to shoot; it
  turns green when the nose ring is on it, and is faint when the target is beyond the gun's range. A
  panel at the right shows the selected target's name, side, distance and shield, armor and hull bars.
- The **lead indicator** is `Lead.solve`: where a shot of the primary weapon's speed meets the target
  if it keeps its velocity. A target that outruns the shot has no solution and the aim falls back to
  its position.
- **Aim assist (gamepad/touch):** light bullet magnetism plus reticle "friction" near the locked
  target. Magnetism bends the guns toward the lead point by up to the weapon's gimbal (3°) times the
  assist strength; friction slows the right stick (down to 45% right on the target at full strength,
  starting 6° out). Strength = the difficulty's `aim_assist_scale` (easy 1.0, normal 0.7, hard 0.4)
  times the accessibility slider (`accessibility/aim_assist`, default 1). **The mouse gets none** unless
  the player turns on `controls/aim_assist_mouse`. There is no options menu yet, so these are settings
  keys only.
- **Subsystem targeting:** on capital ships, D-pad cycles subsystems (turrets, shield
  generators, engines, hangars). Not built yet (M7).

### 7.4 Feedback (pillar 1)
Hit markers, a shield-impact ripple on the target, damage-direction indicators, a distinct
sound for shield/armor/hull hits, a low-shield alarm, and a kill confirmation with a short
slow-motion tick on the last enemy (optional setting).

*As built (M2-T7; numbers in `data/combat/feedback_default.tres`):* hit markers at the nose ring (shield: thin cyan
ticks, armor: amber, hull: thick white with a dot, kill: large red burst and a "DESTROYED" line); damage-direction arcs
on a ring round the screen (cyan / amber / red by the deepest layer hit, pointing at the shooter); the ship's own
shield / armor / hull bars at the bottom left; a low-shield alarm from 25% (until 40%): flashing screen edge, "LOW
SHIELD" and a beep every 1.1 s; camera shake on hits (hull hits shake most), on the player's death and on nearby
explosions; a kill sound; and an optional slow-motion tick (0.3x for 0.45 s) when the last hostile ship dies, off unless
the `feedback/kill_slowmo` setting (or the F7 menu switch in the combat test) is on.

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
- *As built (M2-T5):* an AI pilot attacks in runs: it closes on the lead point, fires when the nose lines up,
  breaks off sideways when a collision is coming, and loops back round. Shot at, it dodges sideways with the
  guns still on you; locked by a missile, or with one in flight, it jinks, boosts and throws flares (after its
  reaction time: rookie 0.8 s, standard 0.4 s, ace 0.15 s). It rests its guns when its capacitor is empty,
  like you have to. Rookie, standard and ace differ in reaction time, aim, aggression and range
  (`data/ai/*.tres`).
- *As built (M2-T7):* AI pilots call out behavior changes as text on a comms strip (five lines per behavior, with a
  chance per behavior, a gap of 1.6 s on the radio and 5 s per pilot; `data/combat/barks.tres`). No voices yet.
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
