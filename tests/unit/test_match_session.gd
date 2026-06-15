extends GutTest

# MatchSession — the interactive re-simulation controller (spec §3).

func _session() -> MatchSession:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	# force_player_bats_first = 1 → innings1 is the Player batting (deterministic offers)
	return MatchSession.start(a, team, opp, tour, 20260615, 1)

# -- Task 3: start / events / prefix stability ------------------------------

func test_start_produces_result_and_events():
	var s := _session()
	assert_not_null(s.result(), "a baseline match is simulated")
	assert_gt(s.events().size(), 0, "an event stream is built")

func test_player_bats_first_when_forced():
	var s := _session()
	assert_true(s.result().player_bats_first, "forced bats-first")

func test_decide_boost_leaves_prefix_byte_identical():
	var s := _session()
	var before := s.result().ball_log_innings1.duplicate(true)
	var k := 8
	s.decide_boost_over(k)
	var after := s.result().ball_log_innings1
	for i in range(before.size()):
		if before[i]["over"] < k:
			assert_eq(after[i], before[i], "prefix ball %d unchanged" % i)
		else:
			break

# -- Task 4: boost budgets + helpers ----------------------------------------

func test_boost_changes_score():
	var s := _session()
	var base_total := s.result().innings1.total
	s.decide_boost_over(2); s.decide_boost_over(5)
	assert_ne(s.result().innings1.total, base_total, "boost shifted the batting total")

func test_innings1_is_player_batting():
	var s := _session()
	assert_true(s.player_bats_this(1), "innings1 = Player batting when forced bats-first")
	assert_false(s.player_bats_this(2), "innings2 = Player bowling")

func test_presses_left_decrements_and_caps():
	var s := _session()
	assert_eq(s.presses_left(1), MatchSession.BOOST_BUDGET)
	s.decide_boost_over(2)
	assert_eq(s.presses_left(1), MatchSession.BOOST_BUDGET - 1)

func test_can_boost_respects_budget():
	var s := _session()
	s.decide_boost_over(2); s.decide_boost_over(3)
	assert_eq(s.presses_left(1), 0)
	assert_false(s.can_boost(1), "budget exhausted")

# -- Task 5: DRS review -----------------------------------------------------

func _first_dismissal_cursor(s: MatchSession) -> int:
	var ev := s.events()
	for i in range(ev.size()):
		var e: Dictionary = ev[i]
		if e["type"] == "ball" and e.get("player_batting", false) and e["wicket"]:
			return i
	return -1

func test_review_offer_fires_on_player_dismissal():
	var s := _session()
	var c := _first_dismissal_cursor(s)
	assert_gt(c, -1, "the seed produces a Player dismissal")
	var offer := s.review_offer(c)
	assert_false(offer.is_empty(), "an offer is returned at the dismissal cursor")
	assert_true(offer.has("ball_id"), "offer carries the ball_id")

func test_decide_review_overturn_or_burn():
	var s := _session()
	var c := _first_dismissal_cursor(s)
	var offer := s.review_offer(c)
	var bid: Array = offer["ball_id"]
	var reviews_before := s.reviews_left()
	s.decide_review(bid)
	var still_out := false
	for b in s.result().ball_log_innings1:
		if b["over"] == bid[0] and b["ball_in_over"] == bid[1]:
			still_out = b["wicket"]
	if still_out:
		assert_eq(s.reviews_left(), reviews_before - 1, "failed review burned one")
	else:
		assert_eq(s.reviews_left(), reviews_before - 1, "a committed review counts against budget")

func test_review_offer_stops_when_no_reviews_left():
	var s := _session()
	s._reviews_used = MatchSession.REVIEW_BUDGET
	assert_eq(s.reviews_left(), 0)
	var c := _first_dismissal_cursor(s)
	if c > -1:
		assert_true(s.review_offer(c).is_empty(), "no offer with 0 reviews left")

func test_decide_review_leaves_prefix_byte_identical():
	var s := _session()
	var c := _first_dismissal_cursor(s)
	var offer := s.review_offer(c)
	var bid: Array = offer["ball_id"]
	var before := s.result().ball_log_innings1.duplicate(true)
	s.decide_review(bid)
	var after := s.result().ball_log_innings1
	for i in range(before.size()):
		var b = before[i]
		if b["over"] < bid[0] or (b["over"] == bid[0] and b["ball_in_over"] < bid[1]):
			assert_eq(after[i], b, "prefix ball %d unchanged" % i)
		else:
			break
