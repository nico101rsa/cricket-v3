extends GutTest

# ShopResolver units — spec 2026-06-12-shop-rung-design.md DK5-DK15.

func _state() -> ShopState:
	return ShopState.new()

func _player(tons: int = 1000) -> Player:
	var p := Player.new()
	p.attributes = Attributes.new()
	p.tons_balance = tons
	return p

func _rng(s: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _etun() -> EconomyTuning:
	return EconomyTuning.new()


func test_roll_offer_common_always_present_excludes_owned() -> void:
	var st := _state()
	st.owned_ids.append("dead_bat")
	for s in range(20):
		var offer := ShopResolver.roll_offer(_rng(s), st, 0, 0, _etun())
		assert_true(JokerCatalog.ids_of_rarity("Common").has(offer["common"]), "Common always on the shelf")
		assert_ne(offer["common"], "dead_bat", "owned never offered")
		if offer["rare"] != "":
			assert_true(JokerCatalog.ids_of_rarity("Rare").has(offer["rare"]))
		if offer["legendary"] != "":
			assert_true(JokerCatalog.ids_of_rarity("Legendary").has(offer["legendary"]))
		var present := 1 + (1 if offer["rare"] != "" else 0) + (1 if offer["legendary"] != "" else 0)
		assert_eq(offer["prices"].size(), present, "one price per present slot")

func test_roll_offer_rarity_frequencies() -> void:
	var st := _state()
	var rares := 0
	var legs := 0
	var n := 600
	for s in range(n):
		var offer := ShopResolver.roll_offer(_rng(1000 + s), st, 0, 0, _etun())
		if offer["rare"] != "":
			rares += 1
		if offer["legendary"] != "":
			legs += 1
	assert_between(float(rares) / n, 0.42, 0.58, "Rare ~50%")
	assert_between(float(legs) / n, 0.09, 0.22, "Legendary ~15%")

func test_starter_offer_three_distinct_commons() -> void:
	var ids := ShopResolver.starter_offer(_rng(), _state())
	assert_eq(ids.size(), 3)
	for id in ids:
		assert_true(JokerCatalog.ids_of_rarity("Common").has(id))
	assert_ne(ids[0], ids[1])
	assert_ne(ids[1], ids[2])
	assert_ne(ids[0], ids[2])

func test_buy_moves_tons_and_records_paid() -> void:
	var st := _state()
	var p := _player(100)
	assert_true(ShopResolver.buy(st, p, "dead_bat", 30, _etun()))
	assert_eq(p.tons_balance, 70)
	assert_eq(st.paid_prices["dead_bat"], 30)
	assert_false(ShopResolver.buy(st, p, "dead_bat", 30, _etun()), "no duplicates")

func test_buy_refused_when_broke() -> void:
	var p := _player(10)
	assert_false(ShopResolver.buy(_state(), p, "dead_bat", 30, _etun()))
	assert_eq(p.tons_balance, 10)

func test_buy_full_slots_needs_replacement() -> void:
	var st := _state()
	var p := _player(1000)
	for id in ["dead_bat", "powerplay_punch", "block_the_shine", "rotate_the_strike"]:
		ShopResolver.buy(st, p, id, 30, _etun())
	assert_false(ShopResolver.buy(st, p, "snicko", 90, _etun()), "full, no replace")
	assert_true(ShopResolver.buy(st, p, "snicko", 90, _etun(), "dead_bat"))
	assert_false(st.owned_ids.has("dead_bat"))
	assert_eq(st.owned_ids.size(), 4)

func test_sell_refunds_half_of_paid_and_zero_for_free() -> void:
	var st := _state()
	var p := _player(100)
	ShopResolver.buy(st, p, "dead_bat", 30, _etun())     # balance 70
	assert_true(ShopResolver.sell(st, p, "dead_bat", _etun()))
	assert_eq(p.tons_balance, 85, "70 + floor(30*0.5)")
	st.owned_ids.append("powerplay_punch")               # free (starter/carry-over)
	ShopResolver.sell(st, p, "powerplay_punch", _etun())
	assert_eq(p.tons_balance, 85, "free joker refunds 0")

func test_hold_reappears_in_its_rarity_slot() -> void:
	var st := _state()
	# Find a seed whose offer actually has a Legendary (now only ~15% of visits).
	var offer := {}
	var seed_i := 0
	while true:
		offer = ShopResolver.roll_offer(_rng(seed_i), st, 0, 0, _etun())
		if offer["legendary"] != "":
			break
		seed_i += 1
	var held: String = offer["legendary"]
	assert_true(ShopResolver.hold(st, offer, held))
	var next_offer := ShopResolver.roll_offer(_rng(seed_i + 100), st, 0, 0, _etun())
	assert_eq(next_offer["legendary"], held, "a held joker always reclaims its slot")

func test_hold_refuses_owned_id() -> void:
	var st := _state()
	var p := _player(100)
	ShopResolver.buy(st, p, "dead_bat", 30, _etun())
	var offer := {"common": "dead_bat", "rare": "snicko", "legendary": "choke_hold",
		"prices": {"dead_bat": 30, "snicko": 90, "choke_hold": 225}}
	assert_false(ShopResolver.hold(st, offer, "dead_bat"))
	assert_eq(st.held_id, "")

func test_upgrade_attribute_plus_one_and_caps() -> void:
	var p := _player(10000)
	p.attributes.power = 31.0
	assert_true(ShopResolver.upgrade_attribute(p, "power", _etun()))
	assert_eq(p.attributes.power, 32.0)
	assert_eq(p.tons_balance, 10000 - Economy.attr_upgrade_cost(31.0, _etun()))
	p.attributes.power = 60.0
	assert_false(ShopResolver.upgrade_attribute(p, "power", _etun()), "cap 60")

func test_apply_visit_sell_first_frees_budget_for_buy() -> void:
	var st := _state()
	var p := _player(20)
	ShopResolver.buy(st, p, "dead_bat", 20, _etun())     # balance 0, paid 20
	var offer := {"common": "powerplay_punch", "rare": "snicko",
		"legendary": "choke_hold", "prices": {"powerplay_punch": 10, "snicko": 90, "choke_hold": 225}}
	var log: Array = []
	ShopResolver.apply_visit({"sell": "dead_bat", "buy": "powerplay_punch"},
		st, p, offer, _etun(), log)
	assert_true(st.owned_ids.has("powerplay_punch"), "sell (refund 10) funded the buy")
	assert_eq(log.size(), 2)

func test_loadout_effects_flatten_owned() -> void:
	var st := _state()
	st.owned_ids.append("the_chase_master")
	assert_gt(ShopResolver.loadout_effects(st).size(), 1)

func test_plans_for_field_from_gated_jokers() -> void:
	var fx := JokerCatalog.effects_of_ids(["tight_lines"])
	var plans := ShopResolver.plans_for(fx)
	assert_not_null(plans["field"], "field-gated joker sets the field")
	var fp: FieldPlan = plans["field"]
	assert_eq(fp.powerplay, fp.death, "uniform mode across phases")
	assert_null(plans["boost"])

func test_plans_for_boost_jokers() -> void:
	var fx := JokerCatalog.effects_of_ids(["power_up"])
	var plans := ShopResolver.plans_for(fx)
	assert_not_null(plans["boost"], "boost-channel joker arms the boost plan")

func test_plans_for_empty_loadout() -> void:
	var plans := ShopResolver.plans_for([])
	assert_null(plans["field"])
	assert_null(plans["boost"])
