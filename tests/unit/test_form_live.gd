extends GutTest

# DF6 -- live persistence: form chains across matches within a season, settles onto
# the Player, and reproduces under resim/replay (nothing new serialized -- replay
# re-derives the chain from season-start zero).

func _opps() -> Array:
	var out: Array = []
	for k in 7:
		var t := Team.new()
		t.team_name = "Opp %d" % (k + 1)
		t.stars = 2.5
		out.append(t)
	return out

func _team() -> Team:
	var t := Team.new()
	t.team_name = "My XI"
	t.stars = 2.5
	return t

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 40; a.composure = 30; a.attack = 20; a.control = 10
	return a

func _player() -> Player:
	var p := Player.new()
	var n := NamePair.new(); n.first_name = "Test"; n.surname = "Player"
	p.name = n
	p.attributes = _attrs()
	p.affinity = 3
	return p

func _start() -> SeasonPlay:
	return SeasonPlay.start(_attrs(), _team(), _opps(),
		TourDistribution.new(), BallTuning.new(), InningsTuning.new(), 20260703)

func test_fresh_session_rederives_the_same_match() -> void:
	var sp := _start()
	sp.enable_form(_player())
	var s1 := sp.make_session()
	var end1: float = s1.result().form_end
	s1.decide_boost(1, 3)  # a decision resims s1 from the SAME match-start points
	var s2 := sp.make_session()
	assert_almost_eq(s2.result().form_end, end1, 0.0001,
		"a fresh session re-derives the same match from the same start points")

func test_form_chains_between_matches_and_settles_on_player() -> void:
	var p := _player()
	var sp := _start()
	sp.enable_form(p)
	var s1 := sp.make_session()
	var end1: float = s1.result().form_end
	sp.commit_player_result(s1.result(), s1.export_decisions())
	assert_almost_eq(p.form_points, end1, 0.0001, "match 1 form_end settled onto the Player")
	assert_eq(p.form, roundi(clampf(end1, -3.0, 3.0)), "display int synced")
	assert_almost_eq(sp.form_points_now(), end1, 0.0001, "the driver carries the chain")

func test_affinity_feeds_the_base_mult() -> void:
	var p := _player()   # affinity 3 -> x1.03
	var sp := _start()
	sp.enable_form(p)
	var s := sp.make_session()
	# the base mult is invisible from outside the sim; pin the seeding rule instead
	assert_almost_eq(FormState.affinity_mult(p.affinity), 1.03, 0.0001)
	assert_not_null(s)

func test_replay_reproduces_form() -> void:
	var p := _player()
	var sp := _start()
	sp.enable_form(p)
	for i in 2:
		var s := sp.make_session()
		sp.commit_player_result(s.result(), s.export_decisions())
	var snap: float = p.form_points
	var p2 := _player()
	var sp2 := SeasonPlay.replay(_attrs(), _team(), _opps(),
		TourDistribution.new(), BallTuning.new(), InningsTuning.new(), 20260703,
		null, sp.decisions_log(), p2)
	assert_almost_eq(sp2.form_points_now(), snap, 0.0001, "replay re-derives the same chain")
	assert_almost_eq(p2.form_points, snap, 0.0001, "and settles it onto the loaded Player")

func test_form_off_is_untouched() -> void:
	var sp := _start()
	var s := sp.make_session()
	assert_almost_eq(s.result().form_end, 0.0, 0.0001, "no enable_form -> form never threads")

func test_state_flag_round_trips() -> void:
	var sp := _start()
	assert_false(sp.to_state(0, 0).form_enabled, "form off -> flag off (old saves stay byte-identical)")
	sp.enable_form(_player())
	assert_true(sp.to_state(0, 0).form_enabled, "form on -> flag stamped for resume parity")
