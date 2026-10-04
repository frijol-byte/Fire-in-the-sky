# CLAUDE.md — rules for every AI session on this repo

**Fire in the Sky** (working title) is a single-player space combat/trading game inspired by
Galaxy on Fire 2 and Everspace. Godot 4, GDScript, PC first (gamepad-first), Android later.
**The project owner does not read code.** You are the engineer. The tests, the docs and your
PR descriptions are how the owner trusts your work.

## Read before you start
1. `docs/STATUS.md`: where the project is and what's next.
2. Your task card in `docs/tasks/` and every doc it links.
3. `docs/00-decisions.md`: settled decisions. **Don't contradict them.** If your task
   seems to need a different decision, choose the conservative option and list it under
   "Design questions" in the PR.
4. `docs/03-tech-architecture.md` before writing code, and `docs/04-art-audio-bible.md`
   before making models, VFX, UI or audio.

## Golden rules
- **One task card per session and PR.** Don't start other cards. If a card is too big, do
  the first coherent half and split the rest into a new card in the same milestone file.
- **Everything is reproducible from files.** No editor-only steps. Scenes and resources stay
  text (`.tscn`/`.tres`).
- **Static typing everywhere** in GDScript. Follow `gdformat`/`gdlint`.
- **Content is data.** Stats, prices, ships, items and missions go in `*Def` resources under
  `game/data/`, never as magic numbers in code.
- **Player and AI share the same `ShipControls` → flight/weapons path.** Never give AI
  special physics.
- **Stat stacking, damage math and pricing each live in exactly one function**, with unit
  tests. Extend those functions; don't duplicate them.
- **Never hand-edit `game/assets/models/*.glb`.** Change the Blender recipe in `tools/blender/`
  and rebuild.
- **All player-facing text uses `tr("KEY")`** with keys in `game/localization/strings.csv`.
- **Every third-party asset gets a row in `game/assets/licenses.csv`** (CC0 preferred, see the
  art bible §9). Never add non-commercial or share-alike licensed content.
- **Write tests for what you build:** unit tests for logic, sim tests for behavior (flight,
  AI, bosses, economy), and the smoke test must still boot every scene.
- **Look at your visual work.** For anything visual, run the screenshot harness and the
  Blender previews and *read the PNGs* before opening the PR.
- Don't add GoF2/Everspace names, races, ships or plot. The lore is original.

## Commands (created in M0; until then, follow the M0 cards)
| Command | Purpose |
|---|---|
| `bash tools/cloud/setup.sh` | Bootstrap a fresh cloud session (Godot, bpy venv, Xvfb, lint tools) |
| `bash tools/check.sh` | **Run before every push:** format-check, lint, data validation, unit + sim + smoke tests |
| `bash tools/screenshot.sh <scene or shot list>` | Render PNGs to `build/screens/` for review |
| `tools/blender/.venv/bin/python tools/blender/build.py --recipe <path>` | Rebuild a model + preview |
| `python3 tools/balance/report.py` | Balance sheet + pacing sim (from M5) |

If Godot can't be installed (network policy), say so in the PR and rely on CI. Don't skip
writing tests.

## Definition of done (every task)
- [ ] The card's acceptance criteria are met
- [ ] `tools/check.sh` passes locally (or CI passes, if Godot is unavailable locally)
- [ ] New logic has tests. Visual changes have screenshots in the PR
- [ ] `docs/STATUS.md` updated (task state, plus anything the next session must know)
- [ ] Docs updated if behavior or design details changed (never `00-decisions.md` without
      owner consent)
- [ ] The PR uses the template below. Then fix CI until it's green

## PR description template
```
## What changed (plain language, for the owner)
## What to try (step-by-step, in the game build)
## Screenshots / previews
## Tests added
## Design questions (decisions I made that the owner may want to change)
## Follow-ups (new task cards created, if any)
```

## Git
- Use the branch your session was given, or `task/<card-id>-<slug>` otherwise.
- Clear commit messages. Merge commits are fine. Never force-push `main`.
- Don't merge your own PR. The owner merges.
