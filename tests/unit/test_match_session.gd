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

# -- Key Moments (spec 2026-06-16) ------------------------------------------

func _km_cursor(s: MatchSession, kind_contains: String) -> int:
	for c in range(s.events().size()):
		var o := s.key_moment_offer(c)
		if not o.is_empty() and (kind_contains in o["title"]):
			return c
	return -1

func test_powerplay_exit_offer_fires():
	var s := _session()
	var c := _km_cursor(s, "Powerplay")
	assert_gt(c, -1, "a Powerplay Exit moment is offered")
	var o := s.key_moment_offer(c)
	assert_eq(o["from_over"], 7, "PP Exit overrides from over 7")
	assert_eq(o["choices"].size(), 2, "two choices")

func test_death_plan_offer_fires():
	var s := _session()
	var c := _km_cursor(s, "Death")
	assert_gt(c, -1, "a Death Plan moment is offered")
	assert_eq(s.key_moment_offer(c)["from_over"], 16, "Death Plan overrides from over 16")

func test_decide_key_moment_prefix_byte_identical():
	var s := _session()
	var c := _km_cursor(s, "Powerplay")
	var o := s.key_moment_offer(c)
	var before := s.result().ball_log_innings1.duplicate(true)
	s.decide_key_moment(o["from_over"], BallResolver.Intent.AGGRESSIVE)
	var after := s.result().ball_log_innings1
	for i in range(before.size()):
		if before[i]["over"] < o["from_over"]:
			assert_eq(after[i], before[i], "prefix ball %d unchanged" % i)
		else:
			break

func test_decide_key_moment_changes_the_future():
	var s := _session()
	var _c := _km_cursor(s, "Powerplay")
	var base_total := s.result().innings1.total
	s.decide_key_moment(7, BallResolver.Intent.AGGRESSIVE)
	assert_ne(s.result().innings1.total, base_total, "an Aggressive middle changed the batting total")

func test_offer_clears_after_decision():
	var s := _session()
	var c := _km_cursor(s, "Powerplay")
	s.decide_key_moment(7, BallResolver.Intent.DEFENSIVE)
	assert_true(s.key_moment_offer(c).is_empty(), "a decided moment no longer offers")

func test_empty_km_is_byte_identical_to_no_plan():
	var s := _session()
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var rng := RandomNumberGenerator.new(); rng.seed = 20260615
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	# Mirror the session's exact policies (empty boost, scoped-empty DRS) but pass a
	# NULL intent plan — isolating the IntentPlan(empty-km) swap. If they match, an
	# empty Key Moment plan is byte-identical to no intent plan at all.
	var boost := BoostPlan.new()
	var drs := DRSPolicy.new()
	drs.review_balls = []
	var l1: Array = []; var l2: Array = []
	MatchResolver.simulate_match_teams(a, team, opp, tour, BallTuning.new(), InningsTuning.new(),
		rng, null, null, [], null, null, null, boost, drs,
		null, null, null, 1, null, l1, l2)
	assert_eq(s.result().ball_log_innings1, l1, "no-decision KM session == null-intent baseline (byte-identical)")

# -- Opponent brain (difficulty-scaled, spec 2026-06-17) --------------------

func _adaptive_spec() -> TourSpec:
	var spec := TourSpec.new()
	spec.brain_tier = TourSpec.Tier.ADAPTIVE
	spec.blend = 1.0   # fixed tier, blend 1.0 draws NO RNG -> stream-neutral + deterministic
	return spec

# Opponent bats FIRST (force=0) and is a strong 4.5★ side (opp index 6) so it plays a
# full innings that reaches the middle overs — where the adaptive B/A/B plan diverges
# from the brainless all-BALANCED default (the powerplay is BALANCED in both).
func _spec_session(spec) -> MatchSession:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[6]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	return MatchSession.start(a, team, opp, tour, 20260615, 0, null, null, spec)

func test_opp_brain_changes_the_match():
	var s_null := _spec_session(null)
	var s_brain := _spec_session(_adaptive_spec())
	assert_ne(s_brain.result().ball_log_innings1, s_null.result().ball_log_innings1,
		"opponent's full innings now follows its own adaptive plan -> differs from the brainless default")

