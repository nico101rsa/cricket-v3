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
	assert_almost_eq(j.mult, 0.83, 0.0001)
	assert_eq(j.rarity, "Rare")

func _group(id: String) -> Dictionary:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return g
	return {}

func test_implemented_groups_count() -> void:
	# 43 (thru C2g) + 2 (C2h) = 45 groups — the FULL pool wired.
	assert_eq(JokerCatalog.implemented_groups().size(), 45)

func test_implemented_flat_count() -> void:
	# 47 rows (thru C2g) + 2 single-row C2h jokers = 49 rows.
	assert_eq(JokerCatalog.implemented().size(), 49)

func test_field_restrictions_shape() -> void:
	var e: JokerEffect = _group("field_restrictions")["effects"][0]
	assert_eq(e.side, JokerEffect.Side.BATTING)
	assert_eq(e.field_req, FieldPlan.Mode.CATCHING)
	assert_almost_eq(e.mult, 1.05, 0.0001)

func test_chase_master_shape() -> void:
	var e: JokerEffect = _group("the_chase_master")["effects"][0]
	assert_eq(e.rarity, "Legendary")
	assert_eq(e.intent_req, BallResolver.Intent.AGGRESSIVE)
	assert_eq(e.chase_req, 1)
	assert_almost_eq(e.mult, 1.20, 0.0001)

func test_form_source_shapes() -> void:
	assert_eq(_group("the_sheet_anchor")["effects"][0].form_source, JokerEffect.FormSource.ON_BALANCED)
	assert_eq(_group("captains_statement")["effects"][0].form_source, JokerEffect.FormSource.ON_AGGRESSIVE)
	assert_eq(_group("building_phase")["effects"][0].form_source, JokerEffect.FormSource.ON_DEFENSIVE_OVER)

func test_boundary_hunter_snaps_aggressive() -> void:
	var e: JokerEffect = _group("boundary_hunter")["effects"][0]
	assert_eq(e.snaps_intent, BallResolver.Intent.AGGRESSIVE)

func test_drs_roles_present() -> void:
	var roles := {}
	for g in JokerCatalog.implemented_groups():
		var e: JokerEffect = g["effects"][0]
		if e.drs_role != JokerEffect.DRSRole.NONE:
			roles[e.drs_role] = g["id"]
	# ACCURACY is shared (Cool Head/Captain's Eye/Snicko) -> 6 distinct roles across 8 jokers.
	assert_eq(roles[JokerEffect.DRSRole.MASTER], "the_review_master")
	assert_eq(roles[JokerEffect.DRSRole.RETAIN], "the_captains_call")
	assert_eq(roles[JokerEffect.DRSRole.BOWLING_BUFF], "bowlers_backing")

func test_captains_eye_defensive_gate() -> void:
	var e: JokerEffect = _group("captains_eye")["effects"][0]
	assert_eq(e.drs_role, JokerEffect.DRSRole.ACCURACY)
	assert_eq(e.intent_req, BallResolver.Intent.DEFENSIVE)
	assert_almost_eq(e.drs_p_bonus, 0.20, 0.0001)

func test_boost_stack_roles_present() -> void:
	var roles := {}
	for g in JokerCatalog.implemented_groups():
		var e: JokerEffect = g["effects"][0]
		if e.boost_role != JokerEffect.BoostRole.NONE:
			roles[e.boost_role] = g["id"]
	assert_eq(roles.size(), 7, "all 7 Boost Stack roles present")
	assert_eq(roles[JokerEffect.BoostRole.COMEBACK], "the_comeback_press")
	assert_eq(roles[JokerEffect.BoostRole.AMPLIFY], "power_surge")

func test_pace_pack_change_trigger() -> void:
	var e: JokerEffect = _group("pace_pack")["effects"][0]
	assert_eq(e.side, JokerEffect.Side.BOWLING)
	assert_eq(e.trigger, JokerEffect.Trigger.CHANGE_PACE)
	assert_eq(e.window_n, 6)

func test_strike_bowler_catching_gate() -> void:
	var e: JokerEffect = _group("the_strike_bowler")["effects"][0]
	assert_eq(e.trigger, JokerEffect.Trigger.CHANGE_ANY)
	assert_eq(e.field_req, FieldPlan.Mode.CATCHING)
	assert_eq(e.window_n, 12)

func test_the_trap_stateless_shape() -> void:
	var e: JokerEffect = _group("the_trap")["effects"][0]
	assert_eq(e.trigger, JokerEffect.Trigger.NONE, "The Trap is stateless")
	assert_eq(e.field_req, FieldPlan.Mode.CATCHING)
	assert_eq(e.bowler_type_req, BowlingPlan.Kind.SPIN)
	assert_almost_eq(e.mult, 1.25, 0.0001)

func test_ride_the_wave_trigger_shape() -> void:
	var g := _group("ride_the_wave")
	assert_false(g.is_empty())
	var e: JokerEffect = g["effects"][0]
	assert_eq(e.side, JokerEffect.Side.BATTING)
	assert_eq(e.target, JokerEffect.Target.RUNS)
	assert_eq(e.trigger, JokerEffect.Trigger.FORM_BAT)
	assert_eq(e.window_n, 3)
	assert_almost_eq(e.mult, 1.20, 0.0001)

func test_wicket_maiden_bowling_trigger() -> void:
	var g := _group("wicket_maiden")
	var e: JokerEffect = g["effects"][0]
	assert_eq(e.side, JokerEffect.Side.BOWLING)
	assert_eq(e.trigger, JokerEffect.Trigger.FORM_BOWL)
	assert_eq(e.window_n, 6)

func test_hot_streak_two_double_rows() -> void:
	var g := _group("hot_streak")
	assert_eq(g["effects"].size(), 2, "Hot Streak = runs + wicket")
	for e in g["effects"]:
		assert_eq(e.trigger, JokerEffect.Trigger.FORM_DOUBLE_BAT)
		assert_eq(e.window_n, 6)

func test_match_winners_vigil_long_window() -> void:
	var g := _group("match_winners_vigil")
	var e: JokerEffect = g["effects"][0]
	assert_eq(e.rarity, "Legendary")
	assert_eq(e.trigger, JokerEffect.Trigger.FORM_BAT)
	assert_eq(e.window_n, 24)
	assert_almost_eq(e.mult, 0.80, 0.0001)

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

func test_carry_your_bat_scores_while_defending() -> void:
	var rows: Array = _group("carry_your_bat")["effects"]
	var wicket_mult := 1.0
	var runs_mult := 1.0
	for e in rows:
		if e.target == JokerEffect.Target.WICKET:
			wicket_mult = e.mult
		else:
			runs_mult = e.mult
	# Must still protect the wicket but NOT suppress scoring (the bug was runs 0.90).
	assert_lt(wicket_mult, 1.0, "Carry Your Bat still lowers wicket risk")
	assert_gte(runs_mult, 1.0, "Carry Your Bat must not suppress scoring (was 0.90 -> net-negative)")

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
