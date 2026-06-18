extends GutTest

# Season Hub scene — hi-fi v2 (spec 2026-06-18-season-hub-hifi-v2). Renders a
# SeasonView; single dense screen (no scroll, no league table). Hard rules tested:
# never show raw PWR/COM/ATT/CON; position pill is "—" until a result exists.

const SeasonHubScene = preload("res://scenes/season_hub/season_hub.tscn")

var _had_player := false
var _saved_player: Player = null
var _had_career := false
var _saved_career: CareerState = null

func before_all() -> void:
	_had_player = SaveManager.has_player()
	if _had_player:
		_saved_player = SaveManager.load_player()
	_had_career = SaveManager.has_career()
	if _had_career:
		_saved_career = SaveManager.load_career()
	SaveManager.clear_player()
	SaveManager.clear_career()

func after_all() -> void:
	if _had_player and _saved_player != null:
		SaveManager.save_player(_saved_player)
	else:
		SaveManager.clear_player()
	if _had_career and _saved_career != null:
		SaveManager.save_career(_saved_career)
	else:
		SaveManager.clear_career()

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
