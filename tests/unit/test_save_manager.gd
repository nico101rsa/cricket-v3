extends GutTest

const SaveManagerScript = preload("res://scripts/services/save_manager.gd")
const Player = preload("res://scripts/data/player.gd")
const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const LegendsArchive = preload("res://scripts/data/legends_archive.gd")
const LegendEntry = preload("res://scripts/data/legend_entry.gd")

var sm

func before_each() -> void:
	sm = SaveManagerScript.new()
	sm.player_save_path = "user://_test_player.tres"
	sm.legends_save_path = "user://_test_legends.tres"
	sm.clear_player()
	sm.clear_legends()

func after_each() -> void:
	sm.clear_player()
	sm.clear_legends()

func _make_player() -> Player:
	var d := PlayerCreationDraft.new()
	var n := NamePair.new(); n.first_name = "Jonty"; n.surname = "Springer"
	d.name = n
	return Player.from_draft(d)

# --- Player round-trip ---

func test_load_player_returns_null_when_no_save_exists():
	assert_null(sm.load_player())

func test_save_then_load_returns_equivalent_player():
	var p := _make_player()
	p.attributes.power = 7
	sm.save_player(p)
	var loaded = sm.load_player()
	assert_not_null(loaded)
	assert_eq(loaded.name.first_name, "Jonty")
	assert_eq(loaded.attributes.power, 7)

func test_clear_player_removes_save():
	sm.save_player(_make_player())
	assert_true(sm.has_player())
	sm.clear_player()
	assert_false(sm.has_player())

# --- Legends round-trip ---

func test_load_legends_returns_empty_archive_when_none_saved():
	var arc = sm.load_legends()
	assert_not_null(arc)
	assert_eq(arc.size(), 0)

func test_archive_to_legends_appends_and_persists():
	var p := _make_player()
	sm.archive_to_legends(p, LegendEntry.END_REASON_RETIRED, 3)
	var arc = sm.load_legends()
	assert_eq(arc.size(), 1)
	assert_eq(arc.entries[0].end_reason, LegendEntry.END_REASON_RETIRED)
	assert_eq(arc.entries[0].seasons_played, 3)
	assert_eq(arc.entries[0].player.name.first_name, "Jonty")

func test_archive_to_legends_preserves_prior_entries():
	sm.archive_to_legends(_make_player(), LegendEntry.END_REASON_RETIRED, 1)
	sm.archive_to_legends(_make_player(), LegendEntry.END_REASON_WON, 8)
	var arc = sm.load_legends()
	assert_eq(arc.size(), 2)
	assert_eq(arc.entries[1].end_reason, LegendEntry.END_REASON_WON)

# --- Regression guard: archiving a LOADED player must embed inline, not ext-ref ---

func test_archiving_a_loaded_player_then_clearing_it_keeps_the_legend_intact():
	sm.save_player(_make_player())
	var loaded = sm.load_player()        # loaded.resource_path is now the player file
	assert_not_null(loaded)
	sm.archive_to_legends(loaded, LegendEntry.END_REASON_WON, 5)
	sm.clear_player()                     # delete the file the loaded player came from
	# Force a genuine disk read so we can't be fooled by an in-memory cache hit.
	var arc := ResourceLoader.load(sm.legends_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as LegendsArchive
	assert_not_null(arc)
	assert_eq(arc.size(), 1)
	assert_not_null(arc.entries[0].player, "player embedded inline, survived clear_player()")
	assert_eq(arc.entries[0].player.name.first_name, "Jonty")
