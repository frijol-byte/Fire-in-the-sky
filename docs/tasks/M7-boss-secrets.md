# M7 — Boss & Secrets

**Goal:** design pillar #2. One unforgettable boss, plus a secret encounter that plants the
mystery.
**Exit:** owner playtest: "The boss made me change tactics; no death felt unfair; the
Silent Wreck was creepy."

> Rolling plan: the M6 review gate refines these cards. Decision D1 (which boss) can still
> change before this milestone starts.

---

### M7-T1 · Subsystem framework & capital-ship AI
- **Size:** L · **Depends on:** M6 · **Read:** `02-bosses.md` §2
- `SUB_*` parts → subsystem components (their own Durability, hitbox, on-destroyed effects),
  subsystem targeting on the D-pad, a HUD subsystem list, and a capital-ship AI (turret
  control, keeping broadsides to threats, slow maneuvering).
- **Acceptance:** unit tests for subsystem damage routing, and a sim of turrets tracking a
  fighter.

### M7-T2 · Carrier & drone models
- **Size:** L · **Depends on:** T1 · **Read:** art bible §2–3, bosses §3.1
- A Blender recipe for the ~400 m Cinder-captured Concord carrier: hangar bays, dorsal
  reactor vents, an engine block and flak turrets as `SUB_*`, plus the pirate kit-bash look.
  Shield drone model. Drone shield-beam VFX.
- **Acceptance:** previews within budget (≤ 60 k tris), and every subsystem is visible in
  the previews.

### M7-T3 · Carrier boss logic
- **Size:** L · **Depends on:** T1, T2 · **Read:** bosses §1, §3.1
- A phase controller (Bulwark → Exposed → Flight), drone links + invulnerability, relaunch
  from hangar bays, kamikaze drones at 50%, the escape timer + engine stranding, difficulty
  variants, telegraphs (VFX + audio + barks), the boss HUD bar with phase ticks, and the boss
  music state.
- **Acceptance:** see T6.

### M7-T4 · Boss arena & bounty integration
- **Size:** M · **Depends on:** T3, M6-T5
- The debris-field arena around the ruined relay (cover wrecks, bounds), a checkpoint (not in
  Hardcore), the bounty-chain finale + re-attempt as a high-tier bounty, and rewards (Drone
  Bay device blueprint + heavy fighter schematic).
- **Acceptance:** a smoke test of the arena, and reward grant unit tests.

### M7-T5 · Secret encounter: the Silent Wreck
- **Size:** M · **Depends on:** M6 · **Read:** bosses §3.3, lore §3
- The rumor → scanner ping → hidden zone chain. The black-glass derelict (Hush shape language),
  the sky-fire flicker, echo copies of the player's ship + loadout for 60 s, audio ducking to
  near silence, and the reward + lore log.
- **Acceptance:** a sim survives or wins the encounter. Shots of the moment.

### M7-T6 · Boss bot-fight sims
- **Size:** M · **Depends on:** T3, T4
- A scripted bot completes every phase on Easy/Normal/Hard. Softlock checks (drones stuck
  in geometry, the timer, invulnerability never stuck on), and a timing report per phase.
- **Acceptance:** all sims green, and the timing report is in the PR.

---

## M7 playtest checklist (see also bosses §4)
- [ ] Did the carrier fight make you change tactics between phases?
- [ ] Were attacks telegraphed? Did any death feel unfair?
- [ ] Was stranding vs. finishing it a real choice?
- [ ] How long did it take, and how many attempts on Normal?
- [ ] The Silent Wreck: eerie? confusing? Want more?
