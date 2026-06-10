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

func _wins_with_itun(attrs: Attributes, it: InningsTuning, n: int) -> int:
	# Even team strength (all 5s), Player bats first fixed, only the build / tuning varies.
	var wins := 0
	for seed_value in range(1, n + 1):
		var m := MatchResolver.simulate_match(
			attrs, 5, 5, 5, 5, 5, 5, true, tuning, it, _make_rng(seed_value))
		if m.outcome == MatchResult.Outcome.PLAYER_WIN:
			wins += 1
	return wins

func test_player_as_bowler_lifts_bowling_build_win_rate() -> void:
	# The headline this rung exists to make true: wiring the Player in as a bowler
	# makes a bowling build's Attack/Control bite. With the lever OFF (bowl_max_overs
	# = 0 -> the pre-rung behaviour, bowling inert) a bowling build wins fewer matches
	# than with it ON. This test FAILED before the rung (lever had no effect).
	var off := InningsTuning.new()
	off.bowl_max_overs = 0
	var bowler := _attrs(2, 2, 8, 8)
	var wins_off := _wins_with_itun(bowler, off, 120)
	var wins_on := _wins_with_itun(bowler, itun, 120)
	assert_gt(wins_on, wins_off, "Player-as-bowler lifts a bowling build's win-rate vs the inert baseline")

func test_match_deterministic_with_player_bowler() -> void:
	var a := _attrs(2, 2, 8, 8)
	var m1 := MatchResolver.simulate_match(a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(31))
	var m2 := MatchResolver.simulate_match(a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(31))
	assert_eq(m1.outcome, m2.outcome, "deterministic outcome")
	assert_eq(m1.innings1.total, m2.innings1.total, "deterministic innings1")
	assert_eq(m1.innings2.total, m2.innings2.total, "deterministic innings2")

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
	# The Player (5/5/5/5) bowls a 4-over quota at raw 5/5, overriding the spin plan on
	# those overs (Player-as-bowler; the all-rounder bowls its full quota since the
	# 2026-06-09 overs-curve change). The baseline must mirror that.
	var standalone := InningsResolver.simulate_innings(
		null, 5, 5, 5, tuning, itun, _make_rng(123), 0, null, player_team_bowl, plan, 5, 5, 4)
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

# --- Slice 2: real-roster assembly through simulate_match_teams ----------------

func test_teams_player_innings_uses_real_batting_card() -> void:
	var p := _attrs(5, 5, 5, 5)
	var m := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(2024))
	var inn := m.innings1 if not m.innings1.player_line().is_empty() else m.innings2
	var card: Array = inn.batters
	assert_eq(card.size(), 11, "a full XI")
	# Distinguisher: a real standard XI has a FLAT top order (slots 1..6 all BATTERs,
	# equal power) then steps down to the all-rounder (7) and bowler tail (8..11).
	# The old clone path instead decays smoothly via partner_factor, so slot 6 < slot 1.
	assert_eq(card[0]["power"], card[5]["power"], "real roster: flat top order (slots 1 & 6 equal)")
	assert_gt(card[5]["power"], card[6]["power"], "steps down from batters to the all-rounder")
	assert_gt(card[6]["power"], card[10]["power"], "all-rounder above the bowler tail")

func test_teams_determinism_with_roster() -> void:
	var p := _attrs(5, 5, 5, 5)
	var r1 := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(2024))
	var r2 := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(2024))
	assert_eq(r1.innings1.total, r2.innings1.total, "still deterministic (innings1)")
	assert_eq(r1.innings2.total, r2.innings2.total, "still deterministic (innings2)")
	assert_eq(r1.outcome, r2.outcome, "still deterministic (outcome)")

# --- Slice 3: bowling budget conservation (D12) -------------------------------

func test_conserved_bowling_no_overs_returns_scalar() -> void:
	assert_almost_eq(MatchResolver._conserved_bowling(5, 0, 8, 20), 5.0, 0.0001, "n=0 -> unchanged team scalar")

