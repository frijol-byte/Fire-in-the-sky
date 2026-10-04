# 07 — Roadmap

The vertical slice is built in 10 milestones. Each milestone ends with an **Opus review
gate** and an **owner playtest** (see `06-ai-workflow.md`). The order is chosen so the
riskiest, most important thing comes first: **does flying and fighting feel good?** If it
doesn't, we find out in weeks, not months.

Task cards: `docs/tasks/M<n>-*.md`. Planning is **rolling**: M0–M2 are fully detailed. Later
cards set the goals and acceptance criteria, and each review gate refines the next
milestone's cards using what was learned.

## Milestones

| # | Milestone | Goal | Exit criteria (owner-visible) | Tasks |
|---|---|---|---|---|
| **M0** | Foundation | Pipelines: Godot project, tests, CI builds, Blender generator, screenshots | Owner downloads a Windows build showing a generated ship rotating in space with a version number | 8 |
| **M1** | Flight | Newtonian-lite flight with FA/drift/boost, gamepad, cameras, test arena | "Flying around the asteroid field is fun with nothing to shoot" | 7 |
| **M2** | Combat core | Weapons, damage, targeting, missiles, basic AI, HUD | "A 1v3 against pirates is fun and readable" | 7 |
| **M3** | AI depth & challenge | AI roles + squad tactics, more weapons/devices, elites, difficulty, encounter director | "Fights feel different from each other; Hard is hard" | 6 |
| **M4** | World & stations | Zones, cruise + interdiction, jumpgate, docking, station UI, traffic, 2 systems, saves, insurance/Hardcore | "I can travel two systems, dock, save and load" | 10 |
| **M5** | Economy & upgrades | Markets, trading, slots/loadout, Mk upgrades + tuning, ship tiers with visual changes, balance sims | "Trading and upgrading feel rewarding; I can see my ship change" | 9 |
| **M6** | Factions & missions | Reputation, Ithari, dialogue, mission board (templates × modifiers), bounty chain, prologue | "Jobs feel varied; the alien faction is worth befriending" | 7 |
| **M7** | Boss & secrets | Subsystems, the Drone-Shielded Carrier boss, the Silent Wreck secret | "The boss made me change tactics; no death felt unfair" | 6 |
| **M8** | Art & audio pass | Final models, skies, VFX, adaptive music, SFX, UI polish, settings | "It looks and sounds like a real game" | 7 |
| **M9** | Slice polish | Performance, onboarding, balance, bug bash, release packaging | "I'd show this to friends" → tag `v0.1-slice` | 5 |

**Total: about 72 task cards.**

## Timeline estimate (honest guess)

The owner's 1–3 h/week supports roughly **2–4 merged tasks per week** (sessions work on
their own; the owner starts and merges). Assuming the average:

| Milestones | Rough calendar |
|---|---|
| M0–M2 (feel prototype) | 5–8 weeks |
| M3–M5 | 8–12 weeks |
| M6–M7 | 5–8 weeks |
| M8–M9 | 5–8 weeks |
| **Whole slice** | **~6–9 months** |

What speeds it up: running independent tasks in parallel sessions, and quick merges. What
slows it down: feel tuning that needs several playtest rounds (expected for M1/M2), and usage
limits on the Claude plan.

## Risk register

| Risk | Impact | Mitigation |
|---|---|---|
| Flight/combat don't feel good | Kills pillar 1 | M1/M2 first, live tuning overlay, several playtest rounds budgeted |
| AI-made models look amateurish | Weakens atmosphere | Clean-PBR style, modular kits, previews reviewed every PR, lighting/skies doing the heavy lifting, M8 art pass |
| Architecture decays across many sessions | Slows everything later | CLAUDE.md rules, one-place-per-rule, tests, Opus gates |
| Godot blocked in cloud sessions | Sessions can't run tests locally | Owner allowlists GitHub release hosts (06 §2). CI as fallback |
| Software rendering too slow/unstable for screenshots | AI can't check visuals | Movie Maker fixed-fps capture, Compatibility fallback, CI screenshots |
| Scope creep (it's a GoF2-scale dream) | Slice never ships | Decision log, anti-goals, backlog parking lot below |
| Licensing mistakes | Can't sell on Steam | licenses.csv enforced in CI, CC0-first |
| Newtonian flight on touch (Android) | Hard port | Twin-stick gamepad layout from day one, stronger aim assist on touch |

## Post-slice backlog (parking lot, in rough priority order)

1. **Naming + Steam page prep** (pick the final title, capsule art, trailer capture tools)
2. **Android port** (touch controls, UI scaling pass, performance on a mid-range phone, Play
   Store build)
3. **Campaign Chapter 1–3** (scripted missions, characters, the Rival ace duel)
4. **New bosses:** Attrition Cruiser, EMP Dreadnought, capital siege, mystery entities
5. **Alien race 2** + 3–4 minor species
6. **More systems** (target 8–10 for 1.0)
7. **Ship tiers T4–T5, items Mk IV–V, the hidden shipyard**
8. **More elite modifiers** (Overcharged, Swarm-caller, Reflective, Juggernaut)
9. **Fleet hangar** (own multiple ships)
10. **Mining loop** (optional, if wanted)
11. **Steam integration** (achievements, cloud saves, Steam Deck verification)
12. **Localization** into ES/DE/FR/PT-BR/RU…
