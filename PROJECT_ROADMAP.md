# Cricket Sim · Project Roadmap

Mobile **roguelite cricket-career** mashing **Reigns × Balatro × management**, targeting South Africa & Australia. ~2:45 per match. Personal/learning project — "success" = I play it and enjoy it.

---

## Current status

**Phase:** Pre-build · design (design phase complete; first build plan written + reviewed; claude.ai design track incorporated)
**Last closed:** **claude.ai Player Creation + Hall of Fame design incorporated** (2026-06-02) — 5 artefacts landed and reconciled against CONTEXT.md + ADRs + the Player Creation spec/plan (see Decisions log). Kept the spec §3.5 V1 attribute model, so the reviewed build plan executes **unchanged**; Hall of Fame now has a buildable spec (`docs/superpowers/specs/2026-06-02-hall-of-fame-design.md`) that later replaces the plan's HoF stub.
**Next theme:** **Execute** the Player Creation plan (`docs/superpowers/plans/2026-06-01-player-creation-plan.md`) — Theme 7 build start. One open execution choice: subagent-driven vs inline.

---

## Next session

**Primary task — execute the Player Creation build plan.** The claude.ai design track is **incorporated** (2026-06-02): Hall of Fame spec + Player Creation decisions + Godot build-notes + v1/v2 mockups landed, reconciled, and indexed (see Decisions log). The reviewed plan (`docs/superpowers/plans/2026-06-01-player-creation-plan.md`) is **unchanged** and ready to run. Godot 4.6.3 is installed (`/Applications/Godot.app`), satisfying the plan's 4.3+ floor.

**One open choice before building — execution mode:**
- *Subagent-driven* (`superpowers:subagent-driven-development`): dispatch each phase/task to a fresh subagent. Suits the plan's many independent TDD tasks; keeps the main context clean.
- *Inline* (`superpowers:executing-plans`): work the phases in this session with review checkpoints.

**To continue (next Claude Code session):**

> Run the start-of-session routine. Confirm the working tree is clean and the Player Creation plan is unchanged. Pick execution mode (subagent vs inline), then execute `docs/superpowers/plans/2026-06-01-player-creation-plan.md` from Phase 0. **The plan is the build authority** — where the claude.ai build-notes/decisions docs describe a richer 32-pt / 1–10 / 9-label classifier, that is a logged **post-launch candidate**; V1 builds the spec §3.5 model (20 pts · 1–8 · 4 labels: Batter / WK-Batter / Bowler / All-rounder). The Hall of Fame *spec* (`docs/superpowers/specs/2026-06-02-hall-of-fame-design.md`) replaces the plan's Phase-7 HoF stub *later* (not in this plan) — note its additive `Legend` fields (`levelsWon`, `lifetimeTons`, `immortalised`, `retiredSeason`) for then.

**Open auto-sim questions** (participation model · bowler-rotation policy) remain logged below — Theme 7, non-blocking for this build.

---

## The themes (ordered by dependency)

