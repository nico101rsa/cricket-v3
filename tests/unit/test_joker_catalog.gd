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

func _group(id: String) -> Dictionary:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return g
	return {}

func test_implemented_groups_count() -> void:
	# 5 slice jokers + 6 new (C2a) = 11 groups.
	assert_eq(JokerCatalog.implemented_groups().size(), 11)

func test_implemented_flat_count() -> void:
	# 11 groups, two of them (carry_your_bat, dot_ball_pressure) are double-buff -> 13 rows.
	assert_eq(JokerCatalog.implemented().size(), 13)

func test_multi_buff_groups_have_two_effects() -> void:
	assert_eq(_group("carry_your_bat")["effects"].size(), 2, "Carry Your Bat = wicket + runs")
	assert_eq(_group("dot_ball_pressure")["effects"].size(), 2, "Dot Ball Pressure = wicket + runs")

func test_cordon_killer_field_shape() -> void:
	var g := _group("cordon_killer")
	assert_false(g.is_empty())
	var e: JokerEffect = g["effects"][0]
	assert_eq(e.side, JokerEffect.Side.BOWLING)
	assert_eq(e.target, JokerEffect.Target.WICKET)
	assert_eq(e.field_req, FieldPlan.Mode.CATCHING)
	assert_almost_eq(e.mult, 1.10, 0.0001)

func test_rotate_the_strike_shape() -> void:
	var g := _group("rotate_the_strike")
	assert_false(g.is_empty())
	var e: JokerEffect = g["effects"][0]
	assert_eq(e.side, JokerEffect.Side.BATTING)
	assert_eq(e.target, JokerEffect.Target.RUNS)
	assert_eq(e.intent_req, BallResolver.Intent.BALANCED)
	assert_almost_eq(e.mult, 1.08, 0.0001)
