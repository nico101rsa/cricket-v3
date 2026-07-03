extends GutTest

# DF6 headless -- the balance harness must measure the same game Nico plays:
# one FormState threads the player's league + playoff matches, fresh per season.
# Default OFF everywhere = every pre-existing headless caller stays byte-identical.

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

func _league_form_end(seed_v: int) -> float:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_v
	var fs := FormState.make(0.0)
	LeagueResolver.simulate_league(_attrs(), _team(), _opps(),
		TourDistribution.new(), BallTuning.new(), InningsTuning.new(), rng,
		null, null, null, [], Callable(), false, fs)
	return fs.points

func test_league_threads_form_across_player_fixtures() -> void:
	var a := _league_form_end(20260703)
	var b := _league_form_end(20260703)
	assert_almost_eq(a, b, 0.0001, "same seed -> same season-end form")
	assert_ne(a, 0.0, "7 player fixtures move form off neutral")

func test_season_threads_form_through_playoffs() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 20260703
	var fs := FormState.make(0.0)
	var sr := SeasonResolver.simulate_season(_attrs(), _team(), _opps(),
		TourDistribution.new(), BallTuning.new(), InningsTuning.new(), rng,
		null, null, null, [], Callable(), false, fs)
	assert_not_null(sr)
	assert_ne(fs.points, 0.0, "the season moved form")

func test_career_season_runs_form_without_persisting_to_player() -> void:
	var p := Player.new()
	var n := NamePair.new(); n.first_name = "Head"; n.surname = "Less"
	p.name = n
	p.attributes = _attrs()
	p.affinity = 2
	var state := CareerResolver.start_career(0)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var out: Dictionary = CareerResolver.play_season(state, p, 0,
		BallTuning.new(), InningsTuning.new(), EconomyTuning.new(), rng,
		null, null, Callable(), null, true)
	assert_false(out.is_empty(), "season played")
	assert_almost_eq(p.form_points, 0.0, 0.0001,
		"headless careers never persist form onto the Player (fresh per season)")
