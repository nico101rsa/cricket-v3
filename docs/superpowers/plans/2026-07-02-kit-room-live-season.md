# Kit Room in the Live Season — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The live season offers the canon 5-visit Kit Room (buy/sell/hold/train/skip + starter pick + carry-over election) spending real ₸, with lossless cross-session save.

**Architecture:** The shop lives on `SeasonPlay` (`ShopState` + visit scheduling by bitmask + per-tap actions delegating to the existing `ShopResolver`). Persistence records per-match context (`jokers`+`attrs`) in the decisions log so replay is lossless under mid-season shopping, and serializes the `ShopState` in `LiveSeasonState` v2. `main.gd` routes a new code-built Kit Room screen at the visit gates; `season_hub.set_play` swaps Rung 1's carry-over seeding for `enable_shop`.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Headless runs only (editor quit, one Godot process): `--import` once after new scripts, then `-gdir=res://tests/unit`. Red = parse-error skip; green = count climbs + `All tests passed`.

---

## File structure

- `scripts/domain/season_play.gd` — **modify**: shop state/scheduling/actions/accessors + persistence.
- `scripts/data/live_season_state.gd` — **modify**: v2 shop fields.
- `scripts/domain/season_view_builder.gd` — **modify**: optional `owned_ids` feeds `SeasonView.jokers` (DK2-10).
- `scenes/kit_room/kit_room.{gd,tscn}` — **create**: the screen (code-built, 3 modes).
- `scenes/main.gd` — **modify**: routing gates + carry-over flow + `_finish_live_season` extraction.
- `scenes/season_hub/season_hub.gd` — **modify**: `set_play` → `enable_shop`; view fed `shop_owned()`.
- `tools/preview_kit_room.gd` — **create**: state renders for the eyeball.
- Tests: `tests/unit/test_season_play_shop.gd` (**create**), `tests/unit/test_kit_room_scene.gd` (**create**), `tests/unit/test_season_hub_scene.gd` (**modify**).

Suite command (chain, wait): `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

---

## Task 1: SeasonPlay shop core (enable / schedule / actions)

**Files:** Modify `scripts/domain/season_play.gd` · Create `tests/unit/test_season_play_shop.gd`

- [ ] **Step 1: failing tests** — create `tests/unit/test_season_play_shop.gd`:

```gdscript
extends GutTest

# The Kit Room on the live driver (spec 2026-07-02, Rung 2): canon 5-visit
# cadence, per-tap ShopResolver actions, one paid action per visit.

func _rich_player() -> Player:
	var p := Player.new()
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	p.attributes = a
	p.tons_balance = 10000
	return p

func _play_with_shop(seed: int = 20260702, carryover: String = "") -> Dictionary:
	var p := _rich_player()
	var career := CareerResolver.start_career(0)
	var sp := SeasonPlay.start(p.attributes, career.teams[career.current_team_index],
		career.opponents_of_current(), DifficultyLadder.spec_for(0, 0).make_tour(),
		BallTuning.new(), InningsTuning.new(), seed)
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
	assert_eq(v["kind"], "starter"); assert_eq(v["visit"], 0)
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
	var before_next := sp.make_session().result().innings1.total \
		+ sp.make_session().result().innings2.total
	var bal: int = p.tons_balance
	assert_true(sp.apply_shop_action({"kind": "buy", "id": id}))
	assert_eq(p.tons_balance, bal - price, "price deducted")
	assert_true(id in sp.shop_owned())
	var after_next := sp.make_session().result().innings1.total \
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

func test_sell_refunds_half_paid_and_free_refunds_zero() -> void:
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
	_commit_n(sp, 3); sp.apply_shop_action({"kind": "skip"})   # v1
	_commit_n(sp, 2); sp.apply_shop_action({"kind": "skip"})   # v2
	_commit_n(sp, 2)   # league done
	assert_eq(sp.phase(), "playoffs", "precondition: in the playoffs")
	var v3: Dictionary = sp.pending_shop_visit()
	assert_eq(v3.get("visit", -1), 3, "V3 pends before the semi")
	sp.apply_shop_action({"kind": "skip"})
	_commit_n(sp, 1)   # the semi
	var after_semi: Dictionary = sp.pending_shop_visit()
	if not sp.season_done():
		# Won the semi -> V4 pre-final; lost -> third-place has NO visit.
		var nxt := sp.next_player_opponent()
		if nxt.get("stage", "") == "final":
			assert_eq(after_semi.get("visit", -1), 4, "V4 pends before the final")
		else:
			assert_eq(after_semi, {}, "no visit before the 3rd-place match")
