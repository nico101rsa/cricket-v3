extends GutTest

# Season Hub scene — renders a SeasonView, scrubs, and boots a real season
# (spec 2026-06-15-season-hub-replay §5/§7).

const SeasonHubScene = preload("res://scenes/season_hub/season_hub.tscn")

# --- Save isolation: the boot test writes user://player.tres. Snapshot the real
# save once and restore it after, so a dev's actual Player/Career is never lost. ---
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
	# Deterministic boot: no career saved → boot uses start_career(0).
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

# --- Task 7: render ---

func test_scene_renders_view_and_panels_are_visible() -> void:
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	hub.set_view(_view())
	await get_tree().process_frame   # let the containers lay out
	var root := hub.get_node("Scroll/Margin/Root")
	assert_true(root.get_node("Header/TonsChip").text.contains("120"), "tons chip shows balance")
	assert_true(root.get_node("FixturesBox").get_child_count() >= 7, "7 fixture rows")
	assert_gt(root.get_node("FixturesBox").size.y, 0.0, "fixtures box not collapsed")
	assert_true(root.get_node("PlayerCard/NameLabel").is_visible_in_tree(), "name visible")
	assert_true(root.get_node("ScrubBar/ScrubLabel").text.contains("0"), "scrub readout")

# --- Task 8: scrub ---

func test_next_advances_scrub_and_grows_card() -> void:
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	hub.set_source(_player(), CareerResolver.start_career(0), _season7())
	assert_eq(hub.scrub_index(), 0, "boots at 0")
	hub.step(1)
	assert_eq(hub.scrub_index(), 1, "next advances")
	var lbl := hub.get_node("Scroll/Margin/Root/ScrubBar/ScrubLabel")
	assert_true(lbl.text.contains("1"), "readout updated")

# --- Task 9: boot ---

func test_boots_a_real_season_when_player_saved() -> void:
	var p := _player()
	SaveManager.save_player(p)
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	hub.boot()   # router calls this after pushing the hub
	assert_not_null(hub._view, "boot built a view")
	assert_eq(hub._view.fixtures.size(), 7)
	assert_false(hub._view.team_name.is_empty())
	SaveManager.clear_player()
