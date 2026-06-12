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


# --- Offers (DC11 + DC16) -----------------------------------------------------

# End-of-Season offer set: [cross-up slot] + [down slot, DC16] + same-Level
# fill, max OFFER_COUNT, all distinct, never the current Team. Staying is
# always available to the caller — it is not an Offer row.
static func generate_offers(state: CareerState, just_beat: bool, rng: RandomNumberGenerator) -> Array:
	if state.complete:
		return []
	var level := state.current_level()
	var offers: Array = []
	var taken: Array = [state.current_team_index]

	# Cross-up: guaranteed on a fresh beat with the higher Level reachable,
	# else a CROSS_OFFER_P coin (DC11).
	var up := level + 1
	if up < CareerState.LEVELS and state.any_unlocked_at(up):
		if just_beat or rng.randf() < CROSS_OFFER_P:
			_append_offer(state, up, taken, offers, rng)

	# Down: ALWAYS one Team from the highest unwon lower Level (DC16 —
	# anti-softlock: the endgame gate needs every Level's Premium won).
	for down in range(level - 1, -1, -1):
		if not state.level_won[down]:
			_append_offer(state, down, taken, offers, rng)
			break

	while offers.size() < OFFER_COUNT:
		if not _append_offer(state, level, taken, offers, rng):
			break
	return offers


# Draw one random not-yet-taken Team at `level` into offers. False if exhausted.
static func _append_offer(state: CareerState, level: int, taken: Array, offers: Array, rng: RandomNumberGenerator) -> bool:
	var pool: Array = []
	for i in range(level * CareerState.TEAMS_PER_LEVEL, (level + 1) * CareerState.TEAMS_PER_LEVEL):
		if not i in taken:
			pool.append(i)
	if pool.is_empty():
		return false
	var idx: int = pool[rng.randi_range(0, pool.size() - 1)]
	taken.append(idx)
	var o := Offer.new()
	o.team_index = idx
	o.level = level
	o.stars = state.teams[idx].stars
	offers.append(o)
	return true


static func accept_offer(state: CareerState, player: Player, offer: Offer) -> void:
	state.current_team_index = offer.team_index
	player.affinity = 0


static func stay(_state: CareerState, player: Player) -> void:
	player.affinity += 1
