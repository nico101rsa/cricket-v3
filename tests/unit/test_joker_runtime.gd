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
