extends GutTest

# C2c — the per-innings windowed-buff engine.

func _ride_the_wave() -> JokerEffect:
	# FORM_BAT: runs x1.20 for 3 balls.
	return JokerEffect.make("rtw", "Ride the Wave", "Common",
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.20,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BAT, 3)

func _wicket_maiden() -> JokerEffect:
	# FORM_BOWL: wicket x1.30 for 6 balls.
	return JokerEffect.make("wm", "Wicket Maiden", "Rare",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.30,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BOWL, 6)

func _hot_streak_runs() -> JokerEffect:
	# FORM_DOUBLE_BAT: runs x1.30 for 6 balls.
	return JokerEffect.make("hs", "Hot Streak", "Rare",
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.30,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_DOUBLE_BAT, 6)

func test_empty_runtime_is_identity() -> void:
	var rt := JokerRuntime.new()
	var m := rt.tick_mults(true)
	assert_almost_eq(m.x, 1.0, 0.0001)
	assert_almost_eq(m.y, 1.0, 0.0001)

func test_form_bat_pushes_three_ball_runs_buff() -> void:
	var rt := JokerRuntime.new()
	var jk := [_ride_the_wave()]
	# Form event on ball 1 -> buff applies to balls 2,3,4 then expires.
	rt.on_ball_end(jk, true, 1, true)
	assert_almost_eq(rt.tick_mults(true).y, 1.20, 0.0001, "ball 2")
	rt.on_ball_end(jk, true, 2, false)
	assert_almost_eq(rt.tick_mults(true).y, 1.20, 0.0001, "ball 3")
	rt.on_ball_end(jk, true, 3, false)
	assert_almost_eq(rt.tick_mults(true).y, 1.20, 0.0001, "ball 4")
	rt.on_ball_end(jk, true, 4, false)
	assert_almost_eq(rt.tick_mults(true).y, 1.0, 0.0001, "ball 5 — window expired")

func test_no_form_no_buff() -> void:
	var rt := JokerRuntime.new()
	var jk := [_ride_the_wave()]
	rt.on_ball_end(jk, true, 1, false)  # no Form event
	assert_almost_eq(rt.tick_mults(true).y, 1.0, 0.0001)

func test_side_gating() -> void:
	var rt := JokerRuntime.new()
	var jk := [_wicket_maiden()]
	# A Player wicket while bowling fires the bowling buff.
	rt.on_ball_end(jk, false, 1, true)
	assert_almost_eq(rt.tick_mults(false).x, 1.30, 0.0001, "bowling buff applies while bowling")
	assert_almost_eq(rt.tick_mults(true).x, 1.0, 0.0001, "bowling buff inert while batting")

func test_form_bat_does_not_fire_bowling_event() -> void:
	# A batting trigger should not fire on a bowling-side event.
	var rt := JokerRuntime.new()
	var jk := [_ride_the_wave()]
	rt.on_ball_end(jk, false, 1, true)  # event while bowling
	assert_almost_eq(rt.tick_mults(false).y, 1.0, 0.0001)
	assert_almost_eq(rt.tick_mults(true).y, 1.0, 0.0001)

func test_double_trigger_needs_two_within_six() -> void:
	var rt := JokerRuntime.new()
	var jk := [_hot_streak_runs()]
	# First event: not a double yet -> no buff.
	rt.on_ball_end(jk, true, 1, true)
	assert_almost_eq(rt.tick_mults(true).y, 1.0, 0.0001, "single event -> no buff")
	# Second event on ball 3 (3-1=2 < 6) -> double fires.
	rt.on_ball_end(jk, true, 3, true)
	assert_almost_eq(rt.tick_mults(true).y, 1.30, 0.0001, "2nd event within 6 -> buff")

func test_double_trigger_skips_when_far_apart() -> void:
	var rt := JokerRuntime.new()
	var jk := [_hot_streak_runs()]
	rt.on_ball_end(jk, true, 1, true)
	# Event on ball 8 (8-1=7 >= 6) -> not a double.
	rt.on_ball_end(jk, true, 8, true)
	assert_almost_eq(rt.tick_mults(true).y, 1.0, 0.0001, "events > 6 balls apart -> no double buff")

