# Env-span rung — findings: the dial is innocent, career matches run an untuned sim path

**Date:** 2026-06-13 morning · **Branch:** `env-span-100-155` · **Status:** measurement complete, fix re-scoped (decision below is Nico's)

## 1. What this rung set out to do

Nico's ruling (2026-06-12, reacting to Season-1 scorecards like 35 all out): *the starting league should average ~100, scaling to ~155 at the top* — implemented as a re-solve of `TourSpec.mean_frac`'s span, with a guard that nothing else goes out of balance.

## 2. The instrument

`tools/probe_felt_env.gd` — the **felt** environment: mean first-innings total of the Player's own league matches under real career conditions (STAR_LADDER team field, the cell's opponent brain, league fixtures), not the even-★3 textbook mirror the old `probe_scoring_env.gd` measures. Overrides for build (`ATTRS`), team slot (`PLAYER_SLOT`), loadout (`JOKERS`), tour mean (`FRAC`), spread (`SPREAD_ABS`), brain (`BRAIN`). All numbers below: N=50 leagues = 350 first innings per row (seeds 7000–7049).

## 3. What was measured (the trail)

| Setup | Felt mean | p10 / p90 | RR | wkts |
|---|---|---|---|---|
| Club T1 (d=1), fresh build, 1.5★ underdog | **112.3** | 64 / 166 | 6.39 | 7.96 |
| Club T1, same + early joker loadout | 112.2 | 64 / 166 | 6.37 | 7.89 |
| Province Premier (d=20), fresh build, 1.5★ | **94.2** | 28 / 158 | 6.18 | 8.36 |
| Province Premier, maxed build (60×4), 3.0★ side | **84.9** | 36 / 137 | 5.53 | 9.38 |
| Province Premier, maxed build, 4.5★ side | 92.3 | 36 / 160 | 5.85 | 9.07 |
| Province Premier, maxed, 3.0★, **constant spread** 9.375 | 86.2 | 36 / 140 | 5.58 | 9.28 |
| Province Premier, maxed, 3.0★, **textbook brains** | 81.5 | 32 / 139 | 5.93 | 9.59 |
| Province Premier, maxed, 3.0★, both controls | 81.1 | 29 / 140 | 5.98 | 9.53 |

Reference: the tuned environment peg (`probe_scoring_env`, even-★3 textbook mirror) reads **153.4 / RR 8.22** at mid-league and **~167 / RR 8.76 / 5.3 wkts** at the d=20 card level (E3 measurement).

## 4. Findings

**F1 — The bottom of the grid is fine.** Felt Club T1 = 112 (median 109) — at/above Nico's ~100 target already. The Season-1 horror table (mean ~59) was a cold-tail sample: felt p10 is 64, so scrappy seasons genuinely occur, and seed 9001 drew one.

**F2 — The TOP of the grid is broken, in the opposite direction of the ruling's premise.** Felt Province Premier reads **85–94 with 9+ wickets/innings and RR 5.5–6.2** — *lower* than Club — no matter the build, team, spread, or brain. Elite cricket plays like a slaughterhouse. Nico's 100→155 span is violated at the top by ~–70 runs.

**F3 — Root cause: career matches run the untuned SCALAR (clone) sim path.** `LeagueResolver`/`SeasonResolver` call `simulate_match` with no rosters: every non-Player batter's card = the team batting scalar × tail curve (`innings_resolver.gd` clone path), i.e. batting cards ≈ bowling scalar at every level. The balance/tuning instruments (`probe_scoring_env`, the sweeps) run the **ROSTER path** (`Team.standard_xi()` archetype cards × proportional bat factor), where top-order cards run ~1.6× the team scalar — that asymmetry is what produces real-T20 numbers. The ball model's curvature then makes equal-cards bowling win harder as absolute values rise: scalar-path env *falls* with difficulty (112 → 85) while roster-path env rises (≈120 → 167). **Every environment number ever tuned was measured on a path career play does not use.** This is precisely the deferred **DL11 roster-fidelity upgrade** (deferred at E3, deferred again at the Career-loop rung).

**F4 — Bonus finding: gated jokers are inert in career play.** Career matches pass no `FieldPlan`, `BoostPlan` or `DRSPolicy`, so field-gated, boost-gated and DRS-gated jokers never fire there (felt env identical with/without loadouts; the Shop rung's completion gains came from the unconditional jokers only). Joker prices were measured under sweep conditions with those planes active — career play under-delivers what was paid for.

**F5 — Refuted hypotheses (for the record):** proportional season-spread saturation (constant spread changed nothing) and brain-tier suppression (textbook brains read *lower* than adaptive) are NOT the top-end mechanism. The Shop-rung jokers were also initially suspected for Season 1's scores — refuted by F1/F4.

## 5. Recommendation (decision is Nico's — it re-anchors his prior rulings)

**The fix is not a dial. Recommend a CAREER-FIDELITY rung:**
1. **Roster path in career play (DL11):** league/season player-facing fixtures (and derived fixtures, for consistent standings) assemble real XIs + proportional bat factors exactly as `simulate_match_teams` does. Then re-solve `mean_frac`'s span against the *felt* probe to land Nico's **100 → ~155**.
2. **Plans fidelity in career play (F4):** pass sensible defaults (neutral field, base DRS policy, optionally boost) into Player-facing career matches so the 45 jokers work as priced.
3. **Full re-anchor afterwards** (this is why it needs Nico's go): grid beat-rates (the 96%→15% wall WILL move — part of today's wall is the scalar-path slaughterhouse, not design), career completion/median/time-to-beat (the S50 max-out pacing and 24 h figures), possibly `attr_cost_base` and the difficulty-sheet feel. The three Shop-rung policy anchors re-run last.

Until that rung lands, treat felt-environment numbers (and any scorecard texture judgment) as provisional; the balance ledger itself (joker floor, build/pay spreads) is unaffected — it lives on the roster/scalar instruments it was tuned on, and no dial moved in this rung.

## 6. Instruments added by this rung (kept)

- `tools/probe_felt_env.gd` — the felt-env oracle (career-conditions environment, full override set).
- `tools/career_season_log.gd` — one Season match-by-match (results, Player lines, averages, Kit Room log, Offers).
- `tools/career_match_detail.gd` — season-start + Match-1 deep dive (player build, team strength draws, scorecards, pay term-by-term, joker reference). **Narration deliverable runs after the fidelity fix** — current scorecards would narrate the broken path.
