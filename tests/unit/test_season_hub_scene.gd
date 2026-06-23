extends GutTest

# Season Hub scene — hi-fi v2 (spec 2026-06-18-season-hub-hifi-v2). Renders a
# SeasonView; single dense screen (no scroll, no league table). Hard rules tested:
# never show raw PWR/COM/ATT/CON; position pill is "—" until a result exists.

const SeasonHubScene = preload("res://scenes/season_hub/season_hub.tscn")

var _had_player := false
var _saved_player: Player = null
var _had_career := false
var _saved_career: CareerState = null
var _had_live := false
var _saved_live: LiveSeasonState = null

func before_all() -> void:
	_had_player = SaveManager.has_player()
	if _had_player:
		_saved_player = SaveManager.load_player()
	_had_career = SaveManager.has_career()
	if _had_career:
		_saved_career = SaveManager.load_career()
	_had_live = SaveManager.has_live_season()
	if _had_live:
		_saved_live = SaveManager.load_live_season()
	SaveManager.clear_player()
	SaveManager.clear_career()
	SaveManager.clear_live_season()

func after_all() -> void:
	if _had_player and _saved_player != null:
		SaveManager.save_player(_saved_player)
	else:
		SaveManager.clear_player()
	if _had_career and _saved_career != null:
		SaveManager.save_career(_saved_career)
	else:
		SaveManager.clear_career()
	if _had_live and _saved_live != null:
		SaveManager.save_live_season(_saved_live)
	else:
		SaveManager.clear_live_season()

func _player() -> Player:
	var p := Player.new()
	var n := NamePair.new(); n.first_name = "Bongani"; n.surname = "Kgosi"
	p.name = n; p.city = "Durban"; p.country = Country.Code.SA
	p.tons_balance = 120; p.affinity = 3
	var a := Attributes.new(); a.power = 40; a.composure = 30; a.attack = 20; a.control = 10
	p.attributes = a
	return p

func _empty_season() -> SeasonResult:
	var sr := SeasonResult.new(); var lr := LeagueResult.new()
	lr.standings = []; lr.player_matches = []; sr.league = lr
	return sr

func _view() -> SeasonView:
	return SeasonViewBuilder.build(_player(), CareerResolver.start_career(0), _empty_season(), 0)

func _season7() -> SeasonResult:
	var sr := SeasonResult.new(); var lr := LeagueResult.new()
	var pms: Array = []
	for i in range(7):
		var m := MatchResult.new()
		m.player_bats_first = true
		m.innings1 = InningsResult.new(150, 5, 120, [], [
			{"position": 3, "is_player": true, "runs": 30, "balls": 24, "out": true}])
		m.innings2 = InningsResult.new(140, 8, 120, [], [], 2, 26, 24)
		m.outcome = MatchResult.Outcome.PLAYER_WIN
		pms.append(m)
	lr.player_matches = pms; lr.standings = []
	sr.league = lr
	return sr

# Gather all Label text under a node (for the no-raw-stats rule).
func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_scene_renders_view_and_panels_are_visible() -> void:
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	hub.set_view(_view())
	await get_tree().process_frame
	var root := hub.get_node("Margin/Root")
	assert_true(root.get_node("TonsPanel/TonsRow/TonsCol/TonsChip").text.contains("120"), "tons shows balance")
	assert_eq(root.get_node("FixturesPanel/FixturesWrap/FixturesRow/FixturesBox").get_child_count(), 7, "7 fixture nodes")
	assert_true(root.get_node("CardPanel/PlayerCard/CardInfo/NameLabel").is_visible_in_tree(), "name visible")
	for p in ["TopbarPanel", "TonsPanel", "FixturesPanel", "CardPanel", "JokersPanel", "AffinityPanel"]:
		assert_true(root.get_node(p).is_visible_in_tree(), p + " visible")
		assert_gt(root.get_node(p).size.y, 0.0, p + " not collapsed")
	# real portrait art present
	assert_true(root.get_node("CardPanel/PlayerCard/Portrait").is_visible_in_tree(), "portrait visible")
	assert_not_null(root.get_node("CardPanel/PlayerCard/Portrait/PortraitTex").texture, "portrait art bound")
	# position pill is "—" at season start (no fake "1st")
	assert_eq(root.get_node("TopbarPanel/Header/PosPill/PosCol/PosNum").text, "—", "no fake position pre-result")
	# HARD RULE: never show raw skill stats
	var labels := _all_label_text(root)
	assert_false(labels.contains("PWR"), "no raw PWR stat leaked")
	assert_false(labels.contains("COM "), "no raw COM stat leaked")

