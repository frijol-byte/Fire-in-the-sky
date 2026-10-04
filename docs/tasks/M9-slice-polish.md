# M9 — Slice Polish & Release Candidate

**Goal:** a complete, stable, well-paced 3–5 hour vertical slice.
**Exit:** owner: "I'd show this to friends." Tag `v0.1-slice`.

> Rolling plan: the M8 review gate refines these cards.

---

### M9-T1 · Performance pass
- **Size:** L · **Depends on:** M8 · **Read:** architecture §6
- Profile the heaviest scenes (boss fight, a busy station zone, a 14-ship fight), with LOD
  checks, draw-call and particle budgets, and a **perf smoke test in CI** that reports
  frame-time stats and fails on regressions beyond a threshold. Graphics presets validated on
  the owner's PC.
- **Acceptance:** the budgets in architecture §6 are met, and the owner reports smooth play.

### M9-T2 · Onboarding, codex & tooltips
- **Size:** M · **Depends on:** M6-T7
- Contextual hints (first drift, first lock, first dock, first upgrade), a codex (factions,
  ships, items, the mystery logs), and tooltips on every stat.
- **Acceptance:** a fresh-save bot run triggers every hint once.

### M9-T3 · Balance pass v2
- **Size:** M · **Depends on:** M8
- Fold in all the playtest data, rerun the pacing sims and difficulty win-rate sims,
  regenerate the balance sheet, and confirm Hardcore is survivable.
- **Acceptance:** pacing targets within ±15%, and the sheet is committed.

### M9-T4 · Bug bash
- **Size:** L (repeatable) · **Depends on:** T1–T3
- The owner plays the full slice start to finish and files a report. Opus triages it into
  fix cards (`M9-F*`), and fixes land until there are no blocker or major bugs.
- **Acceptance:** zero open blocker/major bugs.

### M9-T5 · Release packaging
- **Size:** S · **Depends on:** T4
- Versioning, a crash-log capture prompt on the next launch, a game icon in the Windows exe
  (rcedit in CI), the `v0.1-slice` GitHub Release with plain-language notes, and a draft
  itch.io/Steam-playtest checklist for the next phase (naming task first).
- **Acceptance:** the release is published, and the owner downloads and plays it.

---

## Slice definition of done
- [ ] Prologue → free loop → bounty chain → carrier boss is completable on all difficulties
- [ ] Both systems, all stations, all slice ships and tiers present with final art
- [ ] Trading, Mk upgrades, ship tiers, reputation, missions and Hardcore all work
- [ ] 60 fps on the owner's PC; no blocker/major bugs
- [ ] Every third-party asset licensed and credited
