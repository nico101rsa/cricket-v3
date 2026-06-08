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

# --- C2b: bowling-captain intent + sets_field ---

func _attack_the_stumps() -> JokerEffect:
	# bowling, gated on the bowling-captain intent = Aggressive, wicket x1.12
	return JokerEffect.make("ats", "Attack the Stumps", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.12,
		-1, 1, 120, -1, BallResolver.Intent.AGGRESSIVE)

func test_bowl_intent_gate() -> void:
	var j := _attack_the_stumps()
	# fires only when the bowling captain intent (5th matches arg) is Aggressive
	assert_true(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL, BallResolver.Intent.AGGRESSIVE))
	assert_false(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL, BallResolver.Intent.DEFENSIVE), "wrong bowl_intent -> off")
	assert_false(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL, -1), "no bowl_intent set -> off")

func test_bowl_intent_any_when_req_negative() -> void:
	# A joker with no bowl_intent_req (default -1) ignores the bowling-captain intent.
	var j := _bowling_catching_wicket()
	assert_true(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.CATCHING, BallResolver.Intent.AGGRESSIVE))
	assert_true(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.CATCHING, -1))

func test_bowl_intent_default_arg_is_unset() -> void:
	# Old 5-arg callers (pre-C2b) get bowl_intent = -1, so bowl-intent jokers are off.
	var j := _attack_the_stumps()
	assert_false(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL), "omitted bowl_intent -> off")

func test_trigger_joker_never_matches_per_ball() -> void:
	# A windowed-trigger joker (trigger != NONE) is owned by JokerRuntime, so the
	# stateless matches() must always return false regardless of conditions.
	var j := JokerEffect.make("rtw", "Ride the Wave", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.20,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BAT, 3)
	assert_false(j.matches(true, BallResolver.Intent.BALANCED, 1), "trigger joker -> never per-ball")
	assert_false(j.matches(true, BallResolver.Intent.AGGRESSIVE, 5, FieldPlan.Mode.NEUTRAL, -1))

func test_bowler_type_gate() -> void:
	# The Trap shape: stateless, catching field AND current bowler = spin.
	var j := JokerEffect.make("trap", "The Trap", "Rare",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.25,
		-1, 1, 120, FieldPlan.Mode.CATCHING, -1, -1, JokerEffect.Trigger.NONE, 0,
		BowlingPlan.Kind.SPIN)
	# fires only with catching field + spin bowler (7th matches arg = bowler_type)
	assert_true(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.CATCHING, -1, BowlingPlan.Kind.SPIN))
	assert_false(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.CATCHING, -1, BowlingPlan.Kind.PACE), "pace -> off")
	assert_false(j.matches(false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.CATCHING, -1, -1), "no bowler type -> off")

func test_change_trigger_never_matches_per_ball() -> void:
	var j := JokerEffect.make("pp", "Pace Pack", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.15,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.CHANGE_PACE, 6)
	assert_false(j.matches(false, BallResolver.Intent.BALANCED, 1), "change trigger -> never per-ball")

func test_boost_role_never_matches_per_ball() -> void:
	var j := JokerEffect.make("pu", "Power Up", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.0,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.NONE, 0, -1, JokerEffect.BoostRole.EXTEND)
	assert_false(j.matches(true, BallResolver.Intent.BALANCED, 1), "boost joker -> never per-ball")

func test_drs_role_never_matches_per_ball() -> void:
	var j := JokerEffect.make("ch", "Cool Head", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.0,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.NONE, 0, -1,
		JokerEffect.BoostRole.NONE, JokerEffect.DRSRole.ACCURACY, 0.10)
	assert_false(j.matches(false, BallResolver.Intent.BALANCED, 1), "drs joker -> never per-ball")

func test_form_source_never_matches_per_ball() -> void:
	var j := JokerEffect.make("sa", "Sheet Anchor", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.0,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.NONE, 0, -1,
		JokerEffect.BoostRole.NONE, JokerEffect.DRSRole.NONE, 0.0, JokerEffect.FormSource.ON_BALANCED)
	assert_false(j.matches(true, BallResolver.Intent.BALANCED, 1), "form-source joker -> never per-ball")

func test_snaps_intent_never_matches_per_ball() -> void:
	var j := JokerEffect.make("bh", "Boundary Hunter", "Rare",
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.0,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.NONE, 0, -1,
		JokerEffect.BoostRole.NONE, JokerEffect.DRSRole.NONE, 0.0,
		JokerEffect.FormSource.NONE, BallResolver.Intent.AGGRESSIVE)
	assert_false(j.matches(true, BallResolver.Intent.AGGRESSIVE, 1), "snap joker -> never per-ball")

func test_chase_req_gate() -> void:
	# The Chase Master shape: batting, Aggressive, chase-only.
	var j := JokerEffect.make("cm", "Chase Master", "Legendary",
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.20,
		BallResolver.Intent.AGGRESSIVE, 1, 120, -1, -1, -1, JokerEffect.Trigger.NONE, 0, -1,
		JokerEffect.BoostRole.NONE, JokerEffect.DRSRole.NONE, 0.0, JokerEffect.FormSource.NONE, -1, 1)
	# is_chase is the 7th matches() arg.
	assert_true(j.matches(true, BallResolver.Intent.AGGRESSIVE, 1, FieldPlan.Mode.NEUTRAL, -1, -1, true))
	assert_false(j.matches(true, BallResolver.Intent.AGGRESSIVE, 1, FieldPlan.Mode.NEUTRAL, -1, -1, false), "not chasing -> off")
	assert_false(j.matches(true, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL, -1, -1, true), "not aggressive -> off")

func test_sets_field_stored() -> void:
	# Defensive Captain shape: an enabler that forces a defensive field.
	var j := JokerEffect.make("dc", "Defensive Captain", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.0,
		-1, 1, 120, -1, BallResolver.Intent.DEFENSIVE, FieldPlan.Mode.DEFENSIVE)
	assert_eq(j.sets_field, FieldPlan.Mode.DEFENSIVE)
	assert_eq(j.bowl_intent_req, BallResolver.Intent.DEFENSIVE)
