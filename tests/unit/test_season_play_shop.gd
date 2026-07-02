extends GutTest

# The Kit Room on the live driver (spec 2026-07-02, Rung 2): canon 5-visit
# cadence, per-tap ShopResolver actions, one paid action per visit, and the
# lossless cross-session round-trip under mid-season shopping.

func _rich_player() -> Player:
	var p := Player.new()
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	p.attributes = a
	p.tons_balance = 10000
	return p

func _play_with_shop(seed_value: int = 20260702, carryover: String = "") -> Dictionary:
	var p := _rich_player()
	var career := CareerResolver.start_career(0)
	var sp := SeasonPlay.start(p.attributes, career.teams[career.current_team_index],
		career.opponents_of_current(), DifficultyLadder.spec_for(0, 0).make_tour(),
		BallTuning.new(), InningsTuning.new(), seed_value)
	sp.enable_shop(p, EconomyTuning.new(), 0, 0, carryover)
	return {"sp": sp, "p": p, "career": career}

func _commit_n(sp: SeasonPlay, n: int) -> void:
	for i in range(n):
		sp.commit_player_result(sp.make_session().result())

func test_shop_off_is_inert() -> void:
	var career := CareerResolver.start_career(0)
	var sp := SeasonPlay.start(Attributes.new(), career.teams[0],
		career.opponents_of_current(), DifficultyLadder.spec_for(0, 0).make_tour(),
		BallTuning.new(), InningsTuning.new(), 1)
	assert_false(sp.shop_enabled())
	assert_eq(sp.pending_shop_visit(), {}, "no shop, no visits")

func test_starter_pends_then_pick_consumes() -> void:
	var c := _play_with_shop()
	var sp: SeasonPlay = c["sp"]
	var v: Dictionary = sp.pending_shop_visit()
	assert_eq(v["kind"], "starter")
	assert_eq(v["visit"], 0)
	assert_eq((v["offer"] as Array).size(), 3, "3 starter Commons")
	var id: String = v["offer"][0]
	assert_true(sp.apply_shop_action({"kind": "pick", "id": id}))
	assert_true(id in sp.shop_owned(), "picked joker owned (free)")
	assert_eq(sp.pending_shop_visit(), {}, "v0 consumed; nothing pends until match 3")

func test_visit_cadence_1_and_2() -> void:
	var c := _play_with_shop()
	var sp: SeasonPlay = c["sp"]
	sp.apply_shop_action({"kind": "skip"})   # consume v0
	_commit_n(sp, 2)
	assert_eq(sp.pending_shop_visit(), {}, "nothing after match 2")
	_commit_n(sp, 1)
	assert_eq(sp.pending_shop_visit()["visit"], 1, "V1 after match 3")
	assert_true(sp.apply_shop_action({"kind": "skip"}))
	_commit_n(sp, 2)
	assert_eq(sp.pending_shop_visit()["visit"], 2, "V2 after match 5")

func test_offer_is_deterministic_and_cached() -> void:
	var c := _play_with_shop()
	var sp: SeasonPlay = c["sp"]
	sp.apply_shop_action({"kind": "skip"})
	_commit_n(sp, 3)
	var a: Dictionary = sp.pending_shop_visit()
	var b: Dictionary = sp.pending_shop_visit()
	assert_eq(a["offer"]["common"], b["offer"]["common"], "same visit, same offer")

func test_buy_deducts_and_changes_next_match() -> void:
	var c := _play_with_shop()
	var sp: SeasonPlay = c["sp"]
	var p: Player = c["p"]
	sp.apply_shop_action({"kind": "skip"})
	_commit_n(sp, 3)
	var offer: Dictionary = sp.pending_shop_visit()["offer"]
	var id: String = offer["common"]
	var price: int = offer["prices"][id]
	var before_next: int = sp.make_session().result().innings1.total \
		+ sp.make_session().result().innings2.total
	var bal: int = p.tons_balance
	assert_true(sp.apply_shop_action({"kind": "buy", "id": id}))
	assert_eq(p.tons_balance, bal - price, "price deducted")
	assert_true(id in sp.shop_owned())
	var after_next: int = sp.make_session().result().innings1.total \
		+ sp.make_session().result().innings2.total
	assert_ne(after_next, before_next, "owned joker alters the next live match")

