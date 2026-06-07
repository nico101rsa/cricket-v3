# Season league phase (7b-2a) — schedule · full-sim table · Player's league finish — design spec

**Date:** 2026-06-07
**Theme:** 7b (Season wrapper). Rung **7b-2a** — the **league phase** half of 7b-2 (the Season loop). 7b-2b will add the playoffs (top-4 bracket → semis → The Final / 3rd-place playoff), the beat-vs-win outcome, and the ★ Markov mutation at Season rollover.
**Status:** Approved (design shape — autonomous/AFK, decisions recorded below) — ready for `writing-plans`
**Builds on:** 7b-1 (`Team`, `TourDistribution`, `simulate_match_teams`) + the `MatchResolver.simulate_match()` core (which already supports a `null` Player → an all-derived innings)
**Implements:** ADR 0002 (Season = 8-team league, 7-game round-robin) + ADR 0004 (headless, deterministic) + CONTEXT.md (Season, Tour, Beat) + ADR 0009 (per-Season strength draw)

---

## 1. Scope

7b-1 plays **one** Match between two ★-rated Teams. This rung loops that into the **league phase of a Season**: an 8-team single round-robin (each team plays the other 7 once = **28 games**), producing a **standings table** and the **Player's league finishing position** + whether they **qualified for the playoffs (top 4)**.

The Player is one of the 8 teams; the other 7 are opponent `Team`s. Crucially, a real table needs results for games the Player isn't in (team B vs team C), so **every game is simulated by the real engine** — Player games via `simulate_match_teams` (statted Player), non-Player games via `simulate_match(null, …)` (both sides derived; the core already supports this).