```

- [ ] **Step 2: run suite, expect the new file red** (`enable_shop` / `pending_shop_visit` / `apply_shop_action` / `shop_owned` not declared → parse-error skip of this file).

- [ ] **Step 3: implement in `season_play.gd`.** New fields after `_player_effects`:

```gdscript
# --- The Kit Room on the live driver (spec 2026-07-02, Rung 2) ---
var _shop: ShopState = null       # null = shop off (byte-identical pre-rung path)
var _shop_player: Player = null   # rebound every enable_shop (hub reloads the Player)
var _setun: EconomyTuning = null
var _shop_level: int = 0
var _shop_tour: int = 0
var _visits_mask: int = 0         # bit v set = visit v consumed (v0..v4)
var _paid_mask: int = 0           # bit v set = the visit's one paid action used (DK2-3)
var _shop_log: Array = []
var _offer_cache: Dictionary = {} # visit -> rolled offer (stable within a visit)
```

Methods (after `set_player_jokers`):

```gdscript
# Turn on the live Kit Room. Rebind + init-once (DK2-5/DK2-9): every call rebinds the
# (freshly re-loaded) Player and its Attributes; the ShopState itself initializes only
# on the first call — the carry-over joker enters free, exactly like headless V0 (DK2).
func enable_shop(player: Player, etun: EconomyTuning, level: int, tour_index: int,
		carryover_id: String = "") -> void:
	_shop_player = player
	_setun = etun
	_shop_level = level
	_shop_tour = tour_index
	_attrs = player.attributes   # training must stay visible to future matches (DK2-9)
	if _shop != null:
		return
	_shop = ShopState.new()
	if carryover_id != "":
		_shop.owned_ids.append(carryover_id)
		_shop.paid_prices[carryover_id] = 0
		_shop_log.append({"action": "carryover_in", "id": carryover_id})
	_refresh_loadout()

func shop_enabled() -> bool: return _shop != null
func shop() -> ShopState: return _shop
func shop_log() -> Array: return _shop_log
func shop_owned() -> Array: return _shop.owned_ids if _shop != null else []
func shop_balance() -> int: return _shop_player.tons_balance if _shop_player != null else 0
func sell_refund_of(id: String) -> int:
	return Economy.sell_refund(int(_shop.paid_prices.get(id, 0)), _setun)
func train_cost_of(attr: String) -> int:
	return Economy.attr_upgrade_cost(_shop_player.attributes.get(attr), _setun)
func paid_action_used() -> bool:
	var p := pending_shop_visit()
	return not p.is_empty() and (_paid_mask & (1 << int(p["visit"]))) != 0

func _refresh_loadout() -> void:
	_player_effects = ShopResolver.loadout_effects(_shop)

# The canon visit now due, or {} (DK2-1). Offers roll on a fresh per-visit RNG
# (_seed + 9000 + v, DK2-2) and are cached until the visit is consumed.
func pending_shop_visit() -> Dictionary:
	if _shop == null:
		return {}
	for v in range(5):
		if _visits_mask & (1 << v):
			continue
		if not _visit_open(v):
			continue
		if not _offer_cache.has(v):
			var rng := RandomNumberGenerator.new()
			rng.seed = _seed + 9000 + v
			_offer_cache[v] = ShopResolver.starter_offer(rng, _shop) if v == 0 \
				else ShopResolver.roll_offer(rng, _shop, _shop_level, _shop_tour, _setun)
		return {"kind": "starter" if v == 0 else "visit", "visit": v, "offer": _offer_cache[v]}
	return {}

func _visit_open(v: int) -> bool:
	match v:
		0: return _phase == Phase.LEAGUE and played_count() == 0
		1: return played_count() >= 3
		2: return played_count() >= 5
		3: return _phase == Phase.PLAYOFFS and _pending_stage == "semi"
		4: return _phase == Phase.PLAYOFFS and _pending_stage == "final"
	return false

