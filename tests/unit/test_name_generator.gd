extends GutTest

const NameGenerator = preload("res://scripts/domain/name_generator.gd")
const NameBanks = preload("res://scripts/domain/name_banks.gd")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

func test_generates_a_name_from_the_correct_bank_slice():
	var rng := _rng(42)
	var n := NameGenerator.generate(Country.Code.SA, Appearance.Bucket.MIXED, rng)
	assert_true(NameBanks.first_names_for(Country.Code.SA, Appearance.Bucket.MIXED).has(n.first_name))
	assert_true(NameBanks.surnames_for(Country.Code.SA, Appearance.Bucket.MIXED).has(n.surname))

func test_same_seed_produces_same_name():
	var n1 := NameGenerator.generate(Country.Code.AUS, Appearance.Bucket.BLACK, _rng(7))
	var n2 := NameGenerator.generate(Country.Code.AUS, Appearance.Bucket.BLACK, _rng(7))
	assert_eq(n1.first_name, n2.first_name)
	assert_eq(n1.surname, n2.surname)

func test_different_seeds_likely_produce_different_names():
	# With 100 unique combos and 10 different seeds, near-certain at least two diverge.
	var seen := {}
	for s in range(10):
		var n := NameGenerator.generate(Country.Code.SA, Appearance.Bucket.WHITE, _rng(s))
		seen[n.display()] = true
	assert_gt(seen.size(), 1, "10 different seeds yielded > 1 distinct name")

func test_invalid_country_appearance_returns_null():
	var rng := _rng(1)
	var n := NameGenerator.generate(-1, Appearance.Bucket.WHITE, rng)
	assert_null(n)

func test_all_eight_banks_are_populated():
	var rng := _rng(0)
	for c in [Country.Code.SA, Country.Code.AUS]:
		for a in Appearance.all():
			var n := NameGenerator.generate(c, a, rng)
			assert_not_null(n, "bank (%s, %s) generated a name" % [Country.to_key(c), Appearance.to_key(a)])
			assert_ne(n.first_name, "")
			assert_ne(n.surname, "")
