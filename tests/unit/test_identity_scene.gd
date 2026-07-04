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

func test_hifi_header_and_cta_text():
	# The hi-fi screen carries the design copy and a real CTA, all visible in-tree.
	assert_eq(identity._kicker_label.text, "NEW PLAYER")
	assert_eq(identity._title_label.text, "Who are you?")
	assert_true("Build your game" in identity._next_btn.text, "CTA names the next step")
	assert_true(identity._next_btn.is_visible_in_tree(), "CTA is actually visible")

func test_hifi_hero_portrait_present_and_sized():
	# Portrait art is wired (PortraitLibrary face) and renders at a real size.
	assert_not_null(identity._hero_portrait.texture, "hero portrait has art")
	assert_true(identity._hero_portrait.is_visible_in_tree())
	assert_gt(identity._hero_portrait.custom_minimum_size.y, 0.0, "portrait reserves height")

func test_hifi_country_toggle_is_text_no_emoji():
	# Barlow has no emoji glyphs (flags would tofu) → text-only segments.
	assert_eq(identity._country_sa_btn.text, "SOUTH AFRICA")
	assert_eq(identity._country_aus_btn.text, "AUSTRALIA")
	assert_true(identity._country_sa_btn.toggle_mode and identity._country_aus_btn.toggle_mode)

func test_hifi_name_sub_shows_city_and_country():
	identity._on_country_pressed(Country.Code.SA)
	identity._on_appearance_selected(Appearance.Bucket.WHITE)
	identity._city_dropdown.select(1)
	identity._on_city_selected(1)
	# Sub reads "City · Country" once a city is chosen.
	assert_true(" · South Africa" in identity._name_sub.text, "sub names the country")
	assert_false(identity._name_sub.text.is_empty(), "sub populated with a city")

func test_reroll_button_state_and_action():
	# Initially no Country/Appearance → re-roll disabled, name unset.
	assert_true(identity._reroll_btn.disabled, "re-roll disabled before name exists")
	assert_eq(identity._name_label.text, "—", "name label shows placeholder before name exists")
	# Pick Country + Appearance → a name is generated, re-roll enabled.
	identity._on_country_pressed(Country.Code.SA)
	identity._on_appearance_selected(Appearance.Bucket.WHITE)
	assert_not_null(identity._draft.name, "name generated once Country + Appearance set")
	assert_false(identity._reroll_btn.disabled, "re-roll enabled once name exists")
	assert_ne(identity._name_label.text, "—", "name label updated from placeholder")
	# Press re-roll → still a valid name, label stays in sync (can't assert it changed; RNG may repeat).
	identity._on_reroll_pressed()
	assert_not_null(identity._draft.name, "name still valid after re-roll")
	assert_eq(identity._name_label.text, identity._draft.name.display_caps(), "label stays in sync after re-roll")

func test_hero_swaps_on_appearance_pick():
	identity._on_country_pressed(Country.Code.SA)
	var before = identity._hero_portrait.texture
	identity._on_appearance_selected(Appearance.Bucket.BLACK)
	assert_eq(identity._hero_portrait.texture, PortraitLibrary.texture_for(Appearance.Bucket.BLACK, 0))
	assert_ne(identity._hero_portrait.texture, before, "picking BLACK swaps the hero art")

func test_hero_rehydrates_from_draft():
	var draft := PlayerCreationDraft.new()
	draft.country = Country.Code.AUS
	draft.appearance = Appearance.Bucket.INDIAN
	identity.set_draft(draft)
	assert_eq(identity._hero_portrait.texture, PortraitLibrary.texture_for(Appearance.Bucket.INDIAN, 0), "Back navigation shows the picked face")

func test_picker_tiles_show_face_thumbnails():
	for bucket in Appearance.all():
		var btn: Button = identity._appearance_picker.button_for(bucket)
		assert_eq(btn.icon, PortraitLibrary.texture_for(bucket, 0), Appearance.to_key(bucket) + " tile wears its face")

# --- T11 city clubs (spec 2026-07-04 DCC4/DCC5/DCC6) --------------------------

func _city_index(city: String) -> int:
	for i in range(identity._city_dropdown.item_count):
		if identity._city_dropdown.get_item_text(i) == city:
			return i
	return -1

func test_club_pick_tiles_exist_and_follow_city():
	identity._on_country_pressed(Country.Code.SA)
	identity._on_city_selected(_city_index("Pretoria"))
	await get_tree().process_frame
	var tiles: Array = identity._club_buttons
	assert_eq(tiles.size(), 3, "3 starting clubs offered (DCC5)")
	for i in range(3):
		assert_eq(tiles[i].text.split("\n")[0], CityClubs.bank("Pretoria")[i],
			"tile %d named from the city bank" % i)
		assert_true(tiles[i].is_visible_in_tree(), "tile %d visible" % i)
		assert_gt(tiles[i].size.y, 0.0, "tile %d not collapsed" % i)
	assert_true(tiles[0].button_pressed, "slot 0 preselected (DCC6)")

func test_club_pick_writes_draft_and_survives_advance():
	identity._on_country_pressed(Country.Code.SA)
	identity._on_city_selected(_city_index("Pretoria"))
	identity._on_club_pressed(2)
	var captured: Array = []
	identity.advance_to_build.connect(func(d): captured.append(d))
	identity._on_appearance_selected(Appearance.Bucket.WHITE)
	identity._on_next_pressed()
	assert_eq(captured.size(), 1, "advanced")
	assert_eq(captured[0].club_slot, 2, "the pick rides the draft (DCC7)")

func test_club_section_hidden_without_city_and_next_not_gated():
	identity._on_country_pressed(Country.Code.SA)
	await get_tree().process_frame
	assert_false(identity._club_box.visible, "no city yet -> section hidden (DCC6)")
	identity._on_city_selected(_city_index("Cape Town"))
	identity._on_appearance_selected(Appearance.Bucket.WHITE)
	assert_false(identity._next_btn.disabled, "club pick never gates Next (DCC6)")
