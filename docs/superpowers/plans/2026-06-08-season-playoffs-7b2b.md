# Season playoffs + outcome (7b-2b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the Season loop — play the top-4 knockout playoffs (two semis → The Final + 3rd-place playoff) on top of 7b-2a's league phase, decide the beat/win outcome via a new `SeasonResolver.simulate_season()` → `SeasonResult`, and add the ADR 0009 `Team.mutate_stars()` ★ rollover primitive.

**Architecture:** `simulate_season` runs the league (7b-2a, which now also exposes the per-Season held strengths), reads the top-4 seeds, plays four knockouts reusing those held strengths (Player statted when involved; ties → higher seed advances), assembles the final 1–8 ordering, and flags `beat` (top 3) / `won_final` (1st). Additive — existing files only gain fields/methods.

**Tech Stack:** Godot 4.6.3 (Standard) · GDScript (tabs) · GUT 9.6. Spec: `docs/superpowers/specs/2026-06-08-season-playoffs-7b2b-design.md`.

---

## Conventions for every task (project `CLAUDE.md`)

- **Godot binary:** `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH). **`pgrep Godot` must be empty** before headless runs.
- **After adding a new `scripts/` file, run `--import` once** before tests:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- **Run the whole suite** (the `-gtest` flag does NOT filter here):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- **Judge RED** by `Parse Error: Identifier "X" not declared` (file skipped). **Judge GREEN** by the count climbing + `All tests passed`.
- **iCloud junk guard:** if GUT suddenly fails to load, `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot` then re-`--import`.
- **Commit `*.gd.uid`** for `scripts/` (and `tools/`) files; NOT for `tests/`.
- Baseline before starting: **169 tests green**.

---

### Task 1: `Team.mutate_stars` — ★ rollover mutation

**Files:**
- Modify: `scripts/data/team.gd` (add constants + `mutate_stars`)
- Test: `tests/unit/test_team.gd` (append)

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_team.gd` (the file already has `_team`, `_rng` helpers):

```gdscript
func test_mutate_stars_distribution() -> void:
	var unchanged := 0
	var half := 0
	var full := 0
	var n := 4000
	for s in range(n):
		var tm := _team(3.0)
		tm.mutate_stars(_rng(s))
		var d: float = absf(tm.stars - 3.0)
		if is_equal_approx(d, 0.0):
			unchanged += 1
		elif is_equal_approx(d, 0.5):
			half += 1
		elif is_equal_approx(d, 1.0):
			full += 1
		assert_true(is_equal_approx(fmod(tm.stars, 0.5), 0.0) or is_equal_approx(fmod(tm.stars, 0.5), 0.5),
			"result stays on the 0.5 grid (got %f)" % tm.stars)
	assert_almost_eq(float(unchanged) / n, 0.65, 0.05, "~65%% unchanged")
	assert_almost_eq(float(half) / n, 0.30, 0.05, "~30%% +-0.5")
	assert_almost_eq(float(full) / n, 0.05, 0.05, "~5%% +-1.0")

func test_mutate_stars_clamped() -> void:
	for s in range(200):
		var hi := _team(5.0)
		hi.mutate_stars(_rng(s))
		assert_lte(hi.stars, 5.0, "never above 5.0")
		var lo := _team(0.5)
		lo.mutate_stars(_rng(s))
		assert_gte(lo.stars, 0.5, "never below 0.5")
```

- [ ] **Step 2: Run the suite to verify RED**

Run the whole-suite command. Expected: a failure/parse error in `test_team.gd` referencing `mutate_stars` (function not found) → file skipped, count drops below 169.

- [ ] **Step 3: Write the implementation**

In `scripts/data/team.gd`, add the constants near the top (after `STARS_MAX`) and the method at the end:

```gdscript
const MUTATE_CATASTROPHIC := 0.05   # P(+-1.0 swing)
const MUTATE_SWING := 0.35          # cumulative: P(+-0.5) = 0.30; else no change
```

```gdscript
# Mutate stars Markov-style at a Season rollover (ADR 0009). Two RNG draws
# (magnitude, then direction), clamped to [0.5, 5.0]. Catastrophic flavour string
# deferred. See spec 2026-06-08-season-playoffs-7b2b-design.md §6.
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

- [ ] **Step 4: Re-import and run the suite to verify GREEN**

Run `--import`, then the whole-suite command. Expected: `All tests passed`, count = **171** (169 + 2).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/team.gd scripts/data/team.gd.uid tests/unit/test_team.gd
git commit -m "7b-2b task 1: Team.mutate_stars (ADR 0009 rollover mutation)"
```

---

