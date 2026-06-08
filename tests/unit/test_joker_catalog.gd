extends GutTest

func test_slice_has_five() -> void:
	assert_eq(JokerCatalog.slice_v1().size(), 5)

func _by_id(id: String) -> JokerEffect:
	for j in JokerCatalog.slice_v1():
		if j.id == id:
			return j
	return null

func test_dead_bat_shape() -> void:
	var j := _by_id("dead_bat")
	assert_not_null(j)
	assert_eq(j.side, JokerEffect.Side.BATTING)
	assert_eq(j.target, JokerEffect.Target.WICKET)
	assert_eq(j.intent_req, BallResolver.Intent.DEFENSIVE)
	assert_almost_eq(j.mult, 0.92, 0.0001)

func test_death_over_shape() -> void:
	var j := _by_id("death_over_stranglehold")
	assert_not_null(j)
	assert_eq(j.side, JokerEffect.Side.BOWLING)
	assert_eq(j.target, JokerEffect.Target.RUNS)
	assert_eq(j.ball_min, 90)
	assert_almost_eq(j.mult, 0.80, 0.0001)
	assert_eq(j.rarity, "Rare")
