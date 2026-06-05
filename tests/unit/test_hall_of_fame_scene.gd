extends GutTest

const HallOfFame = preload("res://scenes/hall_of_fame/hall_of_fame.tscn")
const LegendsArchive = preload("res://scripts/data/legends_archive.gd")
const LegendEntry = preload("res://scripts/data/legend_entry.gd")
const Player = preload("res://scripts/data/player.gd")
const Attributes = preload("res://scripts/data/attributes.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func _legend(first: String, surname: String, pw: int, co: int, at: int, ct: int) -> LegendEntry:
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

func test_hero_is_most_recent_and_count_reflects_size():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	# archive is oldest-first; the bowler is appended last -> hero
	hof.render_archive(_archive([
		_legend("Jonty", "Springer", 8, 8, 2, 2),   # oldest, batter
		_legend("Dale", "Steyner", 2, 2, 8, 8),       # newest, bowler
	]))
	assert_eq(hof._count.text, "2 Legends")
	assert_string_contains(hof._hero_name.text, "DALE STEYNER")
	assert_string_contains(hof._hero_arc.text, "BOWLER")

func test_earlier_list_has_n_minus_one_rows():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	hof.render_archive(_archive([
		_legend("A", "One", 8, 8, 2, 2),
		_legend("B", "Two", 8, 8, 2, 2),
		_legend("C", "Three", 2, 2, 8, 8),
	]))
	assert_eq(hof._earlier_list.get_child_count(), 2)

func test_single_legend_has_zero_earlier_rows():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	hof.render_archive(_archive([_legend("A", "One", 8, 8, 2, 2)]))
	assert_eq(hof._earlier_list.get_child_count(), 0)

func test_earlier_rows_are_laid_out_with_visible_height():
	# Guards the layout bug found during the manual eyeball: a zero-height
	# ScrollContainer clipped the rows even though they existed as children.
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	hof.render_archive(_archive([
		_legend("A", "One", 8, 8, 2, 2),
		_legend("B", "Two", 8, 8, 2, 2),
		_legend("C", "Three", 2, 2, 8, 8),
	]))
	await get_tree().process_frame
	await get_tree().process_frame
	for c in hof._earlier_list.get_children():
		assert_gt(c.size.y, 0.0, "row has non-zero height")
		assert_true(c.is_visible_in_tree(), "row is visible in tree")

func test_new_player_button_emits_signal():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	watch_signals(hof)
	hof._new_player_btn.pressed.emit()
	assert_signal_emitted(hof, "begin_new_player")