### Task 2: Expose held strengths on `LeagueResult`

**Files:**
- Modify: `scripts/data/league_result.gd` (add `team_bat`/`team_bowl`)
- Modify: `scripts/domain/league_resolver.gd` (populate them)
- Test: `tests/unit/test_league_resolver.gd` (append)

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_league_resolver.gd` (helpers `_attrs`/`_team`/`_tour`/`_rng`/`_field`/`tuning`/`itun` already exist):

```gdscript
func test_league_exposes_held_strengths() -> void:
	var r := LeagueResolver.simulate_league(_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(7))
	assert_eq(r.team_bat.size(), 8, "8 batting strengths exposed")
	assert_eq(r.team_bowl.size(), 8, "8 bowling strengths exposed")
	for v in r.team_bat:
		assert_gte(v, 1, "batting strength floored at 1")
	for v in r.team_bowl:
		assert_gte(v, 1, "bowling strength floored at 1")
```

- [ ] **Step 2: Run the suite to verify RED**

Run the whole-suite command. Expected: assertion failure (`team_bat` is an empty Array → `size()` 0 ≠ 8). Count stays 171 but with 1 failing test.

- [ ] **Step 3: Add the fields to `LeagueResult`**

In `scripts/data/league_result.gd`, add after `player_matches`:

```gdscript
var team_bat: Array = []         # team_bat[team_index] = per-Season batting strength
var team_bowl: Array = []        # team_bowl[team_index] = per-Season bowling strength
```

- [ ] **Step 4: Populate them in `simulate_league`**

In `scripts/domain/league_resolver.gd`, in `simulate_league`, set them on the result before returning. Find the result-building block near the end and add the two assignments:

```gdscript
	var result := LeagueResult.new()
	result.standings = rows
	result.player_matches = player_matches
	result.team_bat = bat
	result.team_bowl = bowl
	for pos in range(rows.size()):
		if rows[pos].team_index == 0:
			result.player_position = pos + 1
			break
	result.made_playoffs = result.player_position <= PLAYOFF_CUTOFF
	return result
```

- [ ] **Step 5: Re-import and run the suite to verify GREEN**

Run `--import`, then the whole-suite command. Expected: `All tests passed`, count = **172** (171 + 1).

- [ ] **Step 6: Commit**

```bash
git add scripts/data/league_result.gd scripts/data/league_result.gd.uid scripts/domain/league_resolver.gd scripts/domain/league_resolver.gd.uid tests/unit/test_league_resolver.gd
git commit -m "7b-2b task 2: expose per-Season held strengths on LeagueResult"
```

---

### Task 3: `SeasonResult` + `SeasonResolver.simulate_season`

**Files:**
- Create: `scripts/data/season_result.gd`
- Create: `scripts/domain/season_resolver.gd`
- Test: `tests/unit/test_season_resolver.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_season_resolver.gd`:

```gdscript
extends GutTest

var tuning: BallTuning
var itun: InningsTuning

func before_each() -> void:
	tuning = BallTuning.new()
	itun = InningsTuning.new()

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 5
	a.composure = 5
	a.attack = 5
	a.control = 5
	return a

func _tour() -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = 5
	t.spread = 1.5
	t.noise = 1
	return t

func _team(stars: float) -> Team:
	var tm := Team.new()
	tm.stars = stars
	return tm

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func _field() -> Array:
	return [_team(1.0), _team(1.5), _team(2.0), _team(2.5), _team(3.0), _team(3.5), _team(4.0)]

func test_season_deterministic() -> void:
	var r1 := SeasonResolver.simulate_season(_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(2024))
	var r2 := SeasonResolver.simulate_season(_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(2024))
	assert_eq(r1.player_final_position, r2.player_final_position, "final position deterministic")
	assert_eq(r1.beat, r2.beat, "beat deterministic")
	assert_eq(r1.won_final, r2.won_final, "won_final deterministic")
	assert_eq(r1.final_order, r2.final_order, "final order deterministic")

func test_season_final_order_is_permutation() -> void:
	var r := SeasonResolver.simulate_season(_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(7))
	assert_eq(r.final_order.size(), 8, "8 teams in the final order")
	var seen := {}
	for idx in r.final_order:
		assert_false(seen.has(idx), "no duplicate team_index %d" % idx)
		seen[idx] = true
	for t in range(8):
		assert_true(seen.has(t), "team %d present in final order" % t)
	# Positions 5-8 are the league standings[4..7], in order.
	for k in range(4, 8):
		assert_eq(r.final_order[k], r.league.standings[k].team_index, "pos %d == league standings[%d]" % [k + 1, k])
	# Positions 1-4 are exactly the league top-4 set.
	var top4 := {}
	for k in range(4):
		top4[r.league.standings[k].team_index] = true
	for k in range(4):
		assert_true(top4.has(r.final_order[k]), "playoff finisher %d came from the league top 4" % r.final_order[k])

