extends GutTest

func _wicket(mult: float, side: int = JokerEffect.Side.BATTING) -> JokerEffect:
	return JokerEffect.make("w", "W", "Common", side, JokerEffect.Target.WICKET, mult)

func _runs(mult: float, side: int = JokerEffect.Side.BATTING) -> JokerEffect:
	return JokerEffect.make("r", "R", "Common", side, JokerEffect.Target.RUNS, mult)

func test_empty_is_identity() -> void:
	var m := JokerResolver.roll_mults([], true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 1.0, 0.0001)
	assert_almost_eq(m.y, 1.0, 0.0001)

func test_single_wicket_match() -> void:
	var m := JokerResolver.roll_mults([_wicket(0.9)], true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 0.9, 0.0001)
	assert_almost_eq(m.y, 1.0, 0.0001)

func test_two_same_target_multiply() -> void:
	var m := JokerResolver.roll_mults([_wicket(0.9), _wicket(0.8)], true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 0.72, 0.0001)

func test_targets_split() -> void:
	var m := JokerResolver.roll_mults([_wicket(0.9), _runs(1.2)], true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 0.9, 0.0001)
	assert_almost_eq(m.y, 1.2, 0.0001)

func test_non_matching_excluded() -> void:
	# A bowling joker is inert while the owner is batting.
	var m := JokerResolver.roll_mults([_wicket(0.5, JokerEffect.Side.BOWLING)], true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 1.0, 0.0001)

func _field_wicket(mult: float, field: int) -> JokerEffect:
	# bowling, field-gated wicket joker
	return JokerEffect.make("f", "F", "Common", JokerEffect.Side.BOWLING,
		JokerEffect.Target.WICKET, mult, -1, 1, 120, field)

func test_field_gated_contributes_only_on_match() -> void:
	var jk := [_field_wicket(1.3, FieldPlan.Mode.CATCHING)]
	# field matches -> applies
	var on := JokerResolver.roll_mults(jk, false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.CATCHING)
	assert_almost_eq(on.x, 1.3, 0.0001)
	# wrong field -> identity
	var off := JokerResolver.roll_mults(jk, false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.DEFENSIVE)
	assert_almost_eq(off.x, 1.0, 0.0001)

func test_default_field_is_neutral() -> void:
	# Omitting the field arg (old signature) defaults to NEUTRAL -> field jokers inert.
	var jk := [_field_wicket(1.3, FieldPlan.Mode.CATCHING)]
	var m := JokerResolver.roll_mults(jk, false, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 1.0, 0.0001)

func _bowl_intent_wicket(mult: float, req: int) -> JokerEffect:
	# Attack the Stumps shape: bowling, gated on the bowling-captain intent.
	return JokerEffect.make("ats", "ATS", "Common", JokerEffect.Side.BOWLING,
		JokerEffect.Target.WICKET, mult, -1, 1, 120, -1, req)

func test_bowl_intent_gated_contributes_only_on_match() -> void:
	var jk := [_bowl_intent_wicket(1.3, BallResolver.Intent.AGGRESSIVE)]
	# bowl_intent matches (6th arg) -> applies
	var on := JokerResolver.roll_mults(jk, false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL, BallResolver.Intent.AGGRESSIVE)
	assert_almost_eq(on.x, 1.3, 0.0001)
	# wrong bowl_intent -> identity
	var off := JokerResolver.roll_mults(jk, false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL, BallResolver.Intent.DEFENSIVE)
	assert_almost_eq(off.x, 1.0, 0.0001)

func test_default_bowl_intent_is_unset() -> void:
	# Omitting the bowl_intent arg defaults to -1 -> bowl-intent jokers inert.
	var jk := [_bowl_intent_wicket(1.3, BallResolver.Intent.AGGRESSIVE)]
	var m := JokerResolver.roll_mults(jk, false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL)
	assert_almost_eq(m.x, 1.0, 0.0001)

func _defensive_captain() -> JokerEffect:
	# Enabler: Defensive bowl_intent -> sets a defensive field. mult 1.0, no roll.
	return JokerEffect.make("dc", "DC", "Common", JokerEffect.Side.BOWLING,
		JokerEffect.Target.WICKET, 1.0, -1, 1, 120, -1, BallResolver.Intent.DEFENSIVE, FieldPlan.Mode.DEFENSIVE)

func _defensive_field_runs(mult: float) -> JokerEffect:
	# Tight Lines shape: bowling, field = Defensive, runs suppressor.
	return JokerEffect.make("tl", "TL", "Common", JokerEffect.Side.BOWLING,
		JokerEffect.Target.RUNS, mult, -1, 1, 120, FieldPlan.Mode.DEFENSIVE)

func test_sets_field_enabler_unlocks_field_joker() -> void:
	# #18 + Tight Lines: with no base field set, Defensive Captain upgrades the
	# effective field to Defensive (because bowl_intent is Defensive), so Tight Lines fires.
	var combo := [_defensive_captain(), _defensive_field_runs(0.9)]
	var on := JokerResolver.roll_mults(combo, false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL, BallResolver.Intent.DEFENSIVE)
	assert_almost_eq(on.y, 0.9, 0.0001, "enabler upgrades field -> Tight Lines fires")
	# Without the Defensive bowl_intent the enabler doesn't fire, so Tight Lines stays off.
	var off := JokerResolver.roll_mults(combo, false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL, BallResolver.Intent.AGGRESSIVE)
	assert_almost_eq(off.y, 1.0, 0.0001, "no Defensive captaincy -> field not set -> Tight Lines off")

func test_sets_field_enabler_adds_no_multiplier() -> void:
	# Defensive Captain alone bends no roll (it is an enabler, not a modifier).
	var m := JokerResolver.roll_mults([_defensive_captain()], false, BallResolver.Intent.BALANCED, 1, FieldPlan.Mode.NEUTRAL, BallResolver.Intent.DEFENSIVE)
	assert_almost_eq(m.x, 1.0, 0.0001)
	assert_almost_eq(m.y, 1.0, 0.0001)

func test_multi_buff_same_joker_splits_targets() -> void:
	# Carry Your Bat shape: two same-id rows under one condition -> both rolls bend.
	var carry := [
		JokerEffect.make("carry", "Carry", "Rare", JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.85),
		JokerEffect.make("carry", "Carry", "Rare", JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 0.90),
	]
	var m := JokerResolver.roll_mults(carry, true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 0.85, 0.0001)
	assert_almost_eq(m.y, 0.90, 0.0001)
