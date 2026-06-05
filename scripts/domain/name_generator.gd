class_name NameGenerator
extends RefCounted

# Samples uniformly from the (Country, Appearance) bank slice.
# Caller passes the RNG so tests can seed for determinism.
# Returns null for invalid (country, appearance) combos.

static func generate(country: int, appearance: int, rng: RandomNumberGenerator) -> NamePair:
	var firsts := NameBanks.first_names_for(country, appearance)
	var surnames := NameBanks.surnames_for(country, appearance)
	if firsts.is_empty() or surnames.is_empty():
		return null
	var pair := NamePair.new()
	pair.first_name = firsts[rng.randi() % firsts.size()]
	pair.surname = surnames[rng.randi() % surnames.size()]
	return pair
