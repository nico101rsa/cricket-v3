extends GutTest

const HallOfFame = preload("res://scenes/hall_of_fame/hall_of_fame.tscn")
const LegendsArchive = preload("res://scripts/data/legends_archive.gd")
const LegendEntry = preload("res://scripts/data/legend_entry.gd")
const Player = preload("res://scripts/data/player.gd")
const Attributes = preload("res://scripts/data/attributes.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func _legend(first: String, surname: String, pw: float, co: float, at: float, ct: float) -> LegendEntry:
	var p := Player.new()
	var n := NamePair.new()
	n.first_name = first; n.surname = surname
	p.name = n
	p.appearance = Appearance.Bucket.WHITE
	var s := Attributes.new()
	s.power = pw; s.composure = co; s.attack = at; s.control = ct
	p.starting_attributes = s
	p.attributes = s.duplicate_typed()
	var e := LegendEntry.new()
	e.player = p
	return e

func _archive(entries: Array) -> LegendsArchive:
	var a := LegendsArchive.new()
	for e in entries:
		a.entries.append(e)
	return a

var _original_legends_path: String

func before_each() -> void:
	# Isolate from the real user://legends.tres. Without this, _ready() renders the
	# actual saved archive (4 legends -> 3 earlier rows = 15 nodes). The test's own
	# render_archive() call then remove_child()s + queue_free()s those rows; because
	# queue_free is deferred, the 15 detached nodes sit pending deletion at test-end
	# and GUT counts them as orphans. An empty archive means _ready() builds no rows,
	# so nothing is left pending -- and the test no longer depends on whatever happens
	# to be in the real save file.
	_original_legends_path = SaveManager.legends_save_path
	SaveManager.legends_save_path = "user://_test_hof_legends.tres"
	SaveManager.clear_legends()

func after_each() -> void:
	SaveManager.clear_legends()
	SaveManager.legends_save_path = _original_legends_path

func test_hero_is_most_recent_and_count_reflects_size():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	# archive is oldest-first; the bowler is appended last -> hero
	hof.render_archive(_archive([
		_legend("Jonty", "Springer", 50.0, 50.0, 12.5, 12.5),   # oldest, batter
		_legend("Dale", "Steyner", 12.5, 12.5, 50.0, 50.0),       # newest, bowler
	]))
	assert_eq(hof._count.text, "2 Legends")
	assert_string_contains(hof._hero_name.text, "DALE STEYNER")
	assert_string_contains(hof._hero_arc.text, "BOWLER")

func test_earlier_list_has_n_minus_one_rows():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	hof.render_archive(_archive([
		_legend("A", "One", 50.0, 50.0, 12.5, 12.5),
		_legend("B", "Two", 50.0, 50.0, 12.5, 12.5),
		_legend("C", "Three", 12.5, 12.5, 50.0, 50.0),
	]))
	assert_eq(hof._earlier_list.get_child_count(), 2)

func test_single_legend_has_zero_earlier_rows():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	hof.render_archive(_archive([_legend("A", "One", 50.0, 50.0, 12.5, 12.5)]))
	assert_eq(hof._earlier_list.get_child_count(), 0)

func test_earlier_rows_are_laid_out_with_visible_height():
	# Guards the layout bug found during the manual eyeball: a zero-height
	# ScrollContainer clipped the rows even though they existed as children.
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	hof.render_archive(_archive([
		_legend("A", "One", 50.0, 50.0, 12.5, 12.5),
		_legend("B", "Two", 50.0, 50.0, 12.5, 12.5),
		_legend("C", "Three", 12.5, 12.5, 50.0, 50.0),
	]))
	await get_tree().process_frame
	await get_tree().process_frame
	for c in hof._earlier_list.get_children():
		assert_gt(c.size.y, 0.0, "row has non-zero height")
		assert_true(c.is_visible_in_tree(), "row is visible in tree")

func test_hero_meta_and_strip_singularise_for_a_one_season_one_level_career():
	# "1 Seasons played" / "1 Levels won" reads as a typo. A single-count career
	# must render the singular noun in both the meta line and the lifetime strip.
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	var e := _legend("Solo", "Career", 31.25, 31.25, 31.25, 31.25)
	e.seasons_played = 1
	e.levels_won = 1
	hof.render_archive(_archive([e]))
	assert_string_contains(hof._hero_meta.text, "1 Season played")
	assert_string_contains(hof._hero_meta.text, "1 Level won")
	assert_false(hof._hero_meta.text.contains("1 Seasons"), "no plural 's' on a single season")
	assert_false(hof._hero_meta.text.contains("1 Levels"), "no plural 's' on a single level")
	assert_string_contains(hof._hero_strip.text, "1 Season")
	assert_string_contains(hof._hero_strip.text, "1 Level won")

func test_hero_meta_keeps_plural_for_multiple_seasons_and_levels():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	var e := _legend("Multi", "Career", 31.25, 31.25, 31.25, 31.25)
	e.seasons_played = 3
	e.levels_won = 2
	hof.render_archive(_archive([e]))
	assert_string_contains(hof._hero_meta.text, "3 Seasons played")
	assert_string_contains(hof._hero_meta.text, "2 Levels won")

func test_earlier_rows_never_overflow_the_scroll_width():
	# Regression guard for the manual-eyeball find: a one-line row of
	# "NAME    ROLE → ROLE    N Seasons" overflowed the column and clipped on the
	# right (and let the list scroll sideways). The row must stay within the
	# ScrollContainer's width so nothing is cut off — long name is the worst case.
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	hof.render_archive(_archive([
		_legend("Bartholomew", "Cunningham-Smith", 31.25, 31.25, 31.25, 31.25),
		_legend("Hero", "Latest", 12.5, 12.5, 50.0, 50.0),
	]))
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll: ScrollContainer = hof.get_node("Layout/EarlierScroll")
	for c in hof._earlier_list.get_children():
		assert_lte(c.size.x, scroll.size.x + 1.0,
			"earlier row must fit inside the scroll width (no horizontal clip)")

func test_new_player_button_emits_signal():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	watch_signals(hof)
	hof._new_player_btn.pressed.emit()
	assert_signal_emitted(hof, "begin_new_player")
