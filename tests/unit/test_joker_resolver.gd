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

func test_multi_buff_same_joker_splits_targets() -> void:
	# Carry Your Bat shape: two same-id rows under one condition -> both rolls bend.
	var carry := [
		JokerEffect.make("carry", "Carry", "Rare", JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.85),
		JokerEffect.make("carry", "Carry", "Rare", JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 0.90),
	]
	var m := JokerResolver.roll_mults(carry, true, BallResolver.Intent.BALANCED, 1)
	assert_almost_eq(m.x, 0.85, 0.0001)
	assert_almost_eq(m.y, 0.90, 0.0001)
