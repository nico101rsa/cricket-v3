class_name PlayerNames
extends RefCounted

# FLAVOUR ONLY. The match sim is statistical — it tracks batters by position and
# never models named players. These surnames are pure cosmetic dressing for the
# in-match scorecard (like the commentary text): they carry NO data and never feed
# the sim. All NUMBERS shown beside a name (runs/balls/economy/★) come from the real
# model; the name itself is decoration keyed deterministically to team + position so
# a given team always fields the same XI on screen. See docs/design-inbox/in-match.md
# (the "flavour names + real numbers" decision, 2026-06-19).

# Surname pools per country (Country.Code: SA = 0, AUS = 1).
const POOL_SA: Array[String] = [
	"Kgosi", "Naidoo", "Pretorius", "Du Plessis", "Mkhize", "Botha", "Swart",
	"Van Wyk", "Dlamini", "Steyn", "Maharaj", "Nkosi", "Coetzee", "Jacobs", "Sithole",
]
const POOL_AUS: Array[String] = [
	"Smith", "Cummins", "Maxwell", "Head", "Carey", "Hazlewood", "Marsh",
	"Green", "Zampa", "Warner", "Starc", "Labuschagne", "Inglis", "Abbott", "Stoinis",
]

static func _pool(country_code: int) -> Array:
	return POOL_AUS if country_code == Country.Code.AUS else POOL_SA

# A stable flavour surname for batting `position` (1-based) of a team. Deterministic
# from the team name + position so the same team always shows the same XI; the offset
# spreads the pool so two teams rarely share a name.
static func for_position(team_name: String, country_code: int, position: int) -> String:
	var pool := _pool(country_code)
	var offset := absi(team_name.hash()) % pool.size()
	return pool[(offset + maxi(position, 1) - 1) % pool.size()]

# UPPER-cased form for the scorecard chips.
static func upper(team_name: String, country_code: int, position: int) -> String:
	return for_position(team_name, country_code, position).to_upper()

# Two-letter badge initials from a surname ("Du Plessis" -> "DP", "Kgosi" -> "KG").
static func badge(surname: String) -> String:
	var parts := surname.split(" ", false)
	if parts.size() >= 2:
		return (parts[0].substr(0, 1) + parts[1].substr(0, 1)).to_upper()
	return surname.substr(0, 2).to_upper()
