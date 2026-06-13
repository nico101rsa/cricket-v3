class_name ShopPolicy
extends RefCounted

# Fixed Shop strategies for headless career runs (shop rung DK9). E4 searches
# this space properly; these are honest fixed lines. Each preset is a Callable
# matching play_season's shop_policy contract:
#   {"kind":"starter","offer":[3 common ids],...}  -> {"pick": id}
#   {"kind":"visit","offer":{...},"shop":ShopState,"player":Player,...}
#       -> {"buy": id, "replace": id, "upgrade": attr, "sell": id, "hold": id} (all optional)
#   {"kind":"carryover","shop":ShopState,...}      -> {"keep": id or ""}

const KINDS := ["attr_only", "joker_only", "balanced"]


static func preset(kind: String) -> Callable:
	return func(ctx: Dictionary) -> Dictionary:
		match ctx["kind"]:
			"starter":
				return {"pick": _best_common(ctx["offer"])}
			"visit":
				return _visit(kind, ctx)
			"carryover":
				return {"keep": _priciest_owned(ctx["shop"])}
		return {}


# The free starter: everyone takes the catalog-priciest Common (it is free).
static func _best_common(offer: Array) -> String:
	var best: String = offer[0]
	for id in offer:
		if JokerCatalog.price(id) > JokerCatalog.price(best):
			best = id
	return best


static func _priciest_owned(shop: ShopState) -> String:
	var best := ""
	for id in shop.owned_ids:
		if best == "" or JokerCatalog.price(id) > JokerCatalog.price(best):
			best = id
	return best


# Catalog price, deliberately NOT paid price: a free carried-over Legendary
# (paid 0) must rank as a Legendary, not as the first eviction target.
static func _cheapest_owned(shop: ShopState) -> String:
	var worst := ""
	for id in shop.owned_ids:
		if worst == "" or JokerCatalog.price(id) < JokerCatalog.price(worst):
			worst = id
	return worst


# The lowest current attribute under the cap ("" if all maxed) — keeps the four
# level, equivalent to the old preview round-robin.
static func _lowest_attr(player: Player) -> String:
	var best := ""
	var best_v := ShopResolver.ATTR_CAP
	for a in ShopResolver.ATTR_NAMES:
		var v: float = player.attributes.get(a)
		if v < best_v:
			best_v = v
			best = a
	return best


# The best affordable, not-owned joker across `rarities` (high to low), honouring
# the slot cap: when slots are full, never swap a joker DOWN in catalog price.
# Returns "" if none qualifies. Pure — mutates nothing.
static func _best_affordable(rarities: Array, offer: Dictionary, shop: ShopState,
		player: Player, etun: EconomyTuning) -> String:
	for r in rarities:
		var id: String = offer.get(r, "")
		if id == "" or id in shop.owned_ids:
			continue
		if player.tons_balance < int(offer["prices"][id]):
			continue
		if shop.owned_ids.size() >= etun.loadout_cap:
			if JokerCatalog.price(id) <= JokerCatalog.price(_cheapest_owned(shop)):
				continue   # full slots: never swap down
		return id
	return ""


# Wrap a buy id into an action dict, adding the slot-replacement when full.
static func _buy_act(id: String, shop: ShopState, etun: EconomyTuning) -> Dictionary:
	var act: Dictionary = {"buy": id}
	if shop.owned_ids.size() >= etun.loadout_cap:
		act["replace"] = _cheapest_owned(shop)
	return act


static func _visit(kind: String, ctx: Dictionary) -> Dictionary:
	var offer: Dictionary = ctx["offer"]
	var shop: ShopState = ctx["shop"]
	var player: Player = ctx["player"]
	var etun: EconomyTuning = ctx["etun"]
	match kind:
		"attr_only":
			var a := _lowest_attr(player)
			return {"upgrade": a} if a != "" else {}
		"joker_only":
			# Nico's playstyle: best affordable joker every visit, never
			# attributes; hold the Legendary it cannot yet afford.
			var id := _best_affordable(["legendary", "rare", "common"], offer, shop, player, etun)
			if id != "":
				return _buy_act(id, shop, etun)
			if offer["legendary"] != "" and not offer["legendary"] in shop.owned_ids:
				return {"hold": offer["legendary"]}
			return {}
		"balanced":
			# One action per visit (Nico 2026-06-13): buy a SCARCE joker (Rare or
			# Legendary) when one is affordably on the shelf, otherwise train the
			# lowest attribute — a Common joker loses to a permanent attribute
			# point. Once every attribute is maxed, spend on the best affordable
			# joker (Commons included), else hold an unaffordable Legendary.
			var scarce := _best_affordable(["legendary", "rare"], offer, shop, player, etun)
			if scarce != "":
				return _buy_act(scarce, shop, etun)
			var a := _lowest_attr(player)
			if a != "":
				return {"upgrade": a}
			var any_id := _best_affordable(["legendary", "rare", "common"], offer, shop, player, etun)
			if any_id != "":
				return _buy_act(any_id, shop, etun)
			if offer["legendary"] != "" and not offer["legendary"] in shop.owned_ids:
				return {"hold": offer["legendary"]}
			return {}
	return {}
