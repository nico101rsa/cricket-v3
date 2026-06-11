# E3 Difficulty Ladder (rung 7c-E3) — design

**Date:** 2026-06-12 · **Branch:** `difficulty-ladder-7cE3` · **Status:** built AFK (defaults recorded per decision; Nico reviews at leisure)

## 1. Goal (plain English)

The sim already knows four opponent "brains" of increasing skill — measured, not invented:
**naive** (a random game plan every match) → **textbook** (sensible fixed cricket) →
**static-eq** (the best fixed plan self-play found) → **adaptive-eq** (the E2 brain that reads
the match state: chase hard when the required rate climbs, protect a collapse).

This rung ships those brains as *the game's difficulty system*: every cell of the Career grid
(3 Levels × 8 Tours) gets a row in one table — **how strong the league's cards are** (tour
mean), **how smart the opponent plays** (brain + blend), and the league's **★ field**. Climbing
the grid then *feels* harder for two honest reasons: the Player's fixed /100 card matters less
against stronger league cards, and the opposing captain actually plays better cricket.

Deliverables: the data table (`DifficultyLadder`), the brain factory (`OpponentBrain`),
threading through `LeagueResolver`/`SeasonResolver` (off by default, byte-identical when off),
and a measured beat-rate ladder over all 24 cells proving difficulty is monotone and the
overlap topology holds. The Career rung (next) consumes this table when the Player actually
navigates the grid.

## 2. Inputs this rung consumes

- **The brain ladder + anchors** (E2 spec §10.3, re-anchored at full N post-rescale this rung —
  numbers in §10): naive ≈ floor, textbook ≈ mid, static-eq ≈ high, adaptive-eq ≈ ceiling.
  Brain literals: static-eq `B/A/B·P/S/P`, adaptive-eq `B/A/A·P/S/P+u11d6c4`.
- **League-band card mapping** (card-rescale DR6 strawman): tour mean as a fraction of the mid
  anchor (`MatchResolver.REF_SCALAR` 31.25) sets what cards in that league look like.
