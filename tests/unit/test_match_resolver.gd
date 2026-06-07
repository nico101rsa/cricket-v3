extends GutTest

func _innings(total: int, wkts: int, balls: int) -> InningsResult:
	return InningsResult.new(total, wkts, balls, [], [])

func test_decide_win_by_runs() -> void:
	# Player bats first (innings1), defends 150 vs 140 -> Player wins by 10 runs.
	var r := MatchResolver._decide_result(_innings(150, 8, 120), _innings(140, 9, 120), true, 120)
	assert_eq(r.outcome, MatchResult.Outcome.PLAYER_WIN, "first-batting Player defends -> player win")
	assert_eq(r.margin_runs, 10, "won by total1 - total2 runs")
	assert_eq(r.margin_wickets, 0, "no wickets margin on a runs win")

func test_decide_win_by_wickets() -> void:
	# Player bats second (innings2), chases 141 with 4 down in 112 balls -> wins by 6, 8 left.
	var r := MatchResolver._decide_result(_innings(140, 10, 120), _innings(141, 4, 112), false, 120)
	assert_eq(r.outcome, MatchResult.Outcome.PLAYER_WIN, "chasing Player passes target -> player win")
	assert_eq(r.margin_wickets, 6, "won by 10 - wkts2 wickets")
	assert_eq(r.balls_remaining, 8, "balls_remaining = max_balls - balls2")
	assert_eq(r.margin_runs, 0, "no runs margin on a wickets win")

func test_decide_tie() -> void:
	var r := MatchResolver._decide_result(_innings(150, 7, 120), _innings(150, 10, 120), true, 120)
	assert_eq(r.outcome, MatchResult.Outcome.TIE, "equal totals -> tie")
	assert_true(r.is_tie(), "is_tie convenience true")

func test_decide_perspective_opponent_win() -> void:
	# Player bats second; opposition batted first (innings1) and defends 150 vs 140
	# -> the first-batting side is the OPPONENT, so it's an opponent win.
	var r := MatchResolver._decide_result(_innings(150, 8, 120), _innings(140, 9, 120), false, 120)
	assert_eq(r.outcome, MatchResult.Outcome.OPPONENT_WIN, "opponent defended first -> opponent win")
	assert_eq(r.margin_runs, 10, "margin still 10 runs (perspective only changes the winner)")

var tuning: BallTuning
var itun: InningsTuning

func before_each() -> void:
	tuning = BallTuning.new()
	itun = InningsTuning.new()

func _attrs(power: int, comp: int, attack: int, control: int) -> Attributes:
	var a := Attributes.new()
	a.power = power
	a.composure = comp
	a.attack = attack
	a.control = control
	return a

func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

# Even contest: Player 5/5/5/5, both teams strength 5, bowling 5/5.
func _even_match(player_bats_first: bool, seed_value: int) -> MatchResult:
	return MatchResolver.simulate_match(
		_attrs(5, 5, 5, 5), 5, 5, 5,   # Player's team: bat + bowling pair
		5, 5, 5,                       # opposition: bat + bowling pair
		player_bats_first, tuning, itun, _make_rng(seed_value))

func test_same_seed_deterministic() -> void:
	var r1 := _even_match(true, 2024)
	var r2 := _even_match(true, 2024)
	assert_eq(r1.outcome, r2.outcome, "outcome deterministic")
	assert_eq(r1.innings1.total, r2.innings1.total, "innings1 total deterministic")
	assert_eq(r1.innings2.total, r2.innings2.total, "innings2 total deterministic")
	assert_eq(r1.margin_runs, r2.margin_runs, "margin deterministic")
	assert_eq(r1.margin_wickets, r2.margin_wickets, "wkts margin deterministic")

func test_player_bats_first_places_player_in_innings1() -> void:
	var r := _even_match(true, 11)
	assert_false(r.innings1.player_line().is_empty(), "Player features in innings1 when batting first")
	assert_true(r.innings2.player_line().is_empty(), "opposition (innings2) has no statted Player")

func test_player_bats_second_places_player_in_innings2() -> void:
	var r := _even_match(false, 11)
	assert_true(r.innings1.player_line().is_empty(), "opposition (innings1) has no statted Player")
	assert_false(r.innings2.player_line().is_empty(), "Player features in innings2 when batting second")

func test_outcome_always_valid_and_consistent() -> void:
	for sv in range(1, 40):
		var r := _even_match(sv % 2 == 0, sv)
		assert_true(
			r.outcome == MatchResult.Outcome.PLAYER_WIN
			or r.outcome == MatchResult.Outcome.OPPONENT_WIN
			or r.outcome == MatchResult.Outcome.TIE,
			"outcome is one of the three (seed %d)" % sv)
		if r.outcome == MatchResult.Outcome.TIE:
			assert_eq(r.innings1.total, r.innings2.total, "tie <-> equal totals (seed %d)" % sv)
		elif r.margin_runs > 0:
			assert_eq(r.margin_wickets, 0, "runs win has no wkts margin (seed %d)" % sv)
		else:
			assert_gt(r.margin_wickets, 0, "non-runs, non-tie win is by wickets (seed %d)" % sv)

