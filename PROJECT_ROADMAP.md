# Cricket Sim · Project Roadmap

Mobile **roguelite cricket-career** mashing **Reigns × Balatro × management**, targeting South Africa & Australia. ~2:45 per match. Personal/learning project — "success" = I play it and enjoy it.

---

## Current status

**Phase:** Pre-build · design
**Next theme:** Jokers & meta loop
**Where to do it:** Fresh chat

---

## Next session

Start a new chat. Prime it with:

> Read `PROJECT_ROADMAP.md`, `CONTEXT.md`, and `docs/DESIGN_HANDOFF.md`, plus ADRs 0001–0006. Scope, Game shape, and Gameplay & balance are locked. We're at the Jokers & meta loop theme: design the Joker pool (effect types, rarities, synergies, acquisition flow) and the between-Match flow (Joker drafts, Pay spending, Offer screen). The 6-verb typed-effect palette (ADR 0006) is the only lever Jokers can pull. Use the `grill-with-docs` skill.

(`grill-with-docs` from Matt Pocock's skills repo — installed at `~/.claude/skills/grill-with-docs/`. Better than `/superpowers:brainstorming` for conceptual / non-visual work.)

---

## The 7 themes (ordered by dependency)

1. ~~**Scope**~~ ✅ — V1 locked: SA+AUS roguelite cricket-career (ADR 0002)
2. ~~**Game shape**~~ ✅ — Career grid (Levels × Tours), Offers/Pay/Affinity (CONTEXT.md)
3. ~~**Gameplay & balance**~~ ✅ — sim math (ADR 0004), skill model (ADR 0003), Manager Boost (ADR 0005), 6-verb effect palette (ADR 0006), all 8 KMs designed. Numerical tuning deferred to the balance harness.
4. **Jokers & meta loop** — pool + rarities + synergies + acquisition + between-match flow
5. **Around-the-match screens** — pre-match · main menu · onboarding · result · settings
6. **Visual & audio content** — joker art · backgrounds · icons · music · SFX · commentary bank
7. **Tech foundation** — Godot project · save system · build pipeline · **balance harness** (headless sim runner — parameter sweeps over Tour distributions, KM/Joker/Boost coefficients, and the optimal-vs-naive skill-gap metric per ADR 0003/0004)

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
| 2026-05-21 | Career layer: Offers / Pay / Affinity | Light career sim; full club-management deferred |
| 2026-05-21 | `CONTEXT.md` created | Domain glossary — source of truth for terminology |
| 2026-05-22 | Skill model locked | ADR 0003 — 3 layers (Tactical / Strategic / Meta), no-dominant-answer, never surface the math |
| 2026-05-25 | Auto-sim architecture locked | ADR 0004 — headless, deterministic-seedable, ball-by-ball, 2-stage logistic, 4 Attributes (Power/Composure/Attack/Control), only-Player-statted |
| 2026-05-26 | 5 remaining Key Moments designed | Wicket Crisis, Milestone Ball, Bowling Change, Field Set, DRS Review |
| 2026-05-26 | Portrait redesign | Full-bg = skill, facial expression = Form (supersedes split-bg, DESIGN_HANDOFF §16.3) |
| 2026-05-27 | Manager Boost simplified | ADR 0005 — no menu, side-aware all-Attribute buff, drain-on-press, fill² scaling |
| 2026-05-28 | 6-verb typed-effect palette | ADR 0006 — every in-Match mechanic composes from `setIntent` / `setNextBowler` / `fieldMode` / `buffNextBalls` / `formEvent` / `tryReview` |
| 2026-05-28 | Theme 3 closed | Gameplay & balance design complete; numerical tuning is balance-harness work |

---

## Reference docs

- `CONTEXT.md` — domain glossary · source of truth for terminology
- `docs/adr/` — design decision records (0001 target market · 0002 V1 game shape · 0003 skill model · 0004 auto-sim architecture · 0005 Manager Boost no-menu · 0006 typed-effect palette)
- `docs/DESIGN_HANDOFF.md` — locked design system (chrome, portraits, KMs, IP rules, palette, fonts, motion, country system, hi-fi additions)
- `docs/RESEARCH_LAUNCH_PLAYBOOK.md` — full launch research (not on build critical path)
- `docs/mockups/match-screen-final.html` — locked design (4 frames)
- `docs/mockups/in-match-hi-fi-v1.html` — claude.ai hi-fi pass
- `docs/mockups/playable-prototype.html` — interactive 70-sec demo
- `docs/mockups/player-avatars-styles.html` — 3 art-style comparison

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

---

## Notes

- "Successful" = I play it and enjoy it. Anything beyond is bonus.
- Playtest threads through every theme — budget time for it; fun doesn't emerge from spec docs.
- If a feature would take >1 weekend to design AND build, decide V1 vs V2 first.
- **Balance harness** is the tuning workhorse — pure Python or Godot-headless module that runs thousands of Seasons over a parameter grid, measures the optimal-vs-naive skill gap (ADR 0003), and flags overpowered Jokers / underpowered Tour cells. Lives in the Tech foundation theme but every numerical decision from theme 3 onward routes through it. The auto-sim's headless / deterministic-seedable design (ADR 0004) exists precisely to enable this.
