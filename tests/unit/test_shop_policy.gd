extends GutTest

# ShopPolicy presets (shop rung DK9).

func _ctx_visit(tons: int) -> Dictionary:
	var p := Player.new()
	p.attributes = Attributes.new()
	p.tons_balance = tons
	return {"kind": "visit",
		"offer": {"common": "dead_bat", "rare": "snicko", "legendary": "choke_hold",
			"prices": {"dead_bat": 30, "snicko": 90, "choke_hold": 225}},
		"shop": ShopState.new(), "player": p, "level": 0, "tour": 0,
		"etun": EconomyTuning.new()}


func test_attr_only_never_buys() -> void:
	var act: Dictionary = ShopPolicy.preset("attr_only").call(_ctx_visit(10000))
	assert_false(act.has("buy"))
	assert_true(act.has("upgrade"))

func test_joker_only_never_upgrades_buys_best_affordable() -> void:
	var rich: Dictionary = ShopPolicy.preset("joker_only").call(_ctx_visit(10000))
	assert_eq(rich.get("buy", ""), "choke_hold")
	assert_false(rich.has("upgrade"))
	var mid: Dictionary = ShopPolicy.preset("joker_only").call(_ctx_visit(100))
	assert_eq(mid.get("buy", ""), "snicko")
	var broke: Dictionary = ShopPolicy.preset("joker_only").call(_ctx_visit(5))
	assert_false(broke.has("buy"))
	assert_eq(broke.get("hold", ""), "choke_hold", "holds the Legendary it cannot afford")

func test_balanced_buys_scarce_joker_never_both() -> void:
	# One action per visit: a Legendary is affordable -> buy it, no upgrade.
	var act: Dictionary = ShopPolicy.preset("balanced").call(_ctx_visit(450))
	assert_eq(act.get("buy", ""), "choke_hold")
	assert_false(act.has("upgrade"), "one action per visit — never buy AND train")

func test_balanced_trains_when_no_scarce_joker_affordable() -> void:
	# Only the Common is affordable -> train instead (a Common loses to a point).
	var act: Dictionary = ShopPolicy.preset("balanced").call(_ctx_visit(50))
	assert_true(act.has("upgrade"))
	assert_false(act.has("buy"))

func test_starter_pick_is_priciest_common() -> void:
	var act: Dictionary = ShopPolicy.preset("joker_only").call(
		{"kind": "starter", "offer": ["dead_bat", "powerplay_punch", "cool_head"]})
	assert_eq(act["pick"], "powerplay_punch", "45 > 35 > 30 in the catalog")