# One per-tap Kit Room action against the pending visit. All money/slot maths stays
# in ShopResolver (which push_warnings + no-ops illegal input). Paid actions (buy OR
# train) are capped at one per visit (_paid_mask, DK2-3); sell/hold are free; pick
# and skip consume the visit. Returns success.
func apply_shop_action(act: Dictionary) -> bool:
	var pending := pending_shop_visit()
	if pending.is_empty():
		push_warning("shop action with no pending visit")
		return false
	var v: int = pending["visit"]
	var paid_used := (_paid_mask & (1 << v)) != 0
	match act.get("kind", ""):
		"pick":
			if pending["kind"] != "starter" or not act.get("id", "") in (pending["offer"] as Array):
				return false
			_shop.owned_ids.append(act["id"])
			_shop.paid_prices[act["id"]] = 0
			_shop_log.append({"action": "starter", "id": act["id"]})
			_consume(v)
			_refresh_loadout()
			return true
		"skip":
			_consume(v)
			return true
		"buy":
			if pending["kind"] != "visit" or paid_used:
				return false
			var offer: Dictionary = pending["offer"]
			var price: int = offer["prices"].get(act.get("id", ""), -1)
			if price < 0:
				push_warning("buy not in offer: %s" % act.get("id", ""))
				return false
			if ShopResolver.buy(_shop, _shop_player, act["id"], price, _setun, act.get("replace", "")):
				_shop_log.append({"action": "buy", "id": act["id"], "tons": price})
				_paid_mask |= 1 << v
				_refresh_loadout()
				return true
			return false
		"train":
			if pending["kind"] != "visit" or paid_used:
				return false
			if ShopResolver.upgrade_attribute(_shop_player, act.get("attr", ""), _setun):
				_shop_log.append({"action": "upgrade", "id": act["attr"]})
				_paid_mask |= 1 << v
				return true
			return false
		"sell":
			if pending["kind"] != "visit":
				return false
			if ShopResolver.sell(_shop, _shop_player, act.get("id", ""), _setun):
				_shop_log.append({"action": "sell", "id": act["id"]})
				_refresh_loadout()
				return true
			return false
		"hold":
			if pending["kind"] != "visit":
				return false
			if ShopResolver.hold(_shop, pending["offer"], act.get("id", "")):
				_shop_log.append({"action": "hold", "id": act["id"]})
				return true
			return false
	return false

func _consume(v: int) -> void:
	_visits_mask |= 1 << v
	_offer_cache.erase(v)
```

- [ ] **Step 4: run suite, verify green** (note: buy-changes-next-match asserts `assert_ne` — the joker drawn is whatever the offer rolls, so only inequality is safe).
- [ ] **Step 5: commit** — `git add scripts/domain/season_play.gd tests/unit/test_season_play_shop.gd && git commit -m "feat: SeasonPlay runs the live Kit Room (canon 5-visit cadence + per-tap actions)"` (+ Co-Authored-By trailer).

---

## Task 2: Persistence — lossless resume under mid-season shopping

**Files:** Modify `scripts/data/live_season_state.gd`, `scripts/domain/season_play.gd` · Test in `tests/unit/test_season_play_shop.gd`

- [ ] **Step 1: failing test** (append to `test_season_play_shop.gd`):

```gdscript
func test_cross_session_roundtrip_with_shopping_is_lossless() -> void:
	# Play 3, buy at V1 + (next visit) train, play 2 more, save -> resume: the resumed
	# driver must equal the uninterrupted one (standings + owned + the NEXT match).
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
	var a := sp.live_league().standings
	var b := resumed.live_league().standings
	for i in range(a.size()):
		assert_eq(b[i].points, a[i].points, "standings row %d points equal" % i)
	var na := sp.make_session().result()
	var nb := resumed.make_session().result()
	assert_eq(nb.innings1.total, na.innings1.total, "next match innings1 equal")
	assert_eq(nb.innings2.total, na.innings2.total, "next match innings2 equal")
```

(Check the standings row field name — `test_season_play.gd` asserts on standings rows; mirror its accessor, e.g. `points` or `pts`.)

- [ ] **Step 2: run suite, expect this test red** (shop fields not persisted → resumed loadout empty / next match differs).

- [ ] **Step 3: implement.** `live_season_state.gd` — bump `version` default to 2 and append:

```gdscript
# --- v2: the live Kit Room (spec 2026-07-02). ShopState is tiny + serialisable;
# per-match REPLAY CONTEXT (jokers/attrs at each commit) rides inside `decisions`. ---
@export var shop_enabled: bool = false
@export var shop_owned: Array = []
@export var shop_paid: Dictionary = {}
@export var shop_held: String = ""
@export var shop_visits_mask: int = 0
@export var shop_paid_mask: int = 0
```

`season_play.gd::commit_player_result` — stamp context (stamp-if-absent so replay preserves the saved context):

```gdscript
func commit_player_result(result: MatchResult, decisions: Dictionary = {}) -> void:
	var entry := decisions.duplicate(true)
	# Replay context (DK2-4): the jokers + attrs this match was played with, so a
	# resumed season re-simulates it identically even after mid-season shopping.
	# Stamp-if-absent: replayed entries keep their saved context.
	if not entry.has("jokers"):
		entry["jokers"] = _shop.owned_ids.duplicate() if _shop != null else []
	if not entry.has("attrs"):
		entry["attrs"] = [_attrs.power, _attrs.composure, _attrs.attack, _attrs.control]
	if _phase == Phase.LEAGUE:
		if league_done():
			return
		_decisions.append(entry)
		_player_results.append(result)
		_settle(result)
		if played_count() >= PLAYER_FIXTURES:
			_start_playoffs()
	elif _phase == Phase.PLAYOFFS:
		_decisions.append(entry)
		_settle(result)
		_record_playoff_result(result)
	# DONE: ignore.
