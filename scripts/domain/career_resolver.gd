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

	# Down: ALWAYS one Team from the highest unwon lower Level (DC16, rationale
	# updated by career-pacing DP2: with the endgame gate removed this is the
	# path back down for the optional Premium-trophy chase / future lifeline).
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
# with the cell's DifficultyLadder spec (DC13), bank Tons (DC9/DC10 + v2 prizes
# DV7-DV9 — accrued match-by-match so mid-Season Shop budgets are real, shop
# rung DK4), update the grid, tick Seasons-played, mutate all 24 Teams (DC8),
# then generate Offers. shop_policy (DK9): a Callable deciding Shop actions —
# invalid Callable = no Shop, byte-identical to the pre-Shop path (DK3).
# Returns {season, pay, wins, offers, shop_log, shop_owned}; {} if locked.
# match_snaps (optional, deliverable-only): when an Array is passed, one snapshot
# per settled Player match is appended in play order — {bank, power, composure,
# attack, control, jokers, held} captured as that match was played (state steps
# only at Kit Room visits). Off by default → byte-identical, no RNG touched.
static func play_season(
		state: CareerState, player: Player, tour_index: int,
		tuning: BallTuning, itun: InningsTuning, etun: EconomyTuning,
		rng: RandomNumberGenerator,
		intent_plan: IntentPlan = null, bowling_plan: BowlingPlan = null,
		shop_policy: Callable = Callable(),
		match_snaps = null
) -> Dictionary:
	var level := state.current_level()
	if not state.is_unlocked(level, tour_index):
		push_warning("play_season: cell (%d,%d) is locked" % [level, tour_index])
		return {}
	var spec := DifficultyLadder.spec_for(level, tour_index)
	var team: Team = state.teams[state.current_team_index]
	var stars_at_play := team.stars   # pay uses the stars the Season was played at (DC8)

	var shop := ShopState.new()
	var shop_log: Array = []
	# Closure tally: matches settled so far + running pay/wins (DK4).
	var tally := {"count": 0, "pay": 0, "wins": 0}
	var hook := Callable()
	if shop_policy.is_valid():
		# V0 (DK2): carry-over enters free, then the free starter Common.
		if state.carryover_joker_id != "":
			shop.owned_ids.append(state.carryover_joker_id)
			shop.paid_prices[state.carryover_joker_id] = 0
			shop_log.append({"action": "carryover_in", "id": state.carryover_joker_id})
		var starter := ShopResolver.starter_offer(rng, shop)
		var pick: Dictionary = shop_policy.call({"kind": "starter", "offer": starter,
			"shop": shop, "player": player, "level": level, "tour": tour_index, "etun": etun})
		var pick_id: String = pick.get("pick", starter[0])
		if pick_id in starter:
			shop.owned_ids.append(pick_id)
			shop.paid_prices[pick_id] = 0
			shop_log.append({"action": "starter", "id": pick_id})
		hook = func(pms: Array) -> Array:
			_settle_matches(pms, tally, stars_at_play, level, tour_index, etun, player, match_snaps, shop)
			var offer := ShopResolver.roll_offer(rng, shop, level, tour_index, etun)
			var act: Dictionary = shop_policy.call({"kind": "visit", "offer": offer,
				"shop": shop, "player": player, "level": level, "tour": tour_index, "etun": etun})
			ShopResolver.apply_visit(act, shop, player, offer, etun, shop_log)
			return ShopResolver.loadout_effects(shop)

	var season := SeasonResolver.simulate_season(
		player.attributes, team, state.opponents_of_current(), spec.make_tour(),
		tuning, itun, rng, intent_plan, bowling_plan, spec,
		ShopResolver.loadout_effects(shop), hook)

	# Settle whatever the hooks did not (shop off: everything; shop on: the
	# championship match), then the Season-level prizes (DV9).
	_settle_matches(_player_matches(season), tally, stars_at_play, level, tour_index, etun, player, match_snaps, shop)
	var season_prize := Economy.season_prizes(
		season.player_final_position, season.won_final, level, tour_index, etun)
	player.tons_balance += season_prize
	tally["pay"] += season_prize

	# Season end: elect the carry-over (DK6), Shop state dies with the Season.
	if shop_policy.is_valid():
		var keep: Dictionary = shop_policy.call({"kind": "carryover",
			"shop": shop, "player": player, "level": level, "tour": tour_index, "etun": etun})
		var keep_id: String = keep.get("keep", "")
		state.carryover_joker_id = keep_id if keep_id in shop.owned_ids else ""

	state.record_outcome(level, tour_index, season.beat, season.won_final)
	state.seasons_played += 1

	for t in state.teams:
		t.mutate_stars(rng)

	return {
		"season": season,
		"pay": tally["pay"],
		"wins": tally["wins"],
		"offers": generate_offers(state, season.beat, rng),
		"shop_log": shop_log,
		"shop_owned": shop.owned_ids.duplicate(),
	}


# Bank pay + win prizes for every not-yet-settled Player match (DK4). The
# slice from tally.count keeps settlement idempotent across hook calls.
static func _settle_matches(pms: Array, tally: Dictionary, stars_at_play: float,
		level: int, tour_index: int, etun: EconomyTuning, player: Player,
		match_snaps = null, shop: ShopState = null) -> void:
	for k in range(tally["count"], pms.size()):
		var m: MatchResult = pms[k]
		var p: int = Economy.match_pay(m, stars_at_play, etun)["total"]
		if m.outcome == MatchResult.Outcome.PLAYER_WIN:
			tally["wins"] += 1
			p += Economy.match_win_prize(level, tour_index, etun)
		tally["pay"] += p
		player.tons_balance += p
		# Deliverable snapshot: state as this match was played (attrs/jokers step
		# only at Kit Room visits, which run after this settle in the hook).
		if match_snaps != null:
			match_snaps.append({
				"bank": player.tons_balance,
				"power": player.attributes.power,
				"composure": player.attributes.composure,
				"attack": player.attributes.attack,
				"control": player.attributes.control,
				"jokers": shop.owned_ids.duplicate() if shop != null else [],
				"held": shop.held_id if shop != null else "",
			})
	tally["count"] = pms.size()


# Every match the Player actually played: the 7 league fixtures + any knockout
# whose scorecard carries the Player (statted matches only — derived knockouts
# between other teams have no player_line).
static func _player_matches(season: SeasonResult) -> Array:
	var out: Array = season.league.player_matches.duplicate()
	for m in [season.semi1, season.semi2, season.final_match, season.third_place]:
		if not m.innings1.player_line().is_empty() or not m.innings2.player_line().is_empty():
			out.append(m)
	return out
