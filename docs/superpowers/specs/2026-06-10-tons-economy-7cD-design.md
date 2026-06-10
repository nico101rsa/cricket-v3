# ₸ Economy (rung 7c-D) — pricing jokers + skills, match pay, spend ROI

**Date:** 2026-06-10 · **Rung:** 7c-D (the ₸ economy) · **Mode:** AFK (defaults decided here, recorded as DE1–DE10)

## 1. Purpose

Give the game its first working economy numbers, grounded in the balance harness instead of guesswork:

- **Income:** a tested `match_pay()` function — how many Tons (₸, the career currency, ADR 0008) a match earns (base contract by Team ★ + performance bonus), at the scale the design docs already use ("base 50 + perf 18 = 68 ₸").
- **Prices:** every one of the 45 jokers gets a concrete ₸ price derived from its **measured realized strength** (in-condition win-delta × fire-rate, from the rung-2/3 sweeps), positioned inside its documented rarity price band. Attribute upgrades get a cost curve.
- **ROI verification:** a new harness oracle (`tools/sweep_economy.gd`) measures ₸ income per build and the marginal win% of +1 attribute, so the **skills-vs-jokers trade-off** (the ADR 0003 Meta layer) is checked for "no dominant answer" rather than assumed.
- **Loadout cap codified:** the 4-joker slot cap already locked in CONTEXT.md becomes a machine-readable dial, resolving the roadmap's open "~5-slot" thread (answer: it's 4, per the docs; the 7–8-joker archetype-stack sweep arms are measurement-only and unreachable in real play).

