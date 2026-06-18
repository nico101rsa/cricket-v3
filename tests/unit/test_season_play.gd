extends GutTest

# SeasonPlay — the live LEAGUE-phase driver for the forward-play Season Hub
# (spec 2026-06-16-live-league-loop). Pure: no scene tree, no SaveManager.

func _opps() -> Array:
	var out: Array = []
	for k in range(7):
		var t := Team.new()
		t.team_name = "Opp %d" % (k + 1)
		t.stars = 2.5
		out.append(t)
	return out

func _player_team() -> Team:
	var t := Team.new()
	t.team_name = "My XI"
	t.stars = 2.5
	return t

func _tour() -> TourDistribution:
	return TourDistribution.new()

func _start() -> SeasonPlay:
	return SeasonPlay.start(Attributes.new(), _player_team(), _opps(),
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)

# --- Task 1: construction + schedule ---

func test_start_schedules_seven_player_fixtures() -> void:
	var sp := _start()
	assert_eq(sp.total_player_fixtures(), 7, "7 league fixtures")
	assert_eq(sp.played_count(), 0, "none played at start")
	assert_false(sp.league_done(), "league not done at start")

func test_next_player_opponent_is_first_opponent() -> void:
	var sp := _start()
	var nxt := sp.next_player_opponent()
	assert_eq(nxt["name"], "Opp 1", "fixtures run in opponents order")
	assert_eq(nxt["team_index"], 1, "team_index 1 = first opponent")

# --- Task 2: AI resolution + running standings ---

func test_standings_has_eight_rows_and_is_sorted() -> void:
	var sp := _start()
	var lg := sp.live_league()
	assert_eq(lg.standings.size(), 8, "all 8 teams in the table")
	for i in range(lg.standings.size() - 1):
		assert_true(lg.standings[i].points >= lg.standings[i + 1].points,
			"standings sorted by points desc")

func test_no_ai_revealed_before_first_game() -> void:
	var sp := _start()
	var lg := sp.live_league()
	var total_played := 0
	for r in lg.standings:
		total_played += r.played
	assert_eq(total_played, 0, "nothing revealed before you play")

# --- Task 3: make_session + commit + determinism ---

func test_make_session_then_commit_advances() -> void:
	var sp := _start()
	var sess := sp.make_session()
	assert_not_null(sess, "a MatchSession for the next fixture")
	sp.commit_player_result(sess.result())
	assert_eq(sp.played_count(), 1, "one player game played")
	assert_eq(sp.next_player_opponent()["name"], "Opp 2", "advanced to opponent 2")

func test_full_league_finishes() -> void:
	var sp := _start()
	for k in range(7):
		sp.commit_player_result(sp.make_session().result())
	assert_true(sp.league_done(), "league done after 7 games")
	assert_eq(sp.next_player_opponent(), {}, "no next fixture")
	assert_eq(sp.live_league().standings.size(), 8, "final table intact")

func test_determinism_same_seed_same_table() -> void:
	var a := _start()
	var b := _start()
	for k in range(3):
		a.commit_player_result(a.make_session().result())
		b.commit_player_result(b.make_session().result())
	var ta := a.live_league().standings
	var tb := b.live_league().standings
	for i in range(8):
		assert_eq(ta[i].team_index, tb[i].team_index, "row %d team matches" % i)
		assert_eq(ta[i].points, tb[i].points, "row %d points match" % i)

func test_revealed_ai_grows_with_play() -> void:
	var sp := _start()
	sp.commit_player_result(sp.make_session().result())
	var total_played := 0
	for r in sp.live_league().standings:
		total_played += r.played
	# After 1 game: 3 AI fixtures (6 team-appearances) + your 1 game (2) = 8.
	assert_eq(total_played, 8, "3 AI + 1 player game revealed after game 1")

# --- Interactive opponent-brain floor (2026-06-18) ---
# The marquee 1-v-1 opponent always plays at least competent textbook cricket: the
# sub-textbook naive blend (a league-realism device) just hands a random, easily-beaten
# opponent and inflated the underdog's win-rate. Difficulty still SCALES above textbook.

func test_interactive_opponent_floored_to_textbook() -> void:
	var weak := TourSpec.new()
	weak.brain_tier = TourSpec.Tier.TEXTBOOK
	weak.blend = 0.4   # the actual Club entry tour: 60% random plays
	var f := SeasonPlay._floored_spec(weak)
	assert_eq(f.brain_tier, TourSpec.Tier.TEXTBOOK, "stays textbook")
	assert_eq(f.blend, 1.0, "naive blend removed -> full textbook (opponent never plays randomly)")

func test_interactive_opponent_keeps_higher_tier_scaling() -> void:
	var hard := TourSpec.new()
	hard.brain_tier = TourSpec.Tier.ADAPTIVE
	hard.blend = 0.5
	var f := SeasonPlay._floored_spec(hard)
	assert_eq(f.brain_tier, TourSpec.Tier.ADAPTIVE, "tier above textbook preserved (difficulty scales)")
	assert_eq(f.blend, 0.5, "blend above textbook preserved")

func test_floored_spec_passes_through_null() -> void:
	assert_null(SeasonPlay._floored_spec(null), "no spec -> no brain (unchanged)")