# --- C2d: bowling-change windows ---

func _pace_pack() -> JokerEffect:
	# CHANGE_PACE: wicket x1.15 for 6 balls.
	return JokerEffect.make("pp", "Pace Pack", "Common",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.15,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.CHANGE_PACE, 6)

func _strike_bowler() -> JokerEffect:
	# CHANGE_ANY + catching-field gate: wicket x1.35 for 12 balls.
	return JokerEffect.make("sb", "The Strike Bowler", "Legendary",
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.35,
		-1, 1, 120, FieldPlan.Mode.CATCHING, -1, -1, JokerEffect.Trigger.CHANGE_ANY, 12)

func test_bowling_change_applies_from_this_over() -> void:
	var rt := JokerRuntime.new()
	var jk := [_pace_pack()]
	# A pace change pushes a 6-ball buff that applies starting this over's first ball.
	rt.on_bowling_change(jk, BowlingPlan.Kind.PACE, FieldPlan.Mode.NEUTRAL)
	assert_almost_eq(rt.tick_mults(false).x, 1.15, 0.0001, "applies from the change over")
	for b in range(5):
		rt.on_ball_end(jk, false, b + 1, false)
		assert_almost_eq(rt.tick_mults(false).x, 1.15, 0.0001, "still in window")
	rt.on_ball_end(jk, false, 6, false)
	assert_almost_eq(rt.tick_mults(false).x, 1.0, 0.0001, "6-ball window expired")

func test_change_kind_gating() -> void:
	var rt := JokerRuntime.new()
	var jk := [_pace_pack()]
	# A spin change does not fire a pace-change joker.
	rt.on_bowling_change(jk, BowlingPlan.Kind.SPIN, FieldPlan.Mode.NEUTRAL)
	assert_almost_eq(rt.tick_mults(false).x, 1.0, 0.0001)

func test_change_field_req_gating() -> void:
	var rt := JokerRuntime.new()
	var jk := [_strike_bowler()]
	# Wrong field -> no buff.
	rt.on_bowling_change(jk, BowlingPlan.Kind.PACE, FieldPlan.Mode.NEUTRAL)
	assert_almost_eq(rt.tick_mults(false).x, 1.0, 0.0001, "non-catching change -> off")
	# Catching change -> fires (CHANGE_ANY, any kind).
	rt.on_bowling_change(jk, BowlingPlan.Kind.SPIN, FieldPlan.Mode.CATCHING)
	assert_almost_eq(rt.tick_mults(false).x, 1.35, 0.0001, "catching change -> on")

# --- C2e: Manager Boost ---

func _boost(role: int) -> JokerEffect:
	return JokerEffect.make("b", "B", "Common", JokerEffect.Side.BOWLING,
		JokerEffect.Target.WICKET, 1.0, -1, 1, 120, -1, -1, -1,
		JokerEffect.Trigger.NONE, 0, -1, role)

func test_boost_base_buff_side_aware() -> void:
	# A bare press (no Boost jokers) pushes a side-aware base buff.
	var rt := JokerRuntime.new()
	rt.on_boost_press([], true, BallResolver.Intent.BALANCED, 1.5, 6, 1)
	assert_almost_eq(rt.tick_mults(true).y, 1.5, 0.0001, "batting press -> runs buff")
	var rt2 := JokerRuntime.new()
	rt2.on_boost_press([], false, BallResolver.Intent.BALANCED, 1.5, 6, 1)
	assert_almost_eq(rt2.tick_mults(false).x, 1.5, 0.0001, "bowling press -> wicket buff")

func test_boost_power_up_extends_window() -> void:
	var rt := JokerRuntime.new()
	rt.on_boost_press([_boost(JokerEffect.BoostRole.EXTEND)], true, BallResolver.Intent.BALANCED, 1.5, 6, 1)
	assert_eq(rt.active[0]["balls_left"], 8, "Power Up: 6 + 2")

