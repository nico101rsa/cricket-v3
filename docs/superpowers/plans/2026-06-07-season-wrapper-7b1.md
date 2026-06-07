# Season wrapper (7b-1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the game's real vocabulary — ★-rated `Team`s, a `TourDistribution` that maps stars→strength numbers, and a simulated toss — on top of the untouched `simulate_match()` core, via a new `simulate_match_teams()` entry point; plus a real-sim-backed win-rate-vs-star-gap chart to eyeball it.

**Architecture:** Two new pure value objects (`TourDistribution`, `Team`) feed a thin Team-bundled wrapper on `MatchResolver` that derives six strength ints + flips a seeded toss, then delegates to the existing flat-param `simulate_match()`. The core stays byte-identical (same opt-in/additive discipline as rungs 4a/4b). A throwaway headless runner + inline-data HTML chart visualise the stars→outcome curve.

**Tech Stack:** Godot 4.6.3 (Standard) · GDScript (tabs) · GUT 9.6 test framework. Spec: `docs/superpowers/specs/2026-06-07-season-wrapper-7b1-design.md`.

---

## Conventions for every task (project `CLAUDE.md`)

- **Godot binary:** `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH).
- **Quit the Godot editor first** — `pgrep Godot` must be empty before any headless run (two instances corrupt the import cache).
- **After adding a new `scripts/` file, run `--import` once** before tests, so its `class_name` registers:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- **Run the whole suite** (the `-gtest` flag does NOT filter here):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- **Judge RED** by `SCRIPT ERROR: Parse Error: Identifier "X" not declared` (GUT skips that file). **Judge GREEN** by the total test count climbing and `All tests passed`. Suite runs in <1s.
- **iCloud junk guard:** if a run suddenly fails to load GUT, clean conflict copies:
  `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot` then re-`--import`.
- **Commit `*.gd.uid`** for `scripts/` files (Godot generates them). **Do NOT** `git add` a `.uid` for files under `tests/` — GUT test scripts don't generate one.
- Baseline before starting: **154 tests green**.

---

### Task 1: `TourDistribution` — the Tour strength band

**Files:**
- Create: `scripts/data/tour_distribution.gd`
- Test: `tests/unit/test_tour_distribution.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_tour_distribution.gd`:

```gdscript
extends GutTest

func _tour(mean: int, spread: int, noise: int = 1) -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = mean
	t.spread = spread
	t.noise = noise
	return t

func test_endpoints_and_midpoint() -> void:
	var t := _tour(5, 3)
	assert_eq(t.percentile(0.0), 2, "frac 0 -> mean - spread")
	assert_eq(t.percentile(1.0), 8, "frac 1 -> mean + spread")
	assert_eq(t.percentile(0.5), 5, "frac 0.5 -> mean")

func test_monotonic_non_decreasing() -> void:
	var t := _tour(5, 3)
	var prev := t.percentile(0.0)
	for i in range(1, 11):
		var cur := t.percentile(i / 10.0)
		assert_true(cur >= prev, "percentile non-decreasing at frac %f" % (i / 10.0))
		prev = cur

func test_out_of_range_frac_clamps() -> void:
	var t := _tour(5, 3)
	assert_eq(t.percentile(-1.0), t.percentile(0.0), "frac below 0 clamps to 0")
	assert_eq(t.percentile(2.0), t.percentile(1.0), "frac above 1 clamps to 1")
```

- [ ] **Step 2: Run the suite to verify RED**

Run the whole-suite command. Expected: `Parse Error: Identifier "TourDistribution" not declared` (test file skipped); count stays 154.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/data/tour_distribution.gd`:

```gdscript
class_name TourDistribution
extends Resource

# A Tour's strength band. percentile(frac) maps a 0..1 fraction (a Team's
# stars/5) into a strength number on the ~1-8 attribute scale. All three values
# are V1 strawman — the 7c balance harness sweeps them. See spec
# 2026-06-07-season-wrapper-7b1-design.md §2 and ADR 0009.

@export var tour_name: String = ""   # flavour only, not load-bearing
@export var mean: int = 5            # mid-Tour even-contest centre
@export var spread: int = 3          # half-width of the strength band
@export var noise: int = 1           # +-absolute per-derivation jitter

# frac 0.0 -> mean - spread, 0.5 -> mean, 1.0 -> mean + spread. Clamped + rounded.
func percentile(frac: float) -> int:
	var f := clampf(frac, 0.0, 1.0)
	return roundi(mean + (f - 0.5) * 2.0 * spread)
```

- [ ] **Step 4: Re-import (new script) and run the suite to verify GREEN**