func test_conserved_bowling_neutral_player_unchanged() -> void:
	# All-rounder bowls at attack 5 == team scalar -> teammates unchanged.
	assert_almost_eq(MatchResolver._conserved_bowling(5, 2, 5, 20), 5.0, 0.0001, "player at team par -> no change")

func test_conserved_bowling_is_exact_not_rounded() -> void:
	# Strong bowler: 4 overs at attack 8, no concentration penalty -> exact 4.25, NOT rounded to 4.
	assert_almost_eq(MatchResolver._conserved_bowling(5, 4, 8, 20), 4.25, 0.0001, "(20*5 - 4*8)/16 = 4.25 exactly")

func test_conserved_bowling_weak_player_compensated_above_scalar() -> void:
	# Weak part-timer: 1 over at attack 3 -> teammates bowl ABOVE 5 to hold the total. This is
	# the case the old integer round() under-compensated (dragging the team below par).
	var c := MatchResolver._conserved_bowling(5, 1, 3, 20)
	assert_gt(c, 5.0, "a weak player's overs are compensated by stronger teammates (> scalar)")

func test_conserved_bowling_identity_holds_exactly() -> void:
	# The whole point: total team bowling = over_limit * scalar, for any n/player_stat (k=0).
	for case in [[5, 1, 3], [5, 4, 8], [6, 2, 4], [4, 3, 7]]:
		var s: int = case[0]; var n: int = case[1]; var stat: int = case[2]
		var c := MatchResolver._conserved_bowling(s, n, stat, 20)
		assert_almost_eq(n * stat + (20 - n) * c, float(20 * s), 0.0001,
			"team total bowling == over_limit*scalar for n=%d stat=%d" % [n, stat])

func test_conserved_bowling_floored_at_1() -> void:
	assert_almost_eq(MatchResolver._conserved_bowling(1, 4, 8, 20), 1.0, 0.0001, "result floored at 1.0")

# --- Scenario-sweep rung: toss-force seam -------------------------------------

func test_force_bats_first_overrides_toss() -> void:
	# force = 1 -> Player bats first; force = 0 -> Player bats second, every seed.
	var p := _attrs(5, 5, 5, 5)
	for sv in [1, 2, 3, 7, 99]:
		var m1 := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(sv),
			null, null, [], null, null, null, null, null, null, null, null, 1)
		assert_true(m1.player_bats_first, "force=1 -> Player bats first (seed %d)" % sv)
		var m0 := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(sv),
			null, null, [], null, null, null, null, null, null, null, null, 0)
		assert_false(m0.player_bats_first, "force=0 -> Player bats second (seed %d)" % sv)

func test_force_default_is_byte_identical_to_toss() -> void:
	# Omitting the param and passing -1 must produce the identical match -- the
	# override must not perturb the RNG stream when not forcing.
	var p := _attrs(5, 5, 5, 5)
	var ma := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(42))
	var mb := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(42),
		null, null, [], null, null, null, null, null, null, null, null, -1)
	assert_eq(ma.player_bats_first, mb.player_bats_first, "default == explicit -1: toss")
	assert_eq(ma.innings1.total, mb.innings1.total, "default == explicit -1: innings1 total")
	assert_eq(ma.innings2.total, mb.innings2.total, "default == explicit -1: innings2 total")
	assert_eq(ma.outcome, mb.outcome, "default == explicit -1: outcome")

func test_force_bats_second_makes_player_innings_a_chase() -> void:
	# The reason the seam exists: batting 2nd sets target > 0 (is_chase), which fires
	# The Chase Master. Here we just assert the Player's innings is innings2 when forced.
	var p := _attrs(5, 5, 5, 5)
	var m := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(5),
		null, null, [], null, null, null, null, null, null, null, null, 0)
	assert_true(m.innings1.player_line().is_empty(), "opposition bats first (innings1) when Player forced to bat 2nd")
	assert_false(m.innings2.player_line().is_empty(), "Player chases in innings2 when forced to bat 2nd")
