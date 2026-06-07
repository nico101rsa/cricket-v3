# Season playoffs + outcome (7b-2b) — top-4 bracket · beat/win · ★ mutation — design spec

**Date:** 2026-06-08
**Theme:** 7b (Season wrapper). Rung **7b-2b** — the **playoffs + outcome** half of 7b-2, completing the Season loop on top of 7b-2a's league phase.
**Status:** Approved (design shape — autonomous/AFK, decisions recorded below) — ready for `writing-plans`
**Builds on:** 7b-2a (`LeagueResolver.simulate_league`, `LeagueResult`, `StandingsRow`) + `MatchResolver.simulate_match` + `Team`/`TourDistribution`
**Implements:** CONTEXT.md (Season = league → top-4 → semis → The Final / 3rd-place playoff; Beat = top 3; Win the Level = win The Final of a Premium tour) + ADR 0002/0004 + ADR 0009 (★ Markov mutation at Season rollover)

---

## 1. Scope

7b-2a stops at the league table + who made the top 4. This rung plays the **knockout playoffs**, decides the **Season outcome**, and adds the **★ mutation primitive** for Season rollover:

1. **Playoff bracket** from the league top 4: two **semi-finals** (seed 1 v 4, seed 2 v 3) → **The Final** (semi winners → 1st/2nd) + a **3rd-place playoff** (semi losers → 3rd/4th).
2. A **`SeasonResolver.simulate_season(...)`** entry point that runs the league (via 7b-2a) then the playoffs, all on one seed, and returns a **`SeasonResult`** with the full final ordering + the **beat** (top 3) and **won-Final** (1st) flags.
3. **`Team.mutate_stars(rng)`** — the ADR 0009 Season-rollover ★ Markov mutation primitive (±0.5 ~30% / ±1.0 ~5% / no-change ~65%, clamped 0.5–5.0), as a pure standalone function ready for the future multi-Season Career loop.

The Player is team index 0 (the 7b-2a convention); they are statted in any playoff match they're in, and derived otherwise.

**In scope:**
- Expose the per-Season held strengths on `LeagueResult` (`team_bat`/`team_bowl`) so the playoffs reuse the *same* strengths the league drew (the "held all Season" rule — no re-deriving).
- `SeasonResolver.simulate_season` (league → 4 knockouts → outcome), deterministic on one seed.
- `SeasonResult` holder (the `LeagueResult`, the 4 playoff `MatchResult`s, the final 1–8 ordering, `player_final_position`, `beat`, `won_final`).
- Knockout tie-break: **higher seed (better league position) advances**.
- `Team.mutate_stars(rng)`.
- Eyeball: a season-outcome chart — **beat-rate (top 3) and win-Final-rate vs Player team ★**.

**Out of scope (deferred — do not build here):**
- **The multi-Season Career loop** (apply `mutate_stars` between Seasons, walk the Career grid, track Seasons-played, promotion across Levels/Tours, Offers). `mutate_stars` is built + tested as a primitive but **not yet wired into a loop**. → Career rung.
- **"Win the Level" gating on a Premium tour.** `SeasonResult.won_final` is the raw "won the championship Match" (finished 1st). Whether that *also* wins the Level depends on the tour being Premium — a Career-layer fact the sim doesn't model yet (`TourDistribution` has no `is_premium`). The Career rung interprets `won_final` on a Premium cell as a Level win. Documented; not gated here.
- **Catastrophic-swing flavour text** (`Team.last_season_event` commentary string). `mutate_stars` changes the number only; the flavour string is a later commentary/Career concern.
- **Super-overs** for tied knockouts (we use higher-seed-advances), Affinity/Form/Jokers/Boost/Tons, opponent intelligence — all later, as before.

## 2. Recorded design decisions (AFK — made + documented per project CLAUDE.md)

- **D1 — One rung for playoffs + outcome + the mutation primitive.** The mutation is a tiny standalone function; folding it in (built + tested, not yet looped) completes the ADR 0009 picture without a separate micro-rung. The *Career loop that uses it* is a later rung.
- **D2 — Reuse the league's held strengths for the playoffs.** Expose `team_bat`/`team_bowl` on `LeagueResult`; the playoffs index into them. No re-deriving (CONTEXT: strength is one Season-long draw). Keeps the whole Season deterministic on one seed.
- **D3 — Knockout tie → higher seed advances.** Deterministic, fair (rewards the better league campaign), and avoids a super-over sub-system. Documented strawman.
- **D4 — Bracket seeding 1v4 / 2v3.** Standard. SF1 = seed1 v seed4, SF2 = seed2 v seed3. Final = SF winners; 3rd-place playoff = SF losers.
- **D5 — `won_final` is raw championship, not Level-win.** Level-win = `won_final` on a Premium tour, decided by the Career layer (§1 deferral). This rung exposes `beat` (top 3) and `won_final` (1st) only.
- **D6 — Mutation thresholds** `0.05` (±1.0) and `0.35` cumulative (±0.5), 50/50 direction, clamped 0.5–5.0 — ADR 0009's strawman, harness-tunable.

