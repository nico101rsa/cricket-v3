# Cricket Sim · Project Roadmap

Mobile **roguelite cricket-career** mashing **Reigns × Balatro × management**, targeting South Africa & Australia. ~2:45 per match. Personal/learning project — "success" = I play it and enjoy it.

---

## Current status

**Phase:** Pre-build · design
**Next theme:** Theme 4 content — **author the 45 Jokers** (architecture is locked; content half is unwritten)
**Where to do it:** Fresh chat, `grill-with-docs` or a structured authoring doc

---

## Next session

Theme 5 (Around-the-match screens) is closed — architecture locked in ADR 0010, global-rank model in ADR 0011, hi-fi mockup at `docs/mockups/around-the-match-v1.html`, design-system patterns appended to `docs/DESIGN_HANDOFF.md` §17.

**Next up — Theme 4 content half.** The Joker architecture (grammar / archetypes / count / cadence / rarity / carry-over) is locked in ADR 0007 + CONTEXT.md, but the *45 specific Joker cards* have not been authored. They need to exist before the balance harness (Theme 7) can tune them and before Joker art (Theme 6) can be designed against them.

**To continue:**

> Read `PROJECT_ROADMAP.md`, `CONTEXT.md`, `docs/adr/0006-typed-effect-palette.md`, `docs/adr/0007-joker-authoring-grammar.md`. Author all 45 Jokers — ~7-8 per archetype (Anchor / Tempo / Strangler / Wicket Hunter / Boost Stack / Reviewer), split across Common / Rare / Legendary rarities, composing only from the 6-verb palette (`setIntent` / `setNextBowler` / `fieldMode` / `buffNextBalls` / `formEvent` / `tryReview`) and the conditional-trigger grammar in ADR 0007. For each Joker: name, archetype, rarity, verb composition, effect text, flavour, ₸ price band. Use `grill-with-docs` or build the authoring table inline.

---

## The themes (ordered by dependency)

1. ~~**Scope**~~ ✅ — V1 locked: SA+AUS roguelite cricket-career (ADR 0002)
2. ~~**Game shape**~~ ✅ — Career grid (Levels × Tours), Offers/Tons/Affinity (CONTEXT.md)
3. ~~**Gameplay & balance**~~ ✅ — sim math (ADR 0004), skill model (ADR 0003), Manager Boost (ADR 0005), 6-verb effect palette (ADR 0006), all 8 KMs designed. Numerical tuning deferred to the balance harness.
4. **Jokers & meta loop** — architecture ✅ + content ⏳
   - **Architecture ✅** — Shop (5/Season, 4 action types/visit, side-by-side Tons+Jokers) · ~45-Joker pool across 6 archetypes · authoring grammar (ADR 0007) · Carry-Over (1/Season) + Hold (1/Shop) · slot 4 earned at first Level-win · Offer cadence (1 mid-Season immediate-switch + 3 end-of-Season) · Team durability (ADR 0009)
   - **Content ⏳** — author all 45 specific Jokers (name, verb composition, rarity, archetype, effect text, flavour, ₸ price band). Theme 4 was closed too early on architecture only; the content half is the next session.
5. ~~**Around-the-match screens**~~ ✅ — Season hub · Pre-match · Shop · Offer · Result · Career Grid · Career Records (ADR 0010 navigation shell · ADR 0011 global rank · hi-fi at `docs/mockups/around-the-match-v1.html` · DESIGN_HANDOFF §17). Onboarding and Settings deferred to a later pass.
6. **Visual & audio content** — joker art · backgrounds · icons · music · SFX · commentary bank
7. **Tech foundation** — Godot project · save system · build pipeline · **balance harness** (headless sim runner — parameter sweeps over Tour distributions, KM/Joker/Boost coefficients, and the optimal-vs-naive skill-gap metric per ADR 0003/0004)
8. **Long-haul retention** — Collection / Achievements layer (77-feat trophy cabinet across 6 categories with Tons rewards) · streaks · daily prompts · any other replay-extending systems. Deferred until after the build is playable.

Playtest threads through all of them — continuous, not a discrete item.

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

---

## Reference docs

- `CONTEXT.md` — domain glossary · source of truth for terminology
- `docs/adr/` — design decision records (0001 target market · 0002 V1 game shape · 0003 skill model · 0004 auto-sim architecture · 0005 Manager Boost no-menu · 0006 typed-effect palette · 0007 Joker authoring grammar · 0008 currency name + mark · 0009 Team durability · 0010 around-the-match navigation shell · 0011 global rank via Tour-distribution percentile)
- `docs/brand/` — Tons (₸) currency mark · SVG assets and usage notes
- `docs/DESIGN_HANDOFF.md` — locked design system (chrome, portraits, KMs, IP rules, palette, fonts, motion, country system, hi-fi addendum §16, around-the-match design system §17)
- `docs/THEME-5-HANDOFF.md` — claude.ai mockup brief for theme 5 (archival; theme 5 now closed)
- `docs/design-handoff-from-claude-2026-05-31.md` — return handoff from claude.ai for theme 5 (Australia palette fix + Collection screen scope-add)
- `docs/RESEARCH_LAUNCH_PLAYBOOK.md` — full launch research (not on build critical path)
- `docs/mockups/match-screen-final.html` — locked in-Match design (4 frames)
- `docs/mockups/in-match-hi-fi-v1.html` — claude.ai hi-fi pass for in-Match
- `docs/mockups/around-the-match-v1.html` — claude.ai hi-fi pass for around-the-match screens (16 frames across 7 sections)
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
- Jokers & meta loop theme (architecture only) — Shop (5/Season Slay-style, side-by-side Tons + Jokers, 4 action types/visit including Hold), Joker authoring grammar (ADR 0007), ~45-Joker pool across 6 archetypes (Anchor / Tempo / Strangler / Wicket Hunter / Boost Stack / Reviewer), Carry-Over (1 Joker, end-of-Season), slot 4 earned at first Level-win, Offer cadence (1 mid-Season immediate-switch + 3 end-of-Season), Team durability via half-★ Markov rating (ADR 0009) with catastrophic `lastSeasonEvent` commentary flavour. *Content half (authoring the 45 specific Jokers) is still open.*
- Around-the-match screens theme — Season hub, Pre-match, Shop ("Kit Room" scene with Kit Manager persona), Offer (with carry-over picker as footer), Result, Career Grid (diagonal-ladder topology), Career Records (global rank `#X / 2,112` computed analytically — ADR 0011) all designed in hi-fi (`docs/mockups/around-the-match-v1.html`). Navigation shell — Season hub as home + forced Shop/Offer interludes + no Main Menu — locked in ADR 0010. Australia palette fix (gold primary + green accent). Onboarding + Settings deferred.

---

## Notes

- "Successful" = I play it and enjoy it. Anything beyond is bonus.
- Playtest threads through every theme — budget time for it; fun doesn't emerge from spec docs.
- If a feature would take >1 weekend to design AND build, decide V1 vs V2 first.
- **Balance harness** is the tuning workhorse — pure Python or Godot-headless module that runs thousands of Seasons over a parameter grid, measures the optimal-vs-naive skill gap (ADR 0003), and flags overpowered Jokers / underpowered Tour cells. Lives in the Tech foundation theme but every numerical decision from theme 3 onward routes through it. The auto-sim's headless / deterministic-seedable design (ADR 0004) exists precisely to enable this.
