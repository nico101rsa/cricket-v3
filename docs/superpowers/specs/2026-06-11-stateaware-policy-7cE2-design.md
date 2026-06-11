# State-aware policy (rung 7c-E2) — design

**Date:** 2026-06-11 · **Status:** approved (AFK defaults recorded per 2026-06-07 policy) · **Branch:** `stateaware-policy-7cE2`

## 1. What this rung is

The **depth layer** queued after E1 + bowling-balance: make a side's batting Intent react to the **match state** instead of being fixed before the ball is bowled. E1 proved the static layer is searchable and bowling-balance un-solved it into textbook cricket — but every plan is still chosen blind. Real T20 depth lives in the chase: the *required run rate* (the runs-per-over the chasing side still needs) forces intent up or down as the match unfolds. E2 builds the smallest mechanism that captures that, then re-runs the E1 self-play search to answer: **does state-aware play dethrone the static equilibrium?**

Glossary (first use): **required run rate (req RR)** = `(target − total) × 6 / balls remaining` — how fast the chasing side must score from here. **Static equilibrium** = the bowling-balance fixed point `B/A/B·P/S/P` (bat: Balanced powerplay, Aggressive middle, Balanced death; bowl: Pace/Spin/Pace).

## 2. Scope (DS1)

**In:** state-aware **batting intent** — chase-pressure escalation + collapse protection — as optional rules on `IntentPlan`; the search oracle + findings; viz.

