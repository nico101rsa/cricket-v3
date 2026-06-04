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

func test_default_attributes_confirm_enabled_label_all_rounder():
	var build = BuildScene.instantiate()
	build.set_draft(_draft())
	add_child_autofree(build)
	await get_tree().process_frame
	assert_eq(build._draft.attributes.sum(), 20)
	assert_false(build._confirm_btn.disabled)
	assert_string_contains(build._classifier_label.text, "ALL-ROUNDER")

func test_dragging_sliders_above_20_disables_confirm():
	var build = BuildScene.instantiate()
	build.set_draft(_draft())
	add_child_autofree(build)
	await get_tree().process_frame
	build._power_slider.value = 8
	# Simulate the signal manually (gut may not fire it synchronously)
	build._on_slider_changed(8.0)
	assert_ne(build._draft.attributes.sum(), 20)
	assert_true(build._confirm_btn.disabled)
	assert_string_contains(build._points_label.text, "REMAINING")

func test_confirm_persists_player_and_emits_signal():
	SaveManager.player_save_path = "user://_test_build_player.tres"
	SaveManager.clear_player()
	var build = BuildScene.instantiate()
	build.set_draft(_draft())
	add_child_autofree(build)
	await get_tree().process_frame
	watch_signals(build)
	build._on_confirm_pressed()
	assert_signal_emitted(build, "confirmed")
	assert_true(SaveManager.has_player())
	SaveManager.clear_player()

func test_recap_shows_identity_from_draft():
	var build = BuildScene.instantiate()
	build.set_draft(_draft())
	add_child_autofree(build)
	await get_tree().process_frame
	assert_string_contains(build._recap_label.text, "JONTY SPRINGER")
	assert_string_contains(build._recap_label.text, "Cape Town")
	assert_string_contains(build._recap_label.text, "SA")

func test_back_emits_the_same_draft_for_rehydration():
	var build = BuildScene.instantiate()
	var d := _draft()
	build.set_draft(d)
	add_child_autofree(build)
	await get_tree().process_frame
	watch_signals(build)
	build._back_btn.pressed.emit()
	assert_signal_emitted_with_parameters(build, "back_pressed", [d])
