extends GutTest

const Cities = preload("res://scripts/domain/cities.gd")
const Country = preload("res://scripts/domain/country.gd")

func test_sa_has_eleven_cities_per_spec():
	var sa := Cities.for_country(Country.Code.SA)
	assert_eq(sa.size(), 11)
	assert_true(sa.has("Cape Town"))
	assert_true(sa.has("Pietermaritzburg"))

func test_aus_has_ten_cities_per_spec():
	var aus := Cities.for_country(Country.Code.AUS)
	assert_eq(aus.size(), 10)
	assert_true(aus.has("Sydney"))
	assert_true(aus.has("Darwin"))

func test_unknown_country_returns_empty():
	assert_eq(Cities.for_country(-1).size(), 0)
