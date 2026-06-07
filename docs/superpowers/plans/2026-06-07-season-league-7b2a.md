# Season league phase (7b-2a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Loop `simulate_match` into an 8-team single round-robin league phase — every game simulated, a points+NRR standings table, and the Player team's finishing position + playoff qualification — via a new `LeagueResolver.simulate_league()`.

**Architecture:** A pure round-robin schedule + per-Season strength derivation (each Team's strength drawn once, held all Season) feed `simulate_match` for all 28 games (Player games statted, others derived via the already-supported `null`-player path). Results accumulate into `StandingsRow`s (points, runs/balls for & against → NRR), ranked into a `LeagueResult`. Additive only — no existing file changes behaviour.

**Tech Stack:** Godot 4.6.3 (Standard) · GDScript (tabs) · GUT 9.6. Spec: `docs/superpowers/specs/2026-06-07-season-league-7b2a-design.md`.

---

## Conventions for every task (project `CLAUDE.md`)

- **Godot binary:** `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH).
- **`pgrep Godot` must be empty** before any headless run (quit the editor first).
- **After adding a new `scripts/` file, run `--import` once** before tests:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- **Run the whole suite** (the `-gtest` flag does NOT filter here):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- **Judge RED** by `SCRIPT ERROR: Parse Error: Identifier "X" not declared` (file skipped). **Judge GREEN** by the total count climbing and `All tests passed`.
- **iCloud junk guard:** if GUT suddenly fails to load, `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot` then re-`--import`.
- **Commit `*.gd.uid`** for `scripts/` (and `tools/`) files; NOT for `tests/`.
- Baseline before starting: **163 tests green**.

---

### Task 1: `StandingsRow` — one team's league record + NRR

**Files:**
- Create: `scripts/data/standings_row.gd`
- Test: `tests/unit/test_standings_row.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_standings_row.gd`:

```gdscript
extends GutTest

func test_nrr_sign_and_zero_guard() -> void:
	var r := StandingsRow.new()
	# Scored 200 off 240 balls; conceded 150 off 240 -> positive NRR.
	r.runs_for = 200
	r.balls_for = 240
	r.runs_against = 150
	r.balls_against = 240
	assert_gt(r.nrr(), 0.0, "more runs/over for than against -> positive NRR")

	var s := StandingsRow.new()
	s.runs_for = 150
	s.balls_for = 240
	s.runs_against = 200
	s.balls_against = 240
	assert_lt(s.nrr(), 0.0, "fewer runs/over for than against -> negative NRR")

	var empty := StandingsRow.new()
	assert_eq(empty.nrr(), 0.0, "no balls -> 0.0, no divide-by-zero")
```

- [ ] **Step 2: Run the suite to verify RED**

Run the whole-suite command. Expected: `Parse Error: Identifier "StandingsRow" not declared`; count stays 163.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/data/standings_row.gd`:

```gdscript
class_name StandingsRow
extends RefCounted

# One team's league-phase record. NRR uses actual balls faced/bowled — a V1
# simplification of the all-out-quota rule. See spec
# 2026-06-07-season-league-7b2a-design.md §6.

var team_index: int = 0
var played: int = 0
var points: int = 0
var runs_for: int = 0
var balls_for: int = 0
var runs_against: int = 0
var balls_against: int = 0

# Net run rate: runs/over scored minus runs/over conceded. 0.0 if no balls.
func nrr() -> float:
	var rpo_for := (runs_for * 6.0) / balls_for if balls_for > 0 else 0.0
	var rpo_against := (runs_against * 6.0) / balls_against if balls_against > 0 else 0.0
	return rpo_for - rpo_against
```

- [ ] **Step 4: Re-import and run the suite to verify GREEN**

Run `--import`, then the whole-suite command. Expected: `All tests passed`, count = **164** (163 + 1).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/standings_row.gd scripts/data/standings_row.gd.uid tests/unit/test_standings_row.gd
git commit -m "7b-2a task 1: StandingsRow (league record + NRR)"
```

---

### Task 2: `LeagueResolver.round_robin` — the fixture list

**Files:**
- Create: `scripts/domain/league_resolver.gd`
- Test: `tests/unit/test_league_resolver.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_league_resolver.gd`:

```gdscript
extends GutTest

func test_round_robin_count_and_coverage() -> void:
	var fixtures := LeagueResolver.round_robin(8)
	assert_eq(fixtures.size(), 28, "8 teams single round-robin -> 28 fixtures")
	# No self-pairs; no duplicates; each team appears in exactly 7.
	var seen := {}
	var appearances := {}
	for fx in fixtures:
		assert_lt(fx.x, fx.y, "pairs are ordered i < j (no self-pairs)")
		var key := "%d-%d" % [fx.x, fx.y]
		assert_false(seen.has(key), "no duplicate fixture %s" % key)
		seen[key] = true
		appearances[fx.x] = appearances.get(fx.x, 0) + 1
		appearances[fx.y] = appearances.get(fx.y, 0) + 1
	for team in range(8):
		assert_eq(appearances.get(team, 0), 7, "team %d plays 7 games" % team)
```

- [ ] **Step 2: Run the suite to verify RED**

Run the whole-suite command. Expected: `Parse Error: Identifier "LeagueResolver" not declared`; count stays 164.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/domain/league_resolver.gd`:

```gdscript
class_name LeagueResolver
extends RefCounted

# Resolves a Season's league phase: an 8-team single round-robin, every game
# simulated, into a points+NRR table. See spec
# 2026-06-07-season-league-7b2a-design.md and ADR 0002/0004/0009. No member state.

const NUM_TEAMS := 8
const PLAYOFF_CUTOFF := 4

# Every unique unordered pair (i, j) with i < j. 8 teams -> 28 fixtures.
static func round_robin(num_teams: int) -> Array:
	var fixtures: Array = []
	for i in range(num_teams):
		for j in range(i + 1, num_teams):
			fixtures.append(Vector2i(i, j))
	return fixtures
```

- [ ] **Step 4: Re-import and run the suite to verify GREEN**

Run `--import`, then the whole-suite command. Expected: `All tests passed`, count = **165** (164 + 1).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/league_resolver.gd scripts/domain/league_resolver.gd.uid tests/unit/test_league_resolver.gd
git commit -m "7b-2a task 2: LeagueResolver.round_robin (single round-robin fixtures)"
```

---

### Task 3: `simulate_league` + `LeagueResult`

**Files:**
- Create: `scripts/data/league_result.gd`
- Modify: `scripts/domain/league_resolver.gd` (add `simulate_league`)
- Test: `tests/unit/test_league_resolver.gd` (append)

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_league_resolver.gd`:

```gdscript
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

# 7 opponents spanning the star range (mid field).
func _field() -> Array:
	return [_team(1.0), _team(1.5), _team(2.0), _team(2.5), _team(3.0), _team(3.5), _team(4.0)]

func test_league_deterministic() -> void:
	var r1 := LeagueResolver.simulate_league(_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(2024))
	var r2 := LeagueResolver.simulate_league(_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(2024))
	assert_eq(r1.player_position, r2.player_position, "position deterministic")
	assert_eq(r1.made_playoffs, r2.made_playoffs, "qualification deterministic")
	assert_eq(r1.standings[0].team_index, r2.standings[0].team_index, "table order deterministic")
	assert_eq(r1.standings[0].points, r2.standings[0].points, "top points deterministic")

func test_league_structural_integrity() -> void:
	var r := LeagueResolver.simulate_league(_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(7))
	assert_eq(r.standings.size(), 8, "8 standings rows")
	var total_points := 0
	for row in r.standings:
		assert_eq(row.played, 7, "team %d played 7" % row.team_index)
		total_points += row.points
	assert_eq(total_points, 56, "2 points distributed per game x 28 games = 56")
	assert_between(r.player_position, 1, 8, "player position in 1..8")
	assert_eq(r.made_playoffs, r.player_position <= 4, "made_playoffs == top 4")
	assert_eq(r.player_matches.size(), 7, "player played 7 games")

func test_league_table_is_sorted() -> void:
	var r := LeagueResolver.simulate_league(_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(99))
	for k in range(r.standings.size() - 1):
		var a: StandingsRow = r.standings[k]
		var b: StandingsRow = r.standings[k + 1]
		var ok := a.points > b.points or (a.points == b.points and a.nrr() >= b.nrr() - 1e-6)
		assert_true(ok, "row %d ranks >= row %d (points then NRR)" % [k, k + 1])

func test_league_directional_strong_player_finishes_higher() -> void:
	var strong_qualified := 0
	var weak_qualified := 0
	var strong_pos_sum := 0
	var weak_pos_sum := 0
	var n := 30
	for sv in range(1, n + 1):
		var rs := LeagueResolver.simulate_league(_attrs(), _team(5.0), _field(), _tour(), tuning, itun, _rng(sv))
		var rw := LeagueResolver.simulate_league(_attrs(), _team(0.5), _field(), _tour(), tuning, itun, _rng(sv))
		if rs.made_playoffs:
			strong_qualified += 1
		if rw.made_playoffs:
			weak_qualified += 1
		strong_pos_sum += rs.player_position
		weak_pos_sum += rw.player_position
	assert_gt(strong_qualified, weak_qualified, "5.0-star qualifies more often than 0.5-star")
	assert_lt(strong_pos_sum, weak_pos_sum, "5.0-star finishes higher on average (lower position number)")
```

- [ ] **Step 2: Run the suite to verify RED**

Run the whole-suite command. Expected: `Parse Error: Identifier "LeagueResult" not declared` (and/or `simulate_league` not found) → `test_league_resolver.gd` skipped, count drops to **164** (its 1 passing round_robin test goes away with the file).

- [ ] **Step 3: Write `LeagueResult`**

Create `scripts/data/league_result.gd`:

```gdscript
class_name LeagueResult
extends RefCounted

# Outcome of a Season's league phase. standings is ranked best -> worst. See
# spec 2026-06-07-season-league-7b2a-design.md §7.

var standings: Array = []        # Array[StandingsRow], ranked
var player_position: int = 0     # 1..8 (the Player team, index 0, after ranking)
var made_playoffs: bool = false  # player_position <= 4
var player_matches: Array = []   # Array[MatchResult] for the Player team's 7 games
```

- [ ] **Step 4: Add `simulate_league` to `LeagueResolver`**

In `scripts/domain/league_resolver.gd`, add after `round_robin`:

```gdscript
# Simulate the full league phase. teams = [player_team] + opponents (index 0 is
# the Player). Each team's strength is drawn ONCE (held all Season, ADR 0009);
# every game is simulated (Player games statted, others via simulate_match(null)).
# Deterministic given rng. See spec §4-§8.
static func simulate_league(
		player_attrs: Attributes,
		player_team: Team,
		opponents: Array,
		tour: TourDistribution,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator,
		player_intent_plan: IntentPlan = null,
		player_bowling_plan: BowlingPlan = null
) -> LeagueResult:
	var teams: Array = [player_team]
	teams.append_array(opponents)
	var n := teams.size()

	# Per-Season strength draw, held all Season (fixed team order).
	var bat: Array = []
	var bowl: Array = []
	for t in teams:
		bat.append(t.batting_strength(tour, rng))
		bowl.append(t.bowling_strength(tour, rng))

	var rows: Array = []
	for idx in range(n):
		var row := StandingsRow.new()
		row.team_index = idx
		rows.append(row)

	var player_matches: Array = []

	for fx in round_robin(n):
		var i: int = fx.x
		var j: int = fx.y
		var i_bats_first := MatchResolver._resolve_toss(rng)
		var p_attrs: Attributes = player_attrs if i == 0 else null
		var ip: IntentPlan = player_intent_plan if i == 0 else null
		var bp: BowlingPlan = player_bowling_plan if i == 0 else null
		var m := MatchResolver.simulate_match(
			p_attrs,
			bat[i], bowl[i], bowl[i],
			bat[j], bowl[j], bowl[j],
			i_bats_first, tuning, itun, rng, ip, bp)

		# Attribute innings (innings1 = first-batting side).
		var i_inns: InningsResult = m.innings1 if i_bats_first else m.innings2
		var j_inns: InningsResult = m.innings2 if i_bats_first else m.innings1
		var ri: StandingsRow = rows[i]
		var rj: StandingsRow = rows[j]
		ri.played += 1
		rj.played += 1
		ri.runs_for += i_inns.total
		ri.balls_for += i_inns.balls
		ri.runs_against += j_inns.total
		ri.balls_against += j_inns.balls
		rj.runs_for += j_inns.total
		rj.balls_for += j_inns.balls
		rj.runs_against += i_inns.total
		rj.balls_against += i_inns.balls

		match m.outcome:
			MatchResult.Outcome.PLAYER_WIN:
				ri.points += 2
			MatchResult.Outcome.OPPONENT_WIN:
				rj.points += 2
			MatchResult.Outcome.TIE:
				ri.points += 1
				rj.points += 1

		if i == 0:
			player_matches.append(m)

	# Rank: points desc, then NRR desc, then team_index asc.
	var cmp := func(a: StandingsRow, b: StandingsRow) -> bool:
		if a.points != b.points:
			return a.points > b.points
		var na := a.nrr()
		var nb := b.nrr()
		if not is_equal_approx(na, nb):
			return na > nb
		return a.team_index < b.team_index
	rows.sort_custom(cmp)

	var result := LeagueResult.new()
	result.standings = rows
	result.player_matches = player_matches
	for pos in range(rows.size()):
		if rows[pos].team_index == 0:
			result.player_position = pos + 1
			break
	result.made_playoffs = result.player_position <= PLAYOFF_CUTOFF
	return result
```

- [ ] **Step 5: Re-import and run the suite to verify GREEN**

Run `--import`, then the whole-suite command. Expected: `All tests passed`, count = **169** (165 + 4 new — the round_robin test plus 4 simulate_league tests = 5 in the file, but +4 over the 165 baseline since round_robin's +1 was already counted in Task 2).

- [ ] **Step 6: Commit**

```bash
git add scripts/data/league_result.gd scripts/data/league_result.gd.uid scripts/domain/league_resolver.gd scripts/domain/league_resolver.gd.uid tests/unit/test_league_resolver.gd
git commit -m "7b-2a task 3: simulate_league + LeagueResult (full-sim table, player finish)"
```

---

### Task 4: Eyeball deliverable — playoff-qualification vs Player ★

**Files:**
- Create: `tools/league_preview.gd` (headless runner)
- Create: `docs/mockups/league-finish-v1.html` (chart with the runner's data inlined)

No unit tests — diagnostic. Its directional claim is asserted by Task 3's `test_league_directional_strong_player_finishes_higher`.

- [ ] **Step 1: Write the runner**

Create `tools/league_preview.gd`:

```gdscript
extends SceneTree

# Throwaway diagnostic: sweep the Player team's stars against a fixed 7-opponent
# field, run N seeded Seasons (league phase) per star, and print CSV:
#   player_stars,seasons,made_playoffs_rate,avg_finish
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/league_preview.gd

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

	var field := [_team(1.0), _team(1.5), _team(2.0), _team(2.5), _team(3.0), _team(3.5), _team(4.0)]
	var player_stars := [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
	var n := 80
	print("player_stars,seasons,made_playoffs_rate,avg_finish")
	for ps in player_stars:
		var qualified := 0
		var pos_sum := 0
		for sv in range(1, n + 1):
			var r := LeagueResolver.simulate_league(player, _team(ps), field, tour, tuning, itun, _rng(sv + int(ps * 1000)))
			if r.made_playoffs:
				qualified += 1
			pos_sum += r.player_position
		print("%.1f,%d,%.4f,%.3f" % [ps, n, float(qualified) / float(n), float(pos_sum) / float(n)])
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
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/league_preview.gd`
Expected: a `player_stars,seasons,made_playoffs_rate,avg_finish` header + 10 rows. `made_playoffs_rate` should rise with stars (low at 0.5★, high at 5.0★); `avg_finish` should fall (toward 1) as stars rise. Keep the rows for Step 3.

- [ ] **Step 3: Write the chart with the data inlined**

Create `docs/mockups/league-finish-v1.html` — a self-contained page (no external libs; inline `<canvas>`) plotting **playoff-qualification rate % (left Y) vs Player team ★ (X)**, plus the **average finishing position** as a second line (right Y, 1 at top → 8 at bottom). Paste the captured rows into a `const DATA = [...]`. Caption: "Real Godot sim — Player team ★ vs playoff qualification (top 4) and average league finish over N Seasons, against a fixed 1.0–4.0★ field (7b-2a)." Mark the 4th-place playoff cut line.

- [ ] **Step 4: Eyeball in a browser**

Serve and open `docs/mockups/league-finish-v1.html` (reuse `.claude/launch.json`'s `mockups` server). Confirm qualification rises with ★ and average finish improves (line drops toward 1). Manual check — the rung's "learn by seeing" gate.

- [ ] **Step 5: Commit**

```bash
git add tools/league_preview.gd docs/mockups/league-finish-v1.html
# add tools/league_preview.gd.uid only if git status shows it was generated
git commit -m "7b-2a task 4: league-finish-vs-star runner + chart"
```

---

## Self-review notes

- **Spec coverage:** §3 round_robin → Task 2; §4 per-Season draw + §5 play games + §6 standings/NRR + §8 simulate_league → Task 3; §6 StandingsRow/NRR → Task 1; §7 LeagueResult → Task 3; §10 eyeball → Task 4; §9 backward-compat/determinism → Task 3 `test_league_deterministic` + additive design (no existing-file edits). §11 tests 1–6 map: test 1 → Task 2; test 2 → Task 1; tests 3–6 → Task 3.
- **Type consistency:** `StandingsRow` fields (`team_index`, `played`, `points`, `runs_for/against`, `balls_for/against`, `nrr()`), `LeagueResult` fields (`standings`, `player_position`, `made_playoffs`, `player_matches`), `LeagueResolver.round_robin`/`simulate_league` signatures match spec §3/§6/§7/§8 exactly. `MatchResolver._resolve_toss` and `MatchResolver.simulate_match` reused with the 7b-1/4b signatures. `MatchResult.Outcome.{PLAYER_WIN,OPPONENT_WIN,TIE}` and `InningsResult.total/balls` match existing definitions.
- **Counts:** baseline 163 → 164 (T1) → 165 (T2) → 169 (T3). T4 adds no tests.
- **No placeholders:** all code complete; commands exact.
- **GDScript notes:** multi-line lambda used for `sort_custom` (supported in 4.6). Ternaries (`x if cond else y`) used in `nrr()` and the player-slot guards. `MatchResolver._resolve_toss` is callable cross-class despite the leading underscore (GDScript has no enforced privacy).
</content>
