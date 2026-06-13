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
			var act: Dictionary = {}
			for r in ["legendary", "rare", "common"]:
				var id: String = offer[r]
				if id == "":
					continue   # rarity not on the shelf this visit
				if not id in shop.owned_ids and player.tons_balance >= int(offer["prices"][id]):
					if shop.owned_ids.size() >= etun.loadout_cap:
						var out_id := _cheapest_owned(shop)
						if JokerCatalog.price(id) <= JokerCatalog.price(out_id):
							continue   # full slots: never swap a joker down
						act["replace"] = out_id
					act["buy"] = id
					break
			if not act.has("buy") and offer["legendary"] != "" and not offer["legendary"] in shop.owned_ids:
				act["hold"] = offer["legendary"]
			return act
		"balanced":
			# Reserve the next attribute upgrade, buy with the remainder.
			var act: Dictionary = {}
			var a := _lowest_attr(player)
			var reserve := 0
			if a != "":
				reserve = Economy.attr_upgrade_cost(player.attributes.get(a), etun)
				act["upgrade"] = a
			var budget: int = player.tons_balance - reserve
			for r in ["legendary", "rare", "common"]:
				var id: String = offer[r]
				if id == "":
					continue   # rarity not on the shelf this visit
				if not id in shop.owned_ids and budget >= int(offer["prices"][id]):
					if shop.owned_ids.size() >= etun.loadout_cap:
						var out_id := _cheapest_owned(shop)
						if JokerCatalog.price(id) <= JokerCatalog.price(out_id):
							continue   # full slots: never swap a joker down
						act["replace"] = out_id
					act["buy"] = id
					break
			if not act.has("buy") and offer["legendary"] != "" and not offer["legendary"] in shop.owned_ids and player.tons_balance >= int(offer["prices"][offer["legendary"]] * 0.6):
				act["hold"] = offer["legendary"]
			return act
	return {}