## 3. `LeagueResult` change — expose held strengths

Add two fields (indexed by original `team_index`, 0 = Player):

```
var team_bat: Array = []    # team_bat[idx] = that team's per-Season batting strength
var team_bowl: Array = []   # team_bowl[idx] = that team's per-Season bowling strength
```

`LeagueResolver.simulate_league` already derives `bat[]`/`bowl[]` once at Season start; it now also stores them on the returned `LeagueResult`. Additive — existing 7b-2a tests stay green (they don't read these).

## 4. `SeasonResult` holder

A `RefCounted` at `scripts/data/season_result.gd`:

```
class_name SeasonResult extends RefCounted

var league: LeagueResult            # the league phase (table, etc.)
var semi1: MatchResult              # seed1 v seed4
var semi2: MatchResult              # seed2 v seed3
var final_match: MatchResult        # the two semi winners (1st/2nd)
var third_place: MatchResult        # the two semi losers (3rd/4th)
var final_order: Array = []         # 8 team_index values, finishing 1st..8th
var player_final_position: int = 0  # 1..8 (where team 0 finished)
var beat: bool = false              # player finished top 3
var won_final: bool = false         # player finished 1st (won The Final)
```

(`final_match` not `final` — `final` is not a reserved word in GDScript but reads ambiguously; `final_match` is clear.)

## 5. `SeasonResolver.simulate_season`

`scripts/domain/season_resolver.gd`:

```
static func simulate_season(
        player_attrs: Attributes,
        player_team: Team,
        opponents: Array,            # 7 Team objects
        tour: TourDistribution,
        tuning: BallTuning,
        itun: InningsTuning,
        rng: RandomNumberGenerator,
        player_intent_plan: IntentPlan = null,
        player_bowling_plan: BowlingPlan = null
) -> SeasonResult
```

Flow (one seed, fixed RNG order):
1. `var league := LeagueResolver.simulate_league(... same args, rng ...)` — derives strengths + plays the 28 league games (rng consumed exactly as in 7b-2a).
2. Read the four seeds by `team_index`: `s1 = league.standings[0].team_index`, `s2 = [1]`, `s3 = [2]`, `s4 = [3]` (seeds 1–4 = league positions 1–4).
3. **SF1** = knockout(better = s1 @pos1, worse = s4 @pos4). **SF2** = knockout(s2 @pos2, s3 @pos3).
4. **Final** = knockout(the two SF winners, ordered better-seed-first). **3rd-place** = knockout(the two SF losers, better-seed-first).
5. Build `final_order`:
   - 1st = Final winner, 2nd = Final loser, 3rd = 3rd-place winner, 4th = 3rd-place loser,
   - 5th–8th = `league.standings[4..7]` team_index in order.
6. `player_final_position` = 1 + index of team_index 0 in `final_order`; `beat = position <= 3`; `won_final = position == 1`.

### Knockout helper

```
# Returns {winner: int, loser: int, result: MatchResult}. On a tie, the better
# seed (lower league position number) advances. The Player (team 0), when
# involved, is statted; otherwise both sides derived.
static func _knockout(
        a_idx: int, a_seed: int, b_idx: int, b_seed: int,
        team_bat: Array, team_bowl: Array,
        player_attrs, tuning, itun, rng, ip, bp) -> Dictionary
```

Slot ordering so the statted Player is always the `simulate_match` "player slot" when present:

```
var s1 := a_idx          # slot-1 (the "player slot" of simulate_match)
var s2 := b_idx
if b_idx == 0:           # Player is side b -> make Player slot-1
    s1 = b_idx
    s2 = a_idx
var pa = player_attrs if s1 == 0 else null
var ipp = ip if s1 == 0 else null
var bpp = bp if s1 == 0 else null
var toss := MatchResolver._resolve_toss(rng)
var m := MatchResolver.simulate_match(
    pa, team_bat[s1], team_bowl[s1], team_bowl[s1],
    team_bat[s2], team_bowl[s2], team_bowl[s2],
    toss, tuning, itun, rng, ipp, bpp)
var s1_won: bool
if m.outcome == MatchResult.Outcome.TIE:
    s1_won = (a_seed < b_seed) if s1 == a_idx else (b_seed < a_seed)   # better seed advances
elif m.outcome == MatchResult.Outcome.PLAYER_WIN:
    s1_won = true
else:
    s1_won = false
var winner := s1 if s1_won else s2
var loser := s2 if s1_won else s1
return {"winner": winner, "loser": loser, "result": m}
```

The Final/3rd-place callers pass the better seed as `a` so the tie-break reads naturally; seeds carried through are the original league positions (1–4).

## 6. `Team.mutate_stars(rng)`

Add to `scripts/data/team.gd` (ADR 0009 rollover mutation; constants strawman):

```
const MUTATE_CATASTROPHIC := 0.05   # P(±1.0 swing)
const MUTATE_SWING := 0.35          # cumulative: P(±0.5) = 0.35 - 0.05 = 0.30; else no change

# Mutate stars Markov-style at a Season rollover. Two RNG draws (magnitude, then
# direction), clamped to [0.5, 5.0]. The catastrophic-swing flavour string is
# deferred. See ADR 0009.
func mutate_stars(rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	var delta := 0.0
	if roll < MUTATE_CATASTROPHIC:
		delta = 1.0 * dir
	elif roll < MUTATE_SWING:
		delta = 0.5 * dir
	stars = clampf(stars + delta, STARS_MIN, STARS_MAX)
```

## 7. Backward compatibility & determinism

Additive: `LeagueResult` gains two fields (existing 7b-2a tests don't read them); `Team` gains a method; new `SeasonResolver`/`SeasonResult`. All 169 existing tests stay green. Determinism: `simulate_season` consumes the league's RNG (strength draws + 28 games) then the four knockouts' (toss + match draws) in fixed order (SF1, SF2, Final, 3rd-place) → identical `SeasonResult` for a fixed seed + Teams + Tour. `mutate_stars` is deterministic per rng.

## 8. Eyeball deliverable — beat-rate + win-Final-rate vs Player ★

`tools/season_outcome_preview.gd` sweeps the Player team's ★ (0.5→5.0) against a random 7-opponent field, runs N seeded full Seasons per ★, and prints CSV `player_stars,seasons,beat_rate,win_final_rate,avg_finish`. Render `docs/mockups/season-outcome-v1.html`: **beat-rate (top 3) and win-Final-rate (champion) vs Player ★** — the payoff curve of the whole Season loop (both rise with ★; beat-rate sits above win-rate by construction). Real Godot sim, data inlined.

## 9. Test plan (TDD, red → green)

Per project `CLAUDE.md`: red by `Parse Error: Identifier "…" not declared`; green by the count climbing past 169 + `All tests passed`. Statistical tests use fixed seeds + generous tolerances.

`Team.mutate_stars` (seeded):
1. **Distribution** — from `stars = 3.0`, over ~4000 mutated copies, the fraction unchanged ≈ 0.65, |Δ|==0.5 ≈ 0.30, |Δ|==1.0 ≈ 0.05 (each within ±0.05); every result is on the 0.5 grid.
2. **Clamp** — from `stars = 5.0`, no result exceeds 5.0; from `stars = 0.5`, none below 0.5 (over many seeds).

`LeagueResult` strengths (via simulate_league):
3. **Strengths exposed** — `team_bat.size() == 8` and `team_bowl.size() == 8`; every entry `>= 1`.

`SeasonResolver.simulate_season` (seeded):
4. **Determinism** — same seed + Teams + Tour → identical `SeasonResult` (player_final_position, beat, won_final, final_order).
5. **Final order is a permutation** — `final_order` has 8 entries, exactly the set {0..7}, no duplicates; positions 1–4 are exactly the league top-4 team_indexes (the playoff participants), in some order; positions 5–8 equal `league.standings[4..7]` team_indexes in order.
6. **Outcome consistency** — `player_final_position` in 1..8; `beat == (position <= 3)`; `won_final == (position == 1)`; if `won_final` then `beat`.
7. **Champion came through the Final** — the team at `final_order[0]` is the `final_match` winner, and `final_order[1]` is the `final_match` loser; `final_order[2]`/`[3]` are the `third_place` winner/loser.
8. **Directional** — over N seeded Seasons, a 5.0★ Player team beats (top 3) and wins the Final far more often than a 0.5★ team vs the same field.

(The eyeball runner/chart §8 has no unit tests — its directional claim is test 8.)

## 10. Open questions

None blocking. Confirmed deferrals (landing rungs): multi-Season Career loop + grid + Offers + applying `mutate_stars` between Seasons → **Career rung**; "win the Level" Premium gating → Career rung; catastrophic flavour string + super-overs + Form/Jokers/Boost/Tons/opponent-intelligence → later.
</content>
