extends GutTest

# Season Outcome screen (live-season-loop Slice 2). Shown when the live SeasonPlay
# finishes — surfaces final position + ₸ banked, with a Continue button.

const OutcomeScene = preload("res://scenes/outcome/outcome.tscn")

func _result(pos: int) -> SeasonResult:
	var sr := SeasonResult.new()
	sr.player_final_position = pos
	sr.beat = pos <= 3
	sr.won_final = pos == 1
	return sr

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_renders_position_and_pay() -> void:
	var screen = OutcomeScene.instantiate()
	add_child_autofree(screen)
	screen.set_outcome(_result(1), 412, 8)
	await get_tree().process_frame
	var labels := _all_label_text(screen)
	assert_true(labels.contains("CHAMPIONS"), "champion headline shown for 1st")
	assert_true(labels.contains("412"), "₸ banked shown")
	assert_true(labels.contains("8 of 9 won"), "record shows wins of games (top-4 plays 9)")
	var cta := screen.find_child("ContinueBtn", true, false)
	assert_not_null(cta, "continue button present")
	assert_gt(cta.size.y, 0.0, "continue button not collapsed")

func test_missed_playoffs_headline_and_seven_games() -> void:
	var screen = OutcomeScene.instantiate()
	add_child_autofree(screen)
	screen.set_outcome(_result(6), 300, 3)
	await get_tree().process_frame
	var labels := _all_label_text(screen)
	assert_true(labels.contains("MISSED THE PLAYOFFS"), "missed-playoffs headline for 6th")
	assert_true(labels.contains("3 of 7 won"), "5th-8th played 7 league games only")
	assert_true(labels.contains("6th"), "ordinal finish shown")

func test_continue_emits() -> void:
	var screen = OutcomeScene.instantiate()
	add_child_autofree(screen)
	screen.set_outcome(_result(2), 200, 6)
	await get_tree().process_frame
	watch_signals(screen)
	var cta := screen.find_child("ContinueBtn", true, false)
	cta.pressed.emit()
	assert_signal_emitted(screen, "continue_pressed")
