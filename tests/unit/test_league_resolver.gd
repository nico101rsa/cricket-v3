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

var tuning: BallTuning
var itun: InningsTuning

func before_each() -> void:
	tuning = BallTuning.new()
	itun = InningsTuning.new()

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 31.25
	a.composure = 31.25
	a.attack = 31.25
	a.control = 31.25
	return a

func _tour() -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = 31.25
	t.spread = 9.375
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

func test_league_exposes_held_strengths() -> void:
	var r := LeagueResolver.simulate_league(_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(7))
	assert_eq(r.team_bat.size(), 8, "8 batting strengths exposed")
	assert_eq(r.team_bowl.size(), 8, "8 bowling strengths exposed")
	for v in r.team_bat:
		assert_gte(v, 1, "batting strength floored at 1")
	for v in r.team_bowl:
		assert_gte(v, 1, "bowling strength floored at 1")


# --- E3 (spec 2026-06-12-difficulty-ladder-7cE3-design.md): opponent brain ---

func _ladder_league(seed_v: int, spec: TourSpec) -> LeagueResult:
	var tour := spec.make_tour() if spec != null else _tour()
	return LeagueResolver.simulate_league(
		_attrs(), _team(3.0), _field(), tour, tuning, itun, _rng(seed_v),
		IntentPlan.textbook(), BowlingPlan.textbook(), spec)

func test_league_with_brain_is_deterministic() -> void:
	var a := _ladder_league(31, DifficultyLadder.spec_for(2, 7))
	var b := _ladder_league(31, DifficultyLadder.spec_for(2, 7))
	assert_eq(a.player_position, b.player_position)
	for k in range(8):
		assert_eq(a.standings[k].points, b.standings[k].points)
		assert_eq(a.standings[k].team_index, b.standings[k].team_index)

func test_league_null_spec_matches_omitted_param() -> void:
	var a := _ladder_league(47, null)
	var b := LeagueResolver.simulate_league(
		_attrs(), _team(3.0), _field(), _tour(), tuning, itun, _rng(47),
		IntentPlan.textbook(), BowlingPlan.textbook())
	assert_eq(a.player_position, b.player_position)
	for k in range(8):
		assert_eq(a.standings[k].points, b.standings[k].points)

func test_smarter_brain_wins_more_player_games() -> void:
	# Same tour strength, only the brain differs: an adaptive-eq opponent should
	# take more games off the Player than a naive one (seed-summed, 20 leagues
	# x 7 player games per arm; the measured ladder gap is ~24 pts).
	var naive_spec := DifficultyLadder.spec_for(1, 2)
	naive_spec.brain_tier = TourSpec.Tier.NAIVE
	naive_spec.blend = 1.0
	var smart_spec := DifficultyLadder.spec_for(1, 2)
	smart_spec.brain_tier = TourSpec.Tier.ADAPTIVE
	smart_spec.blend = 1.0
	var naive_wins := 0
	var smart_wins := 0
	for s in range(20):
		for m in _ladder_league(100 + s, naive_spec).player_matches:
			if m.player_won():
				naive_wins += 1
		for m in _ladder_league(100 + s, smart_spec).player_matches:
			if m.player_won():
				smart_wins += 1
	assert_lt(smart_wins, naive_wins, "adaptive opponent must beat the Player more often than naive")

func test_league_fixtures_run_roster_path() -> void:
	# Career-fidelity CF1: the standard XI's archetype plateau (6 equal BATTER
	# cards, the all-rounder, then 4 equal BOWLER cards) must show in a league
	# match's batting cards — the old clone path decayed every position instead.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var team := Team.new()
	team.stars = 3.0
	var opps: Array = []
	for k in range(7):
		var t := Team.new()
		t.stars = 3.0
		opps.append(t)
	var league := LeagueResolver.simulate_league(null, team, opps,
		TourDistribution.new(), BallTuning.new(), InningsTuning.new(), rng)
	var m: MatchResult = league.player_matches[0]
	var our_inn: InningsResult = m.innings1 if m.player_bats_first else m.innings2
	var b: Array = our_inn.batters
	assert_eq(b.size(), 11)
	assert_almost_eq(float(b[0]["power"]), float(b[5]["power"]), 0.0001, "top-6 BATTER plateau")
	assert_almost_eq(float(b[7]["power"]), float(b[10]["power"]), 0.0001, "BOWLER tail plateau")
	assert_gt(float(b[0]["power"]), float(b[7]["power"]), "openers above tail")
