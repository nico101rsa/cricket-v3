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
