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

## §10 Findings — filled at close-out.
