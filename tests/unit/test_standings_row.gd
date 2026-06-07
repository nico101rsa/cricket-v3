extends GutTest

func test_nrr_sign_and_zero_guard() -> void:
	var r := StandingsRow.new()
	# Scored 200 off 240 balls; conceded 150 off 240 -> positive NRR.
	r.runs_for = 200
	r.balls_for = 240
	r.runs_against = 150
	r.balls_against = 240
	assert_gt(r.nrr(), 0.0, "more runs/over for than against -> positive NRR")

	var s := StandingsRow.new()
	s.runs_for = 150
	s.balls_for = 240
	s.runs_against = 200
	s.balls_against = 240
	assert_lt(s.nrr(), 0.0, "fewer runs/over for than against -> negative NRR")

	var empty := StandingsRow.new()
	assert_eq(empty.nrr(), 0.0, "no balls -> 0.0, no divide-by-zero")