func test_opp_brain_deterministic():
	var a := _spec_session(_adaptive_spec())
	var b := _spec_session(_adaptive_spec())
	assert_eq(a.result().ball_log_innings1, b.result().ball_log_innings1,
		"same spec + seed -> identical opponent innings (re-sim stays stable)")

# -- Review outcome query (spec 2026-06-17) ---------------------------------

func test_ball_is_wicket_reflects_log():
	var s := _session()
	var c := _first_dismissal_cursor(s)
	assert_gt(c, -1, "a dismissal exists")
	var e: Dictionary = s.events()[c]
	var bid := [e["over"], e["ball"]]
	assert_true(s.ball_is_wicket(bid), "the dismissal ball reads as a wicket before any review")

# -- Bowling Key Moments (spec 2026-06-18) ----------------------------------
# Bowling moments fire in the OPPOSITION batting innings, and need rotation mode on
# (which only the opponent brain activates), so these use a spec'd session: opp bats
# FIRST (force=0) as a full innings, adaptive brain spec, mirror of _spec_session.

func test_empty_bowling_km_is_byte_identical_to_textbook_plan():
	var spec := _adaptive_spec()
	var s := _spec_session(spec)   # force=0, opp index 6, spec'd (rotation on)
	# Rebuild the same match but pass an explicit textbook player bowling plan (no KM).
	# If the session (empty bowling-KM) matches it, an empty plan is byte-identical.
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var rng := RandomNumberGenerator.new(); rng.seed = 20260615
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[6]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	var plans := OpponentBrain.draw_plans(spec.brain_tier, spec.blend, rng)
	var boost := BoostPlan.new()
	var drs := DRSPolicy.new(); drs.review_balls = []
	var l1: Array = []; var l2: Array = []
	MatchResolver.simulate_match_teams(a, team, opp, tour, BallTuning.new(), InningsTuning.new(),
		rng, IntentPlan.new(), BowlingPlan.new(), [], null, null, plans[0], boost, drs,
		null, null, null, 0, plans[1], l1, l2)
	assert_eq(s.result().ball_log_innings1, l1, "empty bowling-KM session == explicit textbook bowling plan (byte-identical)")

func _bowl_km_cursor(s: MatchSession, kind_contains: String) -> int:
	for c in range(s.events().size()):
		var o := s.key_moment_offer(c)
		if not o.is_empty() and o.get("lever", "intent") == "bowling" and (kind_contains in o["title"]):
			return c
	return -1

func test_bowling_powerplay_exit_offer_fires():
	var s := _spec_session(_adaptive_spec())   # opp bats first, full innings
	var c := _bowl_km_cursor(s, "Powerplay")
	assert_gt(c, -1, "a bowling Powerplay Exit moment is offered")
	var o := s.key_moment_offer(c)
	assert_eq(o["from_over"], 7, "bowling PP Exit overrides from over 7")
	assert_eq(o["lever"], "bowling", "tagged as a bowling lever")
	assert_eq(o["choices"].size(), 2, "two choices")
	assert_true(o["choices"][0].has("kind"), "bowling choices carry a kind, not a band")

func test_bowling_death_defence_offer_fires():
	var s := _spec_session(_adaptive_spec())
	var c := _bowl_km_cursor(s, "Death")
	assert_gt(c, -1, "a bowling Death Defence moment is offered")
	assert_eq(s.key_moment_offer(c)["from_over"], 16, "Death Defence overrides from over 16")

func test_decide_bowling_key_moment_prefix_byte_identical():
	var s := _spec_session(_adaptive_spec())
	var c := _bowl_km_cursor(s, "Powerplay")
	var o := s.key_moment_offer(c)
	# opp bats innings1 here (force=0), so the bowling innings log is ball_log_innings1
	var before := s.result().ball_log_innings1.duplicate(true)
	s.decide_bowling_key_moment(o["from_over"], BowlingPlan.Kind.SPIN)
	var after := s.result().ball_log_innings1
	for i in range(before.size()):
		if before[i]["over"] < o["from_over"]:
			assert_eq(after[i], before[i], "prefix ball %d unchanged" % i)
		else:
			break

