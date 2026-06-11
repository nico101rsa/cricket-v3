extends GutTest

const Player = preload("res://scripts/data/player.gd")
const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func test_from_draft_copies_identity_and_snapshots_attributes():
	var draft := PlayerCreationDraft.new()
	draft.country = Country.Code.AUS
	draft.city = "Melbourne"
	draft.appearance = Appearance.Bucket.INDIAN
	var n := NamePair.new(); n.first_name = "Ricky"; n.surname = "Stumps"
	draft.name = n
	draft.attributes.power = 43.75
	draft.attributes.composure = 37.5
	draft.attributes.attack = 25.0
	draft.attributes.control = 18.75  # sum = 20

	var p := Player.from_draft(draft)

	assert_eq(p.city, "Melbourne")
	assert_eq(p.country, Country.Code.AUS)
	assert_eq(p.appearance, Appearance.Bucket.INDIAN)
	assert_eq(p.name.surname, "Stumps")
	assert_eq(p.attributes.power, 43.75)
	assert_eq(p.starting_attributes.power, 43.75, "starting snapshot matches")
	assert_gt(p.created_at, 0, "created_at populated")

func test_starting_attributes_are_independent_copy():
	var draft := PlayerCreationDraft.new()
	var n := NamePair.new(); n.first_name = "X"; n.surname = "Y"
	draft.name = n
	var p := Player.from_draft(draft)
	p.attributes.power = 50.0
	assert_eq(p.starting_attributes.power, 35.0, "starting snapshot unaffected by later mutation (draft default 35/30/30/30)")