func test_even_contest_roughly_balanced() -> void:
	# Alternate the toss per seed to neutralise any first/second positional bias,
	# then assert the Player's win share sits in a loose band (not flaky 50/50).
	var player_wins := 0
	var decided := 0
	for sv in range(1, 81):
		var r := _even_match(sv % 2 == 0, sv)
		if r.is_tie():
			continue
		decided += 1
		if r.player_won():
			player_wins += 1
	var share := float(player_wins) / float(decided)
	assert_between(share, 0.3, 0.7, "even contest -> roughly balanced win share (got %f over %d decided)" % [share, decided])

func test_plan_routes_to_player_innings_when_batting_first() -> void:
	# Player bats first => innings1 is the Player's, resolved from the seed's
	# initial RNG state, so it must match a standalone Player innings with the
	# same plan and seed.
	var a := _attrs(5, 5, 5, 5)
	var plan := IntentPlan.textbook()
	var m := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(123), plan)
	var standalone := InningsResolver.simulate_innings(
		a, 5, 5, 5, tuning, itun, _make_rng(123), 0, plan)
	assert_eq(m.innings1.total, standalone.total, "Player innings used the supplied plan")
	assert_eq(m.innings1.wickets, standalone.wickets, "Player innings wickets match plan run")

func test_opposition_stays_balanced_not_player_plan() -> void:
	# Player bats second => innings1 is the opposition, resolved from the seed's
	# initial RNG state. It must match a standalone opposition innings on a
	# BALANCED (null) plan, proving the Player's plan did NOT leak to it.
	var a := _attrs(5, 5, 5, 5)
	var m := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, false, tuning, itun, _make_rng(123), IntentPlan.textbook())
	var opp_balanced := InningsResolver.simulate_innings(
		null, 5, 5, 5, tuning, itun, _make_rng(123), 0, null)
	assert_eq(m.innings1.total, opp_balanced.total, "opposition innings ignored the Player plan")
	assert_eq(m.innings1.wickets, opp_balanced.wickets, "opposition stayed balanced")

func test_match_deterministic_with_plan() -> void:
	var a := _attrs(5, 5, 5, 5)
	var r1 := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(55), IntentPlan.textbook())
	var r2 := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(55), IntentPlan.textbook())
	assert_eq(r1.outcome, r2.outcome, "same seed + plan -> same outcome")
	assert_eq(r1.innings1.total, r2.innings1.total, "innings1 deterministic with plan")
	assert_eq(r1.innings2.total, r2.innings2.total, "innings2 deterministic with plan")

func test_null_bowling_plan_matches_rung4a_baseline() -> void:
	# No player_bowling_plan => no rotation either side => identical to rung 4a.
	var a := _attrs(5, 5, 5, 5)
	var base := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(7))
	var explicit := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(7), null, null)
	assert_eq(base.innings1.total, explicit.innings1.total, "innings1 unchanged")
	assert_eq(base.innings2.total, explicit.innings2.total, "innings2 unchanged")
	assert_eq(base.outcome, explicit.outcome, "outcome unchanged")

func test_player_bowling_plan_routes_to_player_team_bowling() -> void:
	# Player bats SECOND => innings1 is the opposition batting against the
	# Player's team bowling, resolved from the seed's initial RNG state. It must
	# equal a standalone opposition innings facing the Player's team BowlingAttack
	# + the supplied plan at the same seed.
	var a := _attrs(5, 5, 5, 5)
	var plan := BowlingPlan.spin_only()
	var m := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, false, tuning, itun, _make_rng(123), null, plan)
	var player_team_bowl := BowlingAttack.new(5, 5)  # from player_team_attack/control
	var standalone := InningsResolver.simulate_innings(
		null, 5, 5, 5, tuning, itun, _make_rng(123), 0, null, player_team_bowl, plan)
	assert_eq(m.innings1.total, standalone.total, "Player team bowling used the plan")
	assert_eq(m.innings1.wickets, standalone.wickets, "opposition wickets match plan run")

func test_match_deterministic_with_bowling_plan() -> void:
	var a := _attrs(5, 5, 5, 5)
	var r1 := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(55), null, BowlingPlan.textbook())
	var r2 := MatchResolver.simulate_match(
		a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(55), null, BowlingPlan.textbook())
	assert_eq(r1.outcome, r2.outcome, "same seed + plan -> same outcome")
	assert_eq(r1.innings1.total, r2.innings1.total, "innings1 deterministic")
	assert_eq(r1.innings2.total, r2.innings2.total, "innings2 deterministic")