func test_boost_power_surge_amplifies() -> void:
	var rt := JokerRuntime.new()
	rt.on_boost_press([_boost(JokerEffect.BoostRole.AMPLIFY)], true, BallResolver.Intent.BALANCED, 1.5, 6, 1)
	assert_almost_eq(rt.active[0]["mult"], 1.5 * 1.20, 0.0001, "Power Surge: mult x1.2")
	assert_eq(rt.active[0]["balls_left"], 9, "Power Surge: 6 + 3")

func test_boost_comeback_only_on_third_press() -> void:
	var rt := JokerRuntime.new()
	var jk := [_boost(JokerEffect.BoostRole.COMEBACK)]
	rt.on_boost_press(jk, true, BallResolver.Intent.BALANCED, 1.0, 6, 1)
	rt.on_boost_press(jk, true, BallResolver.Intent.BALANCED, 1.0, 6, 1)
	rt.on_boost_press(jk, true, BallResolver.Intent.BALANCED, 1.0, 6, 1)
	# Base buffs at indices 0,1,2 (one per press); the 3rd gets the comeback amp.
	assert_almost_eq(rt.active[0]["mult"], 1.0, 0.0001, "press 1 -> no amp")
	assert_almost_eq(rt.active[2]["mult"], 1.50, 0.0001, "press 3 -> mult x1.5")

func test_boost_battery_adds_kicker() -> void:
	var rt := JokerRuntime.new()
	rt.on_boost_press([_boost(JokerEffect.BoostRole.BATTERY)], true, BallResolver.Intent.BALANCED, 1.5, 6, 1)
	# base runs buff (1.5) * battery kicker (1.10), both runs/batting.
	assert_almost_eq(rt.tick_mults(true).y, 1.5 * 1.10, 0.0001)

func test_boost_compound_needs_aggressive() -> void:
	# Balanced press -> no compound (just the base buff).
	var rt := JokerRuntime.new()
	rt.on_boost_press([_boost(JokerEffect.BoostRole.COMPOUND)], true, BallResolver.Intent.BALANCED, 1.0, 6, 1)
	assert_almost_eq(rt.tick_mults(true).y, 1.0, 0.0001, "balanced -> no compound")
	# Aggressive press -> runs x1.25 and wicket x0.85.
	var rt2 := JokerRuntime.new()
	rt2.on_boost_press([_boost(JokerEffect.BoostRole.COMPOUND)], true, BallResolver.Intent.AGGRESSIVE, 1.0, 6, 1)
	assert_almost_eq(rt2.tick_mults(true).y, 1.25, 0.0001, "aggressive -> runs x1.25")
	assert_almost_eq(rt2.tick_mults(true).x, 0.85, 0.0001, "aggressive -> wicket x0.85")

func test_boost_pedal_enables_compound() -> void:
	# Pedal flips a Balanced press to Aggressive, so Compounding Pressure fires.
	var rt := JokerRuntime.new()
	var jk := [_boost(JokerEffect.BoostRole.COMPOUND), _boost(JokerEffect.BoostRole.PEDAL)]
	rt.on_boost_press(jk, true, BallResolver.Intent.BALANCED, 1.0, 6, 1)
	assert_almost_eq(rt.tick_mults(true).y, 1.25, 0.0001, "pedal -> aggressive -> compound fires")

func test_boost_adrenaline_chains_form() -> void:
	# Boost Adrenaline fires a Form event, which triggers a Form joker (Ride the Wave).
	var rt := JokerRuntime.new()
	var jk := [_boost(JokerEffect.BoostRole.ADRENALINE), _ride_the_wave()]
	rt.on_boost_press(jk, true, BallResolver.Intent.BALANCED, 1.0, 6, 1)
	assert_almost_eq(rt.tick_mults(true).y, 1.20, 0.0001, "adrenaline -> form event -> Ride the Wave fires")