**Out (deferred, recorded seeds):**
- **Boost press timing + the opponent water meter** — the Boost is joker-coupled (the #31–#37 stack was banded against fixed press overs); re-searching press timing moves joker bands → its own rung.
- **DRS review thresholds** ("save the review for the death") — same coupling: every DRS joker band/price would ripple.
- **State-aware bowling** (rotation reacting to the batting side's state) — the bowling top is deliberately flat post-bowling-balance; chase pressure is a batting phenomenon first. Re-visit if E2's adaptive layer fails to dethrone statics.
- **First-innings pacing rules** (par-score awareness while setting) — no target exists; the collapse rule still applies both innings, which is the cheap 80%.

One mechanism per rung — the C2a–C2g precedent.

## 3. The mechanism (DS2)

Three optional rule fields on `IntentPlan` (`scripts/data/intent_plan.gd`), all **disabled by default**:

```gdscript
var chase_up_rr: float = -1.0    # chasing & req RR >= this -> escalate one band
var chase_down_rr: float = -1.0  # chasing & req RR <= this -> de-escalate one band
var collapse_wkts: int = -1      # wickets fallen >= this -> de-escalate one band
```

New method `for_state(over, total, wickets, balls, target, max_balls) -> int`:

1. `base = for_over(over)` (the static phase band — unchanged source of truth).
2. **Chase rules** (only when `target > 0` and balls remain): req RR ≥ `chase_up_rr` → delta +1; req RR ≤ `chase_down_rr` → delta −1. Up wins if both are somehow satisfied (can't be, with sane thresholds up > down — but the guard is explicit).
3. **Collapse rule** (both innings): `wickets >= collapse_wkts` → delta −1, **only when the chase didn't escalate** (DS2a: a side forced to chase 11-an-over keeps attacking even 5 down — that's real T20; collapse protection is for setting/cruising).
4. Return `clampi(base + delta, DEFENSIVE, AGGRESSIVE)` — the enum is ordered `DEFENSIVE(0) < BALANCED(1) < AGGRESSIVE(2)`, so a band step is `±1`.

**All rules disabled → `for_state` returns `for_over` exactly** (the byte-identical guarantee). No RNG draws — determinism untouched.

## 4. Threading (DS3)

One call-site change in `InningsResolver.simulate_innings` (line ~155): `intent = intent_plan.for_state(over, total, wickets, balls, target, max_balls)`. Everything needed is already in scope. The intent can now shift **mid-over** as req RR moves — fine: the C2g intent-switch Form source samples at over start only (unchanged), and the Boundary Hunter override still wins (applied after).

Both sides get adaptivity for free: `opp_intent_plan` is the same class, threaded to the opposition innings — symmetric by construction, no new params on the 24-param signature.

The **bowling captain's intent** (`bowl_intent_plan`, C2b) stays `for_over` — the audit showed it is a joker gate with zero intrinsic EV; adapting it buys nothing.

## 5. The search (DS4 + DS5)

New oracle **`tools/sweep_policy_state.gd`** (E1 oracle structure reused; `E2_QUICK=1` smoke mode). No statted Player, even ★3, no jokers/Boost/DRS — the E1 measurement frame.

**Adaptive space (DS4):** bowling pinned at textbook `P/S/P` (the bowling-balance result; rules don't touch bowling). 4 intent bases × 80 rule combos = **320 candidates**:
- bases: `B/A/B` (static eq), `B/A/A` (eq runner-up), `A/B/A` (textbook), `B/B/B` (balanced)
- `chase_up_rr ∈ {off, 8, 9, 10, 11}` · `chase_down_rr ∈ {off, 5, 6, 7}` · `collapse_wkts ∈ {off, 3, 4, 5}`

Rules-off combos duplicate their static base — kept as sanity anchors.

**Protocol (DS5, mirrors E1):**
1. **Screen** all 320 vs the fixed static equilibrium (N=400, paired seeds).
2. **Refine** top-12 + the static eq incumbent on fresh seeds (N=4000) → the **dethrone headline**: best adaptive vs static eq.
3. **Iterated best response in the joint space** (216 statics + 320 adaptives = 536 arms/screen) alternating sides from (best adaptive, static eq) to fixed point (eps 1.5 pts, streak 2, max 4 iters) → is the *new* equilibrium adaptive-vs-adaptive?
4. **Gap arms** (N=4000): new-eq vs naive(random static)/textbook/static-eq/balanced + mirrors → refreshed E3 ladder anchors.
5. **Hero validation** (N=4000): 5/5/5/5 hero side playing new-eq vs static-eq opponent, against hero playing static-eq — does the conclusion transfer to real matches?

Runtime estimate ~25–35 min full (backgrounded), ~2 min quick. Viz: **`docs/mockups/policy-state-v1.html`** — rule-grid heatmap per base + dethrone/gap bars + trajectory.

## 6. What success looks like

- **A1 (regression):** all rules disabled → byte-identical innings; the existing 411 tests stay green untouched.
- **A2 (directional):** a chase-escalation plan converts more big chases than its static base (seed-summed directional test).
- **A3 (the headline):** best adaptive **beats the static equilibrium head-to-head** — any clear margin dethrones (expectation: small single digits; only ~half of matches are chases and the static top was flat). If adaptivity reads ≤ noise, that finding is recorded honestly and the deferred levers (state-aware bowling, Boost timing) become the next candidates.
- **A4 (fairness):** adaptive mirror sits ~48–50 with the side-asymmetry probe logic (both sides same plan object class — no hidden asymmetry).
- **A5 (env):** defaults untouched → `probe_scoring_env.gd` smoke unchanged (153.5 / RR 8.13 band).
- **A6 (ladder):** skill-gap arms re-anchored for E3 (naive ≈ floor / textbook ≈ mid / new-eq ≈ ceiling).

## 7. Ripple (DS6)

**None by construction.** The rules are opt-in fields defaulting off; no dial, archetype, or resolver constant changes. The joker oracle (`sweep_jokers.gd`), build oracle, economy, and the 45.9% floor all measure static plans and are untouched. (Contrast bowling-balance, which changed `resolve_ball` dials and re-pegged everything.) If a *future* rung ships adaptive plans as the AI default, the floor must be re-measured then — recorded as a seed.

## 8. Tests (TDD, inline)

1. `for_state` == `for_over` across overs/states when rules disabled (A1 unit form).
2. Escalation: high req RR → band +1; clamped at AGGRESSIVE.
3. De-escalation: cruising req RR → band −1; clamped at DEFENSIVE.
4. Collapse: wickets ≥ threshold → −1 both innings; **suppressed when chase escalation fired** (DS2a).
5. Chase rules inert when `target == 0`; no div-by-zero at 0 balls remaining.
6. Resolver threading: same seed, rules-off plan == static plan (byte-identical `InningsResult`); an escalating plan *changes* a chase innings; determinism with rules on.
7. Match-level directional (A2): chase-up plan wins more close chases than static base over a seed batch.
8. `PolicySearch` helpers: adaptive enumeration size/labels; `intent_plan_of` carries rule fields.

## 9. Files

- `scripts/data/intent_plan.gd` — rule fields + `for_state` (+ tests `tests/unit/test_intent_plan.gd`)
- `scripts/domain/innings_resolver.gd` — one call-site change
- `scripts/harness/policy_search.gd` — adaptive-space helpers (`enumerate_adaptive`, `adaptive_label`, rule-aware `intent_plan_of`)
- `tools/sweep_policy_state.gd` — the E2 oracle (new)
- `docs/mockups/policy-state-v1.html` — viz (new)

## 10. Findings

*(filled at close-out)*
