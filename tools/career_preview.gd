extends SceneTree

# Career-loop eyeball oracle (spec 2026-06-12-career-loop-design.md DC15/§6):
# N full Careers under a fixed naive policy, printing a DATA json for
# docs/mockups/career-loop-v1.html.
#
# Naive policy (NOT a policy search — that is E4):
#   tour:   lowest unbeaten unlocked Tour at the current Level; if all beaten,
#           Premium again (chasing the Level win)
#   offers: accept the first cross-up Offer once the current Level is won; never
#           move down (this line never needs DC16's safety net)
#   plans:  textbook (the OpponentBrain TEXTBOOK literals)
#   spend:  round-robin +1 attribute upgrades while affordable, cap 60/attr
#
# Run:   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/career_preview.gd
# Smoke: CAREER_QUICK=1 (N=10). Full N=100 is a few minutes; no nohup needed.

const SEASON_CAP := 120
const ATTR_CAP := 60.0


func _choose_tour(state: CareerState) -> int:
	var lvl := state.current_level()
	for t in state.playable_cells():
		if state.status_of(lvl, t) != CareerState.CellStatus.BEATEN:
			return t
	return state.playable_cells().back()


func _spend(player: Player, etun: EconomyTuning) -> void:
	var attrs := ["power", "composure", "attack", "control"]
	var k := 0
	var stalled := 0
	while stalled < 4:
		var attr_name: String = attrs[k % 4]
		k += 1
		var cur: float = player.attributes.get(attr_name)
		var cost := Economy.attr_upgrade_cost(cur, etun)
		if cur >= ATTR_CAP or player.tons_balance < cost:
			stalled += 1
			continue
		stalled = 0
		player.attributes.set(attr_name, cur + 1.0)
		player.tons_balance -= cost


func _init() -> void:
	var quick := OS.get_environment("CAREER_QUICK") == "1"
	var n := 10 if quick else 100
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var etun := EconomyTuning.new()

	var seasons_to_complete: Array = []
	var capped := 0
	var visits: Array = []
	var beats: Array = []
	for i in range(24):
		visits.append(0)
		beats.append(0)
	var bank_sum: Array = []
	var bank_n: Array = []
	for i in range(SEASON_CAP):
		bank_sum.append(0.0)
		bank_n.append(0)

	for c in range(n):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + c
		var player := Player.new()
		var a := Attributes.new()
		a.power = 35.0
		a.composure = 30.0
		a.attack = 30.0
		a.control = 30.0
		player.attributes = a
		var state := CareerResolver.start_career(0)
		var plans := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, rng)
		while not state.complete and state.seasons_played < SEASON_CAP:
			var lvl := state.current_level()
			var tour := _choose_tour(state)
			var out := CareerResolver.play_season(
				state, player, tour, tuning, itun, etun, rng, plans[0], plans[1])
			visits[lvl * 8 + tour] += 1
			if out["season"].beat:
				beats[lvl * 8 + tour] += 1
			bank_sum[state.seasons_played - 1] += player.tons_balance
			bank_n[state.seasons_played - 1] += 1
			_spend(player, etun)
			if state.complete:
				break
			var up: Offer = null
			for o in out["offers"]:
				if o.level > lvl and state.level_won[lvl]:
					up = o
					break
			if up != null:
				CareerResolver.accept_offer(state, player, up)
			else:
				CareerResolver.stay(state, player)
		if state.complete:
			seasons_to_complete.append(state.seasons_played)
		else:
			capped += 1
		print("career %d/%d: %s in %d seasons" % [c + 1, n,
			"COMPLETE" if state.complete else "capped", state.seasons_played])

	var bank_curve: Array = []
	for i in range(SEASON_CAP):
		if bank_n[i] > 0:
			bank_curve.append(snappedf(bank_sum[i] / bank_n[i], 0.1))
	var data := {
		"n": n,
		"season_cap": SEASON_CAP,
		"completed": seasons_to_complete.size(),
		"capped": capped,
		"seasons_to_complete": seasons_to_complete,
		"cell_visits": visits,
		"cell_beats": beats,
		"bank_curve": bank_curve,
	}
	print("DATA ", JSON.stringify(data))
	quit()
