extends GutTest

# The Kit Room screen (spec 2026-07-02, Rung 2): three modes, dumb screen —
# every action routes through SeasonPlay.apply_shop_action.

const KitRoomScene = preload("res://scenes/kit_room/kit_room.tscn")

func _rich_player(bal: int = 10000) -> Player:
	var p := Player.new()
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	p.attributes = a
	p.tons_balance = bal
	return p

func _play(bal: int = 10000) -> SeasonPlay:
	var p := _rich_player(bal)
	var career := CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(0, 0)
	var sp := SeasonPlay.start(p.attributes, career.teams[0], career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), 20260702, spec)
	sp.enable_shop(p, EconomyTuning.new(), 0, 0)
	return sp

func _visit_play(bal: int = 10000) -> SeasonPlay:
	var sp := _play(bal)
	sp.apply_shop_action({"kind": "skip"})
	for i in range(3):
		sp.commit_player_result(sp.make_session().result())
	return sp

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label or node is Button:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_starter_mode_shows_three_free_tiles() -> void:
	var sp := _play()
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_visit(sp, sp.pending_shop_visit())
	await get_tree().process_frame
	var tiles = screen.find_child("StarterBox", true, false)
	assert_not_null(tiles)
	assert_eq(tiles.get_child_count(), 3, "3 starter tiles")
	assert_gt((tiles.get_child(0) as Control).size.y, 0.0, "tiles not collapsed")
	assert_true(_all_label_text(screen).contains("FREE"))

func test_starter_pick_owns_and_emits_done() -> void:
	var sp := _play()
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_visit(sp, sp.pending_shop_visit())
	await get_tree().process_frame
	watch_signals(screen)
	(screen.find_child("StarterBox", true, false).get_child(0) as Button).pressed.emit()
	assert_eq(sp.shop_owned().size(), 1, "pick applied")
	assert_signal_emitted(screen, "done")

func test_visit_mode_buy_disabled_when_broke() -> void:
	var sp := _visit_play(0)   # ₸0 balance
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_visit(sp, sp.pending_shop_visit())
	await get_tree().process_frame
	var buy: Button = screen.find_child("BuyBtn0", true, false)
	assert_not_null(buy, "offer row present (a Common is always on the shelf)")
	assert_true(buy.disabled, "cannot afford at ₸0")

func test_visit_continue_consumes_and_emits_done() -> void:
	var sp := _visit_play()
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_visit(sp, sp.pending_shop_visit())
	await get_tree().process_frame
	watch_signals(screen)
	(screen.find_child("ContinueBtn", true, false) as Button).pressed.emit()
	assert_eq(sp.pending_shop_visit(), {}, "visit consumed on continue")
	assert_signal_emitted(screen, "done")

func test_carryover_mode_elects() -> void:
	var sp := _play()
	sp.apply_shop_action({"kind": "pick", "id": sp.pending_shop_visit()["offer"][0]})
	var owned: String = sp.shop_owned()[0]
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_carryover(sp)
	await get_tree().process_frame
	watch_signals(screen)
	(screen.find_child("CarryBox", true, false).get_child(0) as Button).pressed.emit()
	assert_signal_emitted_with_parameters(screen, "carryover_elected", [owned])

func test_no_emoji_anywhere() -> void:
	var sp := _visit_play()
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_visit(sp, sp.pending_shop_visit())
	await get_tree().process_frame
	var txt := _all_label_text(screen)
	for ch in "🏏🃏🛒▶":
		assert_false(txt.contains(ch), "no emoji (Barlow tofu)")
