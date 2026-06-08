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
	# 5 slice + 6 (C2a) + 4 (C2b) = 15 groups.
	assert_eq(JokerCatalog.implemented_groups().size(), 15)

func test_implemented_flat_count() -> void:
	# 13 rows (C2a) + attack_the_stumps(1) + pressure_cooker(1) + choke_hold(2) +
	# defensive_captain(1) = 18 rows.
	assert_eq(JokerCatalog.implemented().size(), 18)

func test_attack_the_stumps_shape() -> void:
	var g := _group("attack_the_stumps")
	assert_false(g.is_empty())
	var e: JokerEffect = g["effects"][0]
	assert_eq(e.side, JokerEffect.Side.BOWLING)
	assert_eq(e.target, JokerEffect.Target.WICKET)
	assert_eq(e.bowl_intent_req, BallResolver.Intent.AGGRESSIVE)
	assert_almost_eq(e.mult, 1.12, 0.0001)

func test_pressure_cooker_reads_batsman_intent() -> void:
	var g := _group("pressure_cooker")
	assert_false(g.is_empty())
	var e: JokerEffect = g["effects"][0]
	assert_eq(e.side, JokerEffect.Side.BOWLING)
	assert_eq(e.intent_req, BallResolver.Intent.DEFENSIVE, "reads the batsman intent, not bowl_intent")
	assert_eq(e.bowl_intent_req, -1)
	assert_almost_eq(e.mult, 1.10, 0.0001)

func test_choke_hold_two_rows() -> void:
	var g := _group("choke_hold")
	assert_eq(g["effects"].size(), 2, "Choke Hold = runs + wicket")
	assert_eq(g["rarity"], "Legendary")
	for e in g["effects"]:
		assert_eq(e.field_req, FieldPlan.Mode.DEFENSIVE)
		assert_eq(e.bowl_intent_req, BallResolver.Intent.DEFENSIVE)

func test_defensive_captain_sets_field() -> void:
	var g := _group("defensive_captain")
	assert_false(g.is_empty())
	var e: JokerEffect = g["effects"][0]
	assert_eq(e.sets_field, FieldPlan.Mode.DEFENSIVE)
	assert_eq(e.bowl_intent_req, BallResolver.Intent.DEFENSIVE)
	assert_almost_eq(e.mult, 1.0, 0.0001, "enabler bends no roll")

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
