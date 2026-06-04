extends GutTest

const IdentityScene = preload("res://scenes/player_creation/identity.tscn")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")
const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")

var identity

func before_each() -> void:
	identity = IdentityScene.instantiate()
	add_child_autofree(identity)
	await get_tree().process_frame

func test_loads_with_next_disabled_and_no_picks():
	assert_true(identity._next_btn.disabled)
	assert_eq(identity._draft.country, -1)

func test_picking_country_sa_resets_city_and_re_rolls_name_when_appearance_is_set():
	identity._draft.appearance = Appearance.Bucket.MIXED
	identity._on_country_pressed(Country.Code.SA)
	assert_eq(identity._draft.country, Country.Code.SA)
	assert_eq(identity._draft.city, "")
	assert_not_null(identity._draft.name, "name re-rolled because Country + Appearance now both set")

func test_picking_all_three_enables_next():
	identity._on_country_pressed(Country.Code.SA)
	identity._on_appearance_selected(Appearance.Bucket.WHITE)
	# Simulate the OptionButton selecting "Cape Town" (item index 1)
	identity._city_dropdown.select(1)
	identity._on_city_selected(1)
	assert_false(identity._next_btn.disabled)

func test_changing_country_resets_city_pick():
	identity._on_country_pressed(Country.Code.SA)
	identity._on_appearance_selected(Appearance.Bucket.WHITE)
	identity._city_dropdown.select(1)
	identity._on_city_selected(1)
	assert_ne(identity._draft.city, "")
	identity._on_country_pressed(Country.Code.AUS)
	assert_eq(identity._draft.city, "", "city resets on country change")
	assert_true(identity._next_btn.disabled)

func test_appearance_picker_disabled_until_country_picked():
	# Fresh screen, no Country yet → picker disabled (spec §4).
	for child in identity._appearance_picker.get_children():
		assert_true((child as Button).disabled, "picker disabled before Country")
	identity._on_country_pressed(Country.Code.SA)
	for child in identity._appearance_picker.get_children():
		assert_false((child as Button).disabled, "picker enabled after Country")

func test_set_draft_hydrates_ui_and_preserves_name():
	# Simulate returning from Build with a fully-populated draft (Back navigation).
	var d := PlayerCreationDraft.new()
	d.country = Country.Code.AUS
	d.city = "Sydney"
	d.appearance = Appearance.Bucket.BLACK
	var n = load("res://scripts/data/name_pair.gd").new()
	n.first_name = "Pat"; n.surname = "Stumps"
	d.name = n

	var fresh = IdentityScene.instantiate()
	fresh.set_draft(d)                       # before tree entry
	add_child_autofree(fresh)
	await get_tree().process_frame

	assert_true(fresh._country_aus_btn.button_pressed, "AUS toggle restored")
	assert_eq(fresh._appearance_picker.selected_bucket(), Appearance.Bucket.BLACK, "appearance ring restored")
	assert_eq(fresh._city_dropdown.get_item_text(fresh._city_dropdown.get_selected()), "Sydney", "city restored")
	assert_eq(fresh._name_label.text, "PAT STUMPS", "name preserved, NOT re-rolled")
	assert_false(fresh._next_btn.disabled, "all picks present → Next enabled")
