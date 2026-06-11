# Bowling Balance — phase-dependent pace/spin tilt, intent×kind matchup, wicket-cost check

**Date:** 2026-06-11 · **Rung:** Theme 7c, post-E1 (queue: DRS fix ✅ → **this** → E2 → E3 → Career → E4)
**Mode:** AFK (decisions recorded here per the standing policy; design seed pre-agreed with Nico 2026-06-10, E1 spec §10.3; tail-steepening lever added by Nico 2026-06-11).

---

## 1. Problem

E1 (PR #42) searched the 216 static no-joker policies and found a single dominant answer: **A/A/A·S/S/S** (all-aggressive batting + all-spin bowling, both sides, stable pure equilibrium in 5 iterations). The static strategy layer is *solved*, which ADR 0003 forbids: if one plan always wins, the player's per-phase decisions are dead weight.

Two root causes, both validated against real T20 aggregates Nico supplied (E1 spec §10.3):

1. **Spin strictly dominates** because the sim's pace/spin tilt is phase-constant. Real spinners *do* beat pacers on aggregate economy (9.08 vs 9.93 rpo) *and* strike rate (22.2 vs 25.3) — the sim's aggregate isn't wrong — but real cricket keeps the choice alive through **phase-dependence**: pace takes ~70% of Powerplay wickets and owns the death; spin owns overs 7–15. The sim has no phase term, so the aggregate winner wins everywhere.
2. **Getting out is too cheap.** All-AGG beats textbook pacing by ~20 points. Real T20 batting is not all-slog; the risk side of the aggression EV trade is under-priced.

And one structural gap: nothing makes the best reply **depend on the opponent's plan**. With additively separable payoffs, some pure policy is always globally best → a pure equilibrium always exists → solvable. Killing the dominant answer *requires* an interaction term.

## 2. Goal

Three bundled `resolve_ball`/innings-level changes so that **textbook P/S/P emerges as strong play and no constant plan dominates**:

- **(a) Phase-dependent pace/spin tilt** — pace better in Powerplay + death, spin better in the middle.
- **(b) Intent × bowler-kind matchup term** — e.g. slogging spin carries extra wicket risk. The cheapest true un-solver: the best bowling reply now depends on the opponent's batting intent (and vice versa) → cycles possible, pure equilibrium no longer guaranteed.
- **(c) Wicket-cost check** — re-price the aggression risk until all-AGG no longer dominates textbook. **Nico's lever (2026-06-11): steepen the tail drop-off** — a wicket walks the batting card down a steeper quality gradient, so each dismissal costs more without touching the dismissal probability itself.

**Acceptance test = re-run the E1 self-play oracle** (`tools/sweep_policy_selfplay.gd`): equilibrium gone or cycling, textbook competitive (§6).

## 3. Non-goals (deferred, per §10.3 + standing decisions)

- **MEDIUM bowler kind** (low-tilt hedge) — later rung.
- **Pitch / Tour conditions** (per-venue tilt modifiers) — later still.
- **Player bowling kind (pace/spin)** — still deferred (player-as-bowler D4); see BB4.
- **Per-bowler husbanding** (pool/cap/fatigue) — optional 4c, unchanged.
- **Intent EV re-shape beyond the wicket-cost check** — E2 (state-conditional policy) owns deeper batting depth.

## 4. Design

### 4.1 (a) Phase tilt — per-kind, per-phase additive bonus (BB1, BB2)

A bowler kind gets an additive effectiveness bonus to **both** attack and control in its favoured phase (a uniformly better bowler in-phase, worse out-of-phase). The base ±2 style tilt in `BowlingAttack` is untouched — pace stays the wicket-taking choice and spin the containment choice *within* any phase; the phase bonus decides **which kind is the better buy per phase**.

- **`IntentPlan.phase_of(over) -> int`** (new static): 0 = Powerplay (1–6), 1 = middle (7–15), 2 = death (16–20). Single source of truth — reuses the existing `POWERPLAY_OVERS` / `DEATH_START_OVER` constants. (`for_over` refactors onto it.)
- **Dials in `InningsTuning`** (phases are an innings concept; BallTuning stays over-blind):
  ```
  pace_phase_bonus: Array[float] = [+0.7, -0.7, +0.7]   # [PP, middle, death]
  spin_phase_bonus: Array[float] = [-0.7, +0.7, -0.7]
  ```
  Strawman magnitudes (tuned in §6's loop): at `k_w` 0.24 / `k_r` 0.34, ±0.7 on both stats ≈ ∓0.17 wicket-logit and ±0.24 scoring-logit per ball — a meaningful, not match-deciding, nudge. Mirrored signs keep the per-phase sum across kinds ~zero so the overall scoring environment barely moves.
- **Applied in `InningsResolver.simulate_innings`** at the existing profile lookup: when `bowling_attack != null and bowling_plan != null`, add the kind's phase bonus to both `bat_attack` and `bat_control`, floored at 1.0. **`bowling_plan == null` (scalar path) ⇒ no bonus — byte-identical**, every pre-rotation regression test stands (BB9).

### 4.2 (b) Intent × kind matchup — inside the ball atom (BB3)

The matchup is ball physics, so it lives in `resolve_ball`, not the caller:

- New trailing param **`bowler_kind: int = -1`** on `BallResolver.resolve_ball` (after `runs_mult`). `-1` = unknown/no rotation ⇒ term is 0 ⇒ byte-identical.
- **Table in `BallTuning`**, indexed by Intent (flat arrays — GDScript exported nesting is awkward):
  ```
  matchup_w_pace: Array[float] = [0.0, 0.0, 0.0]    # [DEF, BAL, AGG] vs pace
  matchup_w_spin: Array[float] = [0.0, 0.0, 0.30]   # slogging spin: stumped / holed out
  ```
  Added to the **wicket logit** (stage 1) alongside `intent_w`. Strawman: only AGG-vs-spin is non-zero (+0.30 on top of `intent_w[AGG]` 0.60); the table exists so the tuning loop can shape the full 3×2 if needed.
- **Wiring:** the innings resolver already computes `bowler_type` per over (C2d); pass it through. **On Player-bowled overs pass `-1`** (BB4): the Player's bowling kind is deferred (player-as-bowler D4), so the Player's deliveries carry no matchup term and no phase bonus (the player override already bypasses the profile). `bowler_type` itself is untouched, so C2d joker gating semantics don't move.

Why this un-solves: with the matchup term, the bowling side's best kind in a phase depends on the batting side's intent in that phase (AGG ⇒ spin punishes; DEF/BAL ⇒ phase tilt favours pace in PP/death), and the batting side's best intent depends on the kind it expects (don't slog spin). Payoffs are no longer additively separable ⇒ best replies can cycle ⇒ no guaranteed pure equilibrium. Both innings run the same code path, so the term is side-symmetric by construction.

### 4.3 (c) Wicket cost — tail steepening first, then intent_w (BB5)

The check: after (a)+(b) land, measure all-AGG vs textbook head-to-head. If all-AGG still dominates (gap beyond §6's band), apply levers **in this order** until it doesn't:

1. **Tail steepening (Nico's lever) — archetype specialization sharpening.** The oracle and the real game run the **roster path** (`Team.standard_xi()`), where the tail is the four BOWLER archetypes batting 8–11 at 2/2 — the legacy `tail_slope`/`tail_floor` dials bind only the clone path and are left alone. The roster lever that conserves the **build-equality principle** (every player an exact 20-point build, team = 220):
   ```
   BATTER  8/8/2/2 → 9/9/1/1
   BOWLER  2/2/8/8 → 1/1/9/9
   ALLROUNDER 5/5/5/5 (unchanged)
   ```
   Specialists get more specialist: the top order rises, the tail drops to near-useless with the bat — the gradient a fallen wicket walks down is steeper at both ends. Side-effect to verify: team batting points shift 122→126, bowling 98→94 (sum 220 ✓); gap-fill is relative to the XI's own totals so it adapts; build spread + pay spread re-verified in §7.
2. **`intent_w[AGGRESSIVE]` up** (0.60 → tuned) — the direct price on slog risk — only if the tail lever alone can't close the gap (it also moves every joker sweep's shared plans, so prefer the tail).

Either lever may also end up *partially* applied (e.g. tail sharpening adopted at half step via 8.5 → not possible on int attrs — so it's all-or-nothing per step; intent_w is continuous).

### 4.4 What deliberately does NOT change

- `BowlingAttack`'s base ±2 tilt, `base_w` (even-contest 3.5%), `k_w`, `k_r`, run distributions.
- The clone-path tail curve (`tail_floor`/`tail_slope`) — legacy/scalar-path only.
- DRS, jokers, Boost, field, economy formulas — only re-*measured* (§7).
- The scalar no-rotation `simulate_match` path: **byte-identical** (BB9) — proven by the standing regression tests.

## 5. Decisions

| # | Decision | Why |
|---|---|---|
| **BB1** | Phase tilt = per-kind per-phase **additive bonus to both attack & control**, dials `pace_phase_bonus`/`spin_phase_bonus` in `InningsTuning`, applied at the innings resolver's profile lookup, floored at 1.0. Strawman ±0.7 mirrored. | Simplest mechanism that makes "which kind, this phase" a live choice while keeping the within-phase style trade; mirrored signs ≈ scoring-environment-neutral; InningsTuning because phases are innings concepts. |
| **BB2** | New `IntentPlan.phase_of(over)` static; `for_over` refactors onto it. | One source of truth for phase boundaries; BowlingPlan/FieldPlan already mirror IntentPlan's bands. |
| **BB3** | Matchup term lives **inside `resolve_ball`** via trailing `bowler_kind := -1`; table `matchup_w_pace`/`matchup_w_spin` in `BallTuning` indexed by Intent, added to the wicket logit. Strawman: AGG-vs-spin +0.30, rest 0. | It's ball physics (belongs in the atom); `-1` default keeps every existing caller byte-identical; wicket-side term both prices slog risk and creates the intent×kind interaction that un-solves the layer. |
| **BB4** | ~~Player-bowled overs: no phase bonus, kind −1.~~ **REVERSED in-rung (2026-06-11):** the hero bowls *within the rotation* — Player-bowled overs inherit the plan kind's phase bonus + matchup term like any team over. The Player's own pace/spin identity stays deferred (D4). | The original form taxed bowling-capable builds a measured **~3.5 runs/match (~5 win pts)** in any plan-ful context (the joker-sweep floor exposed it: margin −3.50) — a hidden build-equality violation. |
| **BB5** | Wicket-cost lever order: **(1) archetype sharpening** BATTER 9/9/1/1 + BOWLER 1/1/9/9 (AR unchanged), **(2) `intent_w[AGG]`** — applied only as needed to hit §6. | Nico's call (2026-06-11): try the steeper tail first. Sharpening conserves every 20-pt build (build-equality principle) and the 220 team total; intent_w is the blunter dial with wider ripple. |
| **BB6** | Acceptance = E1 oracle re-run, criteria in §6. | The rung exists to fix what E1 measured; same instrument proves the fix. |
| **BB7** | Full ripple **in-rung** (DRS-rung precedent): floor re-measure → 45-joker re-sweep → re-tune blown bands (dial moves only) → re-price moved jokers (DE4 interpolation) → build-spread + pay-spread verification → pool doc + viewer DATA mirrors. | Every baseline this rung touches must leave honest; deferring the ripple recreates the "known-dirty baseline" debt the DRS rung just retired. |
| **BB8** | Deferred: MEDIUM kind, pitch/conditions, Player bowling kind, husbanding, deeper intent re-shape (E2). | §10.3 seed + scope discipline. |
| **BB9** | Scalar path byte-identical: no `bowling_plan` ⇒ no tilt; `bowler_kind=-1` ⇒ no matchup. | Protects the entire pre-rotation test base and the joker unit tests. |
| **BB10** | All new dials are exported tuning data (InningsTuning / BallTuning), never literals in resolvers. | Harness convention since rung 1. |
| **BB11** | Scoring environment is an acceptance rail: textbook mirror first-innings mean **150–167** @ RR 8–9, wickets ~5–7, phases ordered; permanent oracle `tools/probe_scoring_env.gd`. | Nico (2026-06-11): the wicket-cost/tilt levers move the average T20 score; balance = structure AND environment, anchored to his real benchmarks. |

## 6. Acceptance criteria (the tuning loop's exit)

Tuning loop: adjust `*_phase_bonus`, `matchup_w_*`, then BB5 levers; judge on `E1_QUICK=1` smokes (~2 min); confirm on one **full oracle run** (~15 min, N=4000 refine). Exit when, on the full run:

1. **No constant-kind pure equilibrium.** Either no fixed point in `MAX_ITERS` (cycling — fine, that's depth), or the fixed point's bowling rotation is phase-mixed (uses both kinds; e.g. P/S/P), for both sides.
2. **All-AGG no longer dominates textbook:** textbook vs A/A/A (same rotation) head-to-head within **±5 points** of even (was ~−20).
3. **Textbook is competitive:** the iteration-0 best-response gain over textbook ≤ **8 points** (was ~+20 to all-AGG·all-spin), and textbook's mirror stays ~48–49 (sanity).
4. **Skill gap survives (ADR 0003):** best-found vs naive still ≥ ~+15 points over mirror — depth restored must not flatten decisions into irrelevance.
5. **Scoring environment stays real (BB11, Nico 2026-06-11):** the rung's levers (sharpened top order, phase bonuses, matchup term) all move the run environment, so it is re-anchored to Nico's real-T20 benchmarks: textbook-vs-textbook **first-innings mean 150–167** (global T20 first-innings average band), **run rate ~8–9/over**, wickets/innings **~5–7** as a sanity rail. Phase run rates are *recorded* (real shape: PP ~8.3 / mid ~7.6 / death ~9.9) but not gated this rung — see §10. Measured by a new permanent oracle `tools/probe_scoring_env.gd`; tune `BallTuning` scoring dials (`base_r`/distributions) ONLY if outside the band — win-structure dials stay where acceptance put them.
6. **Scalar regression tests all green** (byte-identity, BB9) and the full suite ≥ 397 + new tests.

**The full balance ledger this rung must leave healthy** (the rung touches the core, so every layer above re-verifies): (1) scoring environment §6.5 · (2) phase shape §6.5 · (3) strategy depth §6.1–6.3 · (4) skill gap §6.4 · (5) build equality win+pay §7 · (6) joker bands+prices §7 · (7) DRS side symmetry §7.

## 7. Ripple verification (BB7, after acceptance passes)

| Check | Oracle | Pass bar |
|---|---|---|
| New fair-fight floor | `sweep_jokers.gd` no-joker arm | re-measured & recorded (number will move; honesty, not a target) |
| 45 joker bands | `sweep_jokers.gd` both profiles | all in rarity band vs the new floor after dial-only re-tunes |
| Prices | DE4 interpolation on fresh realized deltas | moved jokers re-priced; pool doc + `economy-v1.html` + `joker pool` viewer DATA mirrored |
| Build spread | `build_spectrum_sweep.gd` | win-rate spread ≤ ~3 pts across builds (was 2.0) |
| Pay spread | `sweep_economy.gd` | ≤ ₸1 across builds (was ₸0.2); fee share sanity ~50% |
| DRS symmetry | `probe_side_asymmetry.gd` | DRS-both mirror still ~49/49 (this rung shouldn't touch it; regression only) |

## 8. Testing strategy (TDD per piece)

- **phase_of:** boundary mapping 1/6/7/15/16/20; `for_over` unchanged behaviour.
- **Phase tilt:** bonus applied per kind+phase at the profile site (unit, constructed innings); floor at 1.0; `bowling_plan == null` ⇒ byte-identical innings (seeded regression); directional — over N seeded innings, all-pace takes more PP wickets than all-spin AND all-spin concedes less in the middle than all-pace (the real-benchmark shape).
- **Matchup:** `resolve_ball` default `bowler_kind=-1` byte-identical (seeded); AGG-vs-spin wicket p > AGG-vs-pace at equal stats (directional over N balls); table read from BallTuning not literals.
- **Player overs:** a Player-bowled over's outcome is unchanged by `matchup_w_spin` edits (proves `-1` routing).
- **BB5 levers (if adopted):** archetype point totals still exactly 20 each / 220 team; standard_xi batting+bowling sums asserted.
- **Oracle/acceptance:** not unit tests — the E1 oracle run is the instrument (§6), findings recorded in §10.

## 9. Files

| File | Change |
|---|---|
| `scripts/data/intent_plan.gd` | + `phase_of()` |
| `scripts/data/ball_tuning.gd` | + `matchup_w_pace/spin` |
| `scripts/data/innings_tuning.gd` | + `pace_phase_bonus`/`spin_phase_bonus` |
| `scripts/domain/ball_resolver.gd` | + `bowler_kind := -1` param, matchup logit term |
| `scripts/domain/innings_resolver.gd` | phase bonus at profile lookup; pass kind (−1 on Player overs) |
| `scripts/data/team.gd` | BB5 lever 1 if adopted (archetype sharpening) |
| `tests/unit/…` | new tests per §8 |
| docs/viewers | pool doc, viewer DATA mirrors, roadmap |

## 10. Findings (close-out, 2026-06-11)

### 10.1 Headline — the static layer is un-solved, and textbook cricket emerged

Final full oracle run (N=4000 refine), shipped dials:

| §6 criterion | result |
|---|---|
| 1. No constant-kind equilibrium | ✓ fixed point **B/A/B·P/S/P vs B/A/A·P/S/P** — both sides bowl textbook P/S/P; the two sides hold *different* batting plans within 0.5 pt (flat top = live choice) |
| 2. All-AGG vs textbook | ✓ **+0.2** on the best rotation (50.2, was ~+20); the old dominant **A/A/A·S/S/S now LOSES to textbook 36.2%** |
| 3. Textbook competitive | ✓ iter-0 best-response gain **7.9** (≤8); textbook mirror 48.2; the top 6 replies to textbook are ALL P/S/P rotations |
| 4. Skill gap | ✓ eq-vs-naive **71.3** (+22 over the 49.3 mirror); hero validation: hero+eq 51.5 vs hero+textbook 44.6 (+6.9) |
| 5. Scoring environment | ✓ textbook mirror **153.5 mean / RR 8.13 / 6.26 wkts / 30% all-out** (Nico's bands 150–167 / 8–9 / 5–7) |
| 6. Suite | ✓ **411 green**; scalar paths byte-identical (poison-dial tests) |

The search also *discovered real cricket*: the equilibrium bats **B in the Powerplay** (see off the buffed new-ball pace), attacks the middle, and bowls P/S/P. eq-vs-textbook = 57.0 (was 67.7) — textbook is a genuinely strong plan now.

### 10.2 Final dials

`pace_phase_bonus [1.5, −1.5, 1.5]` / `spin_phase_bonus [−1.5, 1.5, −1.5]` (±0.7 strawman was inert — the base ±2 style tilt is control-dominated; ±1.5 is where the per-phase buy flips) · `matchup_w_spin [0, 0, +0.30]` · `base_r 0.0→0.2` (BB11 re-peg) · BOWLER archetype bats **1/1** (BB5) · `DRSPolicy.base_p 0.4→0.32` · joker dials per §10.4.

### 10.3 BB5 — Nico's tail lever: tried fully, shipped half, by measurement

- **Full sharpening (BATTER 9/9/1/1 + BOWLER 1/1/9/9): rejected.** It barely moved the strategy structure (gain 8.0→7.7) but **blew the build-equality spread 2.0→4.6 pts** and sank the hero floor ~7 pts: 9-power openers saturate the scoring sigmoid, and any hero becomes a relative hole that gap-fill repays in worthless 10th-composure points. Also pushed the env to the band edge (167.0) with an inverted phase shape.
- **Tail-only (BOWLER bats 1/1, BATTER stays 8/8): shipped.** Build spread back to **2.0** exactly; wickets/innings 5.07→**6.26** and all-out 17.7%→**30.4%** (the lever working: more wickets fall and they cost more); env re-pegged via `base_r`.

### 10.4 BB7 ripple — what the new mechanics did to everything above them

- **Two measurement-fairness bugs found and fixed en route:** (1) `sweep_jokers` gave the Player P/S/S but the opponent textbook P/S/P — EV-equivalent pre-tilt, ~10 win-pts apart post-tilt → opponent now bowls the same plan (floor 39.2→45.9 in steps); (2) **BB4 reversed**: kind-less hero overs missed the phase bonus, a hidden **~3.5 runs/match tax on bowling-capable builds** — hero overs now inherit the rotation's kind. **New symmetric-plan floor: 45.9%** (margin −1.25, ≈ hero-context residual; the side-asymmetry probe is dead clean, all mirrors 49–50.5). The old 48.9 floor is not comparable — it contained a Player-favouring plan asymmetry nobody could see pre-tilt.
- **Joker bands:** the steeper tail inflated every DRS joker (more wickets = more reviews): Cool Head +6.9→**+1.6**, Snicko +8.2→**+4.1**, Spare Review +5.7→**+3.5**, Review Master **+8.0** (dials: accuracies 0.10→0.05 / 0.12→0.10, base_p 0.32). Pressure/survival Rares lifted into band: Carry Your Bat **+4.6**, Dot Ball Pressure **+5.1**, Compounding Pressure **+4.7**, Choke Hold **+7.7**, Chase Master realized **+7.7**. **Recorded residuals** (borderline / fire-rate class, not chased): Captain's Call +3.5 (integer grant, no scalar), Wicket Maiden +2.0 + Boundary Hunter +2.2 (participation/condition-capped — the rung-3 residual class; Boundary Hunter is *structurally* worse now because the matchup term prices its latched aggression — arguably the mechanic working).
- **17 prices re-interpolated** (DE4); pool doc + economy viewer mirrored.
- **Economy re-pegged:** the env shift broke pay equality (spread ₸5.3 — hotter SRs overpaid the batter's tempo component) → `sr_par_pay 110→125`, `wicket_rate 8→10` (thematic: wickets cost more, taking them pays more) → **pay 66.2/65.8/66.4, spread ₸0.6, fee share ~50%**.

### 10.5 Known divergence + seeds for later rungs

- **Phase shape inverted vs real T20:** PP is our fastest phase (9.7) and death milder (7.4); real cricket runs PP ~8.3 / death ~9.9. Cause: scoring saturation at the top + the steep tail putting weak hitters in at the death. Fix needs a real mechanic (set-batter momentum / death-overs urgency), not dials — future-rung seed. `phase_runs` on `InningsResult` + `probe_scoring_env.gd` are the permanent instruments.
- The equilibrium converged again (B/A/x·P/S/P) rather than cycling — acceptable per §6 (phase-mixed, flat top), but **E2's state-conditional layer** is still what makes the choice opponent- and match-state-dependent.
- The joker sweep's hero-context floor (45.9) vs the probe's clean team-vs-team mirrors: the ~−1.25-run residual is the all-rounder hero in a plan-ful match (conservation convexity under phase bonuses) — small, documented, watch at E2.