This is a **domain + harness rung** — pure calculators, data, sweeps, docs. No Shop UI, no shop state machine (that's the Theme-5 Shop screen build).

## 2. Context (what exists)

- **Design (locked):** Tons earned per match = Team base (stronger Teams pay less) × scaled by performance (runs, wickets, KMs won) — CONTEXT.md §Tons. 5 Shop visits/Season; per visit at most: buy 1 joker (of 1C+1R+1L offered), upgrade 1 attribute (+1, cost scales with current value), sell 1 (partial refund), hold 1 — CONTEXT.md §Shop. 4 joker slots (slot 4 unlocks at first Level win). Tons persist across Seasons (Career bank); jokers are Season-scoped (+1 carry-over).
- **Strawman price bands** (docs/joker-pool-v1.md): Common ₸30–50 · Rare ₸90–120 · Legendary ₸220–250, with the note "once Tons inflow per Match is set (Theme 7), these all rescale together". This rung sets the inflow and fills the per-joker numbers.
- **Measured strengths** (rung 2 re-tune + rung 3 scenario sweep + capped-joker mechanic changes): every non-enabler joker's solo win-delta sits in its rarity band (Common +1–4% · Rare +4–7% · Legendary +7–12%) vs the 48.1% fair-fight floor; conditional jokers have measured **fire-rates** (e.g. The Chase Master ~50% — the toss) and the pricing rule of thumb is **realized = in-condition × fire-rate**.
- **Code:** no economy code exists except `Player.tons_balance` (placeholder). `JokerCatalog` has no price field. Oracles: `tools/sweep_jokers.gd` (joker win-deltas, 2 profiles), `tools/build_spectrum_sweep.gd` (per-build win%/rating).

## 3. Scope

**In:** `EconomyTuning` (dials) · `Economy.match_pay()` (pure) · `Economy.attr_upgrade_cost()` · per-joker prices in `JokerCatalog` + filled ₸ column in the pool doc · `tools/sweep_economy.gd` (income per build + marginal attribute value) · `docs/mockups/economy-v1.html` viz · tests.

**Out (deferred):** Shop scene/UI + transactional state (buy/sell/hold flows — Theme 5); Tour-difficulty price scaling (single-Tour V1; a future dial); KM component of perf pay (KMs aren't in the sim yet — see DE3); save-system integration beyond the existing `tons_balance` field; self-play purchasing AI (7c-E); offer-set RNG.

## 4. Approaches considered

- **A — doc-only pricing pass:** compute prices on paper from existing sweep numbers, update the pool doc. Cheap, but nothing machine-readable, no income model, ROI unverified, and the pool-doc "rescale when inflow is set" promise stays open.
- **B — domain calculators + measured pricing + ROI harness (CHOSEN):** small pure functions + dials, prices derived from fresh sweep data, a new oracle that *measures* income and attribute value so the price/ROI claims are verified the same way every other balance claim in 7c has been.
- **C — full shop simulation** (offer RNG, hold/sell policy, season-long purchase strategies): drifts into Theme-5 UI + 7c-E self-play. Too big for one rung.

## 5. Design

### 5.1 `EconomyTuning` (`scripts/data/economy_tuning.gd`)

Dials resource, mirroring `BallTuning`/`InningsTuning`/`RatingTuning` style. Defaults are the spec strawman; the sweep tunes `runs_rate`/`wicket_rate` (DE3) and findings record final values.

```gdscript
class_name EconomyTuning
base_pay: float = 50.0        # base contract ₸ per match at ★3
star_pay_slope: float = 8.0   # ₸ less per ★ above 3 (stronger Teams pay less, CONTEXT §Tons)
runs_rate: float = 0.5        # perf ₸ per run scored
wicket_rate: float = 11.0     # perf ₸ per wicket taken
attr_cost_base: float = 12.0  # +1 attribute costs attr_cost_base × current value
sell_refund_frac: float = 0.5 # partial refund when selling a joker (DE9)
loadout_cap: int = 4          # max active joker slots (CONTEXT.md; DE8)
```

### 5.2 `Economy` (`scripts/domain/economy.gd`)

Pure static calculators (no state, no RNG):

- `match_pay(result: MatchResult, team_stars: float, tuning: EconomyTuning) -> Dictionary` → `{"base": int, "perf": int, "total": int}`.
  - `base = round(base_pay − star_pay_slope × (team_stars − 3.0))`, floored at a small minimum (₸10).
  - `perf = round(runs_rate × player_bat_runs + wicket_rate × player_bowl_wickets)` — reads the Player line from whichever innings the Player batted/bowled in (the `InningsResult.player_line()` / `player_bowl_wickets` seams from PR #17).
  - Returns the breakdown because the Result screen displays it ("base 50 + perf 18 = 68 ₸").
- `attr_upgrade_cost(current_value: int, tuning) -> int` = `round(attr_cost_base × current_value)` — +1 from 5 costs ₸60, from 7 costs ₸84 (cost scales with current value, per THEME-5-HANDOFF §3).
- `sell_refund(price: int, tuning) -> int` = `floor(price × sell_refund_frac)`.

### 5.3 Joker prices (`JokerCatalog`)

A `const PRICES: Dictionary` (id → ₸ int) + `static func price(id) -> int` + `static func price_band(rarity) -> Vector2i` (30–50 / 90–120 / 220–250). The pool doc's ₸ column is filled with the same numbers (doc mirrors code).

**Pricing rule (DE4):** within-band linear interpolation of **realized** win-delta onto the rarity price band, rounded to ₸5:

```
frac  = clamp((realized_delta − band_delta_lo) / (band_delta_hi − band_delta_lo), 0, 1)
price = round5(price_lo + frac × (price_hi − price_lo))
```

with delta bands Common 1–4 / Rare 4–7 / Legendary 7–12 (the rung-2 rarity bands). `realized_delta` = the fresh standard-profile sweep delta, except conditional jokers, which use **in-condition × fire-rate** (e.g. The Chase Master: +13.1% in-chase × 0.50 toss fire-rate ≈ +6.6% → below the Legendary delta floor → prices at the band floor ₸220 — the fire-rate discount expressed *within* the band, keeping rarity ≈ price legible). **Enablers** (~0% solo, judged in-combo) price at their band floor. The build re-runs `sweep_jokers.gd` once (fresh post-mechanic-change deltas) and computes the table from that JSON; the spec findings (§10) record the final 45 prices.

### 5.4 The ROI oracle (`tools/sweep_economy.gd`)

Two question sets, one tool (paired-seed `Sweep`, N=2000/arm, even ★3):

1. **Income per build:** the three canonical builds (batter 8/8/2/2 · balanced 5/5/5/5 · bowler 2/2/8/8) → distribution of `match_pay().total` → ₸/match and projected Season income (×8 matches: 7 league + ~1 playoff). **Fairness check:** tune `runs_rate`/`wicket_rate` so the three builds earn within ±15% of each other (a bowler shouldn't starve — mirrors the win-rate flatness work).
2. **Marginal attribute value:** baseline 5/5/5/5 vs four +1 arms (6/5/5/5, 5/6/5/5, 5/5/6/5, 5/5/5/6, sum 21 — legal at runtime; the 20-point cap is a creation rule, upgrades push past it by design) → Δwin% per +1 attribute.

Output JSON feeds `docs/mockups/economy-v1.html`: income per build, the price ladder vs Season income, and an ROI bar chart (₸ per +1% win across: a mid Common, mid Rare, mid Legendary, +1 of the best attribute).

### 5.5 ROI acceptance (the ADR 0003 check)

- **Scarcity:** full-greed spend across a Season (1 joker per paid visit at mid prices + 1 attribute upgrade per visit) must exceed expected Season income — you can't buy everything (CONTEXT §Joker "deliberate scarcity").
- **Affordability pacing:** a Common is affordable at the first paid Shop (after Match 3); a Legendary costs roughly half a Season's income (reachable only by saving).
- **No dominant spend:** ₸-per-+1%-win for jokers (all three rarities) and for +1 attribute within a factor of ~3 of each other, with attributes allowed up to a ~2× premium per win-point (they're Career-permanent; jokers are Season-scoped — DE7). If attributes come out *cheaper* per point than jokers, raise `attr_cost_base`.

## 6. Decisions (AFK defaults)

- **DE1 — scope:** domain calculators + pricing + ROI harness; no Shop UI/state machine.
- **DE2 — pay scale:** the documented "base 50 + perf 18 = 68 ₸" scale (THEME-5-HANDOFF §5 and DESIGN_HANDOFF §17.5 agree). At this scale the existing strawman price bands already sit right against measured income (~₸500–550/Season) — bands are **confirmed, not rescaled** (DE5).
- **DE3 — pay formula:** `base(★) + perf(runs, wickets)` with KMs **excluded** (not in the sim yet; the dial structure leaves room — when KMs land in the sim, a `km_rate` joins the formula). Strawman weights runs 0.5 / wicket 11.0, then sweep-tuned for ±15% build fairness; finals recorded in §10.
- **DE4 — pricing rule:** within-band linear interpolation of realized delta (rule in §5.3), rounded to ₸5. Conditionals priced on realized (× fire-rate); enablers at band floor.
- **DE5 — price bands confirmed:** Common ₸30–50 / Rare ₸90–120 / Legendary ₸220–250 retained as the band frame.
- **DE6 — where prices live:** `JokerCatalog.PRICES` (code is source of truth), pool-doc ₸ column mirrors it.
- **DE7 — attribute cost:** linear-in-current-value (`12 × current`), with a permanence premium target of ~2× joker ₸-per-win-point; coefficient tuned by the harness if the ROI check fails.
- **DE8 — loadout cap = 4**, per CONTEXT.md (slot 4 gated by first Level win is a *progression* rule for later; the economy dial is the ceiling 4). Resolves the roadmap's "~5-slot" open thread. Archetype-stack sweep arms (7–8 jokers) remain measurement-only.
- **DE9 — sell refund 50%** (floor) — CONTEXT says "partial refund" with no number; strawman dial.
- **DE10 — oracles:** `sweep_economy.gd` is the *economy* oracle (income + attribute margins), alongside `sweep_jokers.gd` (joker deltas) and `build_spectrum_sweep.gd` (build win%). Viz `docs/mockups/economy-v1.html`.

## 7. Testing

GUT unit tests (tabs, `tests/unit/`), inline TDD:

- `test_economy.gd`: base pay at ★3 = `base_pay`; directional (★5 base < ★3 base < ★1 base); floor at ₸10; perf monotonic in runs and wickets; breakdown sums (`base + perf == total`); zero-performance match still pays base; `attr_upgrade_cost` monotonic in current value; `sell_refund` floor behaviour.
- `test_joker_catalog.gd` (extend): all 45 ids priced; every price inside its rarity band; price ≥ band floor for enablers; round-to-5 invariant.
- Determinism: `match_pay` is pure (same result → same pay).

Sweep-level acceptance (§5.5) verified by running the oracle, recorded in §10 findings — not unit-asserted (they're statistical).

## 8. Risks / notes

- The +1-attribute arms (sum 21) assume `Attributes` doesn't hard-enforce sum==20 outside creation; if it does, construct directly or relax at the seam (note in plan).
- `sweep_jokers.gd` re-run (~60–80s, backgrounded, editor closed) is a build step — prices computed from *fresh* deltas, not stale spec tables.
- Per-Tour price scaling ("prices scale with Tour difficulty", CONTEXT §Tons) is a single multiplier left for the Career rung — one Tour exists in the harness today.

## 9. Acceptance criteria

1. All 45 jokers have a concrete ₸ price, in-band, code + doc agreeing; tests assert it.
2. `Economy.match_pay` produces the documented breakdown shape at the documented scale; tests green past 366.
3. Income fairness: the three canonical builds earn within ±15% ₸/match of each other (post dial-tune).
4. Scarcity + affordability pacing checks (§5.5) pass, recorded with numbers in §10.
5. No-dominant-spend ROI check (§5.5) passes (or the failing dial is re-tuned and the final value recorded).
6. Pool doc + roadmap updated; the "prices rescale when inflow is set" note replaced by the tuned numbers.

## 10. Findings (build of 2026-06-10)

### 10.1 Final dials (`EconomyTuning`)

`base_pay 50` · `star_pay_slope 8` · `runs_rate 0.5` · **`wicket_rate 11 → 7`** · **`bowl_balls_rate 0 → 0.5`** (the workload re-tune, 10.2) · `attr_cost_base 12 → 10` (see 10.4) · `sell_refund_frac 0.5` · `loadout_cap 4` as specced.

### 10.2 Income per build (sweep_economy, N=2000/arm, even ★3) — workload re-tune

The first pass (runs + wickets only) paid batter ₸67.1 / bowler ₸59.2 / balanced ₸56.3 — a ~19% batter↔all-rounder gap. The stat split exposed why: the bowler and all-rounder bat so deep they score ~0–3 runs (vs the batter's ~34), bowl ~23 balls each, and differ only by wickets (0.82 vs 0.42) — most of their work earned nothing. **Nico's call (2026-06-10): pay must be near-flat across builds (~₸2).** Fixed with a **converting third component — `bowl_balls_rate` ₸0.5/ball bowled** (a ball bowled pays like a run scored; the workload pays whether or not a wicket falls), `wicket_rate` trimmed 11 → 7 so wicket-takers don't overshoot. Solved on the measured split, verified:

| build | win% | runs | wkts | balls bowled | perf | ₸/match | ₸/season (×8) |
|---|---|---|---|---|---|---|---|
| batter 8/8/2/2 | 48.7 | 33.8 | 0.00 | 0 | 17.1 | **67.1** | 537 |
| bowler 2/2/8/8 | 48.6 | 0.2 | 0.82 | 23.2 | 17.5 | **67.5** | 540 |
| balanced 5/5/5/5 | 48.0 | 3.2 | 0.42 | 23.2 | 16.2 | **66.2** | 529 |

**Spread ₸1.3 — inside the ~₸2 target.** Every build earns ~₸66–67/match (~₸530–540/Season); win-rate flat (47.9–48.7). The earlier "pay smile" note is superseded: the smile came from paying only countable output; paying the bowling *workload* (the job, not just its jackpot moments) flattens it without shrinking the perf share — perf is still ~₸17 ≈ the documented "base 50 + perf 18" feel.

### 10.3 The 45 prices (in `JokerCatalog.PRICES`, mirrored in the pool doc)

Computed from a fresh `sweep_jokers.gd` run (post mechanic-change catalog) via the §5.3 rule. Spread within bands: Commons ₸30–50 (top: Cool Head/Field Restrictions/Powerplay Punch ₸50 at +3.9/+4.0/+4.0%), Rares ₸90–115 (top: Death-Over Stranglehold ₸115 at +6.5%, The Captain's Call ₸110 at +5.9%), Legendaries ₸220–235 (The Review Master ₸235 at +9.6%, Choke Hold ₸230 at +8.7%). **Cross-check:** The Chase Master's standard-profile delta read **+6.6%** — exactly the realized number the mechanic-change rung predicted (in-condition × ~50% toss fire-rate) → band floor ₸220. Conditional/enabler jokers whose neutral delta reads ~0 (Form sources, bowling-change triggers, intent-snap enablers) all price at band floor — the fire-rate discount expressed inside the band, rarity ≈ price stays legible.

### 10.4 Marginal attribute value + the attr-cost tune

+1 power **+0.5%** win · +1 attack +0.1% · +1 composure 0.0% · +1 control −0.2% (≈ the N=2000 noise floor). A single attribute point barely moves win% — the Player is one lever in an 11-player conserved team (the Slice-2 finding, again). So attribute upgrades are a **Career-horizon** investment, not a this-Season win lever; at `attr_cost_base 12` a 5→6 upgrade cost ₸60 ≈ ₸120 per +1% single-Season — far outside the joker range. Tuned **12 → 10** (5→6 = ₸50): on a ~3-Season horizon that's ≈ **₸33 per +1% per Season** → 1.3–2.6× the joker ₸-per-point, inside the ~2× permanence-premium target (DE7).

### 10.5 ROI + scarcity acceptance (§5.5) — all pass

| spend | ₸ per +1% win |
|---|---|
| Cool Head (Common ₸50, +3.9%) | 12.8 |
| The Captain's Call (Rare ₸110, +5.9%) | 18.6 |
| The Review Master (Legendary ₸235, +9.6%) | 24.5 |
| +1 power (₸50, ~3-Season horizon) | ~33 /Season |

- **No dominant spend** ✓ — all within a factor ~2.6. ₸-per-point *rises* with rarity: the slot-scarcity premium (4 slots make one strong card worth more per point than two weak ones). Within a single Season jokers strictly beat attributes — the intended Balatro shape (jokers are run power; attributes are meta-progression).
- **Scarcity** ✓ — full-greed Season spend ≈ ₸670 (mid C+R+L+R jokers ₸470 + four +1 upgrades ₸200) > best Season income ₸540 (post workload re-tune).
- **Affordability pacing** ✓ — first paid Shop (after Match 3): ~₸200 banked vs Common ₸30–50; a Legendary = 41–44% of a Season's income (reachable only by saving — "if only I had more money").

### 10.6 Residuals / threads for later rungs

- **Conditional jokers price at band floor by construction** — fine for V1, but when the *player-controlled* context arrives (real Intent control in Theme 6, KM-driven Form), their realized deltas rise and prices should be re-derived (one `sweep_jokers.gd` + `compute_prices` re-run).
- **KM perf pay** (`km_rate`) joins `match_pay` when KMs land in the sim (DE3).
- **Tour-difficulty price scaling** (CONTEXT §Tons) = one multiplier on `PRICES`, deferred to the Career rung.
- **Sell-refund 50% and the Shop's transactional rules** (buy/hold/sell state machine) build with the Theme-5 Shop screen; this rung supplies its data layer.
- Marginal attribute deltas are noise-floor measurements — if a future rung needs precise attribute pricing, run the +1 arms at N≥10000 or measure ±3-point bundles.
