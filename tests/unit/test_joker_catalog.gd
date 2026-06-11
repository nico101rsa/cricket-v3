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
	# 47 rows (thru C2g) + 2 single-row C2h jokers = 49; mechanic-change rung adds the
	# Chase Master composure row + the Wicket Maiden economy row = 51 rows.
	assert_eq(JokerCatalog.implemented().size(), 51)

func test_field_restrictions_shape() -> void:
	var e: JokerEffect = _group("field_restrictions")["effects"][0]
	assert_eq(e.side, JokerEffect.Side.BATTING)
	assert_eq(e.field_req, FieldPlan.Mode.CATCHING)
	assert_almost_eq(e.mult, 1.05, 0.0001)

func test_chase_master_shape() -> void:
	# Mechanic-change rung: Chase Master is now a 2-row joker — runs (score harder)
	# + a composure/survival row (wicket <1, converts where runs saturate vs the
	# chase win-ceiling). Both gated identically (chasing + Aggressive). See spec
	# 2026-06-10-capped-joker-mechanic-changes-design.md.
	var effects: Array = _group("the_chase_master")["effects"]
	assert_eq(effects.size(), 2, "Chase Master = runs + composure rows")
	var runs_row: JokerEffect = null
	var wicket_row: JokerEffect = null
	for e in effects:
		assert_eq(e.rarity, "Legendary")
		assert_eq(e.intent_req, BallResolver.Intent.AGGRESSIVE, "both rows gated on Aggressive")
		assert_eq(e.chase_req, 1, "both rows gated on the chase")
		assert_eq(e.side, JokerEffect.Side.BATTING)
		if e.target == JokerEffect.Target.RUNS:
			runs_row = e
		else:
			wicket_row = e
	assert_not_null(runs_row, "has a runs row")
	assert_not_null(wicket_row, "has a composure (wicket) row")
	assert_almost_eq(runs_row.mult, 1.40, 0.0001, "runs ×1.40 (near the convertible max)")
	# Composure tuned to 0.62: lifts realized +3.6% -> +6.6% (Legendary floor); the
	# survival converts where runs saturate vs the chase win-ceiling. See spec §6.
	assert_almost_eq(wicket_row.mult, 0.62, 0.0001, "composure: dismissal ×0.62")
	assert_lt(wicket_row.mult, 1.0, "composure reduces dismissal chance")

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
	# Mechanic-change rung: Wicket Maiden is now a 2-row joker — wicket (×>1) +
	# an economy/dot-pressure row (runs ×<1) over the same post-wicket window.
	# Economy always converts (every ball conceded counts) where extra wicket-chance
	# only pays off if a wicket falls; thematically a wicket-maiden = wicket + no runs.
	var effects: Array = _group("wicket_maiden")["effects"]
	assert_eq(effects.size(), 2, "Wicket Maiden = wicket + economy rows")
	var wicket_row: JokerEffect = null
	var runs_row: JokerEffect = null
	for e in effects:
		assert_eq(e.side, JokerEffect.Side.BOWLING)
		assert_eq(e.trigger, JokerEffect.Trigger.FORM_BOWL, "both rows fire on the bowling Form event")
		assert_eq(e.window_n, 6, "both over the 6-ball post-wicket window")
		if e.target == JokerEffect.Target.WICKET:
			wicket_row = e
		else:
			runs_row = e
	assert_not_null(wicket_row, "has a wicket row")
	assert_not_null(runs_row, "has an economy (runs) row")
	assert_almost_eq(wicket_row.mult, 1.55, 0.0001, "wicket ×1.55 (bowling-balance band re-tune)")
	# Economy 0.62 -> 0.55 (bowling-balance band re-tune: the steep tail moved the
	# realized delta to +1.7, below Rare floor); economy converts where extra
	# wicket-chance can't (it only pays if a wicket falls).
	assert_almost_eq(runs_row.mult, 0.55, 0.0001, "economy: runs ×0.55")
	assert_lt(runs_row.mult, 1.0, "economy concedes fewer runs")

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
	# Scenario-sweep rung: buffed 0.80 -> 0.62 (in-combo with Form sources; held
	# below full Legendary band to avoid an immortality exploit — see spec §10).
	assert_almost_eq(e.mult, 0.62, 0.0001)

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
	# Mechanic-change rung: both capped jokers gained a converting second component.
	assert_eq(_group("the_chase_master")["effects"].size(), 2, "Chase Master = runs + composure")
	assert_eq(_group("wicket_maiden")["effects"].size(), 2, "Wicket Maiden = wicket + economy")

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

# --- ₸ prices (rung 7c-D, spec 2026-06-10-tons-economy-7cD §5.3) ---

func test_every_joker_has_a_price_in_its_rarity_band() -> void:
	for g in JokerCatalog.implemented_groups():
		var id: String = g["id"]
		var band: Vector2i = JokerCatalog.price_band(g["rarity"])
		assert_true(JokerCatalog.PRICES.has(id), "%s has no price" % id)
		var p: int = JokerCatalog.price(id)
		assert_between(p, band.x, band.y, "%s priced %d outside band %s" % [id, p, str(band)])
		assert_eq(p % 5, 0, "%s price %d not a multiple of 5" % [id, p])

func test_price_count_matches_pool() -> void:
	assert_eq(JokerCatalog.PRICES.size(), JokerCatalog.implemented_groups().size())

func test_price_bands_match_pool_doc() -> void:
	assert_eq(JokerCatalog.price_band("Common"), Vector2i(30, 50))
	assert_eq(JokerCatalog.price_band("Rare"), Vector2i(90, 120))
	assert_eq(JokerCatalog.price_band("Legendary"), Vector2i(220, 250))
