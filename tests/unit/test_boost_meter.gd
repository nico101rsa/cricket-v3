extends GutTest

# The ADR 0005 water-meter (spec 2026-07-04 DW1-DW6): fill in [0,1], starts full,
# press locks (mult, n) from fill, drains to 0 over the locked window, then
# recharges at 1/RECHARGE_BALLS per ball. Pure, ball-ticked, no RNG.

func test_starts_full() -> void:
	var m := BoostMeter.new()
	assert_almost_eq(m.fill, 1.0, 0.0001, "meter starts full")
	assert_false(m.draining(), "not draining at start")

func test_full_press_locks_base_params() -> void:
	var m := BoostMeter.new()
	var p := m.try_press(1.15, 6)
	assert_almost_eq(p["mult"], 1.15, 0.0001, "full fill -> full mult (DW2)")
	assert_eq(p["n"], 6, "full fill -> full window")
	assert_true(m.draining(), "press starts the drain")

func test_half_press_locks_scaled_params() -> void:
	var m := BoostMeter.new()
	m.fill = 0.5
	var p := m.try_press(1.15, 6)
	assert_almost_eq(p["mult"], 1.075, 0.0001, "mult = 1 + F*(base-1) (DW2)")
	assert_eq(p["n"], 3, "n = round(F * base_n)")

func test_drain_reaches_zero_exactly_at_window_end() -> void:
	var m := BoostMeter.new()
	m.try_press(1.15, 6)
	for i in range(6):
		m.tick()
	assert_almost_eq(m.fill, 0.0, 0.0001, "empty exactly when the buff ends (DW3)")
	assert_false(m.draining(), "drain over")

func test_press_while_draining_is_ignored() -> void:
	var m := BoostMeter.new()
	m.try_press(1.15, 6)
	assert_eq(m.try_press(1.15, 6), {}, "one boost at a time (DW3)")

func test_press_under_min_fill_is_ignored() -> void:
	var m := BoostMeter.new()
	m.fill = 0.2
	assert_eq(m.try_press(1.15, 6), {}, "sub-25% press blocked (DW5)")

func test_recharge_rate_and_cap() -> void:
	var m := BoostMeter.new()
	m.try_press(1.15, 6)
	for i in range(6):
		m.tick()
	m.tick()
	assert_almost_eq(m.fill, 1.0 / 34.0, 0.0001, "+1/34 per ball (DW4)")
	for i in range(50):
		m.tick()
	assert_almost_eq(m.fill, 1.0, 0.0001, "capped at 1.0")

func test_three_full_presses_fit_a_120_ball_innings() -> void:
	# Full cycle = 6 drain + 34 recharge = 40 balls (DW4): presses at balls 1/41/81.
	var m := BoostMeter.new()
	var full_presses := 0
	for ball in range(1, 121):
		if ball == 1 or ball == 41 or ball == 81:
			var p := m.try_press(1.15, 6)
			if not p.is_empty() and p["n"] == 6:
				full_presses += 1
		m.tick()
	assert_eq(full_presses, 3, "3 full presses per innings -> ~6 per match (DW4)")