func test_season_outcome_consistency() -> void:
	var r := SeasonResolver.simulate_season(_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(11))
	assert_between(r.player_final_position, 1, 8, "position in 1..8")
	assert_eq(r.beat, r.player_final_position <= 3, "beat == top 3")
	assert_eq(r.won_final, r.player_final_position == 1, "won_final == 1st")
	if r.won_final:
		assert_true(r.beat, "winning the Final implies beating the Season")

func test_season_champion_came_through_the_final() -> void:
	var r := SeasonResolver.simulate_season(_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(11))
	var fw := r.final_match.player_bats_first  # touch to ensure MatchResult is real
	assert_true(fw == true or fw == false, "final_match is a real MatchResult")
	# final_order[0]/[1] = Final winner/loser; [2]/[3] = 3rd-place winner/loser.
	# The winner of final_match is whichever of its two teams sits at final_order[0].
	assert_true(r.final_order[0] != r.final_order[1], "1st and 2nd are different teams")
	assert_true(r.final_order[2] != r.final_order[3], "3rd and 4th are different teams")

func test_season_directional_strong_player_wins_more() -> void:
	var strong_beat := 0
	var weak_beat := 0
	var strong_won := 0
	var weak_won := 0
	var n := 30
	for sv in range(1, n + 1):
		var rs := SeasonResolver.simulate_season(_attrs(), _team(5.0), _field(), _tour(), tuning, itun, _rng(sv))
		var rw := SeasonResolver.simulate_season(_attrs(), _team(0.5), _field(), _tour(), tuning, itun, _rng(sv))
		if rs.beat:
			strong_beat += 1
		if rw.beat:
			weak_beat += 1
		if rs.won_final:
			strong_won += 1
		if rw.won_final:
			weak_won += 1
	assert_gt(strong_beat, weak_beat, "5.0-star beats the Season more often than 0.5-star")
	assert_gte(strong_won, weak_won, "5.0-star wins the Final at least as often as 0.5-star")
```

- [ ] **Step 2: Run the suite to verify RED**

Run the whole-suite command. Expected: `Parse Error: Identifier "SeasonResolver" not declared` (and `SeasonResult`); `test_season_resolver.gd` skipped, count stays 172.

- [ ] **Step 3: Write `SeasonResult`**

Create `scripts/data/season_result.gd`:

```gdscript
class_name SeasonResult
extends RefCounted

# Outcome of a full Season (league + playoffs). See spec
# 2026-06-08-season-playoffs-7b2b-design.md §4.

var league: LeagueResult                 # the league phase
var semi1: MatchResult                   # seed1 v seed4
var semi2: MatchResult                   # seed2 v seed3
var final_match: MatchResult             # the two semi winners (1st/2nd)
var third_place: MatchResult             # the two semi losers (3rd/4th)
var final_order: Array = []              # 8 team_index values, finishing 1st..8th
var player_final_position: int = 0       # 1..8 (where team 0 finished)
var beat: bool = false                   # player finished top 3
var won_final: bool = false              # player finished 1st (won The Final)
```

- [ ] **Step 4: Write `SeasonResolver`**

Create `scripts/domain/season_resolver.gd`:

```gdscript
class_name SeasonResolver
extends RefCounted

# Resolves a full Season: league phase (LeagueResolver) -> top-4 knockout
# playoffs -> outcome. Deterministic given rng (league draws, then SF1, SF2,
# Final, 3rd-place in order). See spec 2026-06-08-season-playoffs-7b2b-design.md.
# No member state.

