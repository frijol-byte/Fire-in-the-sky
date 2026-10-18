# 06 — AI Development Workflow

How a non-coding owner, Sonnet implementation sessions and Opus review sessions build this
game together, at 1–3 owner-hours per week.

## 1. Roles

| Who | Does | Doesn't |
|---|---|---|
| **Owner** | Starts sessions, merges green PRs, playtests, answers design questions, approves art and lore | Write or review code |
| **Sonnet session** (cloud) | Implements **one task card** per session: code, tests, data, Blender recipes, docs updates, PR | Make design decisions that contradict `docs/00-decisions.md`; merge PRs |
| **Opus session** (cloud) | Milestone review gates, triaging playtest reports into tasks, stuck tasks, design changes, refining upcoming task cards | Routine implementation |
| **GitHub Actions** | Tests every PR, builds the Windows/Linux game, checks asset generators, publishes playtest releases | — |

## 2. One-time setup (owner)

1. **Cloud environment network access:** in the cloud environment settings (environment
   menu in the session title bar → Edit), set Network access to **Custom** and add
   `github.com`, `objects.githubusercontent.com` and `release-assets.githubusercontent.com`
   to the allowed domains, keeping the default package-manager list. This lets sessions
   download the Godot engine. Docs:
   https://code.claude.com/docs/en/cloud-environments#network-access
2. **Setup script:** after task M0-T1 merges, set the environment's setup script to
   `bash tools/cloud/setup.sh` (M0-T1's PR explains how). New sessions then start with
   Godot, Blender (`bpy`), Xvfb and lint tools ready.
3. **GitHub:** enable "Allow auto-merge" in the repo settings (optional) and protect `main`
   so it requires the CI check.
4. **Gamepad:** an Xbox-layout controller (Xbox, or most generic pads) is the reference
   device. PlayStation pads work too.

## 3. The task loop (≈10 min of owner time per task)

```
Owner: start a cloud session (Sonnet) on this repo and send the kickoff prompt
   ↓
Sonnet: reads CLAUDE.md + task card → implements → tests → screenshots → opens PR → fixes CI until green
   ↓
Owner: open the PR → read "What changed" + "What to try" → look at screenshots/previews
   → (optional) download the build artifact and try it → click Merge
```

### Kickoff prompt (copy and paste, change the task id)
```
Do task M1-T3 (see docs/tasks/). Follow CLAUDE.md. When everything passes locally,
push, open a pull request, and keep fixing until CI is green.
```

- **Parallel work:** tasks in the same milestone with no dependency on each other (each card
  lists "Depends on") can run in separate sessions at the same time.
- **Asking questions:** if a session hits a design question, it picks the most conservative
  option, notes it under "Design questions" in the PR, and keeps going. The owner answers in
  a PR comment or in a later session.
- **If a task fails twice** (the session gives up, or CI stays red after real attempts):
  start an **Opus** session with: `Task M2-T4 is stuck — see PR #NN. Diagnose and fix or
  re-scope it.`

## 4. Playtests (end of each milestone, ≈30–45 min)

1. Download the build from **GitHub → Releases → `playtest-M<n>`** (or from a PR's Checks →
   Artifacts).
2. Unzip and run the `.exe`. The game isn't code-signed, so Windows SmartScreen will warn:
   click **More info → Run anyway**.
3. Play with the milestone's checklist (in its task file, "Playtest checklist").
4. Press **F12** in-game whenever something is wrong. It saves a screenshot and a state dump
   to the bug-report folder, which the in-game pause menu can open.
5. Fill in `docs/templates/playtest-report.md`. Rough notes are fine, even dictated on a phone.
6. Start a session (Opus recommended): `Triage this playtest report into task cards: <paste
   report>`. It turns feedback into fix or tuning cards and updates `docs/STATUS.md`.

**Feel feedback is the most valuable thing the owner gives.** "Turning feels floaty",
"missiles are pointless", "I got lost" are all perfect bug reports.

## 5. Milestone review gate (Opus)

Kickoff prompt:
```
Run the review gate for milestone M<n> as described in docs/06-ai-workflow.md §5.
```

The gate session:
1. Reads the milestone's task cards, the merged PRs since the previous gate, and
   `docs/03-tech-architecture.md`.
2. Runs `tools/check.sh`, the long sims, and the screenshot harness. It looks at the images.
3. Reviews the code for architecture drift (rules in `03` §3), duplication, missing tests,
   performance risks, hardcoded strings, unlicensed assets, and hand-edited generated files.
4. Fixes small problems directly. Bigger ones become new task cards (`M<n>-F<k>`).
5. Writes `docs/reviews/M<n>.md`: a summary in plain language for the owner, findings, and a
   risk list.
6. Refines the **next** milestone's task cards using what was learned (rolling planning).
7. Tags `playtest-M<n>` to trigger the release build, and updates `docs/STATUS.md`. Cloud
   sessions can't push tags, so the gate PR usually asks the owner to publish the release
   from GitHub's Releases page after merging (owner quickstart §5); `release.yml` then
   attaches the builds and notes.

Then the owner playtests (§4). The milestone is **done** when the review gate is clean and
the playtest checklist passes, or its failures have become tasks the owner accepts as
follow-ups.

## 6. Blender workflow

- **Default (any session):** models are Python recipes in `tools/blender/recipes/`. A session
  edits the recipe, runs the build, **looks at the preview PNGs itself**, and iterates before
  opening the PR. The owner reviews `docs/previews/*.png` in the PR.
- **Art feedback:** comment on the PR in plain words: "nose too long", "needs more
  pirate-y spikes", "engines look tiny". The session adjusts the recipe.
- **Live session (optional, owner's Windows PC):** Blender plus an MCP connection (set up in
  M0-T8) lets the owner watch a model being built and steer it in real time. **Rule:** the
  session must write the final result back into the recipe script and commit it. A model
  that only exists in a `.blend` file doesn't count.

## 7. Keeping the project healthy

- `docs/STATUS.md` is the single source of "where are we". Every session updates it.
- `docs/00-decisions.md` changes only with owner consent (recorded in its Change history).
- Task cards are written for a session that has **no memory of previous sessions**. They
  must stand alone, with the docs they link to.
- Prefer many small PRs. A PR over ~800 changed lines of code (excluding generated assets)
  is a sign the card should be split.
- Never let `main` go red. If it does, fixing it is the next task, before anything else.

## 8. Rough cost of the owner's time

| Activity | Frequency | Time |
|---|---|---|
| Start a task session | 2–4×/week | 2 min each |
| Review + merge a PR | 2–4×/week | 5–10 min each |
| Answer design questions | weekly | 10–20 min |
| Milestone playtest + report | every 3–6 weeks | 30–45 min |
| Start a review gate session | every 3–6 weeks | 2 min |

That's about 1–2 hours a week at a pace of 2–4 tasks a week.