```

`replay` — apply per-entry context before each session:

```gdscript
	for entry in decisions_log_in:
		if sp.season_done():
			break
		# Replay context (DK2-4): run each match with the loadout + attrs it was
		# originally played with (also fixes the Rung-1 carry-over replay divergence).
		sp._player_effects = JokerCatalog.effects_of_ids(entry.get("jokers", []))
		if entry.has("attrs"):
			var arr: Array = entry["attrs"]
			var ca := Attributes.new()
			ca.power = arr[0]; ca.composure = arr[1]; ca.attack = arr[2]; ca.control = arr[3]
			sp._attrs = ca
		var sess := sp.make_session()
		if sess == null:
			break
		sess.apply_decisions(entry)
		sp.commit_player_result(sess.result(), entry)
```

`to_state` — append before `return s`:

```gdscript
	s.version = 2
	if _shop != null:
		s.shop_enabled = true
		s.shop_owned = _shop.owned_ids.duplicate()
		s.shop_paid = _shop.paid_prices.duplicate()
		s.shop_held = _shop.held_id
		s.shop_visits_mask = _visits_mask
		s.shop_paid_mask = _paid_mask
```

New `restore_shop` (after `from_state`) + call it in `from_state` after `restore_pay_tally`:

```gdscript
	sp.restore_pay_tally(state.pay_total, state.wins)
	sp.restore_shop(state, player, EconomyTuning.new())
	return sp

# Rebuild the live ShopState from a save (DK2-4). Re-binds the freshly-loaded
# Player (whose balance/attrs are the persisted truth) and re-derives the loadout
# effects for the matches still to come. Pre-v2 saves (shop_enabled false) no-op;
# the hub's enable_shop then initializes fresh.
func restore_shop(state: LiveSeasonState, player: Player, etun: EconomyTuning) -> void:
	if not state.shop_enabled:
		return
	_shop = ShopState.new()
	_shop.owned_ids.assign(state.shop_owned)
	_shop.paid_prices = state.shop_paid.duplicate()
	_shop.held_id = state.shop_held
	_visits_mask = state.shop_visits_mask
	_paid_mask = state.shop_paid_mask
	_shop_player = player
	_setun = etun
	_shop_level = state.level
	_shop_tour = state.tour_index
	_attrs = player.attributes
	_refresh_loadout()
```

- [ ] **Step 4: run suite, verify green** (the existing cross-session tests must stay green — decisions entries now carry extra keys, which `apply_decisions` ignores by design).
- [ ] **Step 5: commit** — `git add scripts/data/live_season_state.gd scripts/domain/season_play.gd tests/unit/test_season_play_shop.gd && git commit -m "feat: lossless cross-session save under mid-season shopping (replay context + ShopState v2)"` (+ trailer).

---

## Task 3: The Kit Room screen (code-built, 3 modes)

**Files:** Create `scenes/kit_room/kit_room.gd` + `scenes/kit_room/kit_room.tscn` (root `Control` named `KitRoom` with the script, mirroring `scenes/outcome/outcome.tscn`) · Create `tests/unit/test_kit_room_scene.gd`

- [ ] **Step 1: failing scene tests**:

```gdscript
extends GutTest

const KitRoomScene = preload("res://scenes/kit_room/kit_room.tscn")

func _rich_player(bal: int = 10000) -> Player:
	var p := Player.new()
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	p.attributes = a; p.tons_balance = bal
	return p

func _play(bal: int = 10000) -> SeasonPlay:
	var p := _rich_player(bal)
	var career := CareerResolver.start_career(0)
	var sp := SeasonPlay.start(p.attributes, career.teams[0], career.opponents_of_current(),
		DifficultyLadder.spec_for(0, 0).make_tour(), BallTuning.new(), InningsTuning.new(), 20260702)
	sp.enable_shop(p, EconomyTuning.new(), 0, 0)
	return sp

func _visit_play(bal: int = 10000) -> SeasonPlay:
	var sp := _play(bal)
	sp.apply_shop_action({"kind": "skip"})
	for i in range(3):
		sp.commit_player_result(sp.make_session().result())
	return sp

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label or node is Button:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_starter_mode_shows_three_free_tiles() -> void:
	var sp := _play()
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_visit(sp, sp.pending_shop_visit())
	await get_tree().process_frame
	var tiles = screen.find_child("StarterBox", true, false)
	assert_not_null(tiles); assert_eq(tiles.get_child_count(), 3, "3 starter tiles")
	assert_gt((tiles.get_child(0) as Control).size.y, 0.0, "tiles not collapsed")
	assert_true(_all_label_text(screen).contains("FREE"))

