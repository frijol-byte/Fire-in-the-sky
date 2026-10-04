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

### M3-T2 · Squad tactics & barks
- **Size:** L · **Depends on:** T1 · **Read:** GDD §8.2
- A `Squad` with a leader and wingmen: formation flight, a shared focus target, and tactics
  (flank, pincer, bait-and-switch, regroup when shields drop, call reinforcements when
  losing). Barks that telegraph intent.
- **Acceptance:** sims: a 3-ship squad's attack angles are spread (not all chasing from
  behind), and regroup triggers correctly. Shots in the PR.

### M3-T3 · Railgun, Plasma, Torpedo, devices, turrets
- **Size:** L · **Depends on:** M2 · **Read:** GDD §7.2
- Railgun (charge, hitscan), Plasma Caster, Torpedo (can be shot down), devices (Shield
  Booster, EMP Pulse, Repair Nanites), and an auto-turret for ships with a turret slot. All
  defined as data.
- **Acceptance:** unit tests and sims per weapon/device, and every item has VFX/SFX v0.

### M3-T4 · Elite modifiers (mini-bosses)
- **Size:** L · **Depends on:** T1, T3 · **Read:** `02-bosses.md` §3.2
- An `EliteModifierDef` system (stackable stat + behavior packages) with **Shielded, Cloaking,
  Mine-layer, Regenerating**. A callsign generator, an elite HUD frame + comms intro, and
  better loot tables.
- **Acceptance:** a sim per modifier shows the counterplay works (e.g. a flanking attacker
  beats Shielded faster than a head-on one). Shots of each elite.

### M3-T5 · Difficulty & danger rating
- **Size:** M · **Depends on:** T1 · **Read:** GDD §10
- `DifficultyDef` for Easy/Normal/Hard (reaction, aim error, aggression, aim assist, damage
  taken, elite chance, boss mechanic flags), plus a danger rating 1–5 scaling the encounter
  budget, tiers and modifier count. A settings menu entry.
- **Acceptance:** a sim shows the AI win rate vs a reference bot increases from Easy → Hard.

### M3-T6 · Encounter director
- **Size:** M · **Depends on:** T1, T4, T5 · **Read:** architecture §5.3
- Builds encounters from a threat budget (danger × difficulty): picks roles, squads and
  elites, warps them in with VFX, and adds reinforcements mid-fight. A debug panel shows
  the budget.
- **Acceptance:** unit tests show budgets are respected and composition varies across seeds.
  The combat arena uses the director.

---

## M3 playtest checklist
- [ ] Do fights at danger 1 vs 3 vs 5 feel different?
- [ ] Do enemy squads feel coordinated?
- [ ] Is each elite modifier understandable *and* fun to counter?
- [ ] Easy / Normal / Hard: is each one right for its name?
- [ ] Which new weapon/device is your favorite? Which is useless?
