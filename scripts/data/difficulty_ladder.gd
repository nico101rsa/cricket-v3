class_name DifficultyLadder
extends RefCounted

# The Career grid's difficulty table — v2 (spec
# 2026-06-12-difficulty-sheet-v2-design.md DV1-DV3, superseding the E3 v1
# sheet): Nico's condition-named tours, linear 1-step ramp inside a Level,
# jump into Premier, bands Club 1-10 / City 5-15 / Province 9-20.

const LEVEL_NAMES := ["Club", "City", "Province"]
const TOUR_NAMES := [
	"Flat & Warm", "Spin", "Green Mamba", "Day Mixed",
	"Evening Spin", "Evening Mamba", "Evening Mixed", "Premier",
]

# d per [level][tour_index] — Nico's sheet verbatim (DV1).
const D_SHEET := [
	[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 10.0],
	[5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 15.0],
	[9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 20.0],
]

# Neutral 7-opponent ★ field, all cells this rung (DL2): mean 3.0.
const OPP_STARS := [2.0, 2.5, 3.0, 3.0, 3.0, 3.5, 4.0]

# d -> [tier, blend] — v1 thresholds scaled 19/11 onto the d 1-20 axis (DV3).
# The ADAPTIVE 0.5 band (d 16-18) is currently unoccupied; kept for ramp
# continuity under future sheet edits.
static func brain_for(d: float) -> Array:
	if d <= 3.0:
		# Entry-tour over-boost fix (player-leverage PL2, 2026-06-14): a pure-NAIVE
		# (random) opponent handed the Player's weakest side a ~25% Club-league-win
		# floor regardless of card (the Player faces it; the rest of the league plays
		# competently). TEXTBOOK with p=0.4 (else NAIVE via blend-down) = "weak but
		# not a pushover" -> a fresh underdog wins ~12% and must grow the card to win.
		# Sits just below Tour 4's [TEXTBOOK, 0.5]. Only affects Club Tours 1-3.
		return [TourSpec.Tier.TEXTBOOK, 0.4]
	if d <= 6.0:
		return [TourSpec.Tier.TEXTBOOK, 0.5]
	if d <= 10.0:
		return [TourSpec.Tier.TEXTBOOK, 1.0]
	if d <= 13.0:
		return [TourSpec.Tier.STATIC_EQ, 0.5]
	if d <= 15.0:
		return [TourSpec.Tier.STATIC_EQ, 1.0]
	if d <= 18.0:
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