1. ~~**Scope**~~ ✅ — V1 locked: SA+AUS roguelite cricket-career (ADR 0002)
2. ~~**Game shape**~~ ✅ — Career grid (Levels × Tours), Offers/Tons/Affinity (CONTEXT.md)
3. ~~**Gameplay & balance**~~ ✅ — sim math (ADR 0004), skill model (ADR 0003), Manager Boost (ADR 0005), 6-verb effect palette (ADR 0006), all 8 KMs designed. Numerical tuning deferred to the balance harness.
4. ~~**Jokers & meta loop**~~ ✅ — Architecture (Shop cadence, authoring grammar ADR 0007, carry-over, Team durability ADR 0009) + Content (all 45 Jokers authored at `docs/joker-pool-v1.md` — 24 Common / 15 Rare / 6 Legendary across 6 archetypes, magnitudes V1 strawman for the balance harness).
5. ~~**Around-the-match screens**~~ ✅ — Season hub · Pre-match · Shop · Offer · Result · Career Grid · Career Records (ADR 0010 navigation shell · ADR 0011 global rank · hi-fi at `docs/mockups/around-the-match-v1.html` · DESIGN_HANDOFF §17). **Onboarding now closed** — Player Creation spec at `docs/superpowers/specs/2026-06-01-player-creation-design.md` covers the 2-screen Identity → Build flow + hard-permadeath lifecycle. **Hall of Fame screen spec now delivered** (`docs/superpowers/specs/2026-06-02-hall-of-fame-design.md`) — the last Theme 5 sibling-spec gap; it builds later as the real screen replacing the Player Creation plan's HoF stub. Settings still deferred.
6. **Visual & audio content** — joker art · backgrounds · icons · music · SFX · commentary bank · **8 portrait sets** (4 Appearance × 2 Country) + Player Creation backgrounds (per Player Creation spec)
7. **Tech foundation** — Godot project · save system · build pipeline · **balance harness** (headless sim runner — parameter sweeps over Tour distributions, KM/Joker/Boost coefficients, and the optimal-vs-naive skill-gap metric per ADR 0003/0004)
8. **Long-haul retention** — Collection / Achievements layer (77-feat trophy cabinet across 6 categories with Tons rewards) · streaks · daily prompts · any other replay-extending systems. Deferred until after the build is playable.
9. **Career pressure & retirement** (post-launch) — auto-drop / non-selection / age-based retirement triggers. Layered on top of the hard-permadeath lifecycle established in the Player Creation spec; trigger anchors on **Player form** (low runs over last K innings, lost KMs), not Team result. Deferred until V1 ships and the Career-as-life baseline loop is playtested — the cheap escape-hatch (Manual retire button) covers the *"I'm stuck"* case in the meantime.

Playtest threads through all of them — continuous, not a discrete item.

---

## Open design questions

Surfaced 2026-06-02 while pressure-testing the Player Creation plan. Both are **auto-sim design decisions (Theme 7)** — non-blocking for the Player Creation build, but must be settled before/during the sim build. Both sit downstream of ADR 0004 (only-Player-statted; the 21 other players are derived from `teamStrength × role × seed`, not individually authored).

1. **Player participation model** — how much the Player personally bats (batting position → balls faced) and bowls (overs) each Match. Candidates: *fixed participation* (build changes only how **well**, not how **much**; bowler-shaped Players still bat, and bat badly emergently) vs *attribute-driven participation* (a bowler-shaped build bats lower / bowls more automatically). Either keeps the classifier label flavour-only per spec §3.5. **Simplest-first leaning: fixed.**
2. **Bowler-rotation policy** — how an innings' ~20 bowling overs get assigned across bowler-role profiles. *Player side* surfaces as agency via the **Bowling Change** Key Moment; *opponent side* needs an AI rotation policy (currently un-spec'd). Note the scope wall: opponents are regenerated per-Match with no persistent identity or cross-Match form, so "their star bowler is out of form" is **texture-via-commentary**, not simulation — the cheap third door that avoids rebuilding the deferred management sim.

---

## Decisions log

