extends GutTest

var rt: RatingTuning

func before_each() -> void:
	rt = RatingTuning.new()
	rt.sr_par = 120.0
	rt.rr_par = 7.5
	rt.wicket_value = 10.0

func _bat(runs: int, balls: int) -> Dictionary:
	return {"is_player": true, "runs": runs, "balls": balls, "out": true}

func test_batting_value_is_runs_above_par_for_balls_faced() -> void:
	# 60 off 40 at sr_par 120 -> 60 - 1.2*40 = 12. No bowling.
	var r := PlayerRating.rate(_bat(60, 40), 0, 0, 0, rt)
	assert_almost_eq(r["batting"], 12.0, 0.0001, "runs above par")
	assert_almost_eq(r["bowling"], 0.0, 0.0001, "no bowling -> 0")
	assert_almost_eq(r["rating"], 12.0, 0.0001, "rating = batting only")

func test_bowling_value_is_runs_saved_plus_wickets() -> void:
	# 4 overs (24 balls), conceded 20, 2 wkts: (7.5/6)*24 - 20 + 2*10 = 30 - 20 + 20 = 30.
	var r := PlayerRating.rate({}, 2, 20, 24, rt)
	assert_almost_eq(r["batting"], 0.0, 0.0001, "empty bat line -> 0")
	assert_almost_eq(r["bowling"], 30.0, 0.0001, "runs saved + wickets")
	assert_almost_eq(r["rating"], 30.0, 0.0001, "rating = bowling only")

func test_allrounder_blends_both() -> void:
	# bat 30 off 25 -> 30 - 1.2*25 = 0; bowl 12 balls, 14 conceded, 1 wkt -> 1.25*12 - 14 + 10 = 11.
	var r := PlayerRating.rate(_bat(30, 25), 1, 14, 12, rt)
	assert_almost_eq(r["batting"], 0.0, 0.0001, "bat at par -> 0")
	assert_almost_eq(r["bowling"], 11.0, 0.0001, "bowling impact")
	assert_almost_eq(r["rating"], 11.0, 0.0001, "rating = sum")

func test_wicket_value_scales_bowling() -> void:
	# Same bowling line, wicket_value 14 -> 30 - 20 + 2*14 = 38. Confirms the parity knob.
	rt.wicket_value = 14.0
	var r := PlayerRating.rate({}, 2, 20, 24, rt)
	assert_almost_eq(r["bowling"], 38.0, 0.0001, "higher wicket value -> higher bowling rating")