func test_starter_pick_owns_and_emits_done() -> void:
	var sp := _play()
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_visit(sp, sp.pending_shop_visit())
	await get_tree().process_frame
	watch_signals(screen)
	(screen.find_child("StarterBox", true, false).get_child(0) as Button).pressed.emit()
	assert_eq(sp.shop_owned().size(), 1, "pick applied")
	assert_signal_emitted(screen, "done")

func test_visit_mode_buy_disabled_when_broke() -> void:
	var sp := _visit_play(0)   # ₸0 balance
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_visit(sp, sp.pending_shop_visit())
	await get_tree().process_frame
	var buy: Button = screen.find_child("BuyBtn0", true, false)
	assert_not_null(buy, "offer row present")
	assert_true(buy.disabled, "cannot afford at ₸0")

func test_visit_continue_consumes_and_emits_done() -> void:
	var sp := _visit_play()
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_visit(sp, sp.pending_shop_visit())
	await get_tree().process_frame
	watch_signals(screen)
	(screen.find_child("ContinueBtn", true, false) as Button).pressed.emit()
	assert_eq(sp.pending_shop_visit(), {}, "visit consumed on continue")
	assert_signal_emitted(screen, "done")

func test_carryover_mode_elects() -> void:
	var sp := _play()
	sp.apply_shop_action({"kind": "pick", "id": sp.pending_shop_visit()["offer"][0]})
	var owned: String = sp.shop_owned()[0]
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_carryover(sp)
	await get_tree().process_frame
	watch_signals(screen)
	(screen.find_child("CarryBox", true, false).get_child(0) as Button).pressed.emit()
	assert_signal_emitted_with_parameters(screen, "carryover_elected", [owned])

func test_no_emoji_anywhere() -> void:
	var sp := _visit_play()
	var screen = KitRoomScene.instantiate()
	add_child_autofree(screen)
	screen.set_visit(sp, sp.pending_shop_visit())
	await get_tree().process_frame
	var txt := _all_label_text(screen)
	for ch in "🏏🃏🛒▶":
		assert_false(txt.contains(ch), "no emoji (Barlow tofu)")
```

- [ ] **Step 2: run suite, expect red** (scene missing → preload fails / parse skip).
- [ ] **Step 3: implement `kit_room.gd`** (create the `.tscn` as root `Control` "KitRoom" + script, exactly like `outcome.tscn`):

```gdscript
extends Control

# The Kit Room — the live season's shop screen (spec 2026-07-02, Rung 2).
# In-house functional skin (DK2-7): clean, on-language (Palette/UIStyle/Fonts),
# hi-fi via the design track is a later rung. Three modes:
#   set_visit(play, visit)  — "starter" (3 free Commons) or "visit" (buy/sell/hold/train)
#   set_carryover(play)     — season end: elect the one joker that survives (DK2-6)
# The screen is dumb: every action routes through SeasonPlay.apply_shop_action, and
# all money maths lives in ShopResolver/Economy. No emoji (Barlow tofu).

signal done()
signal carryover_elected(id: String)

const VISIT_LABELS := {0: "SEASON START", 1: "AFTER MATCH 3", 2: "AFTER MATCH 5",
	3: "BEFORE THE SEMI-FINAL", 4: "BEFORE THE FINAL"}

var _play: SeasonPlay
var _visit: Dictionary = {}
var _mode: String = ""
var _col: VBoxContainer

func set_visit(play: SeasonPlay, visit: Dictionary) -> void:
	_play = play
	_visit = visit
	_mode = String(visit.get("kind", ""))
	_rebuild()

func set_carryover(play: SeasonPlay) -> void:
	_play = play
	_mode = "carryover"
	_rebuild()

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	scroll.add_child(margin)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 14)
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_col)
	_header()
	match _mode:
		"starter": _starter_body()
		"visit": _visit_body()
		"carryover": _carryover_body()

func _header() -> void:
	var kicker := _lbl("KIT ROOM · %s" % (VISIT_LABELS.get(int(_visit.get("visit", -1)), "SEASON END — CARRY-OVER") if _mode != "carryover" else "SEASON END — CARRY-OVER"), 11, Palette.WHITE_DIM)
	Fonts.weigh(kicker, Fonts.W_BOLD)
	_col.add_child(kicker)
	var bal := _lbl("₸ %d" % _play.shop_balance(), 24, Palette.GOLD)
	bal.name = "Balance"
	Fonts.weigh(bal, Fonts.W_HEADLINE, true)
	_col.add_child(bal)

