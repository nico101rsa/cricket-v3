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

const FARM_MIN_SEASONS := 8   # farm crosses after this many Seasons at a Level even if
                              # the card never maxes (joker_only/balanced never train) —
                              # fixes the 0% softlock. Tunable — swept by career_search.gd.


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


# Accept one end-of-Season cross-up Offer, or stay (null). Never moves DOWN:
# the three poles only ever cross up or stay (the DC16 down-Offer exists for
# softlock recovery the naive line never triggers — E4-5).
static func choose_offer(kind: String, state: CareerState, offers: Array, player: Player) -> Offer:
	if not _wants_to_cross(kind, state, player):
		return null
	var lvl := state.current_level()
	for o in offers:
		if o.level > lvl:
			return o
	return null


# Whether this pole wants to leave the current Level now.
static func _wants_to_cross(kind: String, state: CareerState, player: Player) -> bool:
	match kind:
		"rush":
			return true                                # cross the instant offered
		"farm":
			# Over-invest before moving on: cross once the card maxes OR after
			# lingering FARM_MIN_SEASONS at this Level (the no-softlock fallback,
			# since joker_only/balanced never fully train).
			return _card_maxed(player) or state.seasons_at_level >= FARM_MIN_SEASONS
		"trophy":
			return state.level_won[state.current_level()]  # win the trophy first
	return false


static func _card_maxed(player: Player) -> bool:
	var a := player.attributes
	return a.power >= ShopResolver.ATTR_CAP \
		and a.composure >= ShopResolver.ATTR_CAP \
		and a.attack >= ShopResolver.ATTR_CAP \
		and a.control >= ShopResolver.ATTR_CAP