Run `--import` once, then the whole-suite command. Expected: `All tests passed`, count = **157** (154 + 3).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/tour_distribution.gd scripts/data/tour_distribution.gd.uid tests/unit/test_tour_distribution.gd
git commit -m "7b-1 task 1: TourDistribution (stars-fraction -> strength band)"
```

---

### Task 2: `Team` — the ★-rated side

**Files:**
- Create: `scripts/data/team.gd`
- Test: `tests/unit/test_team.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_team.gd`:

```gdscript
extends GutTest

func _tour(mean: int, spread: int, noise: int) -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = mean
	t.spread = spread
	t.noise = noise
	return t

func _team(stars: float) -> Team:
	var tm := Team.new()
	tm.stars = stars
	return tm

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func test_stronger_stars_higher_mean_strength() -> void:
	var tour := _tour(5, 3, 1)
	var strong := _team(5.0)
	var weak := _team(1.0)
	var strong_sum := 0
	var weak_sum := 0
	var n := 200
	for s in range(n):
		strong_sum += strong.batting_strength(tour, _rng(s))
		weak_sum += weak.batting_strength(tour, _rng(s))
	assert_gt(strong_sum, weak_sum, "5.0 stars derives higher batting than 1.0 stars on average")

func test_noise_bounded_and_floored() -> void:
	var tour := _tour(5, 3, 1)
	var tm := _team(5.0)            # percentile(1.0) == 8
	for s in range(50):
		var v := tm.bowling_strength(tour, _rng(s))
		assert_true(v >= 7 and v <= 9, "5.0-star strength within mean+spread +- noise (got %d)" % v)
	# Floor: a tiny band + lowest star can push below 1; must clamp to 1.
	var tiny := _tour(1, 1, 5)     # percentile(0.1) == roundi(1 + (0.1-0.5)*2*1) == 0
	var cellar := _team(0.5)
	for s in range(50):
		assert_true(cellar.batting_strength(tiny, _rng(s)) >= 1, "strength floored at 1")

func test_zero_noise_matches_percentile() -> void:
	var tour := _tour(5, 3, 0)
	assert_eq(_team(5.0).batting_strength(tour, _rng(1)), tour.percentile(1.0), "5.0 stars, no noise -> percentile(1.0)")
	assert_eq(_team(0.5).bowling_strength(tour, _rng(1)), tour.percentile(0.1), "0.5 stars, no noise -> percentile(0.1)")
```

- [ ] **Step 2: Run the suite to verify RED**

Run the whole-suite command. Expected: `Parse Error: Identifier "Team" not declared`; count stays 157.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/data/team.gd`:

```gdscript
class_name Team
extends Resource

# A star-rated side. Per-Match batting & bowling strengths derive from
# (stars, tour, small noise) per ADR 0009: tour.percentile(stars/5) + noise,
# two independent draws, floored at 1. The Markov star-mutation rule lives in
# 7b-2. See spec 2026-06-07-season-wrapper-7b1-design.md §3.

const STARS_MIN := 0.5
const STARS_MAX := 5.0

@export var team_name: String = ""
@export var stars: float = 2.5                # on the 0.5..5.0 half-step set
@export var last_season_event: String = ""    # ADR 0009 flavour; unused this rung

func batting_strength(tour: TourDistribution, rng: RandomNumberGenerator) -> int:
	return maxi(1, tour.percentile(stars / STARS_MAX) + rng.randi_range(-tour.noise, tour.noise))

func bowling_strength(tour: TourDistribution, rng: RandomNumberGenerator) -> int:
	return maxi(1, tour.percentile(stars / STARS_MAX) + rng.randi_range(-tour.noise, tour.noise))
```

- [ ] **Step 4: Re-import (new script) and run the suite to verify GREEN**

Run `--import`, then the whole-suite command. Expected: `All tests passed`, count = **160** (157 + 3).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/team.gd scripts/data/team.gd.uid tests/unit/test_team.gd
git commit -m "7b-1 task 2: Team (star rating -> per-Match strength derivation, ADR 0009)"
```

---

### Task 3: Toss + `simulate_match_teams()` wrapper

**Files:**
- Modify: `scripts/domain/match_resolver.gd` (add `_resolve_toss` + `simulate_match_teams`)
- Test: `tests/unit/test_match_resolver.gd` (append cases)

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_match_resolver.gd` (helpers `_attrs`, `_make_rng`, `tuning`, `itun` already exist in this file):

