# M8 — Art & Audio Pass

**Goal:** design pillar #3. It looks and sounds like a real game. Every placeholder gets
replaced or polished.
**Exit:** owner playtest: "It looks and sounds like a real game."

> Rolling plan: the M7 review gate refines these cards. Art feedback collected in earlier
> playtests feeds in here.

---

### M8-T1 · Final human & pirate ships
- **Size:** L · **Depends on:** M7 · **Read:** art bible §1–3
- Polish the recipes for kestrel/bulwark/drayman (all tiers) and the pirate
  interceptor/fighter/gunship/bomber, plus Concord patrol and Meridian freighter traffic
  ships: greebles, trims, decals, and canopy frames (human light, human heavy).
- **Acceptance:** contact sheets of every ship, silhouette test images (black fill at
  distance) showing roles are distinguishable, and owner approval in the PR.

### M8-T2 · Ithari ship & station polish, crystal fields
- **Size:** M · **Depends on:** M6-T6
- Faceted crystal shader polish (translucency, inner glow, veins), the Ithari canopy frame,
  and crystal asteroid variants.
- **Acceptance:** previews, and owner approval.

### M8-T3 · Station kit & jumpgate final
- **Size:** L · **Depends on:** M4-T5
- 3 human station variants with lights, traffic lanes, docking guide lights and signage, and
  the final jumpgate with its activation VFX.
- **Acceptance:** previews and in-game shots.

### M8-T4 · Skies, planets & lighting
- **Size:** L · **Depends on:** M4-T9 · **Read:** art bible §5
- The final nebula shader per system (more layers, dust lanes), a gas giant/planet shader
  with an atmosphere rim, sun lens flare, per-zone light tuning, and the Ilu'Vash "sky fire"
  flicker.
- **Acceptance:** a shot of every zone. Owner picks favorites and least favorites.

### M8-T5 · VFX pass
- **Size:** L · **Depends on:** M7 · **Read:** art bible §6
- Everything in the art bible VFX list at final quality, within the particle budgets.
- **Acceptance:** shot sequences for each effect, and a perf check in the heavy combat
  scene.

### M8-T6 · Audio & adaptive music
- **Size:** L · **Depends on:** M7 · **Read:** art bible §8
- The final CC0 SFX set, bus mixing, Doppler, impact-layer sounds, and adaptive music with
  `AudioStreamInteractive` (Explore per system / Tension / Combat / Boss / Station + victory
  sting) using licensed tracks. `CREDITS.md` generated from `licenses.csv`.
- **Acceptance:** validate_data passes (all licenses), and a music state-transition unit
  test.

### M8-T7 · UI polish, settings & main menu
- **Size:** L · **Depends on:** M6 · **Read:** art bible §7
- Final minimal-modern theme, fonts (OFL), live glyph switching (Xbox/PS/keyboard), the
  main menu, and settings (graphics presets, audio, controls + rebinding, accessibility:
  colorblind-safe shapes, aim-assist strength, subtitles/barks, camera shake, text size).
- **Acceptance:** a focus-walk test across all menus, and shots at 1080p and 720p.

---

## M8 playtest checklist
- [ ] Screenshots: would you post them?
- [ ] Is each faction recognisable at a glance?
- [ ] Does the music react well (explore → combat → boss)?
- [ ] Any sound that's annoying after an hour?
- [ ] Are menus clear? Is any text too small?
