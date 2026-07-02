extends GutTest

# Pre-Match screen (nav-shell spec 2026-07-03, Slice 1): the versus moment
# between hub PLAY and the match. Dumb: renders SeasonView + opponent info,
# emits start_pressed. DN1 every number real; DN2 no home/away; DN4 no back.

const PreMatchScene = preload("res://scenes/pre_match/pre_match.tscn")

func _view() -> SeasonView:
	var v := SeasonView.new()
	v.team_name = "Cape Gulls"
	v.team_stars = 2.5
	v.tour_name = "Club Flat & Warm"
	v.country = Country.Code.SA
	v.player_name = "K. Mthembu"
	v.power = 40.0
	v.composure = 35.0
	v.attack = 30.0
	v.control = 20.0
	v.affinity = 3
	v.jokers = [{"id": "j1", "name": "Review Master", "rarity": "common"}]
	return v

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_versus_header_names_both_teams() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("Cape Gulls"), "your team named")
	assert_true(text.contains("Karoo Kings"), "opponent named")
	assert_true(text.contains("MATCH 4"), "league match number shown")

func test_stakes_and_conditions_lines() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("Top 4 advance"), "league stakes line")
	assert_true(text.contains("Club Flat & Warm"), "conditions = real tour name")

func test_playoff_stage_replaces_match_number() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(),
		{"name": "Karoo Kings", "team_index": 3, "stage": "semi"}, 3.5, 8)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("SEMI-FINAL"), "semi named")
	assert_true(text.contains("Win to reach The Final"), "semi stakes line")

func test_captain_panel_shows_real_attrs_and_affinity() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("40"), "power value shown")
	assert_true(text.contains("K. Mthembu"), "player named")
	assert_true(text.contains("AFFINITY"), "affinity row present")

func test_danger_man_is_flavour_name_with_team_stars() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var danger = screen.find_child("DangerName", true, false)
	assert_not_null(danger, "danger-man label present")
	assert_eq(danger.text, PlayerNames.upper("Karoo Kings", Country.Code.SA, 0),
		"deterministic flavour surname")

func test_build_strip_counts_jokers() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("Review Master"), "owned joker named in build strip")

func test_cta_visible_and_emits_start() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var cta: Button = screen.find_child("StartBtn", true, false)
	assert_not_null(cta, "start button present")
	assert_true(cta.is_visible_in_tree(), "start button visible")
	assert_gt(cta.size.y, 0.0, "start button not collapsed")
	watch_signals(screen)
	cta.pressed.emit()
	assert_signal_emitted(screen, "start_pressed")
