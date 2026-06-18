extends GutTest

# Tapping a PLAYED fixture row emits open_match(index). Spec §7.
const HUB := preload("res://scenes/season_hub/season_hub.tscn")

func _view_with_one_played() -> SeasonView:
	var v := SeasonView.new()
	v.team_name = "Karoo Kings"
	v.country = Country.Code.SA
	v.scrub_index = 1
	v.match_count = 7
	v.fixtures = [{"played": true, "player_won": true, "opponent_name": "Dusty Plains",
		"score_text": "165/2  v  162/1"}]
	v.standings = []
	return v

func test_played_row_emits_open_match() -> void:
	var hub = HUB.instantiate()
	add_child_autofree(hub)
	hub.set_view(_view_with_one_played())
	await get_tree().process_frame
	watch_signals(hub)
	var box: HBoxContainer = hub.get_node("Scroll/Margin/Root/FixturesPanel/FixturesWrap/FixturesBox")
	box.get_child(0).pressed.emit()
	assert_signal_emitted_with_parameters(hub, "open_match", [0])
