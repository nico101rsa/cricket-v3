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

- **D1 — Scope: the two intrinsic levers only.** E1 searches Intent × Rotation (216 policies). FieldPlan and bowling-side intent are excluded (no effect without jokers). Boost held at the sweep default (no presses, both sides) until the water meter is modeled (E2). DRS held at the fair-fight symmetric default. Rationale: optimizing a lever whose constraint is unmodeled produces a misleading "optimal".
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

## 10. Findings

*(filled after the search runs)*
