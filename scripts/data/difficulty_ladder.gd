class_name DifficultyLadder
extends RefCounted

# The Career grid's difficulty table (E3, spec
# 2026-06-12-difficulty-ladder-7cE3-design.md). Codifies the canon difficulty
# sheet (CONTEXT.md: overlapping bands Club 1-8 / City 2-10 / Province 3-12,
# jumps at Home->Away and ->Premium) and assigns each cell a brain + blend.

const LEVEL_NAMES := ["Club", "City", "Province"]
const TOUR_NAMES := [
	"Practise", "Home summer", "Home winter", "Home evening",
	"Away summer", "Away winter", "Away evening", "Premium",
]

# d per [level][tour_index] — the tunable artifact (DL1).
const D_SHEET := [
	[1.0, 2.0, 2.5, 3.0, 5.0, 5.5, 6.0, 8.0],
	[2.0, 3.0, 3.5, 4.0, 6.5, 7.0, 7.5, 10.0],
	[3.0, 4.5, 5.0, 5.5, 8.0, 8.5, 9.0, 12.0],
]

# Neutral 7-opponent ★ field, all cells this rung (DL2): mean 3.0.
const OPP_STARS := [2.0, 2.5, 3.0, 3.0, 3.0, 3.5, 4.0]

# d -> [tier, blend] (spec §3.2 strawman).
static func brain_for(d: float) -> Array:
	if d <= 2.0:
		return [TourSpec.Tier.NAIVE, 1.0]
	if d <= 4.0:
		return [TourSpec.Tier.TEXTBOOK, 0.5]
	if d <= 6.0:
		return [TourSpec.Tier.TEXTBOOK, 1.0]
	if d <= 8.0:
		return [TourSpec.Tier.STATIC_EQ, 0.5]
	if d <= 9.0:
		return [TourSpec.Tier.STATIC_EQ, 1.0]
	if d <= 11.0:
		return [TourSpec.Tier.ADAPTIVE, 0.5]
	return [TourSpec.Tier.ADAPTIVE, 1.0]

static func spec_for(level: int, tour_index: int) -> TourSpec:
	var spec := TourSpec.new()
	spec.level = level
	spec.tour_index = tour_index
	spec.d = D_SHEET[level][tour_index]
	spec.cell_name = "%s %s" % [LEVEL_NAMES[level], TOUR_NAMES[tour_index]]
	var brain := brain_for(spec.d)
	spec.brain_tier = brain[0]
	spec.blend = brain[1]
	spec.opp_stars = OPP_STARS.duplicate()
	return spec

static func all() -> Array:
	var out: Array = []
	for lvl in range(3):
		for t in range(8):
			out.append(spec_for(lvl, t))
	return out
