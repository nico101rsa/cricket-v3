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
	# Pass the cell spec exactly as the hub/from_state do — the round-trip pin
	# compares against a from_state rebuild, which always carries spec_for(0,0).
	var spec := DifficultyLadder.spec_for(0, 0)
	var sp := SeasonPlay.start(p.attributes, career.teams[career.current_team_index],
		career.opponents_of_current(), spec.make_tour(),
		BallTuning.new(), InningsTuning.new(), seed_value, spec)
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

func test_buy_deducts_owns_and_feeds_the_loadout() -> void:
	var c := _play_with_shop()
	var sp: SeasonPlay = c["sp"]
	var p: Player = c["p"]
	sp.apply_shop_action({"kind": "skip"})
	_commit_n(sp, 3)
	var offer: Dictionary = sp.pending_shop_visit()["offer"]
	var id: String = offer["common"]
	var price: int = offer["prices"][id]
	var bal: int = p.tons_balance
	assert_true(sp.apply_shop_action({"kind": "buy", "id": id}))
	assert_eq(p.tons_balance, bal - price, "price deducted")
	assert_true(id in sp.shop_owned())
	# The sim hand-off: the live loadout now carries exactly the owned effects.
	# (Whether a given joker moves a given match depends on its trigger — e.g.
	# boost-role jokers only fire on a human Boost press, DLF-BOOST.)
	assert_gt(sp.player_effects().size(), 0, "effects flow to the live matches")
	assert_eq(sp.player_effects().size(),
		JokerCatalog.effects_of_ids(sp.shop_owned()).size(), "loadout == owned effects")

func test_carryover_loadout_alters_the_live_matches() -> void:
	# Same seed, one play carries rotate_the_strike (runs mult on EVERY Balanced
	# hero ball — the live default intent, so it perturbs every hero delivery) —
	# the league must diverge from the joker-less play. (block_the_shine's narrow
	# 18-ball wicket sliver could pass a whole season untouched — a luck test.)
	var base := (_play_with_shop(20260704)["sp"] as SeasonPlay)
	var carry := (_play_with_shop(20260704, "rotate_the_strike")["sp"] as SeasonPlay)
	base.apply_shop_action({"kind": "skip"})
	carry.apply_shop_action({"kind": "skip"})
	var sum_base := 0
	var sum_carry := 0
	for i in range(7):
		var rb := base.make_session().result()
		var rc := carry.make_session().result()
		sum_base += rb.innings1.total + rb.innings2.total
		sum_carry += rc.innings1.total + rc.innings2.total
		base.commit_player_result(rb)
		carry.commit_player_result(rc)
	assert_ne(sum_carry, sum_base, "carried joker alters the live matches")

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

func test_cross_session_roundtrip_with_shopping_is_lossless() -> void:
	# Play 3, buy at V1, play 2 more, train at V2, save -> resume: the resumed driver
	# must equal the uninterrupted one (progress + loadout + standings + the NEXT match).
	var c := _play_with_shop(20260703)
	var sp: SeasonPlay = c["sp"]
	var career: CareerState = c["career"]
	var v0: Dictionary = sp.pending_shop_visit()
	sp.apply_shop_action({"kind": "pick", "id": v0["offer"][0]})
	_commit_n(sp, 3)
	var offer: Dictionary = sp.pending_shop_visit()["offer"]
	sp.apply_shop_action({"kind": "buy", "id": offer["common"]})
	sp.apply_shop_action({"kind": "skip"})
	_commit_n(sp, 2)
	sp.apply_shop_action({"kind": "train", "attr": "power"})   # V2 paid action
	sp.apply_shop_action({"kind": "skip"})

	var state := sp.to_state(0, 0)
	# Simulate a reload: a FRESH Player object carrying the persisted balance/attrs.
	var p2 := _rich_player()
	p2.tons_balance = (c["p"] as Player).tons_balance
	p2.attributes.power = (c["p"] as Player).attributes.power
	var resumed := SeasonPlay.from_state(state, p2, career)

	assert_eq(resumed.played_count(), sp.played_count(), "same progress")
	assert_eq(resumed.shop_owned(), sp.shop_owned(), "same loadout")
	assert_eq(resumed.pending_shop_visit(), sp.pending_shop_visit(), "same pending visit")
	var a: Array = sp.live_league().standings
	var b: Array = resumed.live_league().standings
	for i in range(a.size()):
		assert_eq(b[i].points, a[i].points, "standings row %d points equal" % i)
	var na := sp.make_session().result()
	var nb := resumed.make_session().result()
	assert_eq(nb.innings1.total, na.innings1.total, "next match innings1 equal")
	assert_eq(nb.innings2.total, na.innings2.total, "next match innings2 equal")
