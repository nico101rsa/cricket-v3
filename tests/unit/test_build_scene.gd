extends GutTest

const BuildScene = preload("res://scenes/player_creation/build.tscn")
const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func _draft() -> PlayerCreationDraft:
	var d := PlayerCreationDraft.new()
	d.country = Country.Code.SA
	d.city = "Cape Town"
	d.appearance = Appearance.Bucket.WHITE
	var n := NamePair.new(); n.first_name = "Jonty"; n.surname = "Springer"
	d.name = n
	return d

func _mount() -> Control:
	var build = BuildScene.instantiate()
	build.set_draft(_draft())
	add_child_autofree(build)
	return build

func test_default_attributes_confirm_enabled_label_all_rounder():
	var build = _mount()
	await get_tree().process_frame
	assert_eq(build._draft.attributes.sum(), 44.0)
	assert_false(build._confirm_btn.disabled)
	assert_string_contains(build._classifier_label.text, "ALL-ROUNDER")

func test_unbalanced_sliders_disable_confirm():
	var build = _mount()
	await get_tree().process_frame
	build._power_slider.value = 8
	# Simulate the signal manually (gut may not fire it synchronously)
	build._on_slider_changed(8.0)
	assert_ne(build._draft.attributes.sum(), 44.0)
	assert_true(build._confirm_btn.disabled)
	# Points chip is the live "<sum> / 44 …" balance meter; under-budget here.
	assert_string_contains(build._points_value.text, "/ 44")
	assert_string_contains(build._points_value.text, "to spend")

func test_points_chip_states():
	# Balance-status chip (design review #2): GREEN balanced · RED over · GOLD under.
	var build = _mount()
	await get_tree().process_frame
	# Balanced (default 11/11/11/11 = 44).
	assert_string_contains(build._points_value.text, "44 / 44")
	assert_gt(build._points_value.modulate.g, build._points_value.modulate.r, "balanced reads green")
	# Over-budget — push one slider up.
	build._power_slider.value = 25; build._on_slider_changed(25.0)
	assert_string_contains(build._points_value.text, "over")
	assert_gt(build._points_value.modulate.r, build._points_value.modulate.b, "over reads red")
	# Under-budget — drop one slider low.
	build._power_slider.value = 3; build._on_slider_changed(3.0)
	assert_string_contains(build._points_value.text, "to spend")
	assert_gt(build._points_value.modulate.r, build._points_value.modulate.b, "under reads gold")

func test_confirm_persists_player_and_emits_signal():
	var original_path = SaveManager.player_save_path
	SaveManager.player_save_path = "user://_test_build_player.tres"
	SaveManager.clear_player()
	var build = _mount()
	await get_tree().process_frame
	watch_signals(build)
	build._on_confirm_pressed()
	assert_signal_emitted(build, "confirmed")
	assert_true(SaveManager.has_player())
	SaveManager.clear_player()
	SaveManager.player_save_path = original_path

func test_kicker_shows_player_name():
	# The design folds identity into the header kicker (name only); city/country
	# were chosen on Screen 1 and are deliberately not repeated on Build.
	var build = _mount()
	await get_tree().process_frame
	assert_string_contains(build._kicker_label.text, "JONTY SPRINGER")

func test_back_emits_the_same_draft_for_rehydration():
	var build = BuildScene.instantiate()
	var d := _draft()
	build.set_draft(d)
	add_child_autofree(build)
	await get_tree().process_frame
	watch_signals(build)
	build._back_btn.pressed.emit()
	assert_signal_emitted_with_parameters(build, "back_pressed", [d])

func test_hifi_elements_present_and_visible():
	# UI re-skin guard — the hi-fi blocks must actually render (CLAUDE.md: unit
	# tests can't catch invisibility, but they CAN catch a missing/zero-size node).
	var build = _mount()
	await get_tree().process_frame
	await get_tree().process_frame
	for node in [build._title_label, build._points_value, build._classifier_label, build._confirm_btn]:
		assert_true(node.is_visible_in_tree(), "hi-fi node should be visible in tree")
	assert_gt(build._confirm_btn.size.y, 0.0, "CTA should have real height")
