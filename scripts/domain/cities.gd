class_name Cities
extends RefCounted

# Per-Country V1 city lists. Flavour-only — no mechanical impact.
# Source: spec §3.2.

const SA: Array[String] = [
	"Cape Town", "Johannesburg", "Durban", "Pretoria", "Gqeberha",
	"East London", "Bloemfontein", "Pietermaritzburg", "Centurion",
	"Paarl", "Potchefstroom",
]

const AUS: Array[String] = [
	"Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide",
	"Hobart", "Canberra", "Geelong", "Newcastle", "Darwin",
]

static func for_country(c: int) -> Array[String]:
	match c:
		Country.Code.SA:  return SA.duplicate()
		Country.Code.AUS: return AUS.duplicate()
		_: return [] as Array[String]
