extends GutTest

const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const LegendEntry = preload("res://scripts/data/legend_entry.gd")

func before_each() -> void:
	SaveManager.player_save_path = "user://_test_lc_player.tres"
	SaveManager.legends_save_path = "user://_test_lc_legends.tres"
	SaveManager.career_save_path = "user://_test_lc_career.tres"
	SaveManager.clear_player()
	SaveManager.clear_legends()
	SaveManager.clear_career()

func after_each() -> void:
	SaveManager.clear_player()
	SaveManager.clear_legends()
	SaveManager.clear_career()

func _seeded_player() -> void:
	var d := PlayerCreationDraft.new()
	var n := NamePair.new(); n.first_name = "Jonty"; n.surname = "Springer"
	d.name = n
	SaveManager.save_player(Player.from_draft(d))

func test_manual_retire_clears_player_and_archives_with_retired_reason():
	_seeded_player()
	watch_signals(LifecycleManager)
	LifecycleManager.manual_retire()
	assert_false(SaveManager.has_player(), "Player cleared")
	var arc := SaveManager.load_legends()
	assert_eq(arc.size(), 1)
	assert_eq(arc.entries[0].end_reason, LegendEntry.END_REASON_RETIRED)
	assert_signal_emitted_with_parameters(LifecycleManager, "career_ended", [LegendEntry.END_REASON_RETIRED])

func test_manual_retire_with_no_player_is_a_no_op_warning():
	# No player loaded; should not crash, should not archive.
	LifecycleManager.manual_retire()
	var arc := SaveManager.load_legends()
	assert_eq(arc.size(), 0)

func test_win_out_clears_player_and_archives_with_won_reason():
	_seeded_player()
	watch_signals(LifecycleManager)
	LifecycleManager.win_out()
	assert_false(SaveManager.has_player())
	var arc := SaveManager.load_legends()
	assert_eq(arc.size(), 1)
	assert_eq(arc.entries[0].end_reason, LegendEntry.END_REASON_WON)
	assert_signal_emitted_with_parameters(LifecycleManager, "career_ended", [LegendEntry.END_REASON_WON])

func test_end_career_archives_real_seasons_played_and_clears_career():
	_seeded_player()
	var c := CareerResolver.start_career(0)
	c.seasons_played = 7
	SaveManager.save_career(c)
	LifecycleManager.manual_retire()
	var arc := SaveManager.load_legends()
	assert_eq(arc.entries[0].seasons_played, 7, "real counter archived")
	assert_false(SaveManager.has_career(), "career save cleared")

func test_end_career_without_career_save_defaults_to_one_season():
	_seeded_player()
	LifecycleManager.manual_retire()
	var arc := SaveManager.load_legends()
	assert_eq(arc.entries[0].seasons_played, 1, "back-compat default")
