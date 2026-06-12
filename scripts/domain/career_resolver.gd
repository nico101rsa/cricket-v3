class_name CareerResolver
extends RefCounted

# Drives the multi-Season Career loop on top of SeasonResolver (spec
# 2026-06-12-career-loop-design.md, DC1-DC16). Static, no member state.
# Deterministic given rng; per-Season draw order is fixed:
# league+playoffs -> star mutation x24 -> offer draws.

const STAR_LADDER := [1.5, 2.0, 2.5, 3.0, 3.0, 3.5, 4.0, 4.5]   # mean 3.0 (DC6)
const OFFER_COUNT := 3
const CROSS_OFFER_P := 0.5   # P(next-Level offer) when unlocked but not a fresh beat (DC11)

# Strawman SA-flavoured placeholder names (DC6); the Country master-data axis
# replaces these in a later data rung. "Karoo Kings" is canon-cited (CONTEXT.md).
const TEAM_NAMES := [
	["Karoo Kings", "Dusty Plains", "Riverside Rovers", "Old Mill XI",
	 "Salt Pan Strikers", "Bushveld Bears", "Harbour Town", "Granite Hill"],
	["Metro Mavericks", "Dockside Dynamos", "Uptown Titans", "Foundry Falcons",
	 "Skyline Sixers", "Old Quarter CC", "Park Lane Panthers", "Terminal Tigers"],
	["Highveld Hawks", "Coastal Chargers", "Garden Route Giants", "Drakensberg Drifters",
	 "Platteland Pumas", "Winelands Warriors", "Escarpment Eagles", "Lowveld Lions"],
]


# Build a fresh Career: 24 Teams on the star ladder, only Club Practise
# unlocked, the Player on one of the 3 lowest-star Club teams (DC7).
# Deterministic — no rng.
static func start_career(picked_club_slot: int) -> CareerState:
	var state := CareerState.new()
	for lvl in range(CareerState.LEVELS):
		for k in range(CareerState.TEAMS_PER_LEVEL):
			var t := Team.new()
			t.team_name = TEAM_NAMES[lvl][k]
			t.stars = STAR_LADDER[k]
			state.teams.append(t)
	var status: Array[int] = []
	for i in range(CareerState.LEVELS * CareerState.TOURS):
		status.append(CareerState.CellStatus.LOCKED)
	status[0] = CareerState.CellStatus.UNLOCKED
	state.cell_status = status
	if not picked_club_slot in state.lowest_star_club_indices():
		push_warning("start_career: pick %d is not a lowest-3 Club slot" % picked_club_slot)
		picked_club_slot = state.lowest_star_club_indices()[0]
	state.current_team_index = picked_club_slot
	return state
