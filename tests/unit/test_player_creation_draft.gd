extends GutTest

const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func test_new_draft_has_unset_picks():
	var d := PlayerCreationDraft.new()
	assert_eq(d.country, -1, "country unset")
	assert_eq(d.city, "")
	assert_eq(d.appearance, -1, "appearance unset")
	assert_null(d.name)
	assert_not_null(d.attributes, "attributes always present (defaults applied)")

func test_identity_complete_requires_all_three_picks_and_a_name():
	var d := PlayerCreationDraft.new()
	assert_false(d.identity_complete())
	d.country = Country.Code.SA
	assert_false(d.identity_complete())
	d.city = "Cape Town"
	assert_false(d.identity_complete())
	d.appearance = Appearance.Bucket.MIXED
	assert_false(d.identity_complete(), "name still missing")
	var np = load("res://scripts/data/name_pair.gd").new()
	np.first_name = "Jonty"; np.surname = "Springer"
	d.name = np
	assert_true(d.identity_complete())

func test_attributes_default_to_balanced_all_rounder():
	var d := PlayerCreationDraft.new()
	assert_eq(d.attributes.power, 5)
	assert_eq(d.attributes.sum(), 20)
	assert_true(d.attributes.is_valid_creation_distribution())
