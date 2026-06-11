# Card rescale to /100 — design

**Date:** 2026-06-11 · **Rung:** card-rescale (after 7c-E2, before E3 difficulty ladder) · **Branch:** `card-rescale-100`
**Mode:** AFK — default decisions recorded as DR1–DR14 below (project CLAUDE.md policy).

---

## 1. Goal (plain English)

Player and teammate attributes currently live on a tiny ~1–8 scale (a "card" like 8/8/2/2),
and league strength is applied by *adding* an offset to every card and flooring at 1 — so every
bad team floors out to the same mush and the worst leagues lose all texture.

This rung moves the whole game onto a **/100 card scale** (the scale every sports game reader
already understands), anchored to Nico's spec:

> *A middle-league team's top batters read **50 batting**. Better leagues sit above 50; the worst
> leagues well below (a worst-league card reads ~12/12/…/2/2 — fractional values, no floor-out).*

Three properties must hold at the end:

1. **Mid-league behaviour is unchanged** — the scoring environment (154.7 avg runs / RR 8.20 /
   6.27 wickets on current `main`), the 45.9% fair-fight floor, build spread 2.0, pay spread
   ₸0.6, and the E2 adaptive equilibrium all survive. This is a **units change**, not a re-tune.
2. **Low leagues keep texture** — proportional scaling replaces the additive offset + floor-1,
   so a weak team is a *scaled-down* version of its card shape, not a floored-out clone.
3. **Player creation + economy speak the new units** — budget, caps, upgrade prices remapped.

## 2. Why a pure rescale is behaviour-preserving (the maths)

Every load-bearing use of attribute numbers is one of:

- **A difference** inside a logistic: `k_w·(attack − composure)` (wicket logit),
  `k_r·(power − control)` (scoring logit). Multiplying every attribute by a factor **F** and
  dividing the gains `k_w`, `k_r` by the same F leaves both logits bit-for-bit equal.
- **A ratio of sums**: batting-position and bowling-overs curves use
  `share = batting/(batting+bowling)` — a pure scale cancels out entirely. Dials untouched.
- **Linear conservation**: `_conserved_bowling` is linear in its attribute args (the
  `concentration_k` penalty term multiplies a *difference*), so the conserved value scales by F
  exactly. Dial untouched.
- **Linear differences**: gap-fill deficit, `team_bat_offset` — scale by F.

So one global factor rescales the world exactly. The only divergences are **rounding points**
(`roundi`, `maxi(1, …)` floors, integer noise draws) — handled by the two-stage migration (§4).

**Logit-space numbers do NOT scale**: `base_w`, `base_r`, `intent_w/r`, `matchup_w_*`, all joker
multipliers, DRS probabilities, Boost multipliers. They live after the `k·diff` compression and
are untouched. (This is why all 45 joker magnitudes and prices should survive unchanged.)

## 3. The scale factor and the anchors (DR1–DR3)

**DR1 — F = 6.25** (= 50/8), applied globally. It is the unique factor that lands Nico's primary
anchor exactly: the mid-league top-batter archetype (power/composure 8) → **50**. His other
texture numbers confirm it: worst-league card "~12/12" = 2 old units × 6.25 = 12.5 ✓; "tail
single digits" = 1 old unit = 6.25 ✓.

**DR2 — anchor table (mid league, ★3, even contest):**

