extends GutTest

# Career Grid screen (nav-shell spec 2026-07-03, Slice 3): the between-Seasons
# home (ADR 0010) — career header, the ladder map, START SEASON. DN8: no node
# picking (the domain plays exactly next_live_cell). DN9: no career-stats
# block (no career aggregates exist). Header counters are all real.

const GridScene = preload("res://scenes/career_grid/career_grid.tscn")

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_header_shows_real_career_counters() -> void:
	var screen = GridScene.instantiate()
	add_child_autofree(screen)
	var c := CareerResolver.start_career(0)
	c.seasons_played = 7
	var p := Player.new()
	p.tons_balance = 1520
	p.country = Country.Code.SA
	screen.set_career(c, p)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("SOUTH AFRICA"), "country named (Country.display_name is upper)")
	assert_true(text.contains("7"), "seasons played")
	assert_true(text.contains(c.teams[c.current_team_index].team_name), "current team")
	assert_true(text.contains("0 / 3"), "levels won")
	assert_true(text.contains("1,520"), "tons balance with separator")

func test_ladder_map_present_and_not_collapsed() -> void:
	var screen = GridScene.instantiate()
	add_child_autofree(screen)
	screen.set_career(CareerResolver.start_career(0), Player.new())
	await get_tree().process_frame
	var map = screen.find_child("Map", true, false)
	assert_not_null(map, "ladder map mounted")
	assert_true(map.is_visible_in_tree(), "map visible")
	assert_gt(map.size.y, 0.0, "map not collapsed")

func test_cta_names_the_next_cell_and_emits() -> void:
	var screen = GridScene.instantiate()
	add_child_autofree(screen)
	screen.set_career(CareerResolver.start_career(0), Player.new())
	await get_tree().process_frame
	var cta: Button = screen.find_child("StartBtn", true, false)
	assert_not_null(cta, "start button present")
	assert_true(cta.is_visible_in_tree(), "start button visible")
	assert_gt(cta.size.y, 0.0, "start button not collapsed")
	assert_true(cta.text.contains("CLUB"), "level named on the CTA")
	assert_true(cta.text.contains("FLAT & WARM"), "tour named on the CTA")
	watch_signals(screen)
	cta.pressed.emit()
	assert_signal_emitted(screen, "start_season")
