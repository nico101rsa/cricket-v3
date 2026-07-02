extends GutTest

# The Offers screen (spec 2026-07-02, DO6): season end — pick a team offer or
# stay. Dumb screen: renders what it is given, emits the pick.

const OffersScene = preload("res://scenes/offers/offers.tscn")

func _career() -> CareerState:
	return CareerResolver.start_career(0)

func _offer(team_index: int, level: int, stars: float) -> Offer:
	var o := Offer.new()
	o.team_index = team_index
	o.level = level
	o.stars = stars
	return o

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_renders_one_button_per_offer_plus_stay() -> void:
	var screen = OffersScene.instantiate()
	add_child_autofree(screen)
	var c := _career()
	screen.set_offers(c, [_offer(8, 1, 3.0), _offer(1, 0, 2.0), _offer(2, 0, 2.5)])
	await get_tree().process_frame
	for i in range(3):
		var b = screen.find_child("OfferBtn%d" % i, true, false)
		assert_not_null(b, "offer button %d present" % i)
		assert_gt(b.size.y, 0.0, "offer button %d not collapsed" % i)
	var stay = screen.find_child("StayBtn", true, false)
	assert_not_null(stay, "stay button present")
	assert_gt(stay.size.y, 0.0, "stay button not collapsed")

func test_offer_rows_name_team_level_and_step_up_tag() -> void:
	var screen = OffersScene.instantiate()
	add_child_autofree(screen)
	var c := _career()
	screen.set_offers(c, [_offer(8, 1, 3.0)])
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains(c.teams[8].team_name), "offer names the team")
	assert_true(text.contains("CITY"), "offer names the Level word")
	assert_true(text.contains("STEP UP"), "cross-up offer tagged STEP UP")
	assert_true(text.contains(c.teams[c.current_team_index].team_name),
		"current team named on the stay row")

func test_tapping_an_offer_emits_that_offer() -> void:
	var screen = OffersScene.instantiate()
	add_child_autofree(screen)
	var up := _offer(8, 1, 3.0)
	screen.set_offers(_career(), [up, _offer(1, 0, 2.0)])
	await get_tree().process_frame
	watch_signals(screen)
	var b: Button = screen.find_child("OfferBtn0", true, false)
	b.pressed.emit()
	assert_signal_emitted_with_parameters(screen, "offer_picked", [up])

func test_stay_emits_null() -> void:
	var screen = OffersScene.instantiate()
	add_child_autofree(screen)
	screen.set_offers(_career(), [_offer(1, 0, 2.0)])
	await get_tree().process_frame
	watch_signals(screen)
	var stay: Button = screen.find_child("StayBtn", true, false)
	stay.pressed.emit()
	assert_signal_emitted_with_parameters(screen, "offer_picked", [null])
