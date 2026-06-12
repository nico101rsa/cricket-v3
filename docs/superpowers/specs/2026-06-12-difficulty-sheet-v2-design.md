# Difficulty Sheet v2 + Prize Escalation — Design

**Date:** 2026-06-12 · **Rung:** post-career-pacing, pre-E4 (Nico's evening ruling) ·
**Mode:** AFK (defaults recorded here, decisions DV1–DV12)
**Input:** `docs/difficulty-sheet-v2.md` (Nico's spreadsheet, transcribed verbatim, 7 open
questions — Q1 and Q3 answered by Nico 2026-06-12 18:30; the rest settled below).

## 1. What this rung is

Nico redesigned the Career grid's difficulty sheet. Three connected changes land together:

1. **The d-sheet v2** — every cell's difficulty number (d) changes: a linear 1-step ramp
   inside each Level, a jump into the Premier tour, narrower band overlap
   (Club 1–10 / City 5–15 / Province 9–20), ceiling 12 → 20. Tour names become pitch
   conditions (Flat & Warm, Spin, Green Mamba, …, Premier).
2. **The Tour-4 League gate** — beating Tour 4 (Day Mixed) is what unlocks the next
   League, replacing "beat any cell unlocks the same tour one Level up".
3. **Prize escalation** — higher tours of your current Level pay escalating match prizes,
   plus new playoff/final prize objects topped by the Premier Grand Final super prize.
   This is **the incentive that replaces the removed endgame gate** (career-pacing DP1).

It must land before E4 because E4's career-scale skill-gap measurement anchors on the
grid's difficulty + the career economy; both move here.

**Zero sim ripple by construction:** no ball/innings/match math changes. Only (a) the
mapping from a cell's d to tour card-strength, (b) grid unlock topology, (c) ₸ paid
*after* matches resolve. Joker floor (45.5%), env peg, build spread, and pay spread are
untouched — no joker/build/env oracle re-runs needed. Re-anchored: the E3 ladder grid and
the career metrics (§6).

## 2. Decisions

### DV1 — D-sheet v2 verbatim (Nico's sheet)

`DifficultyLadder.D_SHEET` becomes:

| Tour (index) | Club | City | Province |
|---|---|---|---|
| Flat & Warm (0) | 1 | 5 | 9 |
| Spin (1) | 2 | 6 | 10 |
| Green Mamba (2) | 3 | 7 | 11 |
| Day Mixed (3) | 4 | 8 | 12 |
| Evening Spin (4) | 5 | 9 | 13 |
| Evening Mamba (5) | 6 | 10 | 14 |
| Evening Mixed (6) | 7 | 11 | 15 |
| Premier (7) | 10 | 15 | 20 |

`TOUR_NAMES` = the condition flavours above ("Green Mamba" = seaming pitch; "Day Mixed" =
mixed conditions, the green gate cell). The structural anchors Nico named: **City Flat &
Warm (d5) = Club Evening Spin (d5)** — same d ⇒ identical sim (same strength, same brain,
same neutral ★ field), likewise Province Flat & Warm (d9) = City Evening Spin (d9); and
**a big jump into Premier** (7→10, 11→15, 15→20, escalating by Level).

### DV2 — `mean_frac` re-map: same span, stretched domain

`mean_frac(d) = 0.4 + (d − 1) × 0.9 / 19` — linear over d ∈ [1, 20], spanning the same
0.40 → 1.30 as v1 (per Nico's Q3 answer: the sheet is proportional; d=20 ≈ today's
hardest card strength, the measured-hard Province Premium anchor). Overlap anchors hold
automatically (same d ⇒ same tour mean). Premier jumps in strength-fraction terms:
Club +0.14, City +0.19, Province +0.24 — visibly harder, escalating by Level.
`SPREAD_RATIO` and the neutral ★ field are unchanged.

### DV3 — Brain table re-mapped proportionally (Q5)

v1 thresholds were tuned to d ≤ 12; scale the d-axis by 19/11 and round to integers:

| d | brain |
|---|---|
| ≤ 3 | NAIVE 1.0 |
| ≤ 6 | TEXTBOOK 0.5 |
| ≤ 10 | TEXTBOOK 1.0 |
| ≤ 13 | STATIC_EQ 0.5 |
| ≤ 15 | STATIC_EQ 1.0 |
| ≤ 18 | ADAPTIVE 0.5 |
| > 18 | ADAPTIVE 1.0 |

Resulting grid: Club runs naive → textbook, Club Premier (d10) tops out at TEXTBOOK 1.0;
City climbs to STATIC_EQ 1.0 at its Premier (d15); Province opens at TEXTBOOK 1.0 (d9),
climbs through STATIC_EQ, and **only Province Premier (d20) faces the full ADAPTIVE
brain**. The ADAPTIVE 0.5 band (d 16–18) is currently empty — kept in the table so future
d-sheet edits land on a smooth ramp. Strawman like v1's; the oracle measures the result
(§6 acceptance).

### DV4 — Conditions are names-only this rung (Q4)

The condition flavours (Spin / Green Mamba / Evening …) ship as **names only**.
Mechanical per-tour pace/spin tilts = ideas-backlog cluster 1; it rides the
bowling-balance matchup machinery and is its own rung (it would move measured balance).

### DV5 — The Tour-4 League gate (unlock rule)

`CareerState.mark_beaten(L, T)`:
- **Within a Level (unchanged):** beating (L, T) unlocks (L, T+1) — sequential ramp.
- **Across (new):** only **T = 3 (Day Mixed, the green cell)** unlocks the next League,
  and it unlocks at its **first tour**: (L+1, 0). Beating any other tour no longer
  unlocks across. Rationale for (L+1, 0) over (L+1, 3): the next League starts at the
  bottom of its own ramp — d-continuity (Club T4 d4 → City T1 d5) and the sheet's
  "unlock next league" row semantics.

Tours 5–8 become the **optional escalation farm + trophy chase** — exactly the
stick-around incentive (DV7). Completion path: Club T1→T4 → City T1→T4 → Province
T1→T7→Premier → win the Grand Final. `record_outcome` (Premium-Final win ⇒ Level won;
Province ⇒ complete) is unchanged; there is still **no gate on Province Premier**
(career-pacing DP1 stands — adjacency only).

### DV6 — Offers: DC11/DC16 logic unchanged (Q6)

`generate_offers` already keys on `any_unlocked_at(level+1)` + `just_beat`; the new
topology flows through it. Consequences: cross-up offers can first appear the Season
Tour 4 is beaten (guaranteed that Season, DC11 honoured); a fresh beat of T5–T7 with the
next League already unlocked still guarantees a cross-up offer (the "done farming, move
up" nudge — kept). The DC16 down-offer survives unchanged as the path back down for the
trophy chase (career-pacing DP2 rationale).

### DV7 — Prize escalation: per-tour absolute multipliers on match-prize objects only (Q1, answered)

`EconomyTuning.prize_escalation` (per-tour, vs the Tour-1 base, **not compounding** —
Nico's recorded interpretation, T8 = 1.6×):

```
[1.0, 1.1, 1.1, 1.1, 1.3, 1.4, 1.5, 1.6]   # tours 1..8
```

It scales the four match-prize objects (DV8) and **nothing else** — game fee and
performance pay are untouched, so build-pay equality is untouched by construction.

### DV8 — The prize objects (Q2)

All four scale as `(base + level_step × Level) × prize_escalation[tour]`, rounded.
Existing `Economy.win_bonus` (₸5 + ₸5/Level) survives as the match-win base.

| Object | When paid | Base + step (strawman dials) |
|---|---|---|
| **Match-win prize** | each Player-team win, league or playoff | `win_bonus`: 5 + 5/Level |
| **Playoff-win bonus** | winning a semi-final (⇒ finishing top 2) or the 3rd-place playoff (finishing 3rd) | 15 + 10/Level |
| **Reached-the-Final bonus** | playing The Final (finishing top 2) | 25 + 15/Level |
| **Grand-Final prize** | winning The Final | 60 + 40/Level |
| **Premier super prize** | winning a **Premier (T8)** Grand Final | flat 250 + 250/Level (Club ₸250 / City ₸500 / Province ₸750), **not escalated** |

The super prize is deliberately un-escalated: it is only payable at T8, so an escalation
factor is just a constant fold into the dial — flat keeps the semantics legible. Sizing
rationale: a naive Season's match income is ~₸530–560 (economy oracle, 2026-06-10 + pay
re-pegs); a Club Premier trophy run pays roughly ₸450+ on top (≈ doubling the Season),
Province ≈ ₸1k+ — big enough to make farming up a Level compete with jumping early,
which is Nico's stated intent. Strawman until `career_preview` measures the bank
trajectory (§6); the deferred trophy-*surface* design (roadmap Awaiting-Nico #1) stays
open — this rung ships the ₸ side.

### DV9 — Pure season-prize calculator

New pure helper so the season-level prizes are unit-testable without forcing a sim:

```
Economy.season_prizes(final_pos, won_final, level, tour, etun) -> int
```

- `final_pos ≤ 2` → reached-the-Final bonus + one playoff-win bonus (the semi win)
- `final_pos == 3` → one playoff-win bonus (won the 3rd-place playoff)
- `won_final` → Grand-Final prize, plus the Premier super prize when `tour == 7`

`CareerResolver.play_season` replaces its `win_bonus` call with
`Economy.match_win_prize(level, tour, etun)` per win and adds one
`season_prizes(...)` from the `SeasonResult` (`player_final_position`, `won_final`).

### DV10 — "Premium" → "Premier" naming

The T8 tour is canon-named **Premier** (Nico's sheet). Rename the display name and
`CareerState.PREMIUM_TOUR` → `PREMIER_TOUR` (3 code references; comments updated where
touched). Docs keep historical "Premium Final" mentions in past specs untouched;
CONTEXT.md canon updates to Premier.

### DV11 — Re-anchor protocol (Q7)

After build, in order:
1. `tools/sweep_difficulty_ladder.gd` full N=200 (~3–4 min) → new 24-cell beat-grid +
   brain isolation; refresh `docs/mockups/difficulty-ladder-v1.html` DATA.
2. `tools/career_preview.gd` full N=100 (~6–12 min, detached per repo convention with a
   log-grep watcher) → new completion median, max-out Season, time-to-beat, bank
   trajectory **with prizes**; refresh `docs/mockups/career-loop-v1.html` DATA.
3. CONTEXT.md canon: new bands + tour names + Tour-4 gate + prize escalation.
4. E4 unblocks after this lands.

### DV12 — Acceptance criteria (measured, not asserted)

- d monotone within each Level; Premier jump visible in beat-rate (T8 clearly harder
  than T7 at every Level).
- Overlap anchors: City T1 ≡ Club T5 and Province T1 ≡ City T5 (identical beat-rates up
  to seed noise — same d ⇒ same sim).
- Province Premier remains the wall (beat-rate in the ~10–20% band of E3 v1's 15% for a
  fresh build; the adaptive brain + d20 cards).
- Naive career completion still possible (no softlock: T4s reachable by the sequential
  ramp; DC16 down-offers intact).
- Build-pay spread untouched (prizes are build-independent team outcomes).

## 3. Code changes

| File | Change |
|---|---|
| `scripts/data/difficulty_ladder.gd` | `TOUR_NAMES` v2, `D_SHEET` v2, `brain_for` v2 thresholds |
| `scripts/data/tour_spec.gd` | `mean_frac` slope /19; comment |
| `scripts/data/career_state.gd` | `mark_beaten` Tour-4 across-gate → (L+1, 0); `PREMIER_TOUR` rename |
| `scripts/data/economy_tuning.gd` | `prize_escalation` + 8 prize dials |
| `scripts/domain/economy.gd` | `match_win_prize`, `playoff_win_bonus`, `final_appearance_bonus`, `grand_final_prize`, `premier_super_prize`, `season_prizes` |
| `scripts/domain/career_resolver.gd` | pay prizes in `play_season` (DV9) |
| tests | `test_difficulty_ladder` (endpoints, bands lo/hi, overlap-equality, Premier-jump, brains, names), `test_career_state` (T4 gate), `test_career_resolver` (offer setup via `mark_beaten(0,3)`, prize wiring), `test_economy` (escalation, prize objects, `season_prizes`) |
| docs | CONTEXT.md canon, both viz DATA blocks, `docs/difficulty-sheet-v2.md` marked built |

## 4. Out of scope (deferred)

- Mechanical pitch conditions per tour (ideas cluster 1, own rung — DV4).
- Trophy *surface*/UI (cabinet, banners) — ₸ side only here.
- DL11 roster fidelity in League/Season — unchanged, still its own rung.
- Joker-vs-attribute ROI re-solve — Shop rung (career-pacing DP3 stands).
- E4 player-AI career runs — next rung, anchors on this one's measurements.

## 10. Findings (close-out)

### 10.1 The measured v2 grid (oracle `tools/sweep_difficulty_ladder.gd`, N=200 Seasons/cell, fresh 35/30/30/30 build at Team ★3, textbook plans; full table on `docs/mockups/difficulty-ladder-v1.html`)

- **Beat-rate ramp:** Club Flat & Warm **96%** → Club Premier **50.5%** → City Premier **30.5%** → **Province Premier 15.0%** (win-Final **1.0%**) — the wall reads exactly like v1's (15%), as designed by anchoring d=20 to the same 1.30 strength fraction.
- **Overlap canon holds exactly:** same d ⇒ same sim, so City's row T1–T7 is byte-identical to Club T5–T7 / City's own ramp (e.g. City T1 = Club T5 = 81.5%; Province T1 = City T5 = 56.5%). The Level rows are one continuous difficulty line that each Level windows.
- **Premier jumps:** City 46.0% → 30.5% and Province 30.5% → 15.0% are unmistakable walls (+4/+5 d). **Club's jump is the softest (56.0% → 50.5%, +3 d)** because its brain stays TEXTBOOK across d7→10 — a per-d brain table can't special-case Premier without breaking the same-d ⇒ same-sim canon. Accepted: Club is the gentle league; its trophy pull is the prize money, not the wall.
- **Brain isolation** (City Green Mamba strength d7, naive vs adaptive, N=200): beat 86.0% vs 43.0% — **the brain alone is worth ~43 beat-points at fixed card strength** (v1 read ~41.5); difficulty stays genuinely two-axis.
- The v2 brain map leaves ADAPTIVE 0.5 (d16–18) unoccupied; ADAPTIVE 1.0 fires only at Province Premier d20.

### 10.2 Career metrics with the Tour-4 gate + prizes (oracle `tools/career_preview.gd`, N=100 naive careers, cap 120 — numbers on `docs/mockups/career-loop-v1.html`)

- **One ripple found and fixed in-rung: prize income accelerated attribute growth.** First preview run (attr_cost_base 11): max-out median **Season 41** — 8 Seasons earlier than Nico's pacing target (~49, DP3). One-dial re-peg `attr_cost_base` **11 → 13** (same move as the pacing rung; the attr-cost tests are symbolic so nothing re-pinned) restores **max-out median Season 50** (89/100 careers maxed, range 44–57).
- **Final numbers (attr_cost_base 13):** completion **79/100** (21 hit the 120-Season cap), median **62 Seasons** (min 34, max 119); **time-to-beat median 529 Player matches ≈ 24.2 h of match play** at 2:45 (range 13.8–43.8 h, 79 completed careers) — essentially the career-pacing baseline (24 h) preserved under the new sheet.
- **Premier farming stays the by-design choke:** beat-rates while farming Club Premier 420/1294 = 32%, City 343/776 = 44%, Province 574/2440 = 24% (the naive line farms each Premier until winning The Final; visits dominated by Province).
- **Bank trajectory:** flat ~₸1.4–1.7k through the growth phase (Seasons 5–40 — the sink is binding), then climbing to ~₸97k by the cap once maxed — the uncapped bank remains the Shop-rung seed (joker sink still missing by design).
- **No softlock:** the naive line (sequential tours, cross up only after a Level win) completes 79/100 under the Tour-4 gate; DC16 down-offers unused by this policy, retained as the trophy-chase path.

### 10.3 Ripple ledger

- **Sim math untouched** — joker floor / env peg / build & pay spreads unaffected by construction (no oracle re-runs needed; the only ₸ change is additive prize income, team-outcome-keyed, build-independent).
- `attr_cost_base` 11 → 13 (above) — supersedes the career-pacing value, same ruling honoured.
- E3 ladder anchors: superseded by §10.1's v2 grid; brain literals unchanged (no policy re-search needed).
- E4 unblocked: anchors = §10.1 grid + §10.2 career metrics.
