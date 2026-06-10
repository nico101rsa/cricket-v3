# Self-play baseline policy search (rung 7c-E1) — design

**Date:** 2026-06-10 · **Status:** approved (AFK rung; defaults recorded per the AFK convention) · **Branch:** `selfplay-baseline-7cE1`

## 1. What this rung is

The first rung of the 7c-E "self-play decision AI" layer (ADR 0003). Three questions, answered with the existing harness and **no jokers**:

1. **What is the best way to play?** Find the strongest static per-phase game plan (the "textbook-optimal" policy) by exhaustive sweep + self-play.
2. **How big is the skill gap?** ADR 0003's headline metric: optimal policy vs a naive (random) one. Healthy = well above 0% (decisions matter) and well below 100% (not everything).
3. **Is the static layer solved?** If one plan beats *every* opponent plan, the no-joker game has a single dominant answer (bad per ADR 0003). If the best plan *depends on what the opponent plays*, there is genuine rock-paper-scissors depth.

The winning policy becomes the **computer opponent's brain** and the anchor for E3's difficulty ladder (dumb city-tour AI → near-optimal provincial AI). Later rungs: E2 (state-conditional policy — chasing vs setting, wickets in hand, Boost timing, DRS thresholds), E3 (difficulty ladder), then the Career loop and E4 (career-run player AI).

## 2. The decision space (and why it is small)

Audit of every decision lever in the no-joker sim:

| Lever | Per-phase options | Intrinsic effect without jokers? |
|---|---|---|
| Batting `IntentPlan` | DEF / BAL / AGG × 3 phases = 27 | **Yes** — feeds the `resolve_ball` logit |
| `BowlingPlan` (pace/spin) | PACE / SPIN × 3 phases = 8 | **Yes** — tilted attack/control profiles |
| `FieldPlan` | 3 modes × 3 phases = 27 | **No** — joker-gate only (C2a, deferred lever) |
| Bowling-side intent | 3 × 3 = 27 | **No** — joker-gate only (C2b) |
| `BoostPlan` (press timing) | which overs | Yes, but the water-meter constraint is unmodeled — unlimited presses make "optimal" degenerate |
| `DRSPolicy` | threshold dials | Yes, but codified as fixed symmetric rules (fair-fight rung) |

**A static policy = batting IntentPlan × BowlingPlan = 27 × 8 = 216 per side.** Small enough to brute-force — no learning machinery (RL, neural nets, autoresearch loops) needed at this layer. That machinery becomes appropriate at E4 (career runs), where the space explodes.

## 3. Decisions