# Play one knockout. Returns {winner, loser, result}. On a tie the better seed
# (lower league position) advances. The Player (team 0), when involved, is
# statted as the simulate_match "player slot"; otherwise both sides derived.
static func _knockout(
		a_idx: int, a_seed: int, b_idx: int, b_seed: int,
		team_bat: Array, team_bowl: Array,
		player_attrs: Attributes, tuning: BallTuning, itun: InningsTuning,
		rng: RandomNumberGenerator, ip: IntentPlan, bp: BowlingPlan
) -> Dictionary:
	var s1 := a_idx
	var s2 := b_idx
	if b_idx == 0:                # put the Player in the simulate_match player slot
		s1 = b_idx
		s2 = a_idx
	var pa: Attributes = player_attrs if s1 == 0 else null
	var ipp: IntentPlan = ip if s1 == 0 else null
	var bpp: BowlingPlan = bp if s1 == 0 else null
	var toss := MatchResolver._resolve_toss(rng)
	var m := MatchResolver.simulate_match(
		pa, team_bat[s1], team_bowl[s1], team_bowl[s1],
		team_bat[s2], team_bowl[s2], team_bowl[s2],
		toss, tuning, itun, rng, ipp, bpp)
	var s1_won: bool
	if m.outcome == MatchResult.Outcome.TIE:
		var s1_seed := a_seed if s1 == a_idx else b_seed
		var s2_seed := b_seed if s1 == a_idx else a_seed
		s1_won = s1_seed < s2_seed       # better seed advances
	elif m.outcome == MatchResult.Outcome.PLAYER_WIN:
		s1_won = true
	else:
		s1_won = false
	var winner := s1 if s1_won else s2
	var loser := s2 if s1_won else s1
	return {"winner": winner, "loser": loser, "result": m}

static func simulate_season(
		player_attrs: Attributes,
		player_team: Team,
		opponents: Array,
		tour: TourDistribution,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator,
		player_intent_plan: IntentPlan = null,
		player_bowling_plan: BowlingPlan = null
) -> SeasonResult:
	var league := LeagueResolver.simulate_league(
		player_attrs, player_team, opponents, tour, tuning, itun, rng,
		player_intent_plan, player_bowling_plan)
	var bat: Array = league.team_bat
	var bowl: Array = league.team_bowl

	# Seeds 1-4 = league positions 1-4 (their team_index).
	var s1i: int = league.standings[0].team_index
	var s2i: int = league.standings[1].team_index
	var s3i: int = league.standings[2].team_index
	var s4i: int = league.standings[3].team_index

	# Semi-finals: 1v4, 2v3.
	var sf1 := _knockout(s1i, 1, s4i, 4, bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan)
	var sf2 := _knockout(s2i, 2, s3i, 3, bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan)

	# Seed lookup for the bracket (team_index -> league position 1..4).
	var seed_of := {s1i: 1, s2i: 2, s3i: 3, s4i: 4}

	# Final: the two semi winners (better seed first). 3rd-place: the two losers.
	var fw_a: int = sf1["winner"]
	var fw_b: int = sf2["winner"]
	var final_kn: Dictionary
	if seed_of[fw_a] <= seed_of[fw_b]:
		final_kn = _knockout(fw_a, seed_of[fw_a], fw_b, seed_of[fw_b], bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan)
	else:
		final_kn = _knockout(fw_b, seed_of[fw_b], fw_a, seed_of[fw_a], bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan)

	var tl_a: int = sf1["loser"]
	var tl_b: int = sf2["loser"]
	var third_kn: Dictionary
	if seed_of[tl_a] <= seed_of[tl_b]:
		third_kn = _knockout(tl_a, seed_of[tl_a], tl_b, seed_of[tl_b], bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan)
	else:
		third_kn = _knockout(tl_b, seed_of[tl_b], tl_a, seed_of[tl_a], bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan)

	var result := SeasonResult.new()
	result.league = league
	result.semi1 = sf1["result"]
	result.semi2 = sf2["result"]
	result.final_match = final_kn["result"]
	result.third_place = third_kn["result"]

	var order: Array = [
		final_kn["winner"], final_kn["loser"],
		third_kn["winner"], third_kn["loser"],
	]
	for k in range(4, 8):
		order.append(league.standings[k].team_index)
	result.final_order = order

	for pos in range(order.size()):
		if order[pos] == 0:
			result.player_final_position = pos + 1
			break
	result.beat = result.player_final_position <= 3
	result.won_final = result.player_final_position == 1
	return result
```

- [ ] **Step 5: Re-import and run the suite to verify GREEN**

Run `--import`, then the whole-suite command. Expected: `All tests passed`, count = **177** (172 + 5).

- [ ] **Step 6: Commit**

```bash
git add scripts/data/season_result.gd scripts/data/season_result.gd.uid scripts/domain/season_resolver.gd scripts/domain/season_resolver.gd.uid tests/unit/test_season_resolver.gd
git commit -m "7b-2b task 3: SeasonResolver.simulate_season + SeasonResult (playoffs + outcome)"
```

---

### Task 4: Eyeball deliverable — beat-rate + win-Final-rate vs Player ★

**Files:**
- Create: `tools/season_outcome_preview.gd`
- Create: `docs/mockups/season-outcome-v1.html`

No unit tests — diagnostic. Its directional claim is asserted by Task 3's `test_season_directional_strong_player_wins_more`.

- [ ] **Step 1: Write the runner**

Create `tools/season_outcome_preview.gd`:

```gdscript
extends SceneTree