func test_decide_bowling_key_moment_changes_the_future():
	var s := _spec_session(_adaptive_spec())
	var c := _bowl_km_cursor(s, "Death")
	assert_gt(c, -1, "a Death Defence moment exists to decide")
	var before := s.result().ball_log_innings1.duplicate(true)
	# Force the death overs to spin (away from textbook pace) — the opp innings (the balls
	# from over 16 on) must diverge. (The TOTAL can coincidentally re-land at this seed; the
	# honest proof of "your call changed the match" is that the future balls differ.)
	s.decide_bowling_key_moment(16, BowlingPlan.Kind.SPIN)
	assert_ne(s.result().ball_log_innings1, before, "a spin death changed the opposition innings")

func test_bowling_offer_clears_after_decision():
	var s := _spec_session(_adaptive_spec())
	var c := _bowl_km_cursor(s, "Powerplay")
	s.decide_bowling_key_moment(7, BowlingPlan.Kind.SPIN)
	assert_true(s.key_moment_offer(c).is_empty(), "a decided bowling moment no longer offers")

# -- export / apply decisions (cross-session save, spec 2026-06-23) ----------
# A MatchSession is replayable from the small set of player decisions it holds.
# export_decisions() snapshots them; apply_decisions() on a fresh same-seed session
# reproduces the decided result (the determinism the save system relies on).

func _result_signature(r: MatchResult) -> Array:
	return [r.outcome, r.player_bats_first, r.innings1.total, r.innings1.wickets,
		r.innings2.total, r.innings2.wickets]

func test_export_apply_reproduces_a_decided_match():
	var a := _session()
	a.decide_boost(1, 3)
	a.decide_key_moment(7, BallResolver.Intent.AGGRESSIVE)
	var d := a.export_decisions()
	# A fresh session on the SAME seed, replayed from the exported decisions.
	var b := _session()
	b.apply_decisions(d)
	assert_eq(_result_signature(b.result()), _result_signature(a.result()),
		"apply(export) reproduces the decided result")
	assert_eq(b.events().size(), a.events().size(), "and the same event stream")
	assert_eq(b.result().ball_log_innings1, a.result().ball_log_innings1,
		"byte-identical batting innings")

func test_apply_empty_decisions_is_a_noop():
	var s := _session()
	var before := s.result().ball_log_innings1.duplicate(true)
	s.apply_decisions({})
	assert_eq(s.result().ball_log_innings1, before, "empty decisions leave the match unchanged")

func test_apply_then_export_round_trips_all_four_channels():
	var s := _session()
	var d := {
		"presses": [[1, 4]],
		"review_balls": [[5, 2]],
		"km": [{"from_over": 7, "band": BallResolver.Intent.DEFENSIVE}],
		"bowl_km": [{"from_over": 16, "kind": BowlingPlan.Kind.SPIN}],
	}
	s.apply_decisions(d)
	assert_eq(s.export_decisions(), d, "apply then export returns the same decision record")
	assert_eq(s.reviews_left(), MatchSession.REVIEW_BUDGET - 1,
		"applied review_balls count against the budget")


# --- Player jokers fire in the live match (spec 2026-06-26, Rung 1) ---

func _fixture() -> Array:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	return [a, team, opp, tour]

func test_empty_player_effects_is_byte_identical() -> void:
	var f := _fixture()
	var base := MatchSession.start(f[0], f[1], f[2], f[3], 7777, 1)
	var with_empty := MatchSession.start(f[0], f[1], f[2], f[3], 7777, 1, null, null, null, [])
	assert_eq(with_empty.result().innings1.total, base.result().innings1.total)
	assert_eq(with_empty.result().innings2.total, base.result().innings2.total)

func test_block_the_shine_raises_player_batting_total_over_seeds() -> void:
	var f := _fixture()
	var effects := JokerCatalog.effects_of_ids(["block_the_shine"])
	var sum_base := 0
	var sum_joker := 0
	for s in range(20):
		var seed := 4200 + s
		var base := MatchSession.start(f[0], f[1], f[2], f[3], seed, 1)
		var jk := MatchSession.start(f[0], f[1], f[2], f[3], seed, 1, null, null, null, effects)
		sum_base += base.result().innings1.total
		sum_joker += jk.result().innings1.total
	assert_gt(sum_joker, sum_base, "block_the_shine (fewer early wickets) lifts the player's total")
