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
#   spend:  via the Shop (CAREER_POLICY=attr_only|joker_only|balanced, default attr_only)
#
# Run:   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/career_preview.gd
# Smoke: CAREER_QUICK=1 (N=10). Full N=100 is a few minutes; no nohup needed.
#        CAREER_POLICY selects the Shop arm (attr_only|joker_only|balanced).

const SEASON_CAP := 120
const ATTR_CAP := 60.0


func _choose_tour(state: CareerState) -> int:
	var lvl := state.current_level()
	for t in state.playable_cells():
		if state.status_of(lvl, t) != CareerState.CellStatus.BEATEN:
			return t
	return state.playable_cells().back()


func _init() -> void:
	var quick := OS.get_environment("CAREER_QUICK") == "1"
	var n := 10 if quick else 100
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var etun := EconomyTuning.new()

	var policy_kind: String = OS.get_environment("CAREER_POLICY")
	if policy_kind == "":
		policy_kind = "attr_only"
	var shop_policy := ShopPolicy.preset(policy_kind)

	var seasons_to_complete: Array = []
	var maxed_seasons: Array = []
	var matches_to_complete: Array = []   # exact Player matches per completed career
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

	var jokers_bought_total := 0
	var end_reasons: Array = []

	for c in range(n):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + c
		var player := Player.new()
		var a := Attributes.new()
		a.power = 11.0       # world-scale v2 WS3: fresh hero starts ≈ a weak Club player
		a.composure = 11.0
		a.attack = 11.0
		a.control = 11.0
		player.attributes = a
		var state := CareerResolver.start_career(0)
		var maxed_season := 0   # first Season-index when all 4 attrs hit ATTR_CAP
		var matches := 0        # 7 league + 2 playoff matches when top-4
		var plans := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, rng)
		while not state.complete and state.seasons_played < SEASON_CAP:
			var lvl := state.current_level()
			var tour := _choose_tour(state)
			var out := CareerResolver.play_season(
				state, player, tour, tuning, itun, etun, rng, plans[0], plans[1], shop_policy)
			for e in out["shop_log"]:
				if e["action"] == "buy":
					jokers_bought_total += 1
			visits[lvl * 8 + tour] += 1
			matches += 7 + (2 if out["season"].league.made_playoffs else 0)
			if out["season"].beat:
				beats[lvl * 8 + tour] += 1
			bank_sum[state.seasons_played - 1] += player.tons_balance
			bank_n[state.seasons_played - 1] += 1
			if maxed_season == 0 and player.attributes.power >= ATTR_CAP \
					and player.attributes.composure >= ATTR_CAP \
					and player.attributes.attack >= ATTR_CAP \
					and player.attributes.control >= ATTR_CAP:
				maxed_season = state.seasons_played
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
		# DK11: "retired_forced" slots in here when Theme 9 builds the forced-retirement mechanic
		var end_reason := "complete" if state.complete else "season_cap"
		end_reasons.append(end_reason)
		if state.complete:
			seasons_to_complete.append(state.seasons_played)
			matches_to_complete.append(matches)
		else:
			capped += 1
		maxed_seasons.append(maxed_season)   # 0 = never maxed within the run
		print("career %d/%d: %s [policy=%s end=%s] in %d seasons (maxed at %d)" % [c + 1, n,
			"COMPLETE" if state.complete else "capped", policy_kind, end_reason,
			state.seasons_played, maxed_season])

	var bank_curve: Array = []
	for i in range(SEASON_CAP):
		if bank_n[i] > 0:
			bank_curve.append(snappedf(bank_sum[i] / bank_n[i], 0.1))
	var data := {
		"n": n,
		"season_cap": SEASON_CAP,
		"policy": policy_kind,
		"completed": seasons_to_complete.size(),
		"capped": capped,
		"seasons_to_complete": seasons_to_complete,
		"maxed_seasons": maxed_seasons,
		"matches_to_complete": matches_to_complete,
		"cell_visits": visits,
		"cell_beats": beats,
		"bank_curve": bank_curve,
		"end_reasons": end_reasons,
		"jokers_bought": jokers_bought_total,
	}
	print("DATA ", JSON.stringify(data))
	quit()
