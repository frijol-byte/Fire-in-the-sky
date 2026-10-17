# STATUS

> Every session updates this file. Keep it short. It's the owner's dashboard and the next
> session's briefing.

## Now
- **Phase:** Planning complete (2026-10-04). Next: **M0 — Foundation**.
- **Next task to start:** `M0-T2` (Godot project bootstrap) or `M0-T6` (Blender pipeline) — parallel-safe.
- **Owner actions waiting:**
  1. Allow Godot downloads in the cloud environment (network allowlist, see
     `docs/06-ai-workflow.md` §2).
  2. Read `docs/05-lore-primer.md` and `docs/00-decisions.md` "Defaults" whenever
     convenient (needed before M6/M7).

## Milestones

| # | Milestone | State | Review | Playtest release |
|---|---|---|---|---|
| M0 | Foundation | 🔨 in progress | — | — |
| M1 | Flight | ⬜ | — | — |
| M2 | Combat core | ⬜ | — | — |
| M3 | AI depth & challenge | ⬜ | — | — |
| M4 | World & stations | ⬜ | — | — |
| M5 | Economy & upgrades | ⬜ | — | — |
| M6 | Factions & missions | ⬜ | — | — |
| M7 | Boss & secrets | ⬜ | — | — |
| M8 | Art & audio pass | ⬜ | — | — |
| M9 | Slice polish | ⬜ | — | — |

## Current milestone tasks (M0)

| Card | Title | State | PR |
|---|---|---|---|
| M0-T1 | Repo skeleton & cloud bootstrap | 👀 | PR open |
| M0-T2 | Godot project bootstrap | ⬜ | |
| M0-T3 | Test, lint & validation harness | ⬜ | |
| M0-T4 | CI: tests + downloadable builds | ⬜ | |
| M0-T5 | Screenshot harness | ⬜ | |
| M0-T6 | Blender generator pipeline v0 | ⬜ | |
| M0-T7 | Godot model import & tier display | ⬜ | |
| M0-T8 | Owner guides | ⬜ | |

Parallel-safe once T1 is merged: **T2 ∥ T6**. After T2: **T3 ∥ T5**.

States: ⬜ not started · 🔨 in progress · 👀 PR open · ✅ merged · ⛔ blocked

## Notes for the next session
- Planning research (2026-10-04): Godot **4.7.2** is the latest stable; gdUnit4 **v6.2.1**;
  `bpy` **5.2.2 LTS** installs from PyPI (Python 3.13) and was verified working headless here
  (generate → export .glb → Cycles render in ~4 s). godotengine.org and GitHub release
  downloads were **blocked** by the cloud network policy at planning time; `git clone` /
  `git ls-remote` to GitHub work.

- M0-T1 (2026-10-04): `bash tools/cloud/setup.sh` works in the cloud env: Godot 4.7.2 download
  from GitHub releases **succeeded** this time, so Godot is available locally (symlinked at
  `~/.local/bin/godot`; make sure `~/.local/bin` is on PATH). `gdtoolkit==4.5.0` is pinned.
  The script is idempotent and never fails on a blocked download.

## Release notes
_(Filled per milestone; release.yml copies the matching section.)_