```gdscript
func _tour() -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = 5
	t.spread = 3
	t.noise = 1
	return t

func _team(stars: float) -> Team:
	var tm := Team.new()
	tm.stars = stars
	return tm

func test_teams_determinism() -> void:
	var p := _attrs(5, 5, 5, 5)
	var r1 := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(2024))
	var r2 := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(2024))
	assert_eq(r1.outcome, r2.outcome, "outcome deterministic")
	assert_eq(r1.innings1.total, r2.innings1.total, "innings1 total deterministic")
	assert_eq(r1.innings2.total, r2.innings2.total, "innings2 total deterministic")
	assert_eq(r1.margin_runs, r2.margin_runs, "margin deterministic")

func test_teams_directional_strong_beats_weak() -> void:
	var p := _attrs(5, 5, 5, 5)
	var tour := _tour()
	var fav_wins := 0
	var dog_wins := 0
	var n := 60
	for sv in range(1, n + 1):
		# Player on a 5-star team vs a 0.5-star opponent.
		var a := MatchResolver.simulate_match_teams(p, _team(5.0), _team(0.5), tour, tuning, itun, _make_rng(sv))
		if a.outcome == MatchResult.Outcome.PLAYER_WIN:
			fav_wins += 1
		# Player on a 0.5-star team vs a 5-star opponent.
		var b := MatchResolver.simulate_match_teams(p, _team(0.5), _team(5.0), tour, tuning, itun, _make_rng(sv))
		if b.outcome == MatchResult.Outcome.PLAYER_WIN:
			dog_wins += 1
	assert_gt(fav_wins, int(n * 0.8), "5.0-star team wins a big majority (got %d/%d)" % [fav_wins, n])
	assert_lt(dog_wins, int(n * 0.2), "0.5-star team wins few (got %d/%d)" % [dog_wins, n])

func test_teams_even_roughly_balanced() -> void:
	var p := _attrs(5, 5, 5, 5)
	var tour := _tour()
	var player_wins := 0
	var decided := 0
	for sv in range(1, 121):
		var r := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), tour, tuning, itun, _make_rng(sv))
		if r.outcome == MatchResult.Outcome.PLAYER_WIN:
			player_wins += 1
			decided += 1
		elif r.outcome == MatchResult.Outcome.OPPONENT_WIN:
			decided += 1
	var share := float(player_wins) / float(decided)
	assert_between(share, 0.30, 0.70, "equal-star contest is roughly balanced (share %f)" % share)
```

- [ ] **Step 2: Run the suite to verify RED**

Run the whole-suite command. Expected: `Parse Error: Identifier "simulate_match_teams" not declared` (or a "function not found" parse error) in `test_match_resolver.gd`; that file is skipped, count stays 160.

- [ ] **Step 3: Write the implementation**

In `scripts/domain/match_resolver.gd`, add the toss helper and the wrapper (place after `_decide_result`, before/after `simulate_match` — both are static, order is free):

```gdscript
# Seeded toss. Returns player_bats_first. Strawman: 50/50, winner bats first.
# A bat/bowl heuristic is deferred (spec §4). Consumes exactly one RNG draw.
static func _resolve_toss(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < 0.5

# Team-bundled match: derive six strength ints from the two Teams + Tour, flip
# the toss, then delegate to simulate_match(). Fixed RNG draw order (toss, then
# the four strength derivations) before the core sim consumes the rest, so a
# fixed seed + Teams + Tour -> identical MatchResult. The bowling number feeds
# both attack and control (spec §1/§5). See ADR 0009.
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
) -> MatchResult:
	var player_bats_first := _resolve_toss(rng)
	var player_bat := player_team.batting_strength(tour, rng)
	var player_bowl := player_team.bowling_strength(tour, rng)
	var opp_bat := opp_team.batting_strength(tour, rng)
	var opp_bowl := opp_team.bowling_strength(tour, rng)

	return simulate_match(
		player_attrs,
		player_bat, player_bowl, player_bowl,
		opp_bat, opp_bowl, opp_bowl,
		player_bats_first, tuning, itun, rng,
		player_intent_plan, player_bowling_plan)
```

- [ ] **Step 4: Re-import (modified script — safe to run) and run the suite to verify GREEN**

Run `--import`, then the whole-suite command. Expected: `All tests passed`, count = **163** (160 + 3). All pre-existing match/innings tests still green (the core was not modified).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_resolver.gd scripts/domain/match_resolver.gd.uid tests/unit/test_match_resolver.gd
git commit -m "7b-1 task 3: simulate_match_teams + seeded toss (delegates to untouched core)"
```

---

### Task 4: Eyeball deliverable — win-rate-vs-star-gap chart (real sim)

**Files:**
- Create: `tools/season_preview.gd` (headless runner — drives the real sim, prints CSV)
- Create: `docs/mockups/star-winrate-v1.html` (chart with the runner's data inlined)

This task has **no unit tests** — it is a diagnostic. Its directional claim is already asserted by Task 3's `test_teams_directional_strong_beats_weak`. Output is for Nico to eyeball in a browser.

- [ ] **Step 1: Write the headless runner**

Create `tools/season_preview.gd`:

```gdscript
extends SceneTree