func test_one_paid_action_per_visit() -> void:
	var c := _play_with_shop()
	var sp: SeasonPlay = c["sp"]
	sp.apply_shop_action({"kind": "skip"})
	_commit_n(sp, 3)
	var offer: Dictionary = sp.pending_shop_visit()["offer"]
	assert_true(sp.apply_shop_action({"kind": "buy", "id": offer["common"]}))
	assert_false(sp.apply_shop_action({"kind": "train", "attr": "power"}),
		"train refused after a buy this visit")
	assert_true(sp.apply_shop_action({"kind": "skip"}))
	assert_eq(sp.pending_shop_visit(), {}, "visit closed")

func test_train_upgrades_attr_and_costs() -> void:
	var c := _play_with_shop()
	var sp: SeasonPlay = c["sp"]
	var p: Player = c["p"]
	sp.apply_shop_action({"kind": "skip"})
	_commit_n(sp, 3)
	var bal: int = p.tons_balance
	assert_true(sp.apply_shop_action({"kind": "train", "attr": "power"}))
	assert_eq(p.attributes.power, 56.0, "+1 power")
	assert_lt(p.tons_balance, bal, "training costs")

func test_sell_refunds_zero_for_free_joker() -> void:
	var c := _play_with_shop(20260702, "block_the_shine")   # carry-over enters free
	var sp: SeasonPlay = c["sp"]
	var p: Player = c["p"]
	sp.apply_shop_action({"kind": "skip"})
	_commit_n(sp, 3)
	var bal: int = p.tons_balance
	assert_true(sp.apply_shop_action({"kind": "sell", "id": "block_the_shine"}))
	assert_eq(p.tons_balance, bal, "free joker refunds 0")
	assert_false("block_the_shine" in sp.shop_owned())

func test_playoff_visits_semi_and_final() -> void:
	# Strong player team reaches the playoffs deterministically (mirrors test_season_play).
	var p := _rich_player()
	var team := Team.new(); team.team_name = "My XI"; team.stars = 4.5
	var opps: Array = []
	for k in range(7):
		var o := Team.new(); o.team_name = "Opp %d" % k; o.stars = 1.5
		opps.append(o)
	var sp := SeasonPlay.start(p.attributes, team, opps,
		DifficultyLadder.spec_for(0, 0).make_tour(), BallTuning.new(), InningsTuning.new(), 20260616)
	sp.enable_shop(p, EconomyTuning.new(), 0, 0)
	sp.apply_shop_action({"kind": "skip"})   # v0
	_commit_n(sp, 3)
	sp.apply_shop_action({"kind": "skip"})   # v1
	_commit_n(sp, 2)
	sp.apply_shop_action({"kind": "skip"})   # v2
	_commit_n(sp, 2)   # league done
	assert_eq(sp.phase(), "playoffs", "precondition: in the playoffs")
	var v3: Dictionary = sp.pending_shop_visit()
	assert_eq(v3.get("visit", -1), 3, "V3 pends before the semi")
	sp.apply_shop_action({"kind": "skip"})
	_commit_n(sp, 1)   # the semi
	var after_semi: Dictionary = sp.pending_shop_visit()
	if not sp.season_done():
		# Won the semi -> V4 pre-final; lost -> the 3rd-place match has NO visit.
		var nxt := sp.next_player_opponent()
		if nxt.get("stage", "") == "final":
			assert_eq(after_semi.get("visit", -1), 4, "V4 pends before the final")
		else:
			assert_eq(after_semi, {}, "no visit before the 3rd-place match")
