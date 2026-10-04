# M5 — Economy, Loadout & Upgrades

**Goal:** design pillar #4. A satisfying earn → upgrade loop: GoF2 slots, Everspace-style Mk
tuning, and ship tiers you can *see*, all with no grind walls.
**Exit:** owner playtest: "Trading and upgrading feel rewarding; I can see my ship change."

> Rolling plan: the M4 review gate refines these cards before work starts.

---

### M5-T1 · Item taxonomy & inventory
- **Size:** M · **Depends on:** M4 · **Read:** GDD §14.1
- `ItemDef` subtypes: Commodity, Material, Equipment (weapon/device/passive), Blueprint,
  Ammo. A cargo hold with capacity, and a player inventory (blueprints and unfitted gear stored
  at stations). Slice content data: 10 commodities, 6 materials.
- **Acceptance:** unit tests for stacking, capacity, and transfers.

### M5-T2 · Market simulation
- **Size:** L · **Depends on:** T1 · **Read:** GDD §14.2
- Per-station production/consumption, the pricing formula (one pure function), stock drift,
  market events, and lazy catch-up.
- **Acceptance:** unit tests for pricing. A **10-hour headless economy sim** report:
  prices stay in bounds, there's no infinite-profit loop between any two stations, and the
  best trade route earns within the target band.

### M5-T3 · Market UI
- **Size:** M · **Depends on:** T2, M4-T6
- Buy/sell with gamepad (hold to repeat, a quantity slider), price vs. regional average
  arrows, cargo/credits display, and "best sold at" hints for known stations.
- **Acceptance:** a focus-walk test, and shots.

### M5-T4 · Slots, loadout & StatCalculator
- **Size:** L · **Depends on:** T1 · **Read:** GDD §15.1, §15.4, architecture §5.5
- Slot definitions per ship (data), equip rules, and `StatCalculator.compute()` as the
  **only** stat-stacking path (base → tier → items → Mk/tuning → difficulty).
- **Acceptance:** extensive unit tests on stacking order and edge cases.

### M5-T5 · Equipment shop & hangar loadout UI
- **Size:** M · **Depends on:** T4
- Buy/sell gear, fit/unfit, and a stat comparison (green/red deltas) before buying or
  fitting. Ammo purchase.
- **Acceptance:** a focus-walk test, and shots.

### M5-T6 · Item Mk upgrades & tuning (Workshop)
- **Size:** L · **Depends on:** T4, T5 · **Read:** GDD §15.2
- Mk I–III for every slice item, with 2 tuning choices at Mk II and Mk III (data), costs in
  credits + materials, a blueprint gate at Mk III, and a respec fee. Workshop UI with
  before/after stats.
- **Acceptance:** unit tests for costs and gating. Every item has tuning text through
  localization keys.

### M5-T7 · Ship tier upgrades with visuals (Shipyard)
- **Size:** L · **Depends on:** T4 · **Read:** GDD §15.3, art bible §3.1
- T1–T3 for kestrel/bulwark/drayman: stat packages, slot unlocks, Shipwright Schematic
  gating (T2+), and **visual tier parts** (update the Blender recipes; previews per tier).
  Shipyard UI with a 3D preview of the next tier before buying.
- **Acceptance:** previews of every ship × tier in the PR, and unit tests for tier
  stats/slots.

### M5-T8 · Buying ships (trade-in)
- **Size:** S · **Depends on:** T7 · **Read:** decision D3
- Buy a ship by trading in the current one (value = base + tiers × depreciation). Gear moves
  to station storage.
- **Acceptance:** unit tests, and an edge case: cargo that doesn't fit is handled.

### M5-T9 · Balance pass v1 & balance sheet
- **Size:** M · **Depends on:** T2–T8 · **Read:** GDD §14.3
- `tools/balance/report.py`: exports every ship/item/upgrade/price into
  `docs/balance/balance-sheet.md` (readable tables for the owner) and runs **pacing sims**
  (scripted player strategies: trader, bounty hunter, mixed) against the GDD pacing targets.
- **Acceptance:** the report is committed, every pacing target is within ±25% or explained in
  the PR.

---

## M5 playtest checklist
- [ ] Is trading fun for a few runs? Do prices make sense?
- [ ] Is the first upgrade quick and satisfying?
- [ ] Do Mk tuning choices feel like real choices?
- [ ] Can you see your ship change with tiers? Do you like the look?
- [ ] Any point where you felt you were grinding?
- [ ] Read `docs/balance/balance-sheet.md`: does anything look off?
