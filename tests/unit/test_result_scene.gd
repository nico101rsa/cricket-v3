extends GutTest

# Result screen (nav-shell spec 2026-07-03, Slice 2; mockup section 5): the
# post-match payoff — verdict, scoreline, your numbers, the tons earned, and a
# handoff CTA naming the destination. DN7: no KM recap / delta bars (not in the
# domain). DN5: champion variant on a Final win. No emoji.

const ResultScene = preload("res://scenes/result/result.tscn")

func _mr(player_won := true) -> MatchResult:
	var bat := InningsResult.new(174, 6, 120, [], [
		{"is_player": true, "runs": 68, "balls": 41, "out": false}])
	var bowl := InningsResult.new(151, 8, 120, [], [], 1, 19, 24)
	var m := MatchResult.new()
	m.innings1 = bat
	m.innings2 = bowl
	m.player_bats_first = true
	m.outcome = MatchResult.Outcome.PLAYER_WIN if player_won else MatchResult.Outcome.OPPONENT_WIN
	m.margin_runs = 23
	return m

func _pay() -> Dictionary:
	return {"base": 50, "perf": 18, "prize": 0, "total": 68}

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_verdict_scoreline_and_perf_grid() -> void:
	var screen = ResultScene.instantiate()
	add_child_autofree(screen)
	screen.set_result(_mr(), "Cape Gulls", "Karoo Kings", 4, "", _pay(), 1308, "", {})
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("YOU WON BY 23 RUNS"), "verdict from result_line_for_player")
	assert_true(text.contains("174/6"), "your scoreline")
	assert_true(text.contains("151/8"), "their scoreline")
	assert_true(text.contains("68"), "runs tile")
	assert_true(text.contains("166"), "strike rate tile (68 off 41 rounds to 166)")
	assert_true(text.contains("1/19"), "bowling figures wickets/runs")

func test_tons_earned_breakdown_and_bank() -> void:
	var screen = ResultScene.instantiate()
	add_child_autofree(screen)
	screen.set_result(_mr(), "Cape Gulls", "Karoo Kings", 4, "",
		{"base": 50, "perf": 18, "prize": 55, "total": 123}, 1308, "", {})
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("base 50 + perf 18"), "pay breakdown")
	assert_true(text.contains("win prize 55"), "win prize named on a win")
	assert_true(text.contains("+123"), "total earned hero")
	assert_true(text.contains("1,308"), "bank total shown with separator")

func test_cta_names_destination_and_emits() -> void:
	var screen = ResultScene.instantiate()
	add_child_autofree(screen)
	screen.set_result(_mr(), "Cape Gulls", "Karoo Kings", 4, "", _pay(), 0, "KIT ROOM", {})
	await get_tree().process_frame
	var cta: Button = screen.find_child("ContinueBtn", true, false)
	assert_not_null(cta, "continue button present")
	assert_true(cta.is_visible_in_tree(), "CTA visible")
	assert_gt(cta.size.y, 0.0, "CTA not collapsed")
	assert_true(cta.text.contains("KIT ROOM"), "destination named")
	watch_signals(screen)
	cta.pressed.emit()
	assert_signal_emitted(screen, "continue_pressed")

func test_champion_panel_only_on_final_win() -> void:
	var screen = ResultScene.instantiate()
	add_child_autofree(screen)
	screen.set_result(_mr(), "Cape Gulls", "Karoo Kings", 0, "final", _pay(), 0,
		"SEASON END", {"level_word": "Club", "tour_name": "Club Premier"})
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("CHAMPIONS"), "champion banner on Final win")
	assert_true(text.contains("CLUB PREMIER"), "the beaten cell named")
	var plain = ResultScene.instantiate()
	add_child_autofree(plain)
	plain.set_result(_mr(), "Cape Gulls", "Karoo Kings", 4, "", _pay(), 0, "", {})
	await get_tree().process_frame
	assert_false(_all_label_text(plain).contains("CHAMPIONS"), "no banner on a league win")

func test_loss_verdict_names_the_opponent() -> void:
	var screen = ResultScene.instantiate()
	add_child_autofree(screen)
	screen.set_result(_mr(false), "Cape Gulls", "Karoo Kings", 4, "", _pay(), 0, "", {})
	await get_tree().process_frame
	assert_true(_all_label_text(screen).contains("OPPONENT WON BY"), "loss names the opponent")
