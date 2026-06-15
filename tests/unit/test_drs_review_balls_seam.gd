extends GutTest

# DI3 seam — DRSPolicy.review_balls scopes the Player's batting-side review.

func test_review_balls_defaults_to_null():
	var d := DRSPolicy.new()
	assert_eq(d.review_balls, null, "auto by default (null) — sweeps untouched")

func test_review_balls_can_be_set():
	var d := DRSPolicy.new()
	d.review_balls = [[9, 3]]
	assert_eq(d.review_balls, [[9, 3]])

# Helper: run a full match, Player forced to bat first (innings1 = Player batting),
# DRS success guaranteed (base_p=1.0). Returns the MatchResult with captured logs.
func _run(review_balls) -> MatchResult:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	var drs := DRSPolicy.new()
	drs.base_p = 1.0
	drs.review_balls = review_balls
	var rng := RandomNumberGenerator.new(); rng.seed = 20260615
	var log1: Array = []
	var log2: Array = []
	var mr := MatchResolver.simulate_match_teams(
		a, team, opp, tour, BallTuning.new(), InningsTuning.new(), rng,
		null, null, [], null, null, null,
		null, drs, null, null, null, 1, null, log1, log2)
	mr.ball_log_innings1 = log1   # caller attaches captured logs (mirrors LeagueResolver)
	mr.ball_log_innings2 = log2
	return mr

func test_auto_null_overturns_every_player_wicket():
	var mr := _run(null)
	assert_eq(mr.innings1.wickets, 0, "base_p=1.0 auto -> all Player wickets overturned")

func test_scripted_empty_lets_wickets_stand():
	var mr := _run([])
	assert_gt(mr.innings1.wickets, 0, "no scripted reviews -> wickets stand")

func test_scripted_one_ball_overturns_only_that_ball():
	var stood := _run([])                      # find the first dismissal in the innings
	var bid := []
	for b in stood.ball_log_innings1:
		if b["wicket"]:
			bid = [b["over"], b["ball_in_over"]]
			break
	assert_false(bid.is_empty(), "the seed must produce a dismissal")
	var mr := _run([bid])
	# that exact delivery is now NOT a wicket in the log
	for b in mr.ball_log_innings1:
		if b["over"] == bid[0] and b["ball_in_over"] == bid[1]:
			assert_false(b["wicket"], "scripted review overturned the dismissal")
	assert_lt(mr.innings1.wickets, stood.innings1.wickets, "one fewer wicket")
