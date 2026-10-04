# M6 — Factions, Missions & Dialogue

**Goal:** fix GoF2's repetitive side missions, and make the neutral alien faction worth
befriending. Build the dialogue and mission systems the campaign will reuse.
**Exit:** owner playtest: "Jobs feel varied; the Ithari are worth earning."

> Rolling plan: the M5 review gate refines these cards. **Owner input needed before T7:**
> approve or replace the lore premise and names in `05-lore-primer.md`.

---

### M6-T1 · Factions & reputation
- **Size:** M · **Depends on:** M5 · **Read:** GDD §16
- `FactionDef`, a relation matrix, reputation bands, actions → reputation changes, and
  effects (docking permission, prices, hostility, shop/ship availability).
- **Acceptance:** unit tests for band transitions and effects.

### M6-T2 · Dialogue system & comms panel
- **Size:** L · **Depends on:** — (M5) · **Read:** architecture §5.6, lore §5
- A data format (speakers, lines through localization keys, choices, conditions, effects),
  a comms panel in space (portrait placeholder + typed text) and a dialogue view in the bar.
  A bark queue (never overlapping).
- **Acceptance:** unit tests for conditions and effects. Shots in the PR.

### M6-T3 · Mission framework
- **Size:** L · **Depends on:** T2 · **Read:** architecture §5.6
- An objectives graph (GoTo, Destroy, DestroySubsystem, Escort, Deliver, Survive, Scan,
  Defend, Collect), triggers, rewards, failure conditions, saved state, and a mission log UI
  + HUD objective markers.
- **Acceptance:** unit tests, and a save/load mid-mission round-trip.

### M6-T4 · Mission board generator (templates × modifiers)
- **Size:** L · **Depends on:** T3 · **Read:** GDD §17.1
- 6 templates, 8 modifiers, ≥ 3 text variants and ≥ 3 location variants per template,
  danger-scaled rewards, anti-repetition rules, and a board refresh timer.
- **Acceptance:** a **variety test**: 200 generated boards with zero consecutive duplicate
  template+modifier pairs at a station, and the distribution report is in the PR.

### M6-T5 · Bounty board & bounty chain
- **Size:** M · **Depends on:** T4, M3-T4 · **Read:** GDD §17.2
- A bounty board (elite targets with modifiers), and the 3-step chain toward the Matriarch
  (lieutenant → intel → boss bounty, which unlocks in M7).
- **Acceptance:** a chain progression unit test, and a save/load mid-chain test.

### M6-T6 · Ithari content
- **Size:** L · **Depends on:** T1 · **Read:** GDD §16, art bible §2
- The Ithari station (faceted crystal kit recipes), reputation-gated docking, the comm buoy
  with Ithari jobs, unique goods, Ithari patrol AI (neutral → hostile if provoked), and the
  purchasable **Ithari ship** (recipe + tiers) at Respected.
- **Acceptance:** previews of the station and ship, and a sim: attacking Ithari turns
  patrols hostile.

### M6-T7 · Tutorial prologue
- **Size:** L · **Depends on:** T2–T4 · **Read:** lore §4, GDD §17.3
- The 3 prologue missions ("Static", "Debts", "Sparks") teaching flight, docking, trading
  and combat, with skippable tutorials. They plant the black-box mystery hook.
- **Acceptance:** a bot-run sim completes the prologue. Owner approval of the text.

---

## M6 playtest checklist
- [ ] Play 10 board missions: did any feel repetitive?
- [ ] Is earning Ithari trust clear and worth it?
- [ ] Does the prologue teach well without being slow?
- [ ] Is the dialogue tone right? (space opera, a bit of humor, mystery)