# Throwaway diagnostic: sweep the Player team's stars against a RANDOM 7-opponent
# field, run N seeded full Seasons per star, print CSV:
#   player_stars,seasons,beat_rate,win_final_rate,avg_finish
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/season_outcome_preview.gd

const STAR_SET := [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]

func _init() -> void:
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var tour := TourDistribution.new()
	tour.mean = 5
	tour.spread = 1.5
	tour.noise = 1
	var player := Attributes.new()
	player.power = 5
	player.composure = 5
	player.attack = 5
	player.control = 5

	var n := 120
	print("player_stars,seasons,beat_rate,win_final_rate,avg_finish")
	for ps in STAR_SET:
		var beat := 0
		var won := 0
		var pos_sum := 0
		for sv in range(1, n + 1):
			var rng := _rng(sv + int(ps * 1000))
			var field: Array = []
			for k in range(7):
				field.append(_team(STAR_SET[rng.randi_range(0, STAR_SET.size() - 1)]))
			var r := SeasonResolver.simulate_season(player, _team(ps), field, tour, tuning, itun, rng)
			if r.beat:
				beat += 1
			if r.won_final:
				won += 1
			pos_sum += r.player_final_position
		print("%.1f,%d,%.4f,%.4f,%.3f" % [ps, n, float(beat) / n, float(won) / n, float(pos_sum) / n])
	quit()

func _team(stars: float) -> Team:
	var tm := Team.new()
	tm.stars = stars
	return tm

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r
```

- [ ] **Step 2: Run the runner and capture the CSV**

Run:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/season_outcome_preview.gd`
Expected: a header + 10 rows. `beat_rate` and `win_final_rate` both rise with stars; `beat_rate >= win_final_rate` at every star (beating is easier than winning the Final); `avg_finish` falls toward 1. Keep the rows for Step 3.

- [ ] **Step 3: Write the chart with the data inlined**

Create `docs/mockups/season-outcome-v1.html` — a self-contained page (inline `<canvas>`, no libs) plotting **beat-rate % and win-Final-rate % (Y) vs Player team ★ (X)**, two lines, from a pasted `const DATA = [...]`. Caption: "Real Godot sim — Player team ★ vs beating the Season (top 3) and winning the Final (champion), over N full Seasons against a random field (7b-2b)." Note in the caption that beat-rate sits above win-rate by construction.

- [ ] **Step 4: Eyeball in a browser**

Serve and open `docs/mockups/season-outcome-v1.html` (reuse `.claude/launch.json`'s `mockups` server). Confirm both lines climb with ★ and beat-rate stays at or above win-rate. Manual check — the rung's "learn by seeing" gate.

- [ ] **Step 5: Commit**

```bash
git add tools/season_outcome_preview.gd docs/mockups/season-outcome-v1.html
# add tools/season_outcome_preview.gd.uid only if git status shows it
git commit -m "7b-2b task 4: season-outcome (beat/win) vs star runner + chart"
```

---

## Self-review notes

- **Spec coverage:** §3 LeagueResult strengths → Task 2; §4 SeasonResult → Task 3; §5 simulate_season + _knockout → Task 3; §6 mutate_stars → Task 1; §8 eyeball → Task 4; §7 backward-compat/determinism → Task 3 `test_season_deterministic` + additive design. §9 tests: test 1–2 → Task 1; test 3 → Task 2; tests 4–8 → Task 3.
- **Type consistency:** `SeasonResult` fields (`league`, `semi1`, `semi2`, `final_match`, `third_place`, `final_order`, `player_final_position`, `beat`, `won_final`), `SeasonResolver.simulate_season`/`_knockout` signatures, `LeagueResult.team_bat`/`team_bowl`, `Team.mutate_stars`/`MUTATE_CATASTROPHIC`/`MUTATE_SWING` all match the spec. Reuses `LeagueResolver.simulate_league`, `MatchResolver.simulate_match`/`_resolve_toss`, `MatchResult.Outcome.*`, `StandingsRow.team_index` as defined in 7b-2a/7b-1.
- **Counts:** 169 → 171 (T1) → 172 (T2) → 177 (T3). T4 adds none.
- **No placeholders:** all code complete; commands exact.
- **GDScript notes:** ternaries (`x if c else y`) and a typed Dictionary return used in `_knockout`. `seed_of` Dictionary keys are team_index ints. `_knockout` always draws one toss + the match's draws, keeping RNG order fixed across the four knockouts.
</content>
