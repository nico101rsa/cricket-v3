extends GutTest

const Country = preload("res://scripts/domain/country.gd")

func test_enum_values_are_sa_and_aus():
	assert_eq(Country.Code.SA, 0)
	assert_eq(Country.Code.AUS, 1)

func test_to_key_returns_canonical_string():
	assert_eq(Country.to_key(Country.Code.SA), "SA")
	assert_eq(Country.to_key(Country.Code.AUS), "AUS")

func test_display_name_returns_uppercased_full_name():
	assert_eq(Country.display_name(Country.Code.SA), "SOUTH AFRICA")
	assert_eq(Country.display_name(Country.Code.AUS), "AUSTRALIA")
