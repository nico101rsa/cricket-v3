extends GutTest

const SaveManagerScript = preload("res://scripts/services/save_manager.gd")
const Player = preload("res://scripts/data/player.gd")
const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const LegendsArchive = preload("res://scripts/data/legends_archive.gd")
const LegendEntry = preload("res://scripts/data/legend_entry.gd")
const LiveSeasonState = preload("res://scripts/data/live_season_state.gd")

var sm

func before_each() -> void:
	sm = SaveManagerScript.new()
	sm.player_save_path = "user://_test_player.tres"
	sm.legends_save_path = "user://_test_legends.tres"
	sm.career_save_path = "user://_test_career.tres"
	sm.live_season_save_path = "user://_test_live_season.tres"
	sm.clear_player()
	sm.clear_legends()
	sm.clear_career()
	sm.clear_live_season()

func after_each() -> void:
	sm.clear_player()
	sm.clear_legends()
	sm.clear_career()
	sm.clear_live_season()
	# sm is a bare Node (never added to the tree), so free() it directly to avoid
	# leaking one orphaned instance per test. queue_free() is only for tree nodes.
	sm.free()

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
	p.attributes.power = 43.75
	sm.save_player(p)
	var loaded = sm.load_player()
	assert_not_null(loaded)
	assert_eq(loaded.name.first_name, "Jonty")
	assert_eq(loaded.attributes.power, 43.75)

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

# The Hall of Fame's stat strip reads these fields; they default to zero/gold today
# (no Season loop yet) and must survive the ResourceSaver round-trip so the Season
# loop can later fill them. Guards against the fields being plain `var` (non-@export).
func test_archived_legend_new_stub_fields_persist_with_defaults():
	sm.archive_to_legends(_make_player(), LegendEntry.END_REASON_RETIRED, 0)
	var arc = sm.load_legends()
	var e = arc.entries[0]
	assert_eq(e.levels_won, 0)
	assert_eq(e.retired_season, 0)
	assert_true(e.immortalised)

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

# --- Card-rescale migration (DR12): legacy 20-point saves scale x6.25 on load ---

func _legacy_player() -> Player:
	var p := _make_player()
	p.attributes.power = 8; p.attributes.composure = 8; p.attributes.attack = 2; p.attributes.control = 2
	p.starting_attributes = p.attributes.duplicate_typed()
	return p

func test_legacy_player_attributes_migrate_to_100_scale():
	var p := _legacy_player()
	sm.migrate_player(p)
	assert_eq(p.attributes.power, 50.0, "legacy 8 -> 50")
	assert_eq(p.attributes.control, 12.5, "legacy 2 -> 12.5")
	assert_eq(p.starting_attributes.power, 50.0, "starting snapshot migrates too")

func test_current_scale_player_is_not_double_migrated():
	var p := _make_player()   # already /100 (fresh build sum 44 > legacy ceiling 40)
	sm.migrate_player(p)
	assert_eq(p.attributes.power, 11.0, "a /100 build passes through untouched")

func test_legacy_save_on_disk_loads_migrated():
	var p := _legacy_player()
	sm.save_player(p)
	var loaded = sm.load_player()
	assert_eq(loaded.attributes.power, 50.0, "load_player migrates a legacy save")

func test_legacy_legend_archive_loads_migrated():
	sm.archive_to_legends(_legacy_player(), LegendEntry.END_REASON_RETIRED, 3)
	var arc = sm.load_legends()
	assert_eq(arc.entries[0].player.attributes.power, 50.0, "load_legends migrates legacy entries")


# --- Career round-trip (career-loop DC14) ---

func test_load_career_returns_null_when_no_save_exists():
	assert_null(sm.load_career())

func test_career_save_then_load_roundtrips():
	var c := CareerResolver.start_career(0)
	c.seasons_played = 5
	c.mark_beaten(0, CareerState.READINESS_TOUR)   # readiness cell — unlocks (1,0)
	c.teams[3].stars = 4.0
	sm.save_career(c)
	var loaded = sm.load_career()
	assert_eq(loaded.seasons_played, 5)
	assert_eq(loaded.current_team_index, 0)
	assert_eq(loaded.status_of(0, CareerState.READINESS_TOUR), CareerState.CellStatus.BEATEN)
	assert_true(loaded.is_unlocked(1, 0), "unlock state survives")
	assert_eq(loaded.teams.size(), 24)
	assert_eq(loaded.teams[3].stars, 4.0)
	assert_eq(loaded.teams[0].team_name, c.teams[0].team_name)

func test_clear_career_removes_save():
	sm.save_career(CareerResolver.start_career(0))
	assert_true(sm.has_career())
	sm.clear_career()
	assert_false(sm.has_career())
	assert_null(sm.load_career())

# --- Live-season round-trip (cross-session save, spec 2026-06-23) ---

func _make_live_state() -> LiveSeasonState:
	var s := LiveSeasonState.new()
	s.seed = 20260623
	s.level = 0
	s.tour_index = 0
	s.pay_total = 517
	s.wins = 5
	s.decisions = [
		{"presses": [[1, 3]], "review_balls": [[5, 2]],
			"km": [{"from_over": 7, "band": 2}], "bowl_km": []},
		{"presses": [], "review_balls": [], "km": [], "bowl_km": [{"from_over": 16, "kind": 1}]},
	]
	return s

func test_load_live_season_returns_null_when_no_save_exists():
	assert_null(sm.load_live_season())
	assert_false(sm.has_live_season(), "no save -> has_live_season false")

func test_save_then_load_live_season_round_trips_scalars():
	sm.save_live_season(_make_live_state())
	assert_true(sm.has_live_season(), "save creates the file")
	var loaded = sm.load_live_season()
	assert_not_null(loaded)
	assert_eq(loaded.seed, 20260623, "seed survives")
	assert_eq(loaded.level, 0, "level survives")
	assert_eq(loaded.pay_total, 517, "pay tally survives")
	assert_eq(loaded.wins, 5, "win count survives")

func test_live_season_preserves_nested_decisions():
	sm.save_live_season(_make_live_state())
	var loaded = sm.load_live_season()
	assert_eq(loaded.decisions.size(), 2, "both match entries survive")
	assert_eq(loaded.decisions[0]["presses"], [[1, 3]], "presses preserved")
	assert_eq(loaded.decisions[0]["km"], [{"from_over": 7, "band": 2}], "km override preserved")
	assert_eq(loaded.decisions[1]["bowl_km"], [{"from_over": 16, "kind": 1}], "bowl-km preserved")

func test_clear_live_season_removes_save():
	sm.save_live_season(_make_live_state())
	assert_true(sm.has_live_season())
	sm.clear_live_season()
	assert_false(sm.has_live_season(), "cleared -> gone")
