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


# --- The Season turn (DC5/DC8/DC9/DC13) ----------------------------------------

# Play one Season at (current Level, tour_index): simulate via SeasonResolver
# with the cell's DifficultyLadder spec (tour distribution + opponent brain,
# DC13), bank ₸ (DC9 + DC10), update the grid, tick Seasons-played, mutate all
# 24 Teams (DC8), then generate Offers. Returns
# {season, pay, wins, offers}; {} if the cell is locked.
static func play_season(
		state: CareerState, player: Player, tour_index: int,
		tuning: BallTuning, itun: InningsTuning, etun: EconomyTuning,
		rng: RandomNumberGenerator,
		intent_plan: IntentPlan = null, bowling_plan: BowlingPlan = null
) -> Dictionary:
	var level := state.current_level()
	if not state.is_unlocked(level, tour_index):
		push_warning("play_season: cell (%d,%d) is locked" % [level, tour_index])
		return {}
	var spec := DifficultyLadder.spec_for(level, tour_index)
	var team: Team = state.teams[state.current_team_index]
	var stars_at_play := team.stars   # pay uses the stars the Season was played at (DC8)
	var season := SeasonResolver.simulate_season(
		player.attributes, team, state.opponents_of_current(), spec.make_tour(),
		tuning, itun, rng, intent_plan, bowling_plan, spec)

	var pay := 0
	var wins := 0
	for m in _player_matches(season):
		pay += Economy.match_pay(m, stars_at_play, etun)["total"]
		if m.outcome == MatchResult.Outcome.PLAYER_WIN:
			wins += 1
			pay += Economy.win_bonus(level, etun)
	player.tons_balance += pay

	state.record_outcome(level, tour_index, season.beat, season.won_final)
	state.seasons_played += 1

	for t in state.teams:
		t.mutate_stars(rng)

	return {
		"season": season,
		"pay": pay,
		"wins": wins,
		"offers": generate_offers(state, season.beat, rng),
	}


# Every match the Player actually played: the 7 league fixtures + any knockout
# whose scorecard carries the Player (statted matches only — derived knockouts
# between other teams have no player_line).
static func _player_matches(season: SeasonResult) -> Array:
	var out: Array = season.league.player_matches.duplicate()
	for m in [season.semi1, season.semi2, season.final_match, season.third_place]:
		if not m.innings1.player_line().is_empty() or not m.innings2.player_line().is_empty():
			out.append(m)
	return out
