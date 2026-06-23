extends GutTest

# Pure run-rate chart data (MatchViewBuilder._build_chart). Hand-built ball-logs →
# per-over bars/worm/flags + the target/par line. No sim, no RNG.

# One legal-ball log entry; only the fields _build_chart reads.
func _ball(over: int, runs: int, total: int, wicket := false, wkts := 0) -> Dictionary:
	return {"over": over, "ball_in_over": 0, "striker_pos": 1, "is_player": false,
		"player_batting": false, "player_bowling": false, "intent": 0,
		"boost_pressed": false, "wicket": wicket, "runs": runs,
		"total": total, "wickets": wkts}

# A full over (6 balls) of flat singles starting from running total `from`.
func _over_singles(over: int, from: int) -> Array:
	var out: Array = []
	var t := from
	for b in range(6):
		t += 1
		out.append(_ball(over, 1, t))
	# the 6th ball closes the over
	out[5]["ball_in_over"] = 6
	return out

func test_per_over_runs_and_crr_series() -> void:
	var log: Array = []
	log.append_array(_over_singles(1, 0))    # over 1: 6 runs, total 6
	log.append_array(_over_singles(2, 6))    # over 2: 6 runs, total 12
	var chart := MatchViewBuilder._build_chart(log, log.size(), 1, 0)
	assert_eq(chart["overs"].size(), 2, "two completed overs")
	assert_eq(chart["overs"][0]["runs"], 6, "over 1 = 6 runs")
	assert_eq(chart["overs"][1]["runs"], 6, "over 2 = 6 runs")
	# CRR at end of over 2 = 12 runs in 12 balls = 6.0
	assert_almost_eq(chart["overs"][1]["crr"], 6.0, 0.01, "cumulative CRR")
	assert_false(chart["overs"][0]["now"], "completed over not flagged now")

func test_boundary_and_wicket_flags() -> void:
	var log: Array = []
	# over 1: a four on ball 1 then five singles
	log.append(_ball(1, 4, 4))
	var t := 4
	for b in range(5):
		t += 1; log.append(_ball(1, 1, t))
	log[5]["ball_in_over"] = 6
	# over 2: a wicket on ball 1 (runs 0) then five singles
	log.append(_ball(2, 0, t, true, 1))
	for b in range(5):
		t += 1; log.append(_ball(2, 1, t, false, 1))
	log[11]["ball_in_over"] = 6
	var chart := MatchViewBuilder._build_chart(log, log.size(), 1, 0)
	assert_true(chart["overs"][0]["has_boundary"], "over 1 had a boundary")
	assert_false(chart["overs"][0]["has_wicket"], "over 1 had no wicket")
	assert_true(chart["overs"][1]["has_wicket"], "over 2 had a wicket")

func test_now_over_partial() -> void:
	var log: Array = []
	log.append_array(_over_singles(1, 0))   # over 1 complete (6)
	log.append(_ball(2, 4, 10))             # over 2 ball 1 only (partial)
	log[6]["ball_in_over"] = 1
	var chart := MatchViewBuilder._build_chart(log, log.size(), 1, 0)
	assert_eq(chart["overs"].size(), 2, "in-progress over included")
	assert_true(chart["overs"][1]["now"], "current over flagged now")
	assert_eq(chart["overs"][1]["runs"], 4, "partial over runs so far")

func test_no_now_on_over_boundary() -> void:
	var log := _over_singles(1, 0)          # exactly one complete over
	var chart := MatchViewBuilder._build_chart(log, log.size(), 1, 0)
	assert_false(chart["overs"][chart["overs"].size() - 1]["now"], "no partial over at a boundary")

func test_target_rr_second_innings() -> void:
	# first_total 160 → target 161 → 161*6/120 = 8.05
	var chart := MatchViewBuilder._build_chart(_over_singles(1, 0), 6, 2, 160)
	assert_almost_eq(chart["target_rr"], 8.05, 0.01, "chase RR over 20 overs")
	assert_eq(chart["innings"], 2, "innings tag 2")

func test_par_rr_first_innings() -> void:
	var chart := MatchViewBuilder._build_chart(_over_singles(1, 0), 6, 1, 0)
	assert_almost_eq(chart["target_rr"], MatchViewBuilder.PAR_RR, 0.01, "1st-innings par benchmark")
	assert_eq(chart["innings"], 1, "innings tag 1")

func test_empty_innings_no_crash() -> void:
	var chart := MatchViewBuilder._build_chart([], 0, 1, 0)
	assert_eq(chart["overs"].size(), 0, "no overs")
	assert_gt(chart["y_max"], 0.0, "y_max sane even with no data")