**In scope:**
- A **round-robin schedule** generator (pure): N teams → the set of unique fixtures.
- **Per-Season strength derivation** (ADR 0009's "draws strength at the start of each Season"): each Team's `(batting, bowling)` is derived **once** at Season start and held across all its games this Season — the "noise hoist" the roadmap called for.
- A **standings table** with points (win 2 / tie 1 / loss 0) and a tiebreak by **Net Run Rate (NRR)**, accumulated from the simulated innings.
- A `LeagueResolver.simulate_league(...)` entry point returning a `LeagueResult` (ranked standings, the Player's position 1–8, `made_playoffs` = top 4, and the Player's own match results).
- An **eyeball deliverable**: extend `tools/season_preview.gd` with a league chart — **playoff-qualification rate + average league finish vs the Player team's ★** against a fixed representative field.

**Out of scope (deferred to 7b-2b / later):**
- **The playoffs** — top-4 bracket, the two semi-finals, **The Final**, the **3rd-place playoff**. → 7b-2b.
- **The beat-vs-win outcome** — "beat the Season" = finish top 3 (needs the playoffs); "win the Level" = win The Final of a Premium tour. → 7b-2b.
- **★ Markov mutation at Season rollover** (ADR 0009's ±0.5 ~30% / ±1.0 ~5% table) — a *between-Season* event; lands in 7b-2b with the multi-Season seam. (This rung simulates **one** Season; ★ are read, not mutated.)
- **The mid-Season + end-of-Season Offers, Affinity, Form, Jokers, Manager Boost, Tons** — later themes/rungs.
- **Opponent batting/bowling intelligence** — opponents bat Balanced + bowl textbook, as in 7b-1.
- **The all-out NRR quota rule** — proper cricket NRR counts a bowled-out side's full 20 overs; this rung uses **actual balls faced/bowled** (a documented V1 simplification; the harness can refine).
- **Double round-robin / home-and-away** — single round-robin per CONTEXT ("7-game league phase").

## 2. Recorded design decisions (AFK — made + documented per project CLAUDE.md)

- **D1 — Split 7b-2 into 7b-2a (league phase, this) + 7b-2b (playoffs + outcome + ★ mutation).** Same size-driven split pattern as 4a/4b and 7b-1/7b-2. Each is an independently shippable, testable PR.
- **D2 — Simulate all 28 league games with the real engine.** Non-Player games call `simulate_match(null, …)` (both sides derived). One code path, a genuine table. Cost is trivial (28×~240 balls/Season). The analytical-approximation alternative (compute non-Player results from the ★ win-curve, à la ADR 0011) is noted as a deferred harness optimisation if perf ever demands it.
- **D3 — Per-Season strength draw.** Each Team's `(batting, bowling)` is derived once at Season start (consuming RNG in a fixed team order) and reused for all its games. Matches consume the held ints, not a fresh per-match `Team` derivation. This is the noise hoist (CONTEXT: strength drawn "at the start of each Season").
- **D4 — Toss per match.** Each game flips its own toss (one RNG draw), as in 7b-1.
- **D5 — Points + NRR tiebreak.** win = 2, tie = 1, loss = 0. Rank by points desc → NRR desc → team index asc (fully deterministic). NRR uses actual balls (D-simplification above).
- **D6 — `made_playoffs` = top 4.** The league-phase outcome surfaced here. "Beat the Season" (top 3) is a *playoff* result → 7b-2b.

## 3. Round-robin schedule

A pure static helper (no RNG, no state) on `LeagueResolver`:

```
static func round_robin(num_teams: int) -> Array      # Array of Vector2i(i, j), i < j
```

Returns every unique unordered pair `(i, j)` with `0 <= i < j < num_teams`. For 8 teams that is 28 fixtures, each team appearing in exactly 7. Match **order is immaterial** this rung — there is no cross-match state yet (Form/Jokers are deferred and the sim does not read them), so a simple `i < j` enumeration is sufficient and deterministic. Team index **0 is always the Player's team** by convention.

## 4. Per-Season strength derivation

At the start of `simulate_league`, build the 8-team list `teams = [player_team] + opponents` and derive each team's held strengths once:

```
for each team t (in index order):
    bat[t]  = t.batting_strength(tour, rng)
    bowl[t] = t.bowling_strength(tour, rng)
```

These consume `2 × num_teams` RNG draws in a fixed order, then every game uses the held `bat[]`/`bowl[]`. (The bowling number feeds both attack and control, exactly as 7b-1's `simulate_match_teams` does.)

## 5. Playing the 28 games

For each fixture `Vector2i(i, j)` from `round_robin(8)`:

Because `round_robin` emits `i < j` and the Player is team 0, the Player (when involved) is **always the `i` side** (`i == 0`) — no swap needed. The toss decides whether team `i` bats first.

```
i_bats_first := _resolve_toss(rng)        # reuse the 7b-1 helper
var p_attrs = player_attrs if i == 0 else null   # statted Player only in team-0 games
result := simulate_match(p_attrs,
                         bat[i], bowl[i], bowl[i], bat[j], bowl[j], bowl[j],
                         i_bats_first, tuning, itun, rng,
                         (player_intent_plan if i == 0 else null),
                         (player_bowling_plan if i == 0 else null))
```

Here the `simulate_match` "player slot" = team `i`, "opponent slot" = team `j`, and `i_bats_first` maps to its `player_bats_first` param. Attribute the result to the two teams' `StandingsRow`s (team `i` = the "player" slot, team `j` = the "opponent" slot):
- **Points:** `PLAYER_WIN` → 2 to team `i`; `OPPONENT_WIN` → 2 to team `j`; `TIE` → 1 each.
- **NRR data:** add each team's batting innings `total` to its `runs_for` and `balls` to its `balls_for`; add the same innings to the *other* team's `runs_against` / `balls_against`. Use `i_bats_first` to know which `InningsResult` (innings1 = first-batting side) belongs to which team: `i_bats_first` → team `i` = innings1, team `j` = innings2; else the reverse.
- Increment each team's `played`.

Player games additionally append their `MatchResult` to `player_matches` (for later Records/UI; cheap to keep).

## 6. Standings, NRR, ranking

A lightweight `RefCounted` row at `scripts/data/standings_row.gd`:

```
class_name StandingsRow extends RefCounted

var team_index: int
var played: int = 0
var points: int = 0
var runs_for: int = 0
var balls_for: int = 0
var runs_against: int = 0
var balls_against: int = 0

func nrr() -> float:
    # runs/over for minus runs/over against; actual balls (V1, no all-out quota rule).
    var of := (runs_for * 6.0) / balls_for if balls_for > 0 else 0.0
    var oa := (runs_against * 6.0) / balls_against if balls_against > 0 else 0.0
    return of - oa
```

Ranking comparator (deterministic): **points desc, then `nrr()` desc, then `team_index` asc.**

## 7. `LeagueResult`

A `RefCounted` holder at `scripts/data/league_result.gd`:

```
class_name LeagueResult extends RefCounted

var standings: Array          # Array[StandingsRow], ranked best -> worst
var player_position: int      # 1..8, the Player team's (index 0) rank
var made_playoffs: bool       # player_position <= 4
var player_matches: Array     # Array[MatchResult] for the Player team's 7 games
```

## 8. `LeagueResolver.simulate_league()`

```
static func simulate_league(
        player_attrs: Attributes,
        player_team: Team,
        opponents: Array,            # 7 Team objects
        tour: TourDistribution,
        tuning: BallTuning,
        itun: InningsTuning,
        rng: RandomNumberGenerator,
        player_intent_plan: IntentPlan = null,
        player_bowling_plan: BowlingPlan = null
) -> LeagueResult
```

Flow: assemble teams (index 0 = Player) → derive held strengths (§4) → one `StandingsRow` per team → play all `round_robin(8)` fixtures (§5) → rank (§6) → find team 0's position → build `LeagueResult`. Deterministic given the seed: strength draws, then per-fixture (toss + the match's own draws) in fixed fixture order.

## 9. Backward compatibility & determinism

Purely additive — no existing file's behaviour changes (the rung reuses `simulate_match`/`_resolve_toss`/`Team`/`TourDistribution` unchanged; `simulate_match(null, …)` is an already-supported path). All 163 existing tests stay green. Determinism: a fixed seed + fixed Teams + fixed Tour → identical `LeagueResult`, because every RNG draw (8×2 strength draws, then each fixture's toss + match draws) happens in a fixed order.

## 10. Eyeball deliverable — playoff-qualification vs Player ★

Extend `tools/season_preview.gd` (or a sibling `tools/league_preview.gd`) to sweep the **Player team's ★** from 0.5→5.0 against a **fixed representative 7-opponent field** (★ spread across the range), running N seeded Seasons per Player-★ and reporting CSV: `player_stars, seasons, made_playoffs_rate, avg_finish`. Render to `docs/mockups/league-finish-v1.html`: **playoff-qualification rate (and average league finish) vs Player team ★** — the league-phase analogue of 7b-1's win-rate curve (a stronger team should qualify more and finish higher). Real Godot sim, data inlined. Nico eyeballs it.

## 11. Test plan (TDD, red → green)

Per project `CLAUDE.md`: judge **red** by `Parse Error: Identifier "…" not declared`, **green** by the count climbing past 163 + `All tests passed`. Statistical tests use fixed seeds + generous tolerances.

`round_robin` (pure):
1. **Count + coverage** — `round_robin(8)` returns 28 unique pairs; each team index 0–7 appears in exactly 7; no self-pairs; no duplicates.

`StandingsRow` (pure):
2. **NRR sign** — a row with more runs_for/over than runs_against/over has positive `nrr()`; the reverse negative; zero balls → 0.0 (no divide-by-zero).

`LeagueResolver.simulate_league` (seeded):
3. **Determinism** — same seed + Teams + Tour → identical `LeagueResult` (player_position, made_playoffs, each standings row's points/nrr) across repeated calls.
4. **Structural integrity** — 8 standings rows; every team `played == 7`; total points across the table equals `2 × 28` minus ties handled (i.e. `sum(points) == 2 * 28` when there are no ties, and each tie reduces the total by 0 — a tie still distributes 2 points total, so `sum(points) == 56` always); `player_position` in 1..8; `made_playoffs == (player_position <= 4)`; `player_matches.size() == 7`.
5. **Ranking is sorted** — standings are non-increasing by (points, then nrr): for every adjacent pair, `a.points > b.points` or (`a.points == b.points` and `a.nrr() >= b.nrr() - 1e-6`).
6. **Directional** — over N seeded Seasons, a **5.0★ Player team** (vs a fixed mid-strength field) makes the playoffs far more often and finishes higher on average than a **0.5★ Player team** vs the same field. (The chart's claim, as a test.)

(The eyeball runner/chart in §10 has no unit tests — its directional claim is test 6.)

## 12. Open questions

None blocking. Confirmed deferrals (landing rungs): playoffs + beat/win outcome → **7b-2b**; ★ Markov mutation + multi-Season Career loop → **7b-2b / Career rung**; proper all-out NRR quota → later/harness; Offers/Affinity/Form/Jokers/Boost/Tons → later themes; opponent intelligence → later.
</content>
