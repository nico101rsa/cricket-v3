extends GutTest

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
