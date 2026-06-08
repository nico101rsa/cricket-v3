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

func _catching_wicket_booster() -> Array:
	# Cordon-Killer shape: bowling, field = Catching, strong wicket boost (directional signal).
	return [JokerEffect.make("ck", "CK", "Common", JokerEffect.Side.BOWLING,
		JokerEffect.Target.WICKET, 2.0, -1, 1, 120, FieldPlan.Mode.CATCHING)]

func test_null_field_plan_equals_no_field() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var jk := _catching_wicket_booster()
	for i in range(20):
		# Owner bowling (player_is_batting=false); null field_plan -> field joker inert -> == no jokers.
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		var base := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1)
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		var same := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, false, null)
		assert_eq(base.wickets, same.wickets)
		assert_eq(base.total, same.total)

func test_catching_field_joker_raises_wickets() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var jk := _catching_wicket_booster()
	var neutral_w := 0; var catching_w := 0
	for i in range(200):
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		neutral_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, false, FieldPlan.neutral()).wickets
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		catching_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, false, FieldPlan.catching()).wickets
	assert_gt(catching_w, neutral_w, "a catching-field wicket booster should raise wickets when the field is catching")

func test_determinism_with_field_plan() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var jk := _catching_wicket_booster()
	var r1 := RandomNumberGenerator.new(); r1.seed = 9
	var first := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, false, FieldPlan.catching())
	var r2 := RandomNumberGenerator.new(); r2.seed = 9
	var second := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, false, FieldPlan.catching())
	assert_eq(first.total, second.total)
	assert_eq(first.wickets, second.wickets)
	assert_eq(first.balls, second.balls)

# --- C2b: bowling-captain intent ---

func _all_aggressive() -> IntentPlan:
	var p := IntentPlan.new()
	p.powerplay = BallResolver.Intent.AGGRESSIVE
	p.middle = BallResolver.Intent.AGGRESSIVE
	p.death = BallResolver.Intent.AGGRESSIVE
	return p

func _bowl_intent_wicket_booster() -> Array:
	# Attack-the-Stumps shape: bowling, gated on bowl_intent = Aggressive, strong wicket boost.
	return [JokerEffect.make("ats", "ATS", "Common", JokerEffect.Side.BOWLING,
		JokerEffect.Target.WICKET, 2.0, -1, 1, 120, -1, BallResolver.Intent.AGGRESSIVE)]

func test_bowl_intent_joker_raises_wickets() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var jk := _bowl_intent_wicket_booster()
	var bip := _all_aggressive()
	var off_w := 0; var on_w := 0
	for i in range(200):
		# No bowl_intent plan -> joker inert.
		var r1 := RandomNumberGenerator.new(); r1.seed = i
		off_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, false, null, null).wickets
		# Aggressive bowl_intent plan -> joker fires.
		var r2 := RandomNumberGenerator.new(); r2.seed = i
		on_w += InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, false, null, bip).wickets
	assert_gt(on_w, off_w, "an Aggressive-bowl-intent wicket booster should raise wickets when the captain is Aggressive")

func test_determinism_with_bowl_intent_plan() -> void:
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	var jk := _bowl_intent_wicket_booster()
	var bip := _all_aggressive()
	var r1 := RandomNumberGenerator.new(); r1.seed = 13
	var first := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r1, 0, null, null, null, 0, 0, 0, jk, false, null, bip)
	var r2 := RandomNumberGenerator.new(); r2.seed = 13
	var second := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, r2, 0, null, null, null, 0, 0, 0, jk, false, null, bip)
	assert_eq(first.total, second.total)
	assert_eq(first.wickets, second.wickets)
	assert_eq(first.balls, second.balls)
