# Owner quickstart

Everything you do as the owner, in order, with the exact things to click. You never need to
read code. Plan on about 10 minutes per task.

> Button names below are the ones at the time of writing. If a label has moved, look for the
> same words nearby; the steps don't change.

**Where things live**
- The repo: `https://github.com/frijol-byte/Fire-in-the-sky`
- Cloud sessions: `https://claude.ai/code`
- Dashboard of "where are we": [`docs/STATUS.md`](../STATUS.md) (open it on GitHub, no download needed)

---

## 1. One-time setup (do once)

These are explained in full in [`06-ai-workflow.md`](../06-ai-workflow.md) §2. Short version:

1. **Network access for cloud sessions.** At `claude.ai/code`, open the environment menu in
   the session title bar → **Edit**. Set **Network access** to **Custom**, keep the default
   package-manager list, and add these allowed domains: `github.com`,
   `objects.githubusercontent.com`, `release-assets.githubusercontent.com`. Save. (Without
   this, sessions can't download the Godot engine.)
2. **Setup script.** In the same environment dialog, set the **Setup script** to:
   `bash tools/cloud/setup.sh`
3. **Protect `main`** so nobody (including a session) can merge a red PR. On GitHub:
   repo → **Settings** → **Branches** → **Add branch protection rule** (or **Add
   classic branch protection rule**).
   - Branch name pattern: `main`
   - Tick **Require a pull request before merging**
   - Tick **Require status checks to pass before merging**, then in the search box type
     `check-and-build` and click it. (If it doesn't appear, open any PR once so the check has
     run, then come back.)
   - Click **Create** / **Save changes**.
4. *(Optional)* In repo **Settings** → **General** → Pull Requests, tick **Allow auto-merge**.

---

## 2. Start a task session

1. Go to `https://claude.ai/code` and sign in.
2. In the prompt box, pick the repository **frijol-byte/Fire-in-the-sky** (the repo selector
   sits at the bottom of the prompt box). Leave the branch alone; the session creates its own.
3. Pick the environment you configured in step 1 (the environment selector is next to the
   repo selector).
4. Pick the model. Use **Sonnet** for normal task cards. Use **Opus** only for review gates,
   playtest triage and stuck tasks (see [`06-ai-workflow.md`](../06-ai-workflow.md) §1).
   The model picker is the drop-down at the bottom of the prompt box.
5. Paste the kickoff prompt, **changing only the task id** (the list of ids is in
   [`docs/STATUS.md`](../STATUS.md); pick a ⬜ task whose "Depends on" tasks are all ✅):

   ```
   Do task M1-T3 (see docs/tasks/). Follow CLAUDE.md. When everything passes locally,
   push, open a pull request, and keep fixing until CI is green.
   ```

6. Press **Enter** (or the send arrow). You can close the tab; the session keeps working.
   Several sessions can run at once if their tasks don't depend on each other.

Other kickoff prompts:

| When | Prompt |
|---|---|
| A task is stuck (use **Opus**) | `Task M2-T4 is stuck — see PR #NN. Diagnose and fix or re-scope it.` |
| Milestone review (use **Opus**) | `Run the review gate for milestone M<n> as described in docs/06-ai-workflow.md §5.` |
| After a playtest (use **Opus**) | `Triage this playtest report into task cards: <paste report>` |

You'll know a session is done when its last message says the PR is open and CI is green. It
will usually link the PR.

---

## 3. Review a PR (5–10 minutes)

1. Open the PR link from the session. (Or: GitHub repo → **Pull requests** tab → click the
   newest one.)
2. On the **Conversation** tab, read the description. It has these headings:
   - **What changed**: plain-language summary. Does it match what you asked for?
   - **What to try**: steps to test it yourself in the game build.
   - **Design questions**: decisions the session made that you may want to overrule. Reply
     in a PR comment, in plain words, if you disagree.
3. Scroll to the bottom of the PR page and look at the checks. You want a green tick and
   **All checks have passed**. If you see a red cross, don't merge: the session is meant to
   keep fixing until it's green; if it has stopped, start a session with the "stuck task"
   prompt above.

### Find the screenshots and previews
- **In the description.** Under **Screenshots / previews**, images appear inline.
- **Model previews.** Click the **Files changed** tab, find files under `docs/previews/`, and
  click **View** (or the file name) to see the image.
- **Fresh screenshots from CI.** Click the **Checks** tab → in the left list click **ci** →
  scroll to **Artifacts** at the bottom of its summary → click **screens-XXXXXXX** to
  download a zip of PNGs.

### Find the build artifact (try the game before merging)
1. PR page → **Checks** tab → in the left list click **ci**.
2. Scroll down to the **Artifacts** section on the run's summary page.
3. Click **FireInTheSky-windows-XXXXXXX** (the `XXXXXXX` is the short commit id) to
   download a zip. (Ignore the `linux` one.)
4. Right-click the downloaded zip → **Extract All…** → **Extract**.
5. Open the extracted folder and double-click **FireInTheSky.exe**. The game isn't
   code-signed, so Windows shows "Windows protected your PC": click **More info**, then
   **Run anyway**.
6. The build's version (the same short commit id) is on the boot screen, so you can confirm
   you're running the build from this PR.

Artifacts disappear after 90 days. The session's "What to try" tells you what to look for.

### Give feedback
Write a normal PR comment on the **Conversation** tab, for example "the ship feels too
floaty", "nose too long", or "I'd rather have the shield bar on the left". The session picks
it up in a follow-up. You can also leave a comment on a specific picture or line under
**Files changed**.

---

## 4. Merge

Only merge when: the checks are green, and you've read **What changed** and answered any
**Design questions** you care about.

1. At the bottom of the **Conversation** tab, click **Merge pull request**.
2. Click **Confirm merge**.
3. Optionally click **Delete branch** afterwards (safe; the work is on `main`).

Sessions never merge their own PRs. That's your job.

After merging, open [`docs/STATUS.md`](../STATUS.md) on GitHub to see the next ⬜ tasks.

---

## 5. Find a release and play a milestone build

At the end of each milestone the review session publishes a **playtest release**.

1. On the repo page, find **Releases** in the right-hand column (below "About") and click it.
   Or go straight to `https://github.com/frijol-byte/Fire-in-the-sky/releases`.
2. Click the newest one, named like `playtest-M0`. (Playtest releases are marked
   **Pre-release**; that's expected.)
3. Under **Assets**, click **FireInTheSky-windows-playtest-M0.zip** to download. The text
   above the Assets lists what changed and what to look for.
4. Extract and run it exactly as in "Find the build artifact" steps 4–6.

### Publish a playtest release yourself (when the review PR asks you to)
Cloud sessions can push branches but not tags, so the review session may ask you to
publish the release. Do it **after** merging the review PR:

1. Open **Releases** (as in step 1 above) and click **Draft a new release**.
2. Click **Choose a tag**, type the name the PR gives you (e.g. `playtest-M0`), and click
   **Create new tag: playtest-M0 on publish**. Leave **Target** on `main`.
3. **Release title:** the same name. Leave the description empty (it gets filled in).
4. Tick **Set as a pre-release**, then click **Publish release**.
5. Wait about 5 minutes. The **Actions** tab shows a **release** run; when it has a green
   tick, the release has its notes and the two zip files under **Assets**. If it shows a red
   cross, start a session and paste the run's link.

---

## 6. File a playtest report

1. Play for 30–45 minutes, with the milestone's playtest checklist at hand (it's at the
   bottom of that milestone's file in `docs/tasks/`, for example
   [`M0-foundation.md`](../tasks/M0-foundation.md)).
2. Whenever something is wrong **and the build has the feature** (it arrives in M1), press
   **F12** (gamepad: **Back + Start**, i.e. Select + Start). It saves a screenshot, the last
   200 log lines and a state dump into a new folder inside the bug-report folder, and shows
   the folder's path on screen for a few seconds. The pause menu (**Esc** / **Start**) has an
   **Open bug report folder** button that opens it. On Windows the folder is
   `%APPDATA%\Godot\app_userdata\Fire in the Sky\bug_reports\`. Until a build has the feature,
   take a normal screenshot with **Win + Shift + S** and note what happened.
   **Switching ships (M1):** in the flight arena press **1 / 2 / 3** (gamepad: d-pad up / right /
   down) to jump into the Kestrel (light fighter), Bulwark (heavy fighter) or Drayman (armed
   freighter). You restart at the beginning of the course in the ship you picked.
   **Tuning flight feel (M1):** press **F1** (gamepad: **Select**) to open the tuning
   overlay. The game pauses; move a slider (left/right on the d-pad or stick) and close it to
   fly with the new value. **Copy values** saves your numbers to `tuning\<ship>.tres` next to
   the bug-report folder, copies them to the clipboard and shows the file path. Paste them
   into the "Feel & tuning" part of your report.
3. Copy [`docs/templates/playtest-report.md`](../templates/playtest-report.md) into any
   text editor (Notepad is fine) and fill it in. Rough notes are fine, even dictated on a
   phone. Gut reactions about *feel* ("floaty", "pointless", "I got lost") are the most
   valuable thing you give.
4. Start an **Opus** session at `claude.ai/code` and send:

   ```
   Triage this playtest report into task cards: <paste your report here>
   ```

   Attach screenshots / bug-report files if the box lets you (the paperclip icon), or paste
   their file names.
5. The session turns your notes into fix/tuning cards and updates `docs/STATUS.md`. You'll
   see them as a PR to review and merge as in sections 3 and 4.

---

## If something goes wrong

| Symptom | What to do |
|---|---|
| Session says Godot can't be installed | Redo setup step 1 (network access), then start a new session. |
| CI stays red and the session stopped | Start an Opus session with the "stuck task" prompt, quoting the PR number. |
| The PR has no build artifact | The `ci` run failed or hasn't finished; wait for the green tick, or see the row above. |
| Windows won't run the `.exe` | Check you extracted the zip first (running from inside the zip fails). Then **More info** → **Run anyway**. |
| You merged by mistake | Tell a session: "Revert PR #NN." Never edit `main` by hand. |