- **D1 — Scope: the two intrinsic levers only.** E1 searches Intent × Rotation (216 policies). FieldPlan and bowling-side intent are excluded (no effect without jokers). Boost held at the sweep default (no presses, both sides) until the water meter is modeled (E2). DRS was to be held at the fair-fight symmetric default — **but the build probe showed that default is not symmetric** (see §10: the player slot's claim-review is gated on the hero's own overs while the opponent claims on all 20, worth ~6.7 points to the opponent slot), so the team-vs-team arms run **DRS off** instead; the hero-validation arms keep DRS both sides (both arms share the bias, comparison stays fair). The DRS fix is deferred to its own rung because it moves the fair-fight baseline the joker prices were measured against. Rationale: optimizing a lever whose constraint is unmodeled (or asymmetric) produces a misleading "optimal".
- **D2 — No statted Player: pure team-vs-team at even ★3.** The policy we are deriving is the *computer team's* brain (E3 ships it as the opponent AI), so the search runs `player_attrs = null` both sides, standard XI vs standard XI, fair-fight config. A cheap validation pass afterwards re-checks the winner with a statted all-rounder hero (does the best team policy survive a real Player in the XI?).
- **D3 — Self-play = iterated best response.** Start both sides on `textbook()`. Sweep all 216 policies for side A against B's current policy, adopt the best ("best response" — game-theory term for the strongest reply to a fixed opponent), then swap sides. Repeat. **Converges to a fixed point** (a pure Nash equilibrium — a pair of policies where neither side gains by changing) → the static layer is "solved" and we report that honestly. **Cycles** (A's best answer to B beats B, B adapts, A must change again) → genuine strategy-dependence. Cap at 6 iterations; report the trajectory either way.
- **D4 — Skill gap = equilibrium vs naive.** Naive = a uniformly random policy drawn per match (seeded; the ADR 0003 "choosing randomly" player). Also report equilibrium-vs-textbook and equilibrium-vs-balanced for context. All gaps measured at N=4000 paired matches.
- **D5 — Screen then refine (winner's curse guard).** Picking the max of 216 noisy win-rates systematically overstates the winner ("winner's curse"). Screening pass at N=400/arm (standard error ≈ 2.5%) keeps the top 12; refinement pass re-measures those at N=4000 (SE ≈ 0.8%) with *fresh* seeds; the best response is chosen on refined numbers only. Paired seeds across arms (Sweep platform) cancel draw-luck between arms.
- **D6 — One new sim seam: `opp_bowling_plan`.** `simulate_match` / `simulate_match_teams` gain a trailing `opp_bowling_plan: BowlingPlan = null`. Rotation activates when *either* side supplies a plan; a side with a null plan rotates `textbook()` (current behaviour). Both null → byte-identical to today (regression-tested). The opponent's batting intent seam (`opp_intent_plan`) already exists (C2b).
- **D7 — Artifacts.** Pure helpers in `scripts/harness/policy_search.gd` (policy enumeration, plan construction, argmax/best-response — unit-tested); oracle `tools/sweep_policy_selfplay.gd` (screening → refinement → best-response loop → skill-gap arms, backgroundable, ~30 min worst case); viz `docs/mockups/policy-selfplay-v1.html` (216-policy win-rate landscape + best-response trajectory + skill-gap readout); findings in §10.

## 4. Components

- **`PolicySearch`** (`scripts/harness/policy_search.gd`, pure static):
  - `enumerate() -> Array` — all 216 `{pp_intent, mid_intent, death_intent, pp_bowl, mid_bowl, death_bowl}` dictionaries, stable order.
  - `intent_plan_of(policy) -> IntentPlan`, `bowling_plan_of(policy) -> BowlingPlan` — plan construction.
  - `label_of(policy) -> String` — compact display label (e.g. `AGG/BAL/AGG · P/S/P`).
  - `best_index(win_rates: Array) -> int` — argmax (ties → lower index).
  - `random_policy(policies, rng) -> Dictionary` — one uniform draw from the supplied policy list (the naive player).
- **`opp_bowling_plan` seam** in `MatchResolver` (D6).
- **Oracle** `tools/sweep_policy_selfplay.gd`: phases printed as they complete; emits the viz DATA block.
- **Viz** `docs/mockups/policy-selfplay-v1.html` (reuses the distribution-viewer pattern).

## 5. Acceptance criteria

1. Seam regression: both bowling plans null → byte-identical `MatchResult` for a fixed seed (existing suite stays green).
2. Seam routing: setting only `opp_bowling_plan` changes the innings where the opponent bowls and only that (first-innings isolation trick), deterministic under a fixed seed.
3. `PolicySearch.enumerate()` returns exactly 216 unique policies; plan construction maps fields correctly; `best_index` picks the max.
4. The oracle completes screening + ≥1 best-response iteration + skill-gap arms in one backgrounded run and prints a machine-readable summary.
5. Findings (§10) answer the three §1 questions with numbers: the equilibrium (or cycle), the optimal-vs-naive gap, the optimal-vs-textbook gap, and the statted-hero validation.
6. Honest-reporting rule: if the 216-policy landscape is nearly flat (best − worst within ~2× refinement SE), say so plainly — it means the static levers are too weak to carry skill and E2/mechanic work must deepen them (ADR 0003 wants the gap well above 0).

## 6. Out of scope (deferred)

State-conditional policies (chase-aware intent, wickets-in-hand rotation — E2) · Boost timing + water meter (E2) · DRS threshold search (E2) · difficulty ladder (E3) · jokers in the policy space (E4 inherits the priced catalog) · Career-loop integration (Theme-2 rung + E4) · opponent Tour-level competence throttle (E3, per the roadmap).

## 10. Findings (2026-06-10, full run: screen N=400 → refine N=4000, gap arms N=4000)

### 10.1 The DRS side-asymmetry bug (found by the build probe, fix deferred)

The first full run read every mirror match (same policy both sides) at ~43–45% for the side-A slot instead of the ~48–49% fair benchmark. A decomposition probe (`tools/probe_side_asymmetry.gd`, N=4000/arm) isolated it:

| mirror arm (same policy both sides) | A-win% | B-win% | tie% |
|---|---|---|---|
| all null (scalar, no DRS) | 50.2 | 48.8 | 1.0 |
| intent textbook both only | 49.8 | 48.8 | 1.4 |
| rotation textbook both only | 50.2 | 48.5 | 1.3 |
| **DRS both only** | **46.3** | **53.0** | 0.7 |
| full textbook config | 44.0 | 55.1 | 0.9 |

**Mechanism** (`innings_resolver.gd` DRS block): the *survive* review (batting side) is symmetric, but the *claim* review (bowling side reviews a dot to steal a wicket) is gated on `player_bowling` for the player slot — it fires only on the hero's personally-bowled 0–4 overs (zero with no statted hero) — while the opponent slot claims on **all 20 overs**. Worth ~6.7 win points to the opponent slot. This has been baked in since the fair-fight rung: the 48.1% "even" baseline carries it.

**Nico's ruling (2026-06-10): DRS is team-wide on every ball for both sides — the hero is just part of the team, no special-casing.** Fix = drop the `player_bowling` gate. Deferred to its own rung because it moves the fair-fight baseline that build-balance and all 45 joker prices were measured against (fix → re-run fair-fight baseline → re-sweep jokers → refresh prices that move band; re-verify against the probe table above).

E1 therefore ran its team-vs-team arms **DRS-off** (clean mirrors, table row 1); the hero-validation arms keep DRS both sides (shared bias → fair comparison). The equilibrium below is robust to this either way: within any single best-response sweep the bias was constant across all 216 arms, so every argmax stood.

### 10.2 The equilibrium: all-aggressive batting + all-spin bowling (static layer is SOLVED)

Iterated best response from textbook converged in 5 iterations to a **pure equilibrium, both sides A/A/A·S/S/S** (Aggressive every phase · Spin every over):

- iter 0, A: textbook (49.7%) → B/A/A·S/S/S (70.5%) — ADOPT
- iter 1, B: textbook (29.1%) → A/A/A·S/S/S (58.1%) — ADOPT
- iter 2, A: B/A/A·S/S/S (41.1%) → A/A/A·S/S/S (50.6%) — ADOPT
- iters 3–4: both sides KEEP (gain 0.0) → equilibrium.

Mild opponent-dependence exists en route (the best reply to *textbook* is B/A/A·S/S/S, not the equilibrium), but it dies out — **the no-joker static layer has a single dominant answer.** Per §5.6 this is reported plainly: the levers are strong (landscape spread 16% → 70%, ≫ 2×SE), but the game at this layer is *solved*, which ADR 0003 forbids long-term. The two queued fixes that restore conditional depth: **phase-dependent bowling tilt** (§10.3) and **E2 state-conditional policy**.

### 10.3 Spin dominance — validated against real T20, and what's missing

All-spin dominating matches real-world aggregates Nico supplied (2026-06-10): T20 spinners beat pacers on *both* economy (9.08 vs 9.93 rpo) and strike rate (22.2 vs 25.3 balls/wicket). So the sim's aggregate isn't wrong — what's missing is **phase-dependence**, which is what keeps the choice alive in real cricket: pace takes ~70% of Powerplay wickets and owns the death; spin earns its keep in overs 7–15. **Design seed for the bowling-balance rung:** make the pace/spin tilt phase-dependent (pace tilts harder in PP/death, spin in the middle) so textbook P/S/P *emerges* as strong play; add MEDIUM as a low-tilt hedge kind later; pitch/Tour conditions later still. Also note the batting side: middle-overs AGGRESSIVE is the single hottest lever in the landscape (the D/A/* and A/A/* rows), and all-AGG beats textbook pacing by ~20 points — when the bowling rung lands, re-check whether the intent EV trade needs sharpening too (real T20 batting is not all-slog).

### 10.4 Skill gap (ADR 0003 headline) — healthy

Head-to-head win% of the first side (N=4000; mirror baselines ~48–49 with ties ~1%):

| arm | win% |
|---|---|
| eq vs **naive** (random plan/match) | **76.2** |
| eq vs textbook | 67.7 |
| eq vs balanced (all-BAL) | 78.5 |
| eq vs eq (mirror) | 47.5 |
| textbook vs textbook (mirror) | 48.1 |
| naive vs naive (mirror) | 48.9 |

The optimal-vs-naive gap is **+27 points over mirror** — far above 0 (decisions matter a lot) and far below 100 (variance keeps cricket's character). Healthy per ADR 0003.

### 10.5 Statted-hero validation (D2)

Through the real game path (`simulate_match_teams`, 5/5/5/5 hero, DRS both sides): hero side playing the equilibrium beats playing textbook by **+12.8 points** (43.7% vs 30.9% against an equilibrium opponent). The team-policy conclusion transfers intact to matches with a real Player in the XI.

### 10.6 What the next rungs inherit

- **Opponent AI brain (E3):** the equilibrium policy literal `{pp_intent: AGGRESSIVE, mid_intent: AGGRESSIVE, death_intent: AGGRESSIVE, pp_bowl: SPIN, mid_bowl: SPIN, death_bowl: SPIN}`; difficulty ladder anchors: naive/random ≈ floor (loses 76.2/23.8 to optimal), textbook ≈ mid, equilibrium ≈ ceiling. A blend dial between random and equilibrium spans dumb-city-tour → provincial-top-tier.
- **DRS-fix rung (queued, Nico-ruled):** §10.1 — one-line fix + baseline/joker re-verification, probe table is the regression oracle.
- **Bowling-balance rung (queued):** §10.3 phase-dependent tilt design seed, grounded in real T20 benchmarks.
- **E2 (conditional policy):** chase-aware/state-aware policies, Boost timing + water meter, DRS thresholds — the depth layer that should dethrone the static equilibrium.
- Viz: `docs/mockups/policy-selfplay-v1.html` (216-policy landscape heatmap + trajectory + gap bars).
