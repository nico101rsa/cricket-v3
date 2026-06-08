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
