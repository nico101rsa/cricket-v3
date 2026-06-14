class_name CareerPolicy
extends RefCounted

# Climb strategies for the headless career search (E4, spec
# 2026-06-14-e4-career-line-search-design.md). Pure, static — mirrors
# ShopPolicy. Owns the two climb decisions each Season: which tour to play and
# whether to accept an end-of-Season cross-up Offer. The search tool
# (tools/career_search.gd) grids these × ShopPolicy spend presets.
#
# Single-agent: careers aren't adversarial (the opponent brain is fixed per
# cell), so these are honest named strategies, not a self-play search.

const KINDS := ["rush", "farm", "trophy"]


# Which unlocked tour to play at the current Level this Season.
static func choose_tour(kind: String, state: CareerState) -> int:
	var cells := state.playable_cells()   # unlocked tours, ascending
	if kind == "farm":
		# Highest unlocked tour — climb to the richest cell, then replay it.
		return cells.back()
	# rush & trophy: lowest unbeaten unlocked tour; if all beaten, the Premier
	# (T7) — replay it to chase the final win still owed.
	var lvl := state.current_level()
	for t in cells:
		if state.status_of(lvl, t) != CareerState.CellStatus.BEATEN:
			return t
	return CareerState.PREMIER_TOUR
