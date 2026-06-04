extends GutTest

const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const LegendEntry = preload("res://scripts/data/legend_entry.gd")

func before_each() -> void:
	SaveManager.player_save_path = "user://_test_lc_player.tres"
	SaveManager.legends_save_path = "user://_test_lc_legends.tres"
	SaveManager.clear_player()
	SaveManager.clear_legends()

func after_each() -> void:
	SaveManager.clear_player()
	SaveManager.clear_legends()

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
