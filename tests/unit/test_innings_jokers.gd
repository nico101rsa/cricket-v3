extends GutTest

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	return a

func _strong_batting_reducer() -> Array:
	# Synthetic always-on batting wicket-reducer — a clean directional signal.
	return [JokerEffect.make("t", "T", "Common", JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.5)]

func test_empty_jokers_equals_baseline() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	for i in range(20):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		var base := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1)
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		var same := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, [], true)
		assert_eq(base.total, same.total)
		assert_eq(base.wickets, same.wickets)
		assert_eq(base.balls, same.balls)

func test_batting_wicket_reducer_lowers_wickets() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	var jk := _strong_batting_reducer()
	var base_w := 0; var buff_w := 0
	for i in range(200):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		base_w += InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1).wickets
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		buff_w += InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, true).wickets
	assert_lt(buff_w, base_w, "a batting wicket-reducer should lower total wickets")

func test_determinism_with_jokers() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var a := _attrs()
	var jk := _strong_batting_reducer()
	var r1 := RandomNumberGenerator.new(); r1.seed = 42
	var first := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, true)
	var r2 := RandomNumberGenerator.new(); r2.seed = 42
	var second := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, true)
	assert_eq(first.total, second.total)
	assert_eq(first.wickets, second.wickets)
	assert_eq(first.balls, second.balls)
