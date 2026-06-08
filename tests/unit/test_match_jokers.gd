extends GutTest

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	return a

func _tour() -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = 5; t.spread = 1.5; t.noise = 1
	return t

func _team() -> Team:
	var t := Team.new()
	t.stars = 3.0
	return t

func _seeded(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s
	return r

func _player_wins(rng_seed: int, jokers: Array) -> bool:
	var m := MatchResolver.simulate_match_teams(
		_attrs(), _team(), _team(), _tour(), BallTuning.new(), InningsTuning.new(),
		_seeded(rng_seed), null, null, jokers)
	return m.outcome == MatchResult.Outcome.PLAYER_WIN

func test_synthetic_batting_buff_raises_win_rate() -> void:
	var buff := [JokerEffect.make("b", "B", "Common", JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.7)]
	var base_wins := 0; var buff_wins := 0
	for i in range(300):
		if _player_wins(i, []):
			base_wins += 1
		if _player_wins(i, buff):
			buff_wins += 1
	assert_gt(buff_wins, base_wins, "a batting wicket-reducer should raise player win-rate")

func test_death_over_bowling_joker_raises_win_rate() -> void:
	# Death-Over Stranglehold from the catalog (intent-agnostic, ball >= 90, runs x0.80).
	var dos := [JokerEffect.make("dos", "Death-Over Stranglehold", "Rare",
		JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.80, -1, 90, 120)]
	var base_wins := 0; var buff_wins := 0
	for i in range(300):
		if _player_wins(i, []):
			base_wins += 1
		if _player_wins(i, dos):
			buff_wins += 1
	assert_gt(buff_wins, base_wins, "a death-over run-suppressor should raise player win-rate")

func test_determinism_with_jokers() -> void:
	var jk := [JokerEffect.make("b", "B", "Common", JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.7)]
	var a := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(7), null, null, jk)
	var b := MatchResolver.simulate_match_teams(_attrs(), _team(), _team(), _tour(),
		BallTuning.new(), InningsTuning.new(), _seeded(7), null, null, jk)
	assert_eq(a.outcome, b.outcome)
	assert_eq(a.innings1.total, b.innings1.total)
	assert_eq(a.innings2.total, b.innings2.total)
