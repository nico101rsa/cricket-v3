extends GutTest

# DI3 seam + DRS decision moments (spec 2026-07-04 DT2/DT4/DT6):
# - review_balls scopes the Player's batting-side survive review (scripted mode)
# - auto mode (null) now reviews only MOMENT wickets (reviewable flavour + set/death
#   gate, DRSMoments.is_moment) at the hash-drawn moment p
# - moment_p_override (>= 0) forces every moment p -- the deterministic test seam.

func test_review_balls_defaults_to_null():
	var d := DRSPolicy.new()
	assert_eq(d.review_balls, null, "auto by default (null)")

func test_moment_p_override_defaults_off():
	assert_lt(DRSPolicy.new().moment_p_override, 0.0, "hash-drawn p by default")

func test_review_balls_can_be_set():
	var d := DRSPolicy.new()
	d.review_balls = [[9, 3]]
	assert_eq(d.review_balls, [[9, 3]])

# Helper: run a full match, Player forced to bat first (innings1 = Player batting),
# moment p forced to 1.0 (every attempted review succeeds). Returns MatchResult
# with captured logs.
func _run(review_balls, p_override := 1.0) -> MatchResult:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	var drs := DRSPolicy.new()
	drs.moment_p_override = p_override
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

# Balls faced by this entry's striker BEFORE this delivery (mirrors the resolver's
# s["balls"] at review time).
func _faced_before(log: Array, idx: int) -> int:
	var pos: int = log[idx]["striker_pos"]
	var n := 0
	for i in range(idx):
		if log[i]["striker_pos"] == pos:
			n += 1
	return n

func _is_moment_wicket(log: Array, idx: int) -> bool:
	var b: Dictionary = log[idx]
	if not b["wicket"]:
		return false
	return DRSMoments.is_moment(
		DRSMoments.flavour_of(b["player_batting"], b["over"], b["ball_in_over"]),
		_faced_before(log, idx), b["over"])

func test_auto_overturns_only_moment_wickets():
	# p=1.0: every ATTEMPTED review succeeds (and is retained), so any standing
	# wicket in auto mode must be a non-moment one.
	var stood := _run([], 1.0)            # scripted-empty control: every wicket stands
	var auto := _run(null, 1.0)
	assert_gt(stood.innings1.wickets, 0, "control innings has wickets")
	# In the auto run every logged wicket must fail the moment gate (moments got
	# overturned and re-simmed away).
	var log: Array = auto.ball_log_innings1
	for i in range(log.size()):
		if log[i]["wicket"] and log[i]["player_batting"]:
			assert_false(_is_moment_wicket(log, i),
				"a standing auto wicket at %d.%d must be a non-moment dismissal" \
				% [log[i]["over"], log[i]["ball_in_over"]])

func test_auto_p_zero_never_overturns():
	# p=0.0 is below AI_BURN_P -> auto never even attempts; byte-identical wickets
	# to the scripted-empty control.
	var stood := _run([], 0.0)
	var auto := _run(null, 0.0)
	assert_eq(auto.innings1.wickets, stood.innings1.wickets,
		"below-threshold p attempts nothing")

func test_scripted_empty_lets_wickets_stand():
	var mr := _run([], 1.0)
	assert_gt(mr.innings1.wickets, 0, "no scripted reviews -> wickets stand")

func test_scripted_one_ball_overturns_only_that_ball():
	var stood := _run([], 1.0)                 # find the first dismissal in the innings
	var bid := []
	for b in stood.ball_log_innings1:
		if b["wicket"]:
			bid = [b["over"], b["ball_in_over"]]
			break
	assert_false(bid.is_empty(), "the seed must produce a dismissal")
	var mr := _run([bid], 1.0)
	# that exact delivery is now NOT a wicket in the log
	for b in mr.ball_log_innings1:
		if b["over"] == bid[0] and b["ball_in_over"] == bid[1]:
			assert_false(b["wicket"], "scripted review overturned the dismissal")
	assert_lt(mr.innings1.wickets, stood.innings1.wickets, "one fewer wicket")