| Date | Decision | Rationale |
|---|---|---|
| 2026-05-18 | In-match screen design locked | See `docs/DESIGN_HANDOFF.md` Sections 3–4, 16 |
| 2026-05-18 | Avatar: Card Portrait + split-bg | Skill tier (sky) + confidence tier (ground) + 3-layer system |
| 2026-05-18 | Match length: 2:45 | India ARPU + session length fit (research-backed) |
| 2026-05-18 | Manager Boost: water-meter | Strength = fill %; tactical-depth via timing |
| 2026-05-18 | No IPL trade dress | Personal project · steer safe on IP |
| 2026-05-18 | Soft launch markets: PAK / BAN / SLK / UAE | Cricket audience · no India burn (when launch becomes relevant) |
| 2026-05-19 | Engine: Godot 4.x | Best fit for 2D card/UI with juice; AI handles ramp |
| 2026-05-19 | Launch track deferred | Build the game first; launch playbook saved for later |
| 2026-05-19 | Next-session skill: `grill-with-docs` | Better than `brainstorming` for conceptual work; opinionated + glossary discipline |
| 2026-05-21 | V1 = roguelite cricket-career | ADR 0002 — you are one rising Player climbing a Career grid |
| 2026-05-21 | Primary target: SA + AUS | ADR 0001 — creator-fit beats market-fit; India deferred |
| 2026-05-21 | Career grid: 3 Levels × 8 Tours | Club/City/Province × named tours; overlapping difficulty bands |
| 2026-05-21 | Career layer: Offers / Tons / Affinity | Light career sim; full club-management deferred |
| 2026-05-21 | `CONTEXT.md` created | Domain glossary — source of truth for terminology |
| 2026-05-22 | Skill model locked | ADR 0003 — 3 layers (Tactical / Strategic / Meta), no-dominant-answer, never surface the math |
| 2026-05-25 | Auto-sim architecture locked | ADR 0004 — headless, deterministic-seedable, ball-by-ball, 2-stage logistic, 4 Attributes (Power/Composure/Attack/Control), only-Player-statted |
| 2026-05-26 | 5 remaining Key Moments designed | Wicket Crisis, Milestone Ball, Bowling Change, Field Set, DRS Review |
| 2026-05-26 | Portrait redesign | Full-bg = skill, facial expression = Form (supersedes split-bg, DESIGN_HANDOFF §16.3) |
| 2026-05-27 | Manager Boost simplified | ADR 0005 — no menu, side-aware all-Attribute buff, drain-on-press, fill² scaling |
| 2026-05-28 | 6-verb typed-effect palette | ADR 0006 — every in-Match mechanic composes from `setIntent` / `setNextBowler` / `fieldMode` / `buffNextBalls` / `formEvent` / `tryReview` |
| 2026-05-28 | Theme 3 closed | Gameplay & balance design complete; numerical tuning is balance-harness work |
| 2026-05-28 | Currency named Tons (₸) | ADR 0008 — "Pay" working name dropped; ₸ glyph (T struck by a bail, two bails standard) locked. Assets in `docs/brand/`. |
| 2026-05-28 | Joker authoring grammar locked | ADR 0007 — passive verb buffs + conditional triggers, nothing else; synergies emerge from shared verb tags (no authored chain logic). |
| 2026-05-28 | Team strength durability via half-★ Markov rating | ADR 0009 — Teams carry durable 0.5–5★ rating in half-star increments, ~30% ±0.5 / ~5% ±1 per Season + `lastSeasonEvent` flavour string for ±1 swings; makes Offers a real Meta-layer signal. |
| 2026-05-28 | Meta-loop shape locked | Shop cadence (5 visits/Season Slay-style) · 4 actions per visit (buy/sell/upgrade/hold) · 45-Joker pool across 6 archetypes · Joker carry-over (1 owned, end-of-Season) · slot 4 earned at first Level-win · mid-Season Offer is immediate-switch. |
| 2026-05-29 | Team durability refined to half-★ + Theme 4 closed | ADR 0009 revised — stars on 0.5–5.0 in half-star increments (was integer 1–5); ±0.5 normal swings, ±1 catastrophic. Theme 4 (Jokers & meta loop) now closed; next theme is Around-the-match screens. |
| 2026-05-30 | Theme 5 architecture locked, hi-fi pass moved to claude.ai | Decisions: **Season hub** is the persistent home within a Season (`CONTEXT.md` updated); **Shop & Offer** are forced full-screen interludes triggered by cadence (no skip, no hub-overlay); **no Main Menu** (resume-first cold start, settings via corner gear); Season hub is **single dense screen** (no scroll, no tabs); Pre-match is **versus-style** (red-gradient `[A] vs [B]` header continues into Match chrome). Mockup pass spec'd in `docs/THEME-5-HANDOFF.md`; claude.ai produces hi-fi HTML at `docs/mockups/around-the-match-v1.html`. |
| 2026-05-31 | Theme 5 closed; ADRs 0010 + 0011 written; Theme 4 reopened (content); Theme 8 added | Around-the-match hi-fi accepted (`docs/mockups/around-the-match-v1.html` + `docs/design-handoff-from-claude-2026-05-31.md`). **ADR 0010** captures the navigation shell. **Career Records adopted** (global rank `#X / 2,112` computed analytically from Tour distributions — no per-rival sim) — **ADR 0011**. **Collection / Achievements deferred to new Theme 8** (Long-haul retention). **Theme 4 reopened** as architecture ✅ + content ⏳ — the 45 specific Jokers are unauthored and are now the next session. **Kit Room** / **Kit Manager** added to CONTEXT.md as canonical world-building. Australia palette fix: was a near-clone of SA green; now amber-gold primary + green accent (DESIGN_HANDOFF §16.2 updated). Onboarding + Settings screens deferred to a later pass within Theme 5's spirit. |
| 2026-06-01 | Theme 4 content closed + Theme 5 onboarding closed + Theme 9 added | All 45 Jokers authored (`docs/joker-pool-v1.md`) across 6 archetypes / 3 rarities, magnitudes V1 strawman for the harness. **Player Creation spec** (`docs/superpowers/specs/2026-06-01-player-creation-design.md`) closes Theme 5's deferred onboarding work: 2-screen Identity → Build flow · 5 decisions (Country / City / Appearance / Name / Attributes) · hard-permadeath lifecycle with Win + Manual retire end-states · live classifier label · 4 Appearance buckets per Country (no textual labels) · cricket-pun name gen (random + re-roll, no manual override). **ADR 0012** to formalise the lifecycle decision at plan time. **New Theme 9 — Career pressure & retirement** (post-launch) holds auto-drop / non-selection / age-based retirement; trigger anchors on Player form not Team result. |
| 2026-06-01 | Soft-launch markets corrected to SA + AUS | The 2026-05-18 "PAK / BAN / SLK / UAE — no India burn" decision was made under the India-primary-target era. With ADR 0001 making SA + AUS the primary target, the soft launch logically follows the primary audience: **soft launch in SA + AUS first**, expand later. Both stores allow per-country availability restriction at upload. iOS publishing is unblocked at the account level — Nico already has an Apple Developer Program membership. Google Play Developer ($25 one-time) is unconfirmed; revisit when Android shipping becomes relevant. |
| 2026-06-02 | Player Creation build plan written + reviewed; 2 sim questions logged | Ran `writing-plans` on the Player Creation spec → 12-phase Godot build plan at `docs/superpowers/plans/2026-06-01-player-creation-plan.md` (bootstrap → data/domain TDD → Creation scenes → permadeath hooks → **ADR 0012** authored in-plan). Two external review passes; key fixes folded in: archive **deep-duplicates the Player** before `clear_player()` (else an `ext_resource` orphan crashes the Hall-of-Fame path), loads use `CACHE_MODE_IGNORE`, autoloads register at the phase their script lands, Back preserves picks, Build recap added, Godot **4.3+ hard-required**. Plan is ready but **execution choice (subagent vs inline) not yet made**. Surfaced two open auto-sim questions (Player participation model · bowler-rotation policy) — logged under "Open design questions", Theme 7, non-blocking. |
| 2026-06-02 | claude.ai Player Creation + Hall of Fame design **incorporated**; V1 attribute model kept | 5 artefacts landed from the parallel claude.ai track and reconciled against CONTEXT.md + ADRs + the Player Creation spec/plan: **Hall of Fame spec** (`docs/superpowers/specs/2026-06-02-hall-of-fame-design.md`), **decisions log** (`docs/PLAYER-CREATION-DECISIONS.md`), **Godot build-notes** (`docs/PLAYER-CREATION-GODOT-BUILD-NOTES.md`), and two mockups (`docs/mockups/player-creation-v2.html` = **locked look**, `player-creation-v1.html` = variants archive). **Decision: keep the spec §3.5 V1 attribute model** (20 pts · 1–8 · 4 labels incl. WK-Batter) — the mockup's richer **32-pt / 1–10 / 9-label** classifier is logged as a **post-launch candidate**, so the reviewed build plan executes **unchanged** (Phases 1/2/6 untouched). HoF spec is **additive** to the plan: Phases 4/7 robust (`LegendEntry` stores a full `Player` snapshot → both arc-roles derivable); the real HoF screen later replaces the Phase-7 stub and gains additive `Legend` fields (`levelsWon`, `lifetimeTons`, `immortalised`, `retiredSeason`). AUS palette `#A86E00` gold-forward confirmed canonical (already in DESIGN_HANDOFF §16.2 + all mockups; the `#FFCD00` in the outgoing brief was stale). Reconciliation banners added to the 3 incorporated docs. |