| Quantity | Old | New (/100) |
|---|---|---|
| Top-batter card (power/composure) | 8/8 | **50/50** (the anchor, exact) |
| Batter card bowling side | 2/2 | 12.5/12.5 |
| Specialist-bowler card (attack/control) | 9/9 | **56.25/56.25** (≈ Nico's "50 bowling") |
| Bowler card batting side (the BB5 tail) | 1/1 | 6.25/6.25 |
| All-rounder card | 5/5/5/5 | 31.25 ×4 |
| Card budget (any XI member / Player) | 20 | **125** |
| Team batting total (gap-fill target) | 114 (BB5 steep-tail split) | 712.5 |
| Team bowling scalar (tour mean, internal) | 5 | 31.25 |
| ★3 mid-tour scalar = the global card anchor `REF_SCALAR` | 5.3→5 | **31.25** (★3-centred mapping, DR5) |

The specialist bowler lands at 56, not 50: the bowler archetype is 1/1/9/9 because the
**tail-steepening lever** (bowling-balance BB5, Nico's call, measured 2026-06-11) moved batting
2→1 and bowling 8→9 to keep the 20-point sum. Re-authoring to a symmetric 12.5/12.5/50/50 would
undo a shipped, measured lever — **measurement outranks roundness**. The anchor is honoured as
"≈50"; a cosmetic re-anchor is possible later if Nico wants it (it would need a base_w/base_r
compensation + share-curve refit, recorded here so the option isn't lost).

**DR3 — attributes become floats.** `Attributes.power/composure/attack/control: int → float`.
Fractional card values are first-class (the whole point of "no floor-out"). Everything
downstream that carried these as `int` widens to `float` (precedent: the bowling-stat
`int → float` widening at PR #31). `BallResolver.resolve_ball` batting params, `partner_batting`,
`BowlingAttack`'s four fields, `_build_batters` dict values, gap-fill arithmetic all go float.

**Dials that scale by F** (×6.25): `TourDistribution.mean` (5→31.25), `spread` (1.5→9.375),
noise step (see DR7), `BowlingAttack.DEFAULT_TILT` (2→12.5), `InningsTuning.pace/spin_phase_bonus`
(±1.5→±9.375), every `maxi(1,…)`/`maxf(1.0,…)` attribute floor (1→6.25 where it means "one old
attribute point", see DR8), `Classifier` thresholds (6/4/2 → 37.5/25/12.5).
**Dials that divide by F**: `BallTuning.k_w` 0.24→**0.0384**, `k_r` 0.34→**0.0544**.
**Untouched**: `base_w`, `base_r`, `intent_w/r`, `matchup_w_*`, `tail_floor/slope` (multiplicative),
`pos_base/pos_span`, `bowl_overs_*` (share-driven), `bowl_concentration_k` (dimensionally a pure
multiplier on an attribute difference — scales with the world), all joker/DRS/Boost/economy-pay
dials.

## 4. Two-stage migration (DR4) — how we *prove* the rescale is right

The danger in a whole-world rescale is one forgotten dial (a phase bonus, the tilt, the noise)
silently shifting balance under the noise floor of a distributional comparison. So:

**Stage A — pure rescale, old grid preserved.** Apply F everywhere, but at every point where the
old code rounded to the integer grid, snap to the **old grid scaled** (`roundi(x/6.25)·6.25`),
and keep the noise draw as the same integer `randi_range(-1,1)` call × 6.25 (same RNG stream).
Acceptance: **`tools/probe_scoring_env.gd` prints digit-for-digit 154.7 / RR 8.20 / 6.27**, and
the full suite is green. A byte-identical probe is proof every scaled dial is consistent.
(Tolerance fallback: if float ulp noise flips a digit, ≤0.1 drift is acceptable *with the diff
understood*; anything larger means a missed dial — stop and find it.)

**Stage B — the real world.** Remove the snap helpers (fractional values live), then make the
deliberate behaviour changes of §5–§7. Mid-league drift is re-measured by the ledger (§9).

## 5. Proportional league scaling (DR5–DR6) — the design change

**Today:** `simulate_match_teams` computes `team_bat_offset = team_bat_scalar − ref3` and
`_build_batters` does `power + offset`, floored at 1. Every card in a bad team is shifted down by
the same amount and squashes into the floor — the worst league is texture-dead.

**DR5 — replace the offset with a factor, and centre the star map on ★3.**
- The old pipeline *rounded* tour strength (★3 read `roundi(5.3) = 5`), so unrounding it would
  silently hand mid-league bowling +0.3 old points — a known drift smuggled in by a units rung.
  Instead the star→strength mapping is **re-centred on ★3** (the even-contest balance baseline):
  `Team.strength_frac() = clampf((stars − 3.0) / 5.0 + 0.5, 0.0, 1.0)` replaces `stars / 5.0`
  at both strength call sites — ★3 → frac 0.5 → **exactly the tour mean**, ★0.5 → 0.0,
  ★5 → 0.9. (The old map's centre was ★2.75 and rounding blurred it; the top half-star band
  compresses slightly — star-gap directional tests are threshold-based and stand.)
- New global constant `MatchResolver.REF_SCALAR := 31.25` — the mid-tour ★3 scalar
  (= the mid tour mean under the ★3-centred map), i.e. *the strength at which a card plays at
  face value*. A ★3 team in the mid tour has factor 1.0 (± noise) → top batter plays at 50,
  and the ★3 strength distribution {25, 31.25, 37.5} is byte-equal to the old {4,5,6} × 6.25 —
  the strength pipeline itself contributes **zero** Stage-B drift.
- `team_bat_factor = team_bat_scalar / REF_SCALAR` (float), threaded where `team_bat_offset`
  went (`simulate_innings`/`simulate_match` param `team_bat_offset: int` →
  `team_bat_factor: float = 1.0`).
- `_build_batters` roster path: `power = m.power * factor`, `composure = m.composure * factor`,
  safety floor `maxf(0.5, …)` only (≈ a twelfth of an old point — "no floor-out", DR8).
- The reference is **global, not per-tour**: that's what lets a low league actually *be* weak
  (today's per-tour `ref3` cancelled the tour mean out of the batting side entirely; league
  weakness only reached batting through ★ spread). Bowling already consumes the scalar
  absolutely, unchanged in shape.

**DR6 — league-band anchor texture (data for E3, not built here).** The E3 difficulty ladder
will assign each league Level a tour mean; this rung defines what those means *look like* on
cards. Strawman table (tour mean as a fraction of mid; E3 sets the real values):

| Band | Flavour | Tour-mean × mid | Top batter card | Tail card |
|---|---|---|---|---|
| 1 (worst) | club / scrapheap | 0.25 | 12.5 | ~1.6 |
| 2 | minor league | 0.5 | 25 | ~3 |
| 3 (anchor) | mid league | 1.0 | **50** | 6.25 |
| 4 | top domestic | 1.15 | 57.5 | ~7 |
| 5 (best) | elite / international | 1.3 | 65 | ~8 |

Nico's worst-league texture ("~12/12/…/2/2, tail single digits") is band 1 ✓. Only band 3 is
load-bearing this rung; the mechanism + this table ship, E3 consumes them. The ledger (§9) runs
the env probe at band 1 and band 5 as an *eyeball* (recorded, not gated — no real-world band
exists yet for those leagues to match).

**DR7 — noise model unchanged, just scaled.** `Team.batting/bowling_strength` keeps the discrete
`randi_range(-1, 1)` draw (same RNG stream type), multiplied onto the new scale as
`noise_step := 6.25` (`TourDistribution.noise: int = 1` stays the step *count*; new field
`noise_step: float = 6.25`). Switching to continuous noise would change the strength variance —
a separate tuning question, not smuggled into a units rung. Under proportional scaling the same
absolute noise becomes ~±19% of card value at mid (today: ±12.5% on the top card, more on the
tail) — the ledger watches for env drift; if it moves out of band the noise re-peg is the first
dial (recorded in §10 if touched).

**DR8 — floors.** Old `maxi(1, …)` floors meant "one old attribute point" and were load-bearing
(they caused the floor-out). New floors are *safety only*: `maxf(0.5, …)` on derived cards and
profile lookups (0.5/100 ≈ nothing), `maxf(1.0, …)` retained inside `_conserved_bowling` and
`BowlingAttack` (an attack of ≤1/100 is already a non-bowler). Gap-fill keeps a 1.0 floor per
stat while docking. No mechanism may quantize a card back to a grid.

**DR9 — gap-fill walks the new grid.** `_apply_batting_gapfill` walks in **1.0-point (/100)
steps** (top-first, alternating composure/power as today), with one final fractional step for any
remainder < 1.0 — deficits are floats now (a creation build is a 5-grid number, archetypes are
.25-fractional). Same topology, same leverage ordering; only the step size changes.

## 6. Player creation + economy remap (DR10–DR12)

**DR10 — creation budget.** `CREATION_TOTAL 20 → 125.0`, `CREATION_MIN 1 → 5.0`,
`CREATION_MAX 8 → 50.0`. The budget **must** be 125 (= 20 × 6.25): the Player replaces a
125-point archetype in the XI and build-balance was measured at point-parity; a rounder 120
would silently hand every build a 5-point teammate subsidy via gap-fill.
- UI (`scenes/player_creation/build.gd`): sliders min 5 / max 50 / **step 5** (drag stays
  snappy; 5 new points = 0.8 old points, finer than the old grid). Readouts show whole numbers.
- `PlayerCreationDraft` default build becomes **35/30/30/30** (sum 125, on the 5-grid, classifies
  ALL_ROUNDER under the scaled thresholds). The domain validator checks sum == 125 (approx-equal
  for floats) and range only — the 5-grid is a UI convention, not a domain rule.
- NPC archetypes stay exempt from the per-attribute cap (prior AFK call, unchanged — the bowler's
  56.25 > 50 is intentional).

**DR11 — attribute upgrade price.** `EconomyTuning.attr_cost_base 10 → 0.256` (= 10 ÷ 6.25²),
keeping ₸-per-effective-upgrade identical: +6.25 new points at card 50 costs
0.256 × 50 × 6.25 = ₸80 — exactly the old "+1 at 8 costs ₸80". The shop's natural upgrade unit
becomes a **+5 block** (≈ ₸64 at card 50); block size is a shop-UI decision later, the per-point
price is what ships here. `sweep_economy.gd` re-verifies the skills-vs-jokers ROI ledger.

**DR12 — save migration.** `SaveManager`/load path: if a loaded Player's
`attributes.sum() == 20` (legacy scale), multiply all four (and `starting_attributes`) by 6.25
once. Cheap, lossless, keeps Nico's existing save alive. New saves write /100 natively.

## 7. Out of scope (DR13)

- **Per-bowler bowling cards** — bowling stays a team scalar + tilt; the bowler card's 56.25
  attack still only bowls when the *Player* owns it. (Future rung, pairs with husbanding 4c.)
- **Continuous strength noise** (DR7), **pitch conditions** (queued seed), **E3 ladder values**
  (DR6 table is strawman data), **shop UI** for +5 blocks (DR11), **set-batter/death-urgency**
  phase-shape work (watch-list).
- **Cosmetic bowling re-anchor to exactly 50** (DR2) — recorded, not built.

## 8. Test plan (DR14)

TDD per project discipline (red = parse error / failing assert, green = count climbs past 428).
New/updated tests, by surface:

1. **Attributes /100**: validator accepts 35/30/30/30 and 50/50/12.5/12.5-style sums at 125,
   rejects 20-scale builds; float fields round-trip `duplicate_typed`.
2. **Scale consistency (the Stage-A theorem test)**: for a canonical build set
   (batter/bowler/all-rounder/hero), `resolve_ball` logits old-vs-new agree — encoded as
   p_wicket/scoring-s equality against hand-computed values with the new dials.
3. **Positions/overs invariant**: `player_position` and `player_overs` for the canonical builds
   ×6.25 equal their old outputs (shares cancel the scale).
4. **Proportional scaling**: factor 1.0 → cards at face value; factor 0.25 → 50→12.5 with **no
   floor-out** (tail 6.25 → 1.5625, still distinct from a 2nd tail card); monotonic in factor.
5. **Gap-fill**: float deficit conserved exactly (sum returns to 762.5), fractional remainder
   lands, Player slot untouched.
6. **Conservation**: `_conserved_bowling` float path scales (new-units inputs reproduce
   old-units outputs ×6.25).
7. **Classifier**: scaled thresholds classify the three archetypes + a WK build correctly.
8. **Migration**: a sum-20 Player loads as ×6.25; a /100 Player loads unchanged.
9. **Determinism**: existing same-seed tests stand (no RNG draw added/removed anywhere).

Existing tests: a mechanical sweep updates literal builds/scalars (8/8/2/2 → 50/50/12.5/12.5,
scalars 5 → 31.25 etc.). Any test asserting old absolute card values is updated, not deleted.

## 9. Re-verification ledger (gates the merge)

Run after Stage B, all numbers recorded in §10:

| Check | Oracle | Gate |
|---|---|---|
| Scoring env, mid league | `probe_scoring_env.gd` | in band 150–167 / RR 8–9 / wkts 5–7; expect ≈154.7 (peg, E2 §10.4) |
| Stage A byte-identity | same | digit-identical 154.7 / 8.20 / 6.27 |
| Fair-fight floor | `sweep_jokers.gd` no-joker arm | ≈45.9% (±1) |
| Build equality | `build_spectrum_sweep.gd` | spread ≤ ~2.5 pts |
| Pay equality | `sweep_economy.gd` | spread ≤ ₸1 |
| Side symmetry | `probe_side_asymmetry.gd` | mirrors ~49–50.5 |
| Joker bands | `sweep_jokers.gd` full | deltas ≈ prior run (logit-space → expect unchanged); re-interpolate prices only if a band breaks |
| Policy layer | `sweep_policy_state.gd E2_QUICK=1` | smoke passes, adaptive arms still lead |
| Low-league texture | env probe at band 1 / band 5 tour | eyeball + record (no gate) |

If mid-league drift exceeds a gate: it's a missed dial, not a re-tune target — find it (the
Stage-A checkpoint should make this near-impossible).

## 10. Findings (close-out, 2026-06-11)

### 10.1 Stage A — the rescale is exact
`probe_scoring_env` after the full ×6.25 sweep (legacy grid snapped) printed **byte-identical**
output to the `main` baseline — every digit: 154.7 mean / sd 39.2 / min-max 19-254 / RR 8.20 /
6.27 wickets / all-out 30.1% / phase RR 9.72-6.57-7.47. The dial table in §3 is therefore
provably complete. 435 tests green at the checkpoint.

### 10.2 Stage B ledger (mid league)

| Check | Peg | Measured | Verdict |
|---|---|---|---|
| Scoring env | 154.7 / 8.20 / 6.27 | **153.4 / 8.22 / 6.24** (sd 43.1, all-out 32.0) | ✓ in band; −1.3 runs = the proportional-noise widening (DR7), no re-peg |
| Build spread | 2.0 pts | **1.9 pts** (46.6–48.5 across 7 builds) | ✓ |
| Pay spread | ₸0.6 | **₸0.3** (66.7 / 67.0 / 67.0, fee share 49.3%) | ✓ after one-dial re-peg: `runs_rate` 0.4 → **0.45** (the noise change trimmed batter runs ~₸2) |
| Side symmetry | mirrors 49–50.5 | 48.5–50.7 across all 5 arms | ✓ |
| No-joker floor | 45.9% | *(see 10.3)* | |
| Phase shape | PP fastest (known divergence) | PP 9.67 / mid 6.54 / death 7.31 | unchanged, watch-list stands |

### 10.3 Joker bands + policy smoke
Full 47-arm `sweep_jokers` (N=2000): **no-joker floor 45.5%** (peg 45.9 ±1 ✓). Every joker
within ~1 pt of its published band — Legendaries: The Chase Master +8.0, The Review Master +7.8,
Choke Hold +7.4, Power Surge +6.6, Death-Over Stranglehold +5.8; Rares in band (Carry Your Bat
+4.5, Dot Ball Pressure +4.5, Snicko +4.2, Captain's Call +3.8); known fire-rate/participation
residuals unchanged (Wicket Maiden +1.9, Boundary Hunter +1.4); enablers read +0.0 as designed;
no joker negative, none an auto-win; stacks shaped as before (Reviewer +36.5 › Boost +26.8 ›
Batting +18.4); Chase Master fire-rate 50.5%. **No price re-interpolation needed** — logit-space
effects rode through the rescale exactly as §2 predicted.

`E2_QUICK` policy smoke (2.4 min): joint self-play converges (A `B/A/A·P/S/P+u11d5c4`,
B `B/A/B·P/S/P`); adaptive-eq vs naive 72.3 / textbook 56.7 / balanced 55.3, hero transfer +3.7
(53.0 vs 49.3). The +1.6-pt dethrone margin is below smoke resolution (N=300) — **re-anchor the
E3 ladder with a full 25-min run when E3 starts** (recorded for the handoff).

### 10.4 League texture (the new capability, eyeball record)
`ENV_TOUR_MEAN` override added to the probe (permanent, for E3):
- **Band 1** (mean 7.8125, factor 0.25 — top batter card 12.5, tail 1.6): **112.8 mean / RR 6.51
  / 8.7 wkts / 60.5% all-out**, death (4.48) *slower* than PP (7.90) — the tail genuinely can't
  bat. Reads like club cricket, not a degenerate sim. ✓
- **Band 5** (mean 40.625, factor 1.3 — top batter 65): **167.2 / RR 8.76 / 5.31 wkts / 24.1%
  all-out**. Elite. Note the asymmetry: batting scales multiplicatively, bowling linearly in the
  logit — high bands lean batting-friendly; E3 tunes band means with this in hand.

### 10.5 Decisions taken during the build (deviations from plan)
- Team batting total is **712.5** (legacy 114 — the BB5 steep-tail split), not the 122 the
  roadmap prose quoted; spec table corrected.
- Plan Tasks 11+12 merged into one commit: switching the tools' `ref3` to `REF_SCALAR` without
  the simultaneous factor change would have biased the probes mid-stream.
- Gap-fill ships once (Task 6) with SCALE-chunk walks + a fractional final chunk — exact for
  Stage A byte-identity AND for 5-grid creation deficits; no Stage-B re-step needed.
- `test_match_resolver`'s star-directionality tour used a custom `spread = 3` the conversion
  regex missed — under the snapped grid all stars collapsed to the mean (coin-flip win rates).
  Caught by the suite; the lesson: **a units sweep needs a leftover-literal grep per dial, not
  just per pattern** (the §3 dial list was the checklist that caught everything else).