func _starter_body() -> void:
	_col.add_child(_lbl("Pick a free joker to start the season", 13, Palette.WHITE))
	var box := VBoxContainer.new()
	box.name = "StarterBox"
	box.add_theme_constant_override("separation", 10)
	_col.add_child(box)
	for id in (_visit["offer"] as Array):
		var b := _row_btn("%s\nCOMMON · FREE" % _jname(id))
		b.pressed.connect(func():
			if _play.apply_shop_action({"kind": "pick", "id": id}):
				done.emit())
		box.add_child(b)
	var skip := _cta("SKIP  >", Palette.WHITE_DIM)
	skip.name = "ContinueBtn"
	skip.pressed.connect(func():
		_play.apply_shop_action({"kind": "skip"})
		done.emit())
	_col.add_child(skip)

func _visit_body() -> void:
	var offer: Dictionary = _visit["offer"]
	var paid_used: bool = _play.paid_action_used()
	# --- the shelf ---
	_col.add_child(_section("ON THE SHELF"))
	var i := 0
	for rarity in ["common", "rare", "legendary"]:
		var id: String = offer.get(rarity, "")
		if id == "":
			continue
		var price: int = offer["prices"][id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_l := _lbl("%s\n%s · ₸ %d" % [_jname(id), rarity.to_upper(), price], 13, Palette.WHITE)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var buy := _small_btn("BUY")
		buy.name = "BuyBtn%d" % i
		buy.disabled = paid_used or _play.shop_balance() < price \
			or _play.shop_owned().size() >= 4
		buy.pressed.connect(func():
			if _play.apply_shop_action({"kind": "buy", "id": id}):
				_rebuild())
		row.add_child(buy)
		var hold := _small_btn("HOLD")
		hold.pressed.connect(func():
			if _play.apply_shop_action({"kind": "hold", "id": id}):
				_rebuild())
		row.add_child(hold)
		_col.add_child(row)
		i += 1
	if i == 0:
		_col.add_child(_lbl("Nothing on the shelf this visit.", 12, Palette.WHITE_DIM))
	# --- your bench ---
	if not _play.shop_owned().is_empty():
		_col.add_child(_section("YOUR JOKERS"))
		for oid in _play.shop_owned():
			var orow := HBoxContainer.new()
			var ol := _lbl(_jname(oid), 13, Palette.WHITE)
			ol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			orow.add_child(ol)
			var sell := _small_btn("SELL ₸%d" % _play.sell_refund_of(oid))
			sell.pressed.connect(func():
				if _play.apply_shop_action({"kind": "sell", "id": oid}):
					_rebuild())
			orow.add_child(sell)
			_col.add_child(orow)
	# --- training ---
	_col.add_child(_section("TRAINING (+1)"))
	for attr in ["power", "composure", "attack", "control"]:
		var cur: float = _play.pay_player().attributes.get(attr) if _play.pay_player() != null \
			else 0.0
		var cost: int = _play.train_cost_of(attr)
		var trow := HBoxContainer.new()
		var tl := _lbl("%s  %d → %d" % [attr.to_upper(), int(cur), int(cur) + 1], 13, Palette.WHITE)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trow.add_child(tl)
		var tb := _small_btn("TRAIN ₸%d" % cost)
		tb.disabled = paid_used or cur >= 60.0 or _play.shop_balance() < cost
		tb.pressed.connect(func():
			if _play.apply_shop_action({"kind": "train", "attr": attr}):
				_rebuild())
		trow.add_child(tb)
		_col.add_child(trow)
	var cta := _cta("CONTINUE  >", Palette.GOLD)
	cta.name = "ContinueBtn"
	cta.pressed.connect(func():
		_play.apply_shop_action({"kind": "skip"})
		done.emit())
	_col.add_child(cta)

func _carryover_body() -> void:
	_col.add_child(_lbl("Pick ONE joker to carry into next season", 13, Palette.WHITE))
	var box := VBoxContainer.new()
	box.name = "CarryBox"
	box.add_theme_constant_override("separation", 10)
	_col.add_child(box)
	for id in _play.shop_owned():
		var b := _row_btn(_jname(id))
		b.pressed.connect(func(): carryover_elected.emit(id))
		box.add_child(b)
	var none := _cta("CARRY NOTHING  >", Palette.WHITE_DIM)
	none.name = "ContinueBtn"
	none.pressed.connect(func(): carryover_elected.emit(""))
	_col.add_child(none)

# --- helpers ---

func _jname(id: String) -> String:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return g["jname"]
	return id

func _lbl(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	Fonts.weigh(l, Fonts.W_BOLD)
	return l

func _section(txt: String) -> Label:
	var l := _lbl(txt, 11, Palette.WHITE_DIM)
	Fonts.weigh(l, Fonts.W_LABEL)
	return l

func _row_btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_stylebox_override("normal", UIStyle.panel())
	b.add_theme_color_override("font_color", Palette.WHITE)
	Fonts.weigh(b, Fonts.W_BOLD)
	return b

func _small_btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_stylebox_override("normal", UIStyle.panel())
	b.add_theme_color_override("font_color", Palette.GOLD)
	b.add_theme_font_size_override("font_size", 11)
	Fonts.weigh(b, Fonts.W_BOLD)
	return b

func _cta(txt: String, col: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_stylebox_override("normal", UIStyle.cta(col))
	b.add_theme_color_override("font_color", Palette.BG)
	b.add_theme_font_size_override("font_size", 15)
	Fonts.weigh(b, Fonts.W_BOLD)
	return b
```

Notes: `_play.pay_player()` may be null in tests without `enable_pay` — the train row falls back to 0 display but `train_cost_of`/`apply_shop_action` use `_shop_player` (always bound). If `UIStyle.cta`/`panel` signatures differ, mirror `outcome.gd`'s exact calls. `queue_free` in `_rebuild` is fine for per-frame tests (children checked post-`await`); if stale nodes interfere use `free()` — verify in the test run.

- [ ] **Step 4: `--import` (new scripts) + run suite, verify green.**
- [ ] **Step 5: commit** — `git add scenes/kit_room tests/unit/test_kit_room_scene.gd && git commit -m "feat: the Kit Room screen (starter / visit / carry-over, in-house skin)"` (+ trailer). Remember: test `.gd` files have no `.uid`; `scenes/kit_room/kit_room.gd.uid` DOES exist — add the whole `scenes/kit_room` dir.

---

## Task 4: Wiring — hub `enable_shop`, main routing gates, carry-over flow, hub bench

**Files:** Modify `scenes/season_hub/season_hub.gd`, `scenes/main.gd`, `scripts/domain/season_view_builder.gd` · Test `tests/unit/test_season_hub_scene.gd`

- [ ] **Step 1: failing test** (append to `test_season_hub_scene.gd`):

```gdscript
# Rung 2: the hub enables the live Kit Room; a fresh boot pends the V0 starter.
func test_boot_enables_shop_with_pending_starter() -> void:
	SaveManager.clear_career(); SaveManager.clear_live_season()
	SaveManager.save_player(_player())
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	hub.boot()
	var play: SeasonPlay = hub.live_play()
	assert_true(play.shop_enabled(), "shop on for live play")
	assert_eq(play.pending_shop_visit()["kind"], "starter", "V0 pends on a fresh season")
	SaveManager.clear_career(); SaveManager.clear_player(); SaveManager.clear_live_season()
```

- [ ] **Step 2: run suite, expect red** (`shop_enabled` false — hub never calls `enable_shop`).
- [ ] **Step 3: implement.**

`season_hub.gd::set_play` — replace the Rung-1 carry-over block:

```gdscript
	# The live Kit Room (spec 2026-07-02, Rung 2): rebind+init-once; the carry-over
	# joker enters the shop free (V0) and the loadout drives set_player_jokers.
	play.enable_shop(player, EconomyTuning.new(), _cell_level, _cell_tour,
		career.carryover_joker_id)
```

(delete the old `var cj := ...` / `play.set_player_jokers(...)` lines.)

Feed the bench (DK2-10): `set_view(SeasonViewBuilder.build(player, career, play.live_season(), play.played_count(), play.shop_owned()))` — and in `season_view_builder.gd`, add a trailing optional `owned_ids: Array = []` to `build`; when non-empty, fill `v.jokers` from it instead of the carry-over:

```gdscript
	if not owned_ids.is_empty():
		v.jokers.clear()
		for oid in owned_ids:
			var m := _joker_meta(oid)
			if not m.is_empty():
				v.jokers.append(m)
```

(match `_joker_meta`'s existing dict shape / append pattern; keep the carry-over branch as the default when `owned_ids` is empty so all existing callers are untouched.)

`main.gd` — preload + routing:

```gdscript
const KIT_ROOM := preload("res://scenes/kit_room/kit_room.tscn")
```

`_push_hub` gains a tail check (after `hub.boot()`):

```gdscript
	if hub.live_play() != null and not hub.live_play().pending_shop_visit().is_empty():
		_show_kit_room(hub.live_play(), hub.current_career())
```

`_play_next` gains a guard after `play` is fetched:

```gdscript
	if not play.pending_shop_visit().is_empty():
		_show_kit_room(play, career)   # move the `career` fetch above this line
		return
```

New methods:

```gdscript
# A pending Kit Room visit: show the screen; when the visit closes, save progress
# and loop (another visit may pend) until none — then fall through to the hub.
func _show_kit_room(play: SeasonPlay, career: CareerState) -> void:
	var visit: Dictionary = play.pending_shop_visit()
	if visit.is_empty():
		_show_live_hub(play, career)
		return
	var screen := KIT_ROOM.instantiate()
	screen.done.connect(func():
		_save_shop_progress(play, career)
		_show_kit_room(play, career))
	_push(screen)
	screen.set_visit(play, visit)

# Shop actions move ₸/attrs (on the Player) and the shop state (in the live save).
func _save_shop_progress(play: SeasonPlay, career: CareerState) -> void:
	var player: Player = play.pay_player()
	if player != null:
		SaveManager.save_player(player)
	var cell := CareerResolver.next_live_cell(career)
	SaveManager.save_live_season(play.to_state(cell["level"], cell["tour"]))
```

`_commit_and_return` — replace the `if play.season_done(): ... else: ...` tail with:

```gdscript
	if play.season_done():
		if play.shop_enabled() and not play.shop_owned().is_empty():
			# Carry-over election (DK2-6) before the career advance.
			var screen := KIT_ROOM.instantiate()
			screen.carryover_elected.connect(func(id: String):
				career.carryover_joker_id = id
				_finish_live_season(play, career))
			_push(screen)
			screen.set_carryover(play)
		else:
			if play.shop_enabled():
				career.carryover_joker_id = ""
			_finish_live_season(play, career)
	else:
		SaveManager.save_live_season(play.to_state(cell["level"], cell["tour"]))
		if play.pending_shop_visit().is_empty():
			_show_live_hub(play, career)
		else:
			_show_kit_room(play, career)
```

…and extract `_finish_live_season` (the existing advance block verbatim — rng `play.seed()+7`, `advance_after_live_season`, `save_career`, `clear_live_season`, `save_player`, `_show_outcome`); it derives its own `cell := CareerResolver.next_live_cell(career)` FIRST (the grid must not have advanced yet).

- [ ] **Step 4: run suite, verify green** — pay attention to the Rung-1 hub tests (`test_boot_seeds_player_jokers_from_carryover` must survive: the carry-over now enters via the shop, same effects) and the resume test.
- [ ] **Step 5: commit** — `git add scenes/main.gd scenes/season_hub/season_hub.gd scripts/domain/season_view_builder.gd tests/unit/test_season_hub_scene.gd && git commit -m "feat: Kit Room wired into the live loop (hub enable_shop + main visit gates + carry-over)"` (+ trailer).

---

## Task 5: Renders, full verification, roadmap, PR

- [ ] **Step 1:** create `tools/preview_kit_room.gd` mirroring `tools/preview_outcome.gd`'s SceneTree pattern (390×844, mount → 6 frames → `save_png` → next): three states — starter (fresh enabled play), visit (after 3 commits, balance ₸10000), carryover (2 owned) → `docs/mockups/kit-room-{starter,visit,carryover}-v1.png`. Run WITH rendering: `/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_kit_room.gd`.
- [ ] **Step 2:** Read/eyeball the 3 PNGs — no tofu, rows not collapsed, prices visible, disabled buys greyed.
- [ ] **Step 3:** full suite green; count climbed (expect ~+15 from 753).
- [ ] **Step 4:** commit renders + tool; update `PROJECT_ROADMAP.md` (history + Next-session: Rung 2 done → next per Nico's basic-gameplay order = Offers/"how to advance" screen); push branch; `gh pr create` (what/why, pieces, zero-ledger-risk note, verification incl. the lossless-resume pin) → `gh pr merge --merge --delete-branch` → sync main.

---

## Self-review

- **Spec coverage:** DK2-1/2/3 → Task 1; DK2-4 → Task 2; DK2-5/9 → Task 1 `enable_shop`; DK2-6 → Task 4 carry-over flow; DK2-7 → Task 3; DK2-8 → no code (ShopState dies with SeasonPlay); DK2-10 → Task 4 builder param. §5 tests all present incl. the lossless round-trip pin and the shop-off guard.
- **Type consistency:** `pending_shop_visit()` → `{kind, visit, offer}`; starter offer `Array`, visit offer `Dictionary` (screen branches by kind). `apply_shop_action(act) -> bool` with kinds pick/skip/buy/train/sell/hold. `enable_shop(player, etun, level, tour_index, carryover_id="")` used identically in hub + tests. `shop_owned()` returns `Array`.
- **Known judgement points at execution time:** standings row field name (mirror `test_season_play.gd`); `UIStyle.panel()/cta()` exact signatures (mirror `outcome.gd`); `_joker_meta` dict shape; `queue_free` vs `free()` in `_rebuild` under same-frame tests.
