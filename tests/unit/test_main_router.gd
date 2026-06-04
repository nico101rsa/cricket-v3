extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func before_each() -> void:
	SaveManager.player_save_path = "user://_test_main_player.tres"
	SaveManager.legends_save_path = "user://_test_main_legends.tres"
	SaveManager.clear_player()
	SaveManager.clear_legends()

func after_each() -> void:
	SaveManager.clear_player()
	SaveManager.clear_legends()

func test_router_instantiates_without_error():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	assert_eq(main._slot.get_child_count(), 1, "one child mounted")
	# No save → first child is Identity
	var first = main._slot.get_child(0)
	assert_true(first.has_signal("advance_to_build"), "first scene is Identity (has advance_to_build signal)")

func test_back_from_build_returns_to_identity_with_picks_preserved():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame

	# Drive Identity to a complete draft, then advance to Build.
	var identity = main._slot.get_child(0)
	identity._on_country_pressed(Country.Code.SA)
	identity._on_appearance_selected(Appearance.Bucket.WHITE)
	identity._city_dropdown.select(1)          # first real city (index 0 is the placeholder)
	identity._on_city_selected(1)
	var draft = identity._draft
	identity.advance_to_build.emit(draft)
	await get_tree().process_frame

	var build = main._slot.get_child(0)
	assert_true(build.has_method("set_draft"), "advanced to Build")

	# Tap Back → router should mount a fresh Identity hydrated from the same draft.
	build.back_pressed.emit(draft)
	await get_tree().process_frame

	var back_identity = main._slot.get_child(0)
	assert_true(back_identity.has_signal("advance_to_build"), "returned to Identity")
	assert_eq(back_identity._draft.city, draft.city, "city pick preserved across Back")
	assert_false(back_identity._next_btn.disabled, "hydrated Identity has Next enabled")
