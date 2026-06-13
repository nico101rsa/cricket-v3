class_name ShopResolver
extends RefCounted

# Pure Shop mechanics (spec 2026-06-12-shop-rung-design.md DK5-DK15).
# The Kit Room screen and the career harness both call these. Illegal actions
# push_warning + no-op (GUT counts push_error as a failure).

const ATTR_CAP := 60.0          # career-pacing DP4
const ATTR_NAMES := ["power", "composure", "attack", "control"]
const RARITIES := ["common", "rare", "legendary"]


# One post-Match offer: 1 Common + 1 Rare + 1 Legendary, owned ids excluded,
# a held id occupies its rarity slot (DK15). Returns
# {"common": id, "rare": id, "legendary": id, "prices": {id: int}}.
static func roll_offer(rng: RandomNumberGenerator, state: ShopState,
		level: int, tour: int, etun: EconomyTuning) -> Dictionary:
	var held_rarity := ""
	if state.held_id != "":
		held_rarity = _rarity_of(state.held_id).to_lower()
	# Rarity odds (Nico 2026-06-13): a Common is always on the shelf; a Rare
	# appears shop_rare_chance of visits, a Legendary shop_legendary_chance —
	# higher tiers genuinely scarce. A HELD joker always reclaims its slot.
	# Absent slots are "" with no price entry; callers must skip them.
	var offer := {"common": "", "rare": "", "legendary": "", "prices": {}}
	for r in RARITIES:
		var present: bool = r == "common" or r == held_rarity
		if not present:
			if r == "rare":
				present = rng.randf() < etun.shop_rare_chance
			elif r == "legendary":
				present = rng.randf() < etun.shop_legendary_chance
		if not present:
			continue
		var id: String = state.held_id if r == held_rarity else _draw(rng, r.capitalize(), state)
		offer[r] = id
		offer["prices"][id] = Economy.joker_price(id, level, tour, etun)
	return offer


# Season-start free pick: 3 distinct Commons, owned excluded (DK2/V0).
static func starter_offer(rng: RandomNumberGenerator, state: ShopState) -> Array:
	var out: Array = []
	while out.size() < 3:
		var id := _draw(rng, "Common", state, out)
		out.append(id)
	return out


static func _draw(rng: RandomNumberGenerator, rarity: String, state: ShopState,
		also_excluded: Array = []) -> String:
	var pool: Array = []
	for id in JokerCatalog.ids_of_rarity(rarity):
		if not id in state.owned_ids and id != state.held_id and not id in also_excluded:
			pool.append(id)
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _rarity_of(id: String) -> String:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return g["rarity"]
	return ""


# --- Actions (each capped at one per visit by the caller, DK7) ---------------

# Buy at the offered price. Full slots need replace_id (the replaced joker is
# removed WITHOUT refund — selling is its own action, DK7). False on no-op.
static func buy(state: ShopState, player: Player, id: String, price: int,
		etun: EconomyTuning, replace_id: String = "") -> bool:
	if id in state.owned_ids or player.tons_balance < price:
		push_warning("shop buy refused: %s" % id)
		return false
	if state.owned_ids.size() >= etun.loadout_cap:
		if not replace_id in state.owned_ids:
			push_warning("shop buy refused (slots full, no valid replacement): %s" % id)
			return false
		state.owned_ids.erase(replace_id)
		state.paid_prices.erase(replace_id)
	player.tons_balance -= price
	state.owned_ids.append(id)
	state.paid_prices[id] = price
	if state.held_id == id:
		state.held_id = ""
	return true


# Sell for sell_refund_frac of the price PAID (DK14; free jokers refund 0).
static func sell(state: ShopState, player: Player, id: String, etun: EconomyTuning) -> bool:
	if not id in state.owned_ids:
		push_warning("shop sell refused: %s" % id)
		return false
	player.tons_balance += Economy.sell_refund(int(state.paid_prices.get(id, 0)), etun)
	state.owned_ids.erase(id)
	state.paid_prices.erase(id)
	return true


