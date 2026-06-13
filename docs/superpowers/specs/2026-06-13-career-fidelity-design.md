# Career-fidelity rung — career matches join the tuned sim

**Date:** 2026-06-13 · **Branch:** `env-span-100-155` (continues the env-span rung after its findings pivoted it) · **Mode:** AFK (Nico's GO 06:36) · **Evidence base:** `2026-06-13-env-span-findings.md` (F1–F5)

## 1. Goal

Career League/Season matches currently run the untuned SCALAR (clone) sim path and pass no match plans — producing an inverted, bowling-dominant environment (felt 112 → 85 across the grid vs the tuned roster-path 153 → 167) and leaving field/boost/DRS-gated jokers inert. This rung makes career play use the same sim the balance ledger was tuned on, then solves Nico's felt span **~100 (Club T1) → ~155 (Province Premier)**, then re-anchors everything downstream.

## 2. Decisions (CF1–CF7)

**CF1 — Roster path in the league.** `LeagueResolver.simulate_league` assembles per-team rosters + proportional bat factors exactly as `simulate_match_teams` does: every team gets `Team.standard_xi()`; the Player's team gets `Team.build_xi(player_attrs, ppos)` with `ppos = InningsResolver.player_position`; factors = season-drawn `bat[x] / MatchResolver.REF_SCALAR`. ALL 28 fixtures go roster-path (derived fixtures too — standings must live in the same environment). Bowling stays scalar (it has no roster concept anywhere; conserved-bowling is the teams-path-only refinement and stays out of league fixtures this rung — same fidelity as `simulate_match_teams`... NO: `_conserved_bowling` lives in `simulate_match_teams` only and league fixtures call `simulate_match` directly; conservation only matters when a statted Player bowls, and the Player's quota already flows through `simulate_match`. Recorded: league Player fixtures do NOT apply `_conserved_bowling` this rung — a known small fidelity gap vs the sweeps, deferred (the sweeps' build-balance numbers used it; if the build-spread eyeball in §10 looks off, it promotes to its own slice).**

**CF2 — Knockouts identical.** `SeasonResolver._knockout` gets the same roster + factor treatment (Player slot roster when s1==0, standard XIs otherwise).

**CF3 — Plans fidelity in Player-facing fixtures.** (a) **DRS:** both sides get a base `DRSPolicy.new()` in Player-facing fixtures (the T20 rule; the 48.9% fair-fight floor was measured WITH two-sided DRS — careers ran without it entirely). Derived fixtures stay plan-less (no Player, no joker stakes; their relative standings are unaffected by a symmetric mechanic). (b) **Field:** the bot sets the field its jokers want — new helper `ShopPolicy.field_plan_for(owned_ids)` returns a `FieldPlan` whose every phase is the modal `field_req` among owned field-gated jokers (null when none owned). This is what a human who bought Tight Lines would do. (c) **Boost:** when the loadout contains boost-channel jokers, pass the joker-sweep's standard `BoostPlan` literal, else null. All three default to today's behaviour when the Shop is off. Dials/choices sweepable at E4.

**CF4 — Span solve.** After CF1–CF3, re-solve `TourSpec.mean_frac`'s endpoints against `probe_felt_env` under canonical conditions: **bottom** = career start (fresh 35/30/30/30 build, 1.5★ underdog, Club T1 brains) targeting felt mean ≈ **100**; **top** = late career (60×4 build, 3.0★ side, Province Premier brains) targeting ≈ **155**. Linear in d between (the v2 d-sheet stays untouched). Update the endpoint-pinning tests with the solved constants.

**CF5 — Test honesty.** This rung intentionally changes career-sim behaviour: the seeded league/season pins (including the Shop rung's DK3 byte-identity pin) are RE-CAPTURED on the new path (documented in the test comments), not weakened. The scalar oracles (joker floor 45.5 / build spread / pay spread / env peg) never touch the league path — unchanged by construction, spot-checked in §10.

**CF6 — Full re-anchor (the cost Nico accepted).** Re-run: the 24-cell grid sweep (N=200/cell — beat-rates WILL move; the wall % is re-measured, the overlap canon should hold since same-d ⇒ same sim still applies), `career_preview` three arms (N=100 each), pacing check against DP3 (max-out ≈ S49 target; re-peg `attr_cost_base` only if drifted), time-to-beat. Viz refresh: difficulty-ladder + shop-career DATA blocks. CONTEXT.md canon updates only where numbers are quoted.

**CF7 — Deliverables (Nico's asks, held until the fix).** Re-run `career_narrate` + `career_season_log` + `career_match_detail` on the fixed sim; deliver the season-start + first-game deep dive (player build, team draws, scorecards, pay term-by-term, joker reference).

## 3. Out of scope

Conserved bowling in league fixtures (CF1 note) · opponent jokers · per-bowler husbanding · the Kit Room screen · E4 (next rung, inherits all of this).

## §10 Findings (close-out, 2026-06-13)

**The fix landed: career matches now play the tuned sim, and the felt environment is real-T20-shaped and rises with difficulty** (was inverted).

### Felt scoring environment (probe_felt_env, roster path, N=350 inns/cell)
| Cell | Before (scalar path) | After (fidelity) | Target |
|---|---|---|---|
| Club Tour 1 (fresh build, 1.5★) | 112, 8.0 wkts, RR 6.4 | **128**, 6.7 wkts, RR 7.0 | ~100 |
| Province Premier (maxed, 3★) | 85, 9.4 wkts, RR 5.5 | **153**, 6.3 wkts, RR 8.3 | ~155 |

Span solved by `mean_frac` 0.40→1.20 (was →1.30). Bottom lands at 128 not 100 — it is dial-insensitive (both sides scale together, card floors bind below frac 0.5), and 128/6.7-down is honest scrappy club cricket. The broken 35-all-out world is gone; the grid texture is no longer inverted.

### Grid beat-rates (sweep_difficulty_ladder, N=200/cell, fresh creation build)
- **New span: 80% (Club Flat & Warm, d1) → 26% (Province Premier, d20)**; win-the-Final 44% → 7.5%.
- Pre-fidelity was 96% → 15%. The curve **flattened**: the bottom is harder (a 1.5★ underdog now drops 20% at the easiest tour — realistic) and the top is more winnable (26% vs the old slaughterhouse 15%).
- Overlap canon holds byte-exact (City Flat&Warm d5 = Club Evening Spin d5 = 0.605). Brain isolation intact (naive 75% vs adaptive 38% at matched d7 = ~37 beat-pts).

### Career arms (career_preview, N=100, fidelity sim) vs pre-fidelity
| Arm | Complete | Median S | Time-to-beat | Max-out S |
|---|---|---|---|---|
| attr_only | 72/100 (was 86) | 78 (was 56) | 28.9h | med S61 |
| **joker_only** | **85/100 (was 60)** | 79 (was 73) | 29.1h | never |
| balanced | 94/100 (was 95) | 65 (was 57) | **24.2h (was 24.2h)** | med S80 |

**The headline shift — jokers are now materially stronger in careers (joker_only 60→85 complete).** This is the F4 fix working: field/DRS/boost-gated jokers now FIRE in career play. Crucially this is a *consistency fix, not a new imbalance* — joker prices were always measured in `sweep_jokers.gd` with those planes active; careers simply weren't honoring them. Careers now match the pricing the jokers were balanced against.

**Balanced (the realistic playstyle) time-to-beat held at 24.2h** — Nico's real pacing metric is stable even though season-count rose (more early playoff exits → fewer knockout matches per season).

### Pacing re-peg: DEFERRED to Nico (not silently changed)
Max-out drifted high (attr S61 / balanced S80 vs DP3's ~49 target). NOT re-pegged this rung because: (1) the binding pacing metric (balanced time-to-beat) held at 24.2h; (2) `attr_cost_base` re-solves the joker-vs-attribute ROI, which the fidelity fix just changed dramatically (jokers much stronger). Re-pegging now would peg to a moving target before Nico has seen the new joker dominance. **Open decision for Nico / the E4-or-Shop-balance rung.** `attr_cost_base` stays 13.

### Ledger untouched (CF5 spot-check)
Scalar oracles never touch the league path: joker floor 45.5%, build spread, pay spread, env peg all unchanged by construction. The DK3 byte-identity pin was re-captured (intentional behaviour change, documented in-test): final-innings 139→224, position/points held (no RNG draws added). **536 tests green.**
