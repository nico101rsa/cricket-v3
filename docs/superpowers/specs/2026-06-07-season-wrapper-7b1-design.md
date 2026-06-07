# Season wrapper (7b-1) — Team · stars→numbers · toss · Team-bundled match — design spec

**Date:** 2026-06-07
**Theme:** 7b (Tech foundation → Season wrapper). Rung **7b-1** of a split: 7b-1 (this — play one Match between two ★-rated Teams in a Tour) → 7b-2 (the Season league loop).
**Status:** Approved (design shape) — ready for `writing-plans`
**Builds on:** `MatchResolver.simulate_match()` (the rung-3/4a/4b flat-param match core)
**Implements:** ADR 0009 (Team durability — ★ rating + `tourDistribution.percentile(stars/5)` derivation) + ADR 0004 (auto-sim — headless, deterministic-seedable) + ADR 0002 (only-Player-statted; opponents derived from Team strength)

---

## 1. Scope

Today `simulate_match()` takes **six raw strength ints** (player team batting/attack/control + opposition batting/attack/control) and a **caller-supplied `player_bats_first` bool**. That is the right *core*, but it does not speak the game's language: the game has **Teams** with **★ ratings**, a **Tour** that sets how strong everyone is, and a **toss**.

This rung adds that language layer on top of the untouched core:

1. **`TourDistribution`** — a Tour's strength band (`mean ± spread`); `percentile(frac)` maps a 0..1 fraction into a strength number.
2. **`Team`** — a ★-rated value object that derives its per-Match batting & bowling strength from `(stars, tour, small noise)` per ADR 0009.
3. **Toss** — a seeded coin-flip that replaces the caller-supplied `player_bats_first` bool.
4. **`simulate_match_teams(...)`** — a new entry point on `MatchResolver` that derives the six numbers from the two Teams + Tour, flips the toss, and **delegates to the existing `simulate_match()` core**, which stays byte-identical (same discipline as 4a/4b).

Plus a **real-sim-backed eyeball deliverable** (the "learn by seeing" artifact for this rung): a throwaway headless runner drives `simulate_match_teams` across a grid of star matchups and dumps win/loss data; a small HTML chart renders **win-rate vs star gap** so the stars→numbers→outcome chain can be *seen* working (a big underdog ≈ 0% wins, even ≈ 50%, big favourite ≈ 100% — a rising S-curve).

**In scope:**
- `TourDistribution` (Resource) + `Team` (Resource) value objects, both pure/testable.
- The toss as a pure seeded function.
- `simulate_match_teams()` wrapper on `MatchResolver`, delegating to the existing core.
- A committed throwaway runner (`tools/season_preview.gd`) + a committed chart (`docs/mockups/star-winrate-v1.html`) — also the first seed of the 7c balance harness.

**Out of scope (deferred — do not build here):**
- **The Season league loop** — schedule generation (8-team round-robin), standings/points table, top-4 cut, semi-final + The Final / 3rd-place playoff, **beat-vs-win** outcome. → **7b-2** (the next rung).
- **★ Markov mutation at Season rollover** (the ±0.5 ~30% / ±1.0 ~5% table of ADR 0009). It is a *between-Season* event; it lands with multi-Season play in 7b-2 or later.
- **Per-Season (vs per-Match) noise.** ADR 0009 draws the per-Team strength noise once *per Season*. 7b-1 has no Season yet, so it derives strengths **per `simulate_match_teams` call**; 7b-2 hoists the draw to once-per-Season and reuses it across that Season's Matches. The `Team.batting_strength()/bowling_strength()` seam supports either caller.
- **A toss bat/bowl heuristic.** The toss winner simply bats first (50/50). A "winner chooses to bat or chase based on conditions" decision is later.
- **Splitting bowling into genuinely distinct attack & control.** ADR 0009 derives one `bowlingStrength`; this rung feeds it to *both* `attack` and `control`. The pace/spin tilt (4b `BowlingAttack`) already differentiates them inside an innings, so a single bowling number per Team is the right V1.
- Affinity, Form, Jokers, Manager Boost, Tons; opponent batting/bowling intelligence; the Theme-6 swipe-card UI. (All as deferred in prior rungs.)

## 2. `TourDistribution` — the Tour strength band

