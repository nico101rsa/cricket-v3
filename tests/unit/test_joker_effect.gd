extends GutTest

func _batting_defensive_wicket() -> JokerEffect:
	# Dead Bat shape: batting, Defensive-only, wicket x0.92
	return JokerEffect.make("dead_bat", "Dead Bat", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.92,
		BallResolver.Intent.DEFENSIVE)

func test_make_sets_fields() -> void:
	var j := _batting_defensive_wicket()
	assert_eq(j.id, "dead_bat")
	assert_eq(j.side, JokerEffect.Side.BATTING)
	assert_eq(j.target, JokerEffect.Target.WICKET)
	assert_almost_eq(j.mult, 0.92, 0.0001)

func test_side_gate() -> void:
	var j := _batting_defensive_wicket()
	# batting joker inert when the owner is bowling
	assert_false(j.matches(false, BallResolver.Intent.DEFENSIVE, 1))
	assert_true(j.matches(true, BallResolver.Intent.DEFENSIVE, 1))

func test_intent_gate() -> void:
	var j := _batting_defensive_wicket()
	assert_false(j.matches(true, BallResolver.Intent.BALANCED, 1), "wrong intent -> off")
	assert_true(j.matches(true, BallResolver.Intent.DEFENSIVE, 1))

func test_ball_window_gate() -> void:
	# Block the Shine shape: any intent, balls 1..18
	var j := JokerEffect.make("bts", "Block the Shine", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.90, -1, 1, 18)
	assert_true(j.matches(true, BallResolver.Intent.BALANCED, 18))
	assert_false(j.matches(true, BallResolver.Intent.BALANCED, 19), "past window -> off")

func test_intent_any_when_req_negative() -> void:
	var j := JokerEffect.make("any", "Any", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.1, -1)
	assert_true(j.matches(true, BallResolver.Intent.DEFENSIVE, 1))
	assert_true(j.matches(true, BallResolver.Intent.AGGRESSIVE, 1))

func _bowling_catching_wicket() -> JokerEffect:
	# Cordon Killer shape: bowling, field = Catching, wicket x1.10
	return JokerEffect.make("cordon", "Cordon Killer", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.10,
		-1, 1, 120, FieldPlan.Mode.CATCHING)

func test_field_gate() -> void:
	var j := _bowling_catching_wicket()
	# fires only when the field matches (and the owner is bowling)
	assert_true(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.CATCHING))
	assert_false(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.DEFENSIVE), "wrong field -> off")
	assert_false(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL), "no field -> off")

func test_field_any_when_req_negative() -> void:
	# A field-agnostic joker (field_req default -1) ignores the field entirely.
	var j := _batting_defensive_wicket()
	assert_true(j.matches(true, BallResolver.Intent.DEFENSIVE, 1, FieldPlan.Mode.CATCHING))
	assert_true(j.matches(true, BallResolver.Intent.DEFENSIVE, 1, FieldPlan.Mode.NEUTRAL))

func test_field_combines_with_side() -> void:
	# Catching-field bowling joker is inert while the owner is batting, even with the field set.
	var j := _bowling_catching_wicket()
	assert_false(j.matches(true, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.CATCHING), "batting -> bowling joker off")
