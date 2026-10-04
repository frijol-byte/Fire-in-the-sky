# Fire in the Sky *(working title)*

A single-player space combat and trading game in the spirit of **Galaxy on Fire 2**, with
the flight feel and atmosphere of **Everspace**: Newtonian-lite dogfights, trading between
living stations, ships you upgrade and *see* change, and boss fights you remember.

- **Engine:** Godot 4 (GDScript), with 3D models generated from Blender Python scripts
- **Platforms:** PC first (gamepad-first), Android second
- **Built by:** AI sessions (Claude) directed by a non-coding owner, with automated tests,
  CI builds and milestone review gates

**Status:** planning complete → next up is **Milestone 0** (see [`docs/STATUS.md`](docs/STATUS.md)).

## Documents

| Doc | What's in it |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Rules every AI session follows |
| [`docs/STATUS.md`](docs/STATUS.md) | Where we are, what's next, owner actions |
| [`docs/00-decisions.md`](docs/00-decisions.md) | Every decision from the planning interview, plus defaults you can override |
| [`docs/01-game-design.md`](docs/01-game-design.md) | Game design: pillars, flight, combat, economy, upgrades, missions, slice content |
| [`docs/02-bosses.md`](docs/02-bosses.md) | Boss design rules and the full boss/mini-boss/secret catalog |
| [`docs/03-tech-architecture.md`](docs/03-tech-architecture.md) | Code structure, systems, testing, CI, performance budgets |
| [`docs/04-art-audio-bible.md`](docs/04-art-audio-bible.md) | Visual style, Blender pipeline, factions' look, UI, audio |
| [`docs/05-lore-primer.md`](docs/05-lore-primer.md) | Proposed setting, factions, mystery, prologue (needs owner approval) |
| [`docs/06-ai-workflow.md`](docs/06-ai-workflow.md) | How sessions, reviews, playtests and Blender fit together |
| [`docs/07-roadmap.md`](docs/07-roadmap.md) | Milestones M0–M9, timeline, risks, post-slice backlog |
| [`docs/tasks/`](docs/tasks/) | Task cards, one AI session each |
| [`docs/templates/playtest-report.md`](docs/templates/playtest-report.md) | Fill this in after each playtest |

## Starting a task

Open a new cloud session on this repo (Sonnet) and send:

```
Do task M0-T1 (see docs/tasks/). Follow CLAUDE.md. When everything passes locally,
push, open a pull request, and keep fixing until CI is green.
```

## License

Proprietary, all rights reserved. Third-party assets are listed in
`game/assets/licenses.csv` (created in M0).