- **Canon difficulty topology** (CONTEXT.md, resolved from Nico's difficulty spreadsheet):
  overlapping Level bands — **Club 1–8, City 2–10, Province 3–12** on a single difficulty-number
  scale, with deliberate jumps at the Home→Away and →Premium transitions. Tour order: Practise,
  Home summer/winter/evening, Away summer/winter/evening, Premium.
- **Canon strength rule** (CONTEXT.md "Tour"): *every* team in a Tour's league — including the
  Player's Team — draws strength from that Tour's distribution. The league rises together; the
  Player's absolute card is the thing that stops keeping up.

## 3. Design

### 3.1 The difficulty sheet (d-numbers, codified)

One number `d` per grid cell, honoring the canon bands + jumps. Strawman (the tunable artifact
of this rung — every later column keys off `d`):

| Tour (index) | Club | City | Province |
|---|---|---|---|
| Practise (0) | 1.0 | 2.0 | 3.0 |
| Home summer (1) | 2.0 | 3.0 | 4.5 |
| Home winter (2) | 2.5 | 3.5 | 5.0 |
| Home evening (3) | 3.0 | 4.0 | 5.5 |
| Away summer (4) | 5.0 | 6.5 | 8.0 |
| Away winter (5) | 5.5 | 7.0 | 8.5 |
| Away evening (6) | 6.0 | 7.5 | 9.0 |
| Premium (7) | 8.0 | 10.0 | 12.0 |

Bands: Club 1–8, City 2–10, Province 3–12 ✓. Jumps: Home-evening → Away-summer (+2 / +2.5)
and Away-evening → Premium (+2 / +2.5 / +3) ✓. Overlap: each Level's Practise is gentler than
the Level below's Away tours ✓ (City Practise d=2 < Club Away-summer d=5).

### 3.2 The ladder table — d → (tour mean, brain, ★ field)

**Tour mean (card strength):** linear strawman `mean_frac(d) = 0.4 + (d − 1) · 0.9/11`
(d=1 → **0.40**, d=8 → **0.97**, d=12 → **1.30**), tour mean = `mean_frac × 31.25`. The
mid-league anchor (frac 1.0, where the env was pegged to real T20) sits at d≈8.3 — upper-Club
Premium / mid-City. DR6's band-5 ceiling (top batter ~65) is Province Premium. Spread scales
proportionally (`spread = 0.3 × mean`, today's mid ratio); noise stays absolute (continuous
noise was explicitly deferred at card-rescale).

**Brain + blend:** per cell a `brain_tier` and a `blend` probability — each Player-facing
fixture, the opponent draws the cell's tier with probability `blend`, else **one tier lower**
(floor = naive). Strawman keyed off d:

| d | tier | blend | reads as |
|---|---|---|---|
| 1–2 | NAIVE | 1.0 | random plans |
| 3–4 | TEXTBOOK | 0.5 | half sensible |
| 5–6 | TEXTBOOK | 1.0 | solid cricket |
| 7–8 | STATIC_EQ | 0.5 | sometimes sharp |
| 9 | STATIC_EQ | 1.0 | consistently sharp |
| 10–11 | ADAPTIVE | 0.5 | reads the game, half the time |
| 12 | ADAPTIVE | 1.0 | the measured ceiling |

So each Premium tour also brings a brain step (part of the canon "jump"), and Province Premium
— the Career-ending Final — is the full adaptive equilibrium.

**★ field:** one neutral 7-opponent star array for all cells this rung —
`[2.0, 2.5, 3.0, 3.0, 3.0, 3.5, 4.0]` (mean 3.0). Stars are *within-league* texture (who's the
local giant), not the difficulty axis — the tour mean carries that, per canon. The column
exists in the table so later feel-tuning can shape it per cell.

### 3.3 New pieces

- **`TourSpec`** (`scripts/data/tour_spec.gd`) — pure data row: `level`, `tour_index`, `d`,
  `tour_name`, `brain_tier`, `blend`, `opp_stars: Array`, and `make_tour() → TourDistribution`
  (mean/spread from `mean_frac(d)`).
- **`DifficultyLadder`** (`scripts/data/difficulty_ladder.gd`) — the codified sheet:
  `spec_for(level: int, tour_index: int) → TourSpec` + `all()` (24 cells, SA/AUS share the
  template per CONTEXT — Country is a master-data axis, not a difficulty axis).
- **`OpponentBrain`** (`scripts/domain/opponent_brain.gd`) — tier enum
  `{NAIVE, TEXTBOOK, STATIC_EQ, ADAPTIVE}` (stored as `int` per project convention) +
  `draw_plans(tier, blend, rng) → Array [IntentPlan, BowlingPlan]`. NAIVE draws a uniform
  static policy (the E1 216-space: 3 intents per phase × pace/spin per phase) without
  depending on the harness; TEXTBOOK = `IntentPlan.textbook()` + `BowlingPlan.textbook()`;
  STATIC_EQ and ADAPTIVE are the measured literals hardcoded with a comment naming the
  oracle run that produced them.

### 3.4 Threading (off by default)

`LeagueResolver.simulate_league(...)` and `SeasonResolver.simulate_season(...)` gain one
optional trailing param `opp_brain: TourSpec = null`:

- `null` → **byte-identical to today** (no extra RNG draws, no plan objects built).
- Set → for each **Player-facing** fixture (7 league games + any playoff game involving the
  Player), draw the opponent's plans via `OpponentBrain.draw_plans(spec.brain_tier,
  spec.blend, rng)` and pass them through the existing `opp_intent_plan`/`opp_bowling_plan`
  seams on `MatchResolver`. Adaptive plans ride the E2 `IntentPlan.for_state` machinery, which
  is side-agnostic.
- Non-Player fixtures stay default both sides — symmetric among AI teams, so the standings
  stay fair and the sim cost stays flat.

### 3.5 Oracle + viz

New **`tools/sweep_difficulty_ladder.gd`**: a reference build plays N Seasons at every one of
the 24 cells (Player Team ★3, the standard field) → beat-rate (top-3) + win-Final-rate per
cell, plus brain-isolation arms (same cell, naive vs adaptive opponent) to show the brain's
own contribution. `E3_QUICK=1` smoke mode; full run nohup-detached + log-grep watcher.
Env texture probes (`probe_scoring_env.gd ENV_TOUR_MEAN=…`) at Club Practise and Province
Premium, recorded (eyeball, not gated). Viz `docs/mockups/difficulty-ladder-v1.html`
(24-cell beat-rate heatmap + ladder lines per Level).

## 4. Decisions (AFK defaults — Nico can overturn any)

- **DL1 — One table, keyed by the canon d-sheet.** The difficulty spreadsheet topology
  (bands 1–8/2–10/3–12 + jumps) is codified as data, not re-derived. Alternatives considered:
  Godot `.tres` resources per tour (editor-friendly, heavier — deferred until content tooling
  matters) and a pure formula with no per-cell rows (fewer dials but nothing individually
  tunable). Chosen: const table + formula defaults — every cell individually editable, formula
  fills the defaults.
- **DL2 — Difficulty = card gap first, brain second.** The tour mean is the primary axis (per
  canon: the league rises together, the Player's absolute card lags); the brain blend is the
  secondary axis layered on top. ★ field stays neutral this rung.
- **DL3 — `mean_frac` spans 0.40–1.30** (linear in d). Floor-aware: the proportional-scaling
  safety floor (`team_bat_factor ≥ 0.5`) starts binding below frac ~0.5, so Club's lowest
  cells sit at its edge by design; true sub-0.4 "village cricket" texture is a future call
  (lower the floor then). Build task 1 verifies where the floor actually binds and records it.
- **DL4 — Blend = "this tier, else one tier lower."** One probability per cell, smooth
  difficulty inside a Level without enumerating mixtures over all four tiers.
- **DL5 — Brains fire on Player-facing fixtures only.** AI-vs-AI league games stay default
  (fair among themselves, no cost increase). Revisit if standings should reflect "smart" teams.
- **DL6 — `OpponentBrain` lives in `scripts/domain/`, independent of the harness.** The NAIVE
  draw re-implements the tiny 216-space draw rather than importing `PolicySearch` (game code
  must not depend on `scripts/harness/`). The eq literals are hardcoded + commented with their
  oracle provenance; if a future re-anchor moves the equilibrium, the literal is a one-line
  update caught by the ladder oracle.
- **DL7 — Spread proportional, noise absolute.** Spread keeps today's mid-league ratio (0.3 ×
  mean) so a star step means the same *relative* amount in every league; noise stays the
  card-rescale discrete-step default (its continuation is an explicitly deferred tuning call).
- **DL8 — Player Team participates in the tour distribution as canon says** — no special
  Player-team exemption. The oracle pins Player Team ★3; the Career rung will drive real ★
  from Offers/mutation.
- **DL9 — No oracle-default changes.** `sweep_jokers.gd`, build/economy/env oracles keep their
  pinned plans and mid-league context — the 45.5% joker floor, prices, and pay are untouched
  by construction (same DS6 logic as E2). The floor only re-measures when a rung changes the
  *oracles'* defaults, not when the game grows a difficulty table.
- **DL10 — Acceptance is ordering + spans, not exact win-rates.** Within a Level, beat-rate
  falls monotonically in d; each Level's Practise reads easier than the Level below's Away
  tours (overlap honored); the brain-isolation arm shows the brain alone is worth meaningful
  points at fixed strength. Exact feel targets (e.g. "Premium should beat me 6 tries in 10")
  are playtest calls on these dials, not this rung's gate.
- **DL11 — League/Season fidelity stays scalar this rung.** `LeagueResolver`/`SeasonResolver`
  predate the discrete-roster world (PR #29): their matches run the scalar clone path (no real
  XIs, no `team_bat_factor`). The difficulty dynamic still holds there — every team's scalar is
  drawn from the Tour distribution while the Player's card is absolute — so the ladder measures
  honestly at that fidelity. Upgrading Season play to the roster+factor path is the Career
  rung's call (it owns "a real XI across a Season"), recorded as a seed there.

## 5. Out of scope (recorded so they don't creep)

- **Career loop** (Offers, ★ persistence, grid navigation, Seasons-played) — the next rung;
  it consumes `DifficultyLadder`.
- **Tour pitch conditions / formats** (ideas backlog cluster 1) — pairs naturally with this
  table (a future condition column), not built here.
- **Country variation** — the ladder is the shared template per canon.
- **Opponent jokers / Boost / DRS-policy intelligence** — the brain is plans-only (intent +
  bowling), the same surface the eq search measured. Smarter captain-tool usage is a future
  fidelity rung (deferred at PR #32).
- **UI** — nothing player-facing ships here.

## 6. Tests (TDD, inline)

1. `DifficultyLadder`: 24 cells; d matches the canon bands (min/max per Level, jump sizes);
   `mean_frac` endpoints + monotonicity; Premium = Level max; overlap property explicit
   (each Level's Practise d < Level-below's Away-summer d).
2. `TourSpec.make_tour()`: mean/spread arithmetic; ★ field array shape.
3. `OpponentBrain`: tier literals reproduce the published plans (static-eq B/A/B·P/S/P,
   adaptive rules u11/d6/c4); NAIVE seed-determinism + stays in the legal 216 space; blend
   respects p (statistical, seed-summed); ADAPTIVE plans carry rule fields, others off.
4. Threading: `simulate_league/season` with `opp_brain = null` byte-identical (existing
   determinism tests + an explicit no-extra-RNG check); with a brain set, determinism holds
   and a directional test shows adaptive-opponent ≤ naive-opponent Player win-rate
   (seed-summed).
5. Oracle smoke (`E3_QUICK=1`) runs end-to-end.

## 7. Build order

1. Full-N ladder re-anchor (running at rung start — §10 records it) + floor-bind check (DL3).
2. `TourSpec` + `DifficultyLadder` + tests.
3. `OpponentBrain` + tests.
4. Threading through league/season + tests.
5. Oracle + viz + full detached run; §10 findings; roadmap close-out.

## 10. Findings (filled in-rung, 2026-06-12)

### 10.1 Full-N ladder re-anchor (post-rescale, 25.6 min, N=4000 gap arms)

The joint-space self-play **converged (EQUILIBRIUM), both sides adaptive — the E2 conclusion
holds on the /100 card scale**, but the equilibrium profile drifted: A `B/A/B·P/S/P+u10d5c5`
vs B `B/A/A·P/S/P+u9d5c5` (E2 pre-rescale: `+u10d6c4`/`+u11d6c4`). **The shipped
`OpponentBrain.ADAPTIVE` literal = the side-A profile `B/A/B·P/S/P+u10d5c5`** (also the
dethrone winner): Balanced death band, chase-up ≥ 10 req RR, cruise-down ≤ 5, collapse gate at
5 wickets — the death slog now comes *from the chase rule*, not the base band. Margins are
structural-not-blowout, as at E2: dethrone +1.1 (50.3 vs incumbent 49.2), hero transfer +1.2
(51.7 vs 50.5).

**Re-anchored ladder (new-eq vs X, N=4000):** naive **69.5** · textbook **56.7** · balanced
**54.9** · static-eq **50.4** — ordering unchanged (naive=floor, textbook=mid, static-eq=high,
adaptive-eq=ceiling); the naive gap compressed vs E2's 74.1 (the rescale's proportional noise
widened match variance). Mirrors clean (adaptive 49.0 / static-eq 50.0).

### 10.2 The measured grid (oracle full run, N=200 Seasons/cell, 3.3 min)

Reference creation build (35/30/30/30, Team ★3, textbook plans), beat = top-3:

| Tour | Club | City | Province |
|---|---|---|---|
| Practise | 96.0 | 94.0 | 77.5 |
| Home s/w/e | 94.0 / 85.5 / 77.5 | 77.5 / 78.0 / 75.0 | 54.0 / 48.0 / 50.5 |
| Away s/w/e | 48.0 / 50.5 / 51.5 | 47.0 / 43.0 / 42.0 | 43.5 / 34.5 / 34.5 |
| Premium | 43.5 | 20.0 | **15.0** |

**DL10 acceptance: PASS.** Monotone within level (wobbles ≤ 3.5 pts = N=200 noise, e.g. Club
Away 48→50.5→51.5); the canon jumps are visible cliffs (Club 77.5→48 at Home→Away, City
42→20 at →Premium); overlap honored everywhere (City Practise 94 vs Club Premium 43.5;
Province Practise 77.5 vs City Premium 20). Province Premium — the Career-ending Final — reads
beat 15% / win-Final **1%** for a fresh creation build: properly brutal; attribute growth +
jokers are what close it (the Career rung's economy). Win-Final ≤ 65.5% even at Club Practise
(the two-knockout championship coin-flip, known emergent).

**Brain isolation (same league strength, City Home-winter):** naive opponent → beat 87.5 /
game-win 79.9; adaptive → beat **46.0** / game-win 55.4. The brain alone is worth **~24.5
game-win pts ≈ 41.5 beat pts** — season structure amplifies the per-match gap. Difficulty is
genuinely two-axis (cards + brain), as designed (DL2).

### 10.3 Env texture at the extremes (probe, N=2000, eyeball not gated)

- **Club Practise** (`ENV_TOUR_MEAN=12.5`, frac 0.40): **120.5 avg / RR 6.89 / 8.2 wkts /
  54.5% all-out** — weak club cricket, tail can't bat. Floor note (DL3): frac 0.40 < 0.5, so
  the roster path's batting factor floors at 0.5 while bowling keeps falling — that's the
  high wicket count. The league/season path (DL11, scalar) has no floor. True sub-0.4
  "village" texture = lower the floor in a future rung.
- **Province Premium** (`ENV_TOUR_MEAN=40.625`, frac 1.30): **167.2 / RR 8.76 / 5.3 wkts /
  24.1% all-out** — the top of Nico's real-T20 band, batting-friendly as the card-rescale §10
  predicted for high bands.

### 10.4 Notes & seeds

- Cells with equal d are identical simulations this rung (same seeds, d is the only input) —
  e.g. City Practise ≡ Club Home-summer. Levels diverge when later rungs add per-cell ★
  fields, pitch conditions (ideas backlog cluster 1), or formats.
- The 0.5-d steps inside an Away block move beat-rate less than noise — if within-block
  progression should *feel* distinct, that's a d-sheet/feel dial for playtest, not a bug.
- DL9 held: no oracle defaults changed — joker floor 45.5%, prices, pay untouched.
- Viz: `docs/mockups/difficulty-ladder-v1.html` (full-run DATA pasted, eyeballed ✓).