func test_step_advances_scrub_head() -> void:
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	hub.set_source(_player(), CareerResolver.start_career(0), _season7())
	assert_eq(hub.scrub_index(), 0, "boots at 0")
	hub.step(1)
	assert_eq(hub.scrub_index(), 1, "step advances the head")
	assert_true(hub.get_node("Margin/Root/TonsPanel/TonsRow/ContextCol/ProgressLabel").text.contains("of 7"),
		"progress readout present")

func test_live_play_shows_played_fixture_and_play_control() -> void:
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	var career := CareerResolver.start_career(0)
	var player := _player()
	var team: Team = career.teams[career.current_team_index]
	var sp := SeasonPlay.start(player.attributes, team, career.opponents_of_current(),
		TourDistribution.new(), BallTuning.new(), InningsTuning.new(), 20260616)
	sp.commit_player_result(sp.make_session().result())   # play 1 game
	hub.set_play(player, career, sp)
	await get_tree().process_frame
	var root := hub.get_node("Margin/Root")
	assert_true(hub.has_play_control(), "live play control present")
	assert_true(root.get_node("CTA/CtaCenter/CtaLines/CtaBig").text.contains("NEXT MATCH"),
		"CTA reads NEXT MATCH after a game")
	assert_true(root.get_node("TonsPanel/TonsRow/ContextCol/ProgressLabel").text.contains("2 of 7"),
		"progress reflects 1 played (about to play match 2)")
	assert_ne(root.get_node("TopbarPanel/Header/PosPill/PosCol/PosNum").text, "—", "a result exists → real position")

# Slice 2: after the league, a top-4 player's hub surfaces the playoff knockout
# as the PLAY control (CTA names the stage), not a dead "season complete".
func test_playoffs_phase_surfaces_knockout_play_control() -> void:
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	var career := CareerResolver.start_career(0)
	var player := _player()
	# A strong team vs weak opponents reaches top-4 deterministically at this seed
	# (mirrors test_season_play.gd's _start_strong / seed 20260616).
	var team := Team.new(); team.team_name = "Strong XI"; team.stars = 4.5
	var opps: Array = []
	for k in range(7):
		var o := Team.new(); o.team_name = "Opp %d" % (k + 1); o.stars = 1.5
		opps.append(o)
	var sp := SeasonPlay.start(player.attributes, team, opps,
		TourDistribution.new(), BallTuning.new(), InningsTuning.new(), 20260616)
	for k in range(7):
		sp.commit_player_result(sp.make_session().result())
	assert_eq(sp.phase(), "playoffs", "precondition: strong player is in the playoffs")
	hub.set_play(player, career, sp)
	await get_tree().process_frame
	assert_true(hub.has_play_control(), "playoff knockout is a pending play control")
	var big: String = hub.get_node("Margin/Root/CTA/CtaCenter/CtaLines/CtaBig").text
	assert_true(big.contains("SEMI-FINAL") or big.contains("FINAL") or big.contains("3RD"),
		"CTA names the knockout stage, got '%s'" % big)

func test_boots_a_real_season_when_player_saved() -> void:
	var p := _player()
	SaveManager.save_player(p)
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	hub.boot()
	assert_not_null(hub._view, "boot built a view")
	assert_eq(hub._view.fixtures.size(), 7)
	assert_false(hub._view.team_name.is_empty())
	SaveManager.clear_player()

# Cross-session save (spec 2026-06-23): boot() resumes an in-progress live season
# (saved as a decision log) instead of starting fresh — the "quit and relaunch" path.
func test_boot_resumes_an_in_progress_live_season() -> void:
	var player := _player()
	SaveManager.save_player(player)
	# Build + partially play a live season the same way the hub boots one (DifficultyLadder
	# cell), then persist it.
	var career := CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(career.current_level(), 0)
	var team: Team = career.teams[career.current_team_index]
	var sp := SeasonPlay.start(player.attributes, team, career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), 4242, spec)
	for i in range(3):
		sp.commit_player_result(sp.make_session().result(), {})
	SaveManager.save_live_season(sp.to_state(career.current_level(), 0))

	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	hub.boot()
	await get_tree().process_frame
	var resumed: SeasonPlay = hub.live_play()
	assert_not_null(resumed, "boot resumed a live season")
	assert_eq(resumed.played_count(), 3, "resumed mid-season at game 3, not a fresh start")
	SaveManager.clear_live_season()
	SaveManager.clear_player()