---

## Reference docs

- `CONTEXT.md` — domain glossary · source of truth for terminology
- `docs/adr/` — design decision records (0001 target market · 0002 V1 game shape · 0003 skill model · 0004 auto-sim architecture · 0005 Manager Boost no-menu · 0006 typed-effect palette · 0007 Joker authoring grammar · 0008 currency name + mark · 0009 Team durability · 0010 around-the-match navigation shell · 0011 global rank via Tour-distribution percentile · *0012 Player lifecycle hard-permadeath — owed at plan time*)
- `docs/joker-pool-v1.md` — all 45 Jokers authored (theme 4 content)
- `docs/superpowers/specs/` — implementation specs (`2026-06-01-player-creation-design.md` — Player Creation flow + permadeath lifecycle · `2026-06-02-hall-of-fame-design.md` — Hall of Fame / Legends-wall screen, replaces the build plan's HoF stub later)
- `docs/superpowers/plans/2026-06-01-player-creation-plan.md` — reviewed 12-phase Godot build plan for Player Creation (**the build authority; next to execute**)
- `docs/PLAYER-CREATION-DECISIONS.md` — claude.ai hi-fi decisions log (Player Creation + Hall of Fame); see its reconciliation banner — V1 builds the spec §3.5 4-label model, not the doc's 9-label matrix
- `docs/PLAYER-CREATION-GODOT-BUILD-NOTES.md` — claude.ai engine-binding notes (data binds / transitions / palette tokens); design reference, *not* the build authority (the plan is)
- `docs/PLAYER-CREATION-HANDOFF.md` — outgoing brief sent to claude.ai (archival; its AUS `#FFCD00` value is stale — DESIGN_HANDOFF §16.2's `#A86E00` is canonical)
- `docs/brand/` — Tons (₸) currency mark · SVG assets and usage notes
- `docs/DESIGN_HANDOFF.md` — locked design system (chrome, portraits, KMs, IP rules, palette, fonts, motion, country system, hi-fi addendum §16, around-the-match design system §17)
- `docs/THEME-5-HANDOFF.md` — claude.ai mockup brief for theme 5 (archival; theme 5 now closed)
- `docs/design-handoff-from-claude-2026-05-31.md` — return handoff from claude.ai for theme 5 (Australia palette fix + Collection screen scope-add)
- `docs/RESEARCH_LAUNCH_PLAYBOOK.md` — full launch research (not on build critical path)
- `docs/mockups/match-screen-final.html` — locked in-Match design (4 frames)
- `docs/mockups/in-match-hi-fi-v1.html` — claude.ai hi-fi pass for in-Match
- `docs/mockups/around-the-match-v1.html` — claude.ai hi-fi pass for around-the-match screens (16 frames across 7 sections)
- `docs/mockups/player-creation-v2.html` — claude.ai hi-fi pass for Player Creation + Hall of Fame (**locked look**: portrait-anchored Identity · drag sliders · portrait-card Legend rows · gold retire badge)
- `docs/mockups/player-creation-v1.html` — Player Creation variants exploration (1A/1B/1C · 2A/2B · 3A/3B/3C; superseded by v2 for the locked directions)
- `docs/mockups/playable-prototype.html` — interactive 70-sec demo
- `docs/mockups/player-avatars-styles.html` — 3 art-style comparison
- `docs/mockups/the-t-mark-v1.html` — Tons (₸) currency-mark exploration

---

## Deferred (launch track — not blocking the build)

Marketing · TikTok/Insta devlog · soft launch playbook · Apple/Google submission · ad mediation · multi-language beyond English/Hindi essentials · battle pass / live ops · multiplayer

When ready, read `docs/RESEARCH_LAUNCH_PLAYBOOK.md`.

---

## Done so far

- Brainstorming session: in-match design (8 key-moment types defined; 3 fully designed)
- Player avatar system: Card Portrait + 3 layers (achievement / wear / identity) + split-bg evolution
- Hi-fi pass on claude.ai: stadium-scene CRR worm, jokers panel, water-meter boost, 10-nation palette
- Design handoff doc (full system spec)
- Engine decision (Godot)
- Launch playbook research saved (`docs/RESEARCH_LAUNCH_PLAYBOOK.md`)
- 7-theme roadmap (this doc)
- `grill-with-docs` skill installed for next session
- Scope + Game shape theme — V1 locked as a roguelite cricket-career
- `CONTEXT.md` domain glossary + ADRs 0001 (target market) & 0002 (V1 shape)
- Git repo initialised + pushed to GitHub (private: `github.com/nico101rsa/cricket-sim`)
- Gameplay & balance theme — auto-sim architecture (ADR 0004), skill model (ADR 0003), all 8 Key Moments designed, Manager Boost simplified (ADR 0005), 6-verb effect palette (ADR 0006)
- Portrait redesign — full-bg skill + facial-expression Form supersedes the split-bg model
- Currency naming + mark — **Tons (₸)**, two-bail T glyph (ADR 0008, `docs/brand/`)
- Jokers & meta loop theme **closed in full** — architecture (Shop cadence, authoring grammar ADR 0007, ~45-Joker pool across 6 archetypes, Carry-Over, slot 4 unlock, Offer cadence, Team durability ADR 0009) plus content (all 45 Jokers authored at `docs/joker-pool-v1.md` — 24 Common / 15 Rare / 6 Legendary, magnitudes V1 strawman pending balance harness).
- Around-the-match screens theme **closed in full** — Season hub, Pre-match, Shop ("Kit Room" scene with Kit Manager persona), Offer (with carry-over picker as footer), Result, Career Grid (diagonal-ladder topology), Career Records (global rank `#X / 2,112` computed analytically — ADR 0011) all designed in hi-fi (`docs/mockups/around-the-match-v1.html`). Navigation shell — Season hub as home + forced Shop/Offer interludes + no Main Menu — locked in ADR 0010. Australia palette fix (gold primary + green accent). **Onboarding closed** — Player Creation spec at `docs/superpowers/specs/2026-06-01-player-creation-design.md`: 2-screen Identity → Build flow, hard-permadeath lifecycle (Win + Manual retire), 4 Appearance buckets per Country, cricket-pun name gen, 20-point attribute slider, live classifier label. Settings still deferred.

---

## Notes

- "Successful" = I play it and enjoy it. Anything beyond is bonus.
- Playtest threads through every theme — budget time for it; fun doesn't emerge from spec docs.
- If a feature would take >1 weekend to design AND build, decide V1 vs V2 first.
- **Balance harness** is the tuning workhorse — pure Python or Godot-headless module that runs thousands of Seasons over a parameter grid, measures the optimal-vs-naive skill gap (ADR 0003), and flags overpowered Jokers / underpowered Tour cells. Lives in the Tech foundation theme but every numerical decision from theme 3 onward routes through it. The auto-sim's headless / deterministic-seedable design (ADR 0004) exists precisely to enable this.
