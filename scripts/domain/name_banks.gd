class_name NameBanks
extends RefCounted

# Stub V1 banks. 8 banks = 4 Appearance × 2 Country.
# Pool size per bank: 10 firsts × 10 surnames = 100 unique combos.
# Surname mix per spec §3.4: ~70% cricketer-surname plays, ~30% equipment puns.
# Full ~30×50 authoring is a separate deliverable.

const _FIRSTS_SA_WHITE: Array[String]  = ["John", "Jonty", "Quinton", "AB", "Faf", "Dale", "Hansie", "Allan", "Shaun", "Graeme"]
const _FIRSTS_SA_MIXED: Array[String]  = ["Vernon", "Wayne", "JP", "Henry", "Garth", "Roger", "Ashwell", "Paul", "Daryll", "Justin"]
const _FIRSTS_SA_INDIAN: Array[String] = ["Hashim", "Imran", "Keshav", "Tabraiz", "Rilee", "Reeza", "Yasir", "Omar", "Sulieman", "Aiden"]
const _FIRSTS_SA_BLACK: Array[String]  = ["Kagiso", "Temba", "Lungi", "Andile", "Aaron", "Makhaya", "Mfuneko", "Loots", "Thami", "Sibonelo"]

const _FIRSTS_AUS_WHITE: Array[String]  = ["Steve", "Ricky", "Glenn", "Pat", "Mitchell", "Travis", "Marnus", "Adam", "Brett", "Cameron"]
const _FIRSTS_AUS_MIXED: Array[String]  = ["Andrew", "Justin", "Damien", "Brad", "Phillip", "Michael", "Stuart", "Tim", "Greg", "Jason"]
const _FIRSTS_AUS_INDIAN: Array[String] = ["Usman", "Fawad", "Gurinder", "Tanveer", "Aman", "Arjun", "Param", "Nishant", "Jaspreet", "Rohan"]
const _FIRSTS_AUS_BLACK: Array[String]  = ["Scott", "Jason", "D'Arcy", "Daniel", "Marcus", "Eddie", "Tyrone", "Will", "Lance", "Nathan"]

# Surnames per bank — same surname pool is reused across (Country, Appearance) variants
# in V1 stub form. Real authoring will diverge them.
const _SURNAMES_GENERIC: Array[String] = [
	# cricketer plays (~7)
	"Springer", "Tendul", "Smithers", "Vilas", "Dhonner", "Kohlrabi", "Amlaa",
	# equipment puns (~3)
	"Bails", "Stumps", "Yorker",
]

static func first_names_for(country: int, appearance: int) -> Array[String]:
	if country == Country.Code.SA:
		match appearance:
			Appearance.Bucket.WHITE:  return _FIRSTS_SA_WHITE.duplicate()
			Appearance.Bucket.MIXED:  return _FIRSTS_SA_MIXED.duplicate()
			Appearance.Bucket.INDIAN: return _FIRSTS_SA_INDIAN.duplicate()
			Appearance.Bucket.BLACK:  return _FIRSTS_SA_BLACK.duplicate()
	elif country == Country.Code.AUS:
		match appearance:
			Appearance.Bucket.WHITE:  return _FIRSTS_AUS_WHITE.duplicate()
			Appearance.Bucket.MIXED:  return _FIRSTS_AUS_MIXED.duplicate()
			Appearance.Bucket.INDIAN: return _FIRSTS_AUS_INDIAN.duplicate()
			Appearance.Bucket.BLACK:  return _FIRSTS_AUS_BLACK.duplicate()
	return [] as Array[String]

static func surnames_for(country: int, appearance: int) -> Array[String]:
	if first_names_for(country, appearance).is_empty():
		return [] as Array[String]
	return _SURNAMES_GENERIC.duplicate()