# Throwaway diagnostic + first seed of the 7c balance harness. Sweeps the star
# gap (playerStars - oppStars), runs N seeded simulate_match_teams per gap
# against a fixed Tour, and prints CSV to stdout:
#   star_gap,matches,player_wins,win_rate
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/season_preview.gd
# (capture stdout; paste the rows into docs/mockups/star-winrate-v1.html)

func _init() -> void:
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var tour := TourDistribution.new()
	tour.mean = 5
	tour.spread = 3
	tour.noise = 1
	var player := Attributes.new()
	player.power = 5
	player.composure = 5
	player.attack = 5
	player.control = 5

	var stars := [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
	var n := 300
	print("star_gap,matches,player_wins,win_rate")
	# Aggregate by integer-rounded star gap so each gap pools several matchups.
	var wins_by_gap := {}
	var total_by_gap := {}
	for ps in stars:
		for os in stars:
			var gap := ps - os
			var pt := Team.new(); pt.stars = ps
			var ot := Team.new(); ot.stars = os
			for sv in range(1, n + 1):
				var r := MatchResolver.simulate_match_teams(player, pt, ot, tour, tuning, itun, _rng(sv + int(ps * 100) + int(os * 10000)))
				var key := snappedf(gap, 0.5)
				total_by_gap[key] = total_by_gap.get(key, 0) + 1
				if r.outcome == MatchResult.Outcome.PLAYER_WIN:
					wins_by_gap[key] = wins_by_gap.get(key, 0) + 1
	var keys := total_by_gap.keys()
	keys.sort()
	for k in keys:
		var w: int = wins_by_gap.get(k, 0)
		var tot: int = total_by_gap[k]
		print("%.1f,%d,%d,%.4f" % [k, tot, w, float(w) / float(tot)])
	quit()

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r
```

- [ ] **Step 2: Run the runner and capture the CSV**

Run:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/season_preview.gd`
Expected: a `star_gap,matches,player_wins,win_rate` header followed by ~19 rows (gaps -4.5 … +4.5), `win_rate` rising roughly monotonically from near 0 at the most-negative gap to near 1 at the most-positive. Keep the printed rows for Step 3.

- [ ] **Step 3: Write the chart with the data inlined**

Create `docs/mockups/star-winrate-v1.html` — a self-contained page (no external libs; a small inline `<canvas>` or SVG plot) that plots **win-rate % (Y) vs star gap (X)** from the captured rows, pasted into a `const DATA = [...]` array. Include a one-line caption: "Real Godot sim — Player team ★ minus opponent ★ vs Player win-rate over N matches per gap (7b-1)." Render the points + a connecting line; mark the 50% gridline and the gap=0 vertical.

- [ ] **Step 4: Eyeball in a browser**

Open `docs/mockups/star-winrate-v1.html`. Confirm a rising S-curve crossing ~50% at gap 0. (Manual check — this is the rung's "learn by seeing" gate.)

- [ ] **Step 5: Commit**

```bash
git add tools/season_preview.gd tools/season_preview.gd.uid docs/mockups/star-winrate-v1.html
git commit -m "7b-1 task 4: real-sim win-rate-vs-star-gap runner + chart"
```

(If `tools/season_preview.gd.uid` was not generated — scripts outside `scripts/` may still get one; add it only if `git status` shows it.)

---

## Self-review notes

- **Spec coverage:** §2 TourDistribution → Task 1; §3 Team → Task 2; §4 toss + §5 simulate_match_teams → Task 3; §7 runner + chart → Task 4; §6 backward-compat/determinism → asserted by Task 3 `test_teams_determinism` + the untouched-core design (no existing test changes). §8 tests 1–9 are distributed across Tasks 1–3 (TourDistribution 1–2; Team 3–5; match 6–9, with the toss-50/50 claim covered indirectly by `test_teams_even_roughly_balanced` which depends on a fair toss + symmetric derivation).
- **Type consistency:** `TourDistribution.percentile`, `Team.batting_strength`/`bowling_strength`, `Team.stars`, `MatchResolver.simulate_match_teams`, `_resolve_toss` names match between spec and plan and across tasks. `simulate_match_teams` param order matches the spec §5 signature exactly.
- **Counts:** baseline 154 → 157 (T1) → 160 (T2) → 163 (T3). Task 4 adds no tests.
- **No placeholders:** all code blocks complete; commands exact.
</content>
</invoke>