A small **Resource** at `scripts/data/tour_distribution.gd` (a Tour's tunable band — harness-swept later, so it is data, like `BallTuning`).

```
class_name TourDistribution extends Resource

@export var tour_name: String = ""   # flavour only, not load-bearing
@export var mean: int = 5            # strawman: mid-Tour even-contest centre
@export var spread: int = 3          # strawman: half-width of the strength band
@export var noise: int = 1           # strawman: ±absolute per-derivation jitter
```

```
percentile(frac: float) -> int
    var f := clampf(frac, 0.0, 1.0)
    return roundi(mean + (f - 0.5) * 2.0 * spread)
```

So `frac` 0.0 → `mean - spread`, 0.5 → `mean`, 1.0 → `mean + spread`. Monotonic, clamped.

**Why `mean 5 / spread 3`:** team strengths sit on the same ~1–8 scale as Player Attributes (the existing even contest is `5/5/5` both sides). `stars/5` maps `0.5★ → 0.1 → ≈ mean - 0.8·spread ≈ 3` and `5.0★ → 1.0 → mean + spread = 8`. That spans a clean ~3→8 strength band, so a 5★ vs 0.5★ game is a real mismatch (a clear S-curve to eyeball) without going off-scale. All three are **V1 strawman** — the 7c balance harness sweeps them.

**Why ±5%-of-mean (ADR 0009) becomes ±1 absolute:** 5% of mean 5 is 0.25, which rounds to 0 at this integer scale — too small to register. A `noise` of ±1 integer point is the smallest meaningful jitter here. Documented strawman; harness-tuned later.

`TourDistribution` knows nothing about ★ ratings or RNG — it is a pure band with a `percentile` mapping, testable on its own.

## 3. `Team` — the ★-rated side

A **Resource** at `scripts/data/team.gd` (Teams persist across Seasons per ADR 0009, so a Resource, not a transient `RefCounted`).

```
class_name Team extends Resource

const STARS_MIN := 0.5
const STARS_MAX := 5.0

@export var team_name: String = ""
@export var stars: float = 2.5                # on the 0.5..5.0 half-step set
@export var last_season_event: String = ""    # ADR 0009 catastrophic-swing flavour; unused this rung
```

Strength derivation (ADR 0009 — `tourDistribution.percentile(stars/5) + noise`, two **independent** draws, floored at 1):

```
batting_strength(tour: TourDistribution, rng: RandomNumberGenerator) -> int
    return maxi(1, tour.percentile(stars / STARS_MAX) + rng.randi_range(-tour.noise, tour.noise))

bowling_strength(tour: TourDistribution, rng: RandomNumberGenerator) -> int
    return maxi(1, tour.percentile(stars / STARS_MAX) + rng.randi_range(-tour.noise, tour.noise))
```

Two separate calls → two independent noise draws (ADR 0009's "independent draw" for batting vs bowling). Each call consumes exactly one RNG draw (so the draw order is stable regardless of `noise` value). The Markov ★ mutation rule lives in 7b-2; here `stars` is just read.

`Team` depends only on `TourDistribution` + an RNG; it has no knowledge of matches, innings, or the toss.

## 4. Toss — a seeded coin-flip

A pure static helper on `MatchResolver`:

```
static func _resolve_toss(rng: RandomNumberGenerator) -> bool   # returns player_bats_first
    return rng.randf() < 0.5
```

Strawman semantics: 50/50, and the toss winner bats first (i.e. this returns "does the Player's team bat first"). A bat/bowl decision heuristic (chase-friendly conditions, etc.) is deferred (§1). One RNG draw.

## 5. `simulate_match_teams()` — the Team-bundled entry point

New static function on `MatchResolver`, alongside the existing `simulate_match()`:

```
static func simulate_match_teams(
        player_attrs: Attributes,
        player_team: Team,
        opp_team: Team,
        tour: TourDistribution,
        tuning: BallTuning,
        itun: InningsTuning,
        rng: RandomNumberGenerator,
        player_intent_plan: IntentPlan = null,
        player_bowling_plan: BowlingPlan = null
) -> MatchResult
```

Body — **fixed RNG draw order for determinism** (toss, then the four strength derivations, *then* the core sim consumes the rest):

```
var player_bats_first := _resolve_toss(rng)               # draw 1
var player_bat  := player_team.batting_strength(tour, rng) # draw 2
var player_bowl := player_team.bowling_strength(tour, rng) # draw 3
var opp_bat  := opp_team.batting_strength(tour, rng)       # draw 4
var opp_bowl := opp_team.bowling_strength(tour, rng)       # draw 5

return simulate_match(
    player_attrs,
    player_bat, player_bowl, player_bowl,   # Player team: batting, attack=bowl, control=bowl
    opp_bat, opp_bowl, opp_bowl,            # opposition:  batting, attack=bowl, control=bowl
    player_bats_first, tuning, itun, rng,
    player_intent_plan, player_bowling_plan)
```

The bowling number feeds both `attack` and `control` for each Team (§1 deferral). `player_intent_plan` / `player_bowling_plan` pass straight through to the core unchanged. The existing `simulate_match()` is **not modified**.

## 6. Backward compatibility & determinism

`simulate_match()` and every existing innings/match test are untouched and stay green — this rung only *adds* `simulate_match_teams` + two new value objects + the toss helper. Determinism: `TourDistribution.percentile` consumes no RNG; the toss + four strength derivations consume exactly five draws in a fixed order before the core sim runs, so a fixed seed + fixed Teams + fixed Tour → identical `MatchResult` every call.

## 7. Eyeball deliverable — win-rate vs star gap (real sim)

The "learn by seeing" artifact for this rung, and the first seed of the 7c balance harness.

- **`tools/season_preview.gd`** — a headless `SceneTree` script (run via `godot --headless -s`). For each star matchup on a grid (e.g. Player team ★ ∈ {0.5..5.0}, opponent ★ ∈ {0.5..5.0}, or simply sweeping the **gap** = playerStars − oppStars), it runs N seeded `simulate_match_teams` calls against a fixed `TourDistribution`, tallies Player wins, and prints CSV (`star_gap, matches, player_wins, win_rate`) to stdout.
- **`docs/mockups/star-winrate-v1.html`** — a self-contained page that renders that data as **win-rate (%) on Y vs star gap on X**. The data is captured from the runner and inlined (the prior mockups' pattern), so what is charted is the **real Godot sim**, not a JS reimplementation. Optionally also shows the raw per-match win/loss scatter and a score-margin spread.

These are tools/diagnostics, not shipped game code; they have no unit tests (the directional claim they visualise is asserted in §8 test 5). Nico eyeballs the chart in a browser.

## 8. Test plan (TDD, red → green)

Per project `CLAUDE.md`: judge **red** by `Parse Error: Identifier "TourDistribution"/"Team" not declared` (GUT skips the file), **green** by the total count climbing past 154 and `All tests passed`. Statistical tests use fixed seeds + generous tolerances. The full suite runs every step (`-gdir=res://tests/unit`); the `-gtest` flag does not filter here.

`TourDistribution` unit tests (pure, no RNG):
1. **Endpoints + midpoint** — `percentile(0.0) == mean - spread`, `percentile(1.0) == mean + spread`, `percentile(0.5) == mean`.
2. **Monotonic + clamp** — `percentile` is non-decreasing across 0→1; `percentile(-1.0) == percentile(0.0)` and `percentile(2.0) == percentile(1.0)` (out-of-range frac clamps).

`Team` unit tests (seeded RNG):
3. **Stronger stars → higher strength** — averaged over many seeds, a 5.0★ Team's `batting_strength` mean exceeds a 1.0★ Team's against the same Tour.
4. **Noise bounded + floored** — every derived strength sits within `[percentile(stars/5) - noise, percentile(stars/5) + noise]` and never below 1 (test a tiny-mean/low-star case to hit the floor).
5. **`stars/5` mapping** — a 5.0★ Team with `noise = 0` derives exactly `tour.percentile(1.0) == mean + spread`; a 0.5★ Team derives `tour.percentile(0.1)`.

`MatchResolver.simulate_match_teams()` tests:
6. **Determinism** — same seed + same Teams + same Tour → identical `MatchResult` (outcome, both totals, margins) across repeated calls.
7. **Directional (the chart's claim, as a test)** — over N seeded matches, a 5.0★ Player team vs a 0.5★ opponent wins a large majority (e.g. > 80%); swapping the ratings flips it to a small minority. This is the stars→outcome chain proven without the chart.
8. **Even Teams roughly balanced** — equal-★ Teams, toss alternated/averaged over many seeds, give a Player win share inside a loose band (mirrors the existing even-contest match test), confirming no structural side bias was introduced by the toss/derivation layer.
9. **Toss ~50/50 + deterministic** — `_resolve_toss` over many seeds returns `true` within a loose band of 50%; a fixed seed returns the same value every call. (Tested via `simulate_match_teams` perspective or a direct call if visibility allows.)

## 9. What this de-risks / sets up

- Gives the sim the **game's real vocabulary** (Teams, ★, Tour, toss) without disturbing the proven ball→innings→match→Intent→bowling core.
- The `Team.batting_strength()/bowling_strength()` + `TourDistribution.percentile()` seam is exactly what **7b-2** loops over (deriving each Team's strength once per Season) and what **7c** sweeps.
- The committed runner + chart are the **first concrete step of the balance harness (7c)** — proving the headless-deterministic design (ADR 0004) pays off for visualising distributions.
- Leaves clean seams: ★ Markov mutation + per-Season noise hoist + the league table all layer into 7b-2 behind these value objects.

## 10. Open questions

None blocking. Confirmed deferrals (with landing rungs):
- **Season league loop** (schedule, table, top-4, semi/final, beat-vs-win) → **7b-2** (next rung).
- **★ Markov mutation + per-Season noise draw** → 7b-2 (needs multi-Season / Season-rollover).
- **Toss bat/bowl heuristic** → later (currently winner always bats first).
- **Distinct attack vs control per Team** → later (one bowling number for now; pace/spin tilt already differentiates inside the innings).
- **Opponent intent/bowling intelligence, Affinity, Form, Jokers, Boost, Tons** → later rungs/themes, as before.
</content>
</invoke>
