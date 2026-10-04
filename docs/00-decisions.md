# 00 — Decision Log

Every major decision behind this project, where it came from, and whether it's still open.
**Sessions must not silently contradict this file.** If a task needs a different decision,
flag it in the PR under "Design questions" and leave the decision to the owner.

Legend: **Owner** = answered by the project owner during the planning interview.
**Default** = chosen by Claude during planning. The owner can override any Default.

## Platform & tooling

| Topic | Decision | Source |
|---|---|---|
| Engine | Godot 4 (latest stable 4.x, pinned in `.godot-version`) | Owner |
| Language | GDScript with static typing everywhere (no C#) | Default — no .NET toolchain, simpler Android export, faster AI iteration |
| Physics | Jolt (built into Godot 4.4+) at a fixed 60 Hz physics tick | Default |
| Renderer | **Mobile renderer on every platform**, with higher quality settings on PC | Default — one visual pipeline to tune, guarantees the Android port looks the same |
| Platforms | PC first (Windows main, Linux build for free), Android second, iOS not planned | Owner |
| Owner's PC | Windows | Owner |
| First release scope | Vertical slice | Owner |
| Release model | Premium (pay once): Steam first, then Play Store. No ads, no IAP | Owner |
| Name | "Fire in the Sky" is a **working title**. A naming task comes before any store page | Owner |
| Languages | English only, but every string goes through translation tables from day one | Owner |

## Workflow

| Topic | Decision | Source |
|---|---|---|
| Who writes code | AI only. The owner does not code: they direct, playtest and decide | Owner |
| Implementation sessions | Sonnet, in cloud sessions, one task card per session/PR | Owner |
| Quality control | Automated tests plus CI on every PR, plus an **Opus review gate** at the end of each milestone | Owner |
| How the owner plays builds | GitHub Actions exports a Windows build for every PR and every merge; the owner downloads and plays it | Owner |
| Blender | **Both**: Python (`bpy`) generator scripts are the source of truth; Blender MCP on the owner's PC is optional for live visual iteration | Owner |
| Owner time budget | 1–3 hours/week, so tasks are small and self-contained, with a short playtest at the end of each milestone | Owner |
| Plan format | Markdown docs in this repo plus task cards (`docs/tasks/`) | Owner |

## Gameplay

| Topic | Decision | Source |
|---|---|---|
| Flight model | Everspace-style Newtonian-lite: 6 axes of movement, flight assist (FA) on by default, hold a button to drift with FA off, boost | Owner |
| Controls | Gamepad-first (twin-stick layout, which maps to mobile touch later), mouse and keyboard supported | Owner |
| Camera | Third-person chase, plus a cockpit view toggle | Owner |
| Cockpit art | Minimal: canopy frame plus holographic HUD (no detailed dashboards) | Owner |
| Combat | GoF2-style: target lock, lead indicator, light aim assist on gamepad, lock-on missiles, turrets on bigger ships | Owner |
| Death | Insurance respawn by default (lose cargo, pay a fee). Optional **Hardcore** permadeath save | Owner |
| Loadout | GoF2 slot system (primary, secondary, turret, device, equipment, cargo) | Owner |
| Ship upgrades | Tiered ship upgrades that change **stats, slots and visuals** (owner's reference: GoF2's "Kamino"-style ship upgrades) | Owner |
| Item upgrades | Everspace-style: weapons and equipment go up Mk levels, with a tuning choice per level. **No rarity/loot randomness** | Owner |
| Upgrade costs | Credits + materials + blueprints (blueprints gate the higher tiers) | Owner |
| Travel | Jumpgates between systems; in-system **cruise drive** between points of interest, which pirates can interrupt (interdiction) | Owner |
| Stations | Fly close → auto-dock animation → menu screens over a 3D hangar view | Owner |
| Slice loops | Combat & bounties, trading, buying/upgrading ships and equipment | Owner |
| Difficulty | Selectable (Easy/Normal/Hard) **plus** a per-system danger rating (1–5) that scales threats and rewards. Hardcore is a separate save flag | Owner |
| Bosses | All of: capital ships with subsystems, ace pilot duels, elite variants (mini-bosses with modifiers), mystery-threat entities, and unique mechanic ships (drone-shielded carrier, attrition cruiser, EMP dreadnought) | Owner |
| Boss placement | Story climaxes, high-tier bounty contracts, secret/optional encounters | Owner |
| Must capture | Dogfight feel, atmosphere and soundtrack (including Everspace's atmosphere), engaging bosses and mini-bosses | Owner |
| Must fix vs GoF2 | Repetitive side missions; lack of challenge; lack of unique boss fights | Owner |

## World & story

| Topic | Decision | Source |
|---|---|---|
| Tone | Classic space opera with an undercurrent of mysterious threat | Owner |
| Factions (full game) | Humans + 2 major alien races + a handful of minor species | Owner |
| Factions (slice) | Humans + 1 alien race, which is **neutral, reputation-based** | Owner |
| Story | A GoF2-style campaign after the slice. The slice builds the mission and dialogue systems, plus a short tutorial prologue | Owner (prologue: Default) |
| Lore originality | Fully original. No GoF2 names, races or plot | Required |

## Art & audio

| Topic | Decision | Source |
|---|---|---|
| Visual style | Stylized clean PBR: crisp hard-surface shapes, with strong lighting, bloom and colorful skies doing the heavy lifting | Owner |
| Third-party assets | AI builds all ships, stations and props. CC0 libraries for support assets (textures, HDRIs, icons, SFX). Every asset's license is tracked | Owner |
| Audio | CC0 sound effects plus licensed (royalty-free / CC-BY) music. Adaptive music in the engine | Owner |
| UI style | Minimal modern (Everspace 2 / No Man's Sky feel), readable on phones later | Owner |

## Defaults the owner may want to revisit

These were decided by Claude to keep the plan concrete. They're easy to change before the
listed milestone, and harder after it.

| # | Default | Why | Change before |
|---|---|---|---|
| D1 | Slice boss = **Drone-Shielded Carrier** (see `02-bosses.md`) | Uses the most reusable systems (subsystems, drones, phases) and was the owner's own example | M7 |
| D2 | Systems are split into **zones** (≤ 8 km across) linked by cruise travel, not one seamless huge map | Avoids floating-point precision problems in Godot and keeps Android performance safe | M4 |
| D3 | One active ship at a time, with trade-in when buying a new one (as in GoF2). A fleet hangar comes later | Simpler economy and UI for the slice | M5 |
| D4 | A 2–3 mission **tutorial prologue** that also plants the mystery hook | The slice needs onboarding anyway | M6 |
| D5 | Lore names and premise in `05-lore-primer.md` are **proposals** | The owner should approve or replace them | M6 |
| D6 | Mining is **not** in the slice; it's a candidate for the post-slice backlog | Not selected in the interview | Post-slice |
| D7 | Top ship-upgrade tiers will eventually only be available at a hidden shipyard (secret location) | Adds discovery and fits "secret encounters"; not in the slice | Post-slice |
| D8 | Steam Deck support is a goal (it comes almost free with gamepad-first) | Good fit for a premium Steam release | M9 |
| D9 | Code and assets are proprietary ("all rights reserved"), with no open-source license | Premium commercial release | M0 |

## Change history

| Date | Change |
|---|---|
| 2026-10-04 | Initial decisions from the planning interview |
