extends GutTest

# Opt-in per-ball capture: a captured Player match carries both innings' ball-logs;
# default-off stays byte-identical (empty logs). Spec §6.

func _itun() -> InningsTuning:
	return InningsTuning.new()

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 40.0; a.composure = 30.0; a.attack = 25.0; a.control = 20.0
	return a

func test_match_result_logs_default_empty() -> void:
	var m := MatchResult.new()
	assert_eq(m.ball_log_innings1, [], "default innings1 log empty")
	assert_eq(m.ball_log_innings2, [], "default innings2 log empty")

func test_simulate_match_capture_fills_both_logs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bl1: Array = []
	var bl2: Array = []
	var m := MatchResolver.simulate_match(
		_attrs(), 31.25, 31.25, 31.25, 31.25, 31.25, 31.25,
		true, BallTuning.new(), _itun(), rng,
		null, null, [], null, null, null, null, null, null,
		[], [], 1.0, 1.0, null, null, null,
		bl1, bl2)  # ball_log_1, ball_log_2 = bound arrays we assert on
	# Both innings produced deliveries (each ball_log entry == one delivery).
	assert_gt(bl1.size(), 0, "innings1 ball-log filled")
	assert_eq(bl1.size(), m.innings1.balls, "innings1 log has one entry per delivery")
	assert_eq(bl2.size(), m.innings2.balls, "innings2 log has one entry per delivery")

func test_league_capture_true_attaches_logs_off_stays_empty() -> void:
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var rng_on := RandomNumberGenerator.new(); rng_on.seed = 7
	var league_on := LeagueResolver.simulate_league(
		_attrs(), team, career.opponents_of_current(),
		DifficultyLadder.spec_for(career.current_level(), 0).make_tour(),
		BallTuning.new(), _itun(), rng_on,
		null, null, null, [], Callable(), true)
	assert_gt(league_on.player_matches[0].ball_log_innings1.size(), 0, "captured innings1 log")
	assert_gt(league_on.player_matches[0].ball_log_innings2.size(), 0, "captured innings2 log")

	var rng_off := RandomNumberGenerator.new(); rng_off.seed = 7
	var league_off := LeagueResolver.simulate_league(
		_attrs(), team, career.opponents_of_current(),
		DifficultyLadder.spec_for(career.current_level(), 0).make_tour(),
		BallTuning.new(), _itun(), rng_off,
		null, null, null, [], Callable())  # capture defaults false
	assert_eq(league_off.player_matches[0].ball_log_innings1, [], "off → empty innings1 log")
	assert_eq(league_off.player_matches[0].ball_log_innings2, [], "off → empty innings2 log")
	# Same seed (7) → capture must not perturb the result vs capture-off.
	assert_eq(league_on.player_matches[0].innings1.total, league_off.player_matches[0].innings1.total, "capture must not change outcomes")
	assert_eq(league_on.player_matches[0].innings2.total, league_off.player_matches[0].innings2.total, "capture must not change outcomes")