# Hold one OFFERED id for the next visit (DK15). Free; expires at Season end.
static func hold(state: ShopState, offer: Dictionary, id: String) -> bool:
	if id in state.owned_ids:
		push_warning("shop hold refused (already owned): %s" % id)
		return false
	if id != offer["common"] and id != offer["rare"] and id != offer["legendary"]:
		push_warning("shop hold refused (not in offer): %s" % id)
		return false
	state.held_id = id
	return true


# +1 to one attribute (canon: one per visit), cap 60 (DP4). False on no-op.
static func upgrade_attribute(player: Player, attr_name: String, etun: EconomyTuning) -> bool:
	if not attr_name in ATTR_NAMES:
		push_warning("shop upgrade refused (unknown attr): %s" % attr_name)
		return false
	var cur: float = player.attributes.get(attr_name)
	var cost := Economy.attr_upgrade_cost(cur, etun)
	if cur >= ATTR_CAP or player.tons_balance < cost:
		return false
	player.attributes.set(attr_name, cur + 1.0)
	player.tons_balance -= cost
	return true


# Apply one visit's decided actions in a fixed order: sell -> buy -> upgrade
# -> hold (selling first frees a slot + cash for the buy). `act` keys are all
# optional: {"sell": id, "buy": id, "replace": id, "upgrade": attr, "hold": id}.
# ONE ACTION PER VISIT (Nico 2026-06-13): a visit buys a joker OR trains an
# attribute, never both — a successful buy pre-empts an upgrade. Sell (frees a
# slot/cash) and hold (reserve an offered joker) are free meta-actions and may
# still accompany the chosen action. Appends plain-English entries to log (DK12).
static func apply_visit(act: Dictionary, state: ShopState, player: Player,
		offer: Dictionary, etun: EconomyTuning, log: Array) -> void:
	if act.get("sell", "") != "":
		if sell(state, player, act["sell"], etun):
			log.append({"action": "sell", "id": act["sell"]})
	var bought := false
	if act.get("buy", "") != "":
		var id: String = act["buy"]
		var price: int = offer["prices"].get(id, -1)
		if price < 0:
			push_warning("shop buy refused (not in offer): %s" % id)
		elif buy(state, player, id, price, etun, act.get("replace", "")):
			log.append({"action": "buy", "id": id, "tons": price})
			bought = true
	if not bought and act.get("upgrade", "") != "":
		if upgrade_attribute(player, act["upgrade"], etun):
			log.append({"action": "upgrade", "id": act["upgrade"]})
	if act.get("hold", "") != "":
		if hold(state, offer, act["hold"]):
			log.append({"action": "hold", "id": act["hold"]})


# The sim-facing loadout: flattened effect rows of everything owned (DK8).
static func loadout_effects(state: ShopState) -> Array:
	return JokerCatalog.effects_of_ids(state.owned_ids)


# Career-fidelity CF3: the plans a sensible owner would set for this loadout —
# the field mode its gated jokers want (modal across effect rows, all phases)
# and the sweep-standard Boost presses when a boost-channel joker is owned.
# The playable game hands these controls to the human; headless career play
# derives them so gated jokers fire as priced. {"field": FieldPlan or null,
# "boost": BoostPlan or null}.
static func plans_for(effects: Array) -> Dictionary:
	var counts := {}
	var has_boost := false
	for e in effects:
		if e.field_req >= 0:
			counts[e.field_req] = counts.get(e.field_req, 0) + 1
		if e.boost_role != JokerEffect.BoostRole.NONE:
			has_boost = true
	var field: FieldPlan = null
	if not counts.is_empty():
		var best := -1
		for mode in counts:
			if best == -1 or counts[mode] > counts[best]:
				best = mode
		field = FieldPlan.new()
		field.powerplay = best
		field.middle = best
		field.death = best
	var boost: BoostPlan = null
	if has_boost:
		boost = BoostPlan.at([1, 10, 16])
	return {"field": field, "boost": boost}
