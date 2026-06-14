extends SceneTree

# E4 optimal career-line search (spec 2026-06-14-e4-career-line-search-design.md).
# Grids 3 climb (CareerPolicy) × 3 spend (ShopPolicy) = 9 arms, N careers each,
# reporting completion-rate + time-to-beat (seasons / matches / hours) +
# card-max season + end bank, then the optimal arm and a dominance verdict.
# Single-agent: careers aren't adversarial (opponent brain fixed per cell), so
# this is an optimization over named strategies, not a self-play search.
#
# Run (full ~30 min, detached — over the 10-min Bash cap):
#   nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
#     -s tools/career_search.gd > /tmp/e4.log 2>&1 &
# Smoke: CAREER_QUICK=1 (N=10). N=<int> overrides. CLIMB=<kind>/SPEND=<kind>
#        restrict to a single arm.

const SEASON_CAP := 120
const MATCH_MINUTES := 2.75   # 2:45 per match — the roadmap time-to-beat unit


func _median(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s := arr.duplicate()
	s.sort()
	var m := int(s.size() / 2)
	if s.size() % 2 == 1:
		return float(s[m])
	return (float(s[m - 1]) + float(s[m])) / 2.0


func _fresh_player() -> Player:
	var p := Player.new()
	var a := Attributes.new()
	a.power = 11.0       # world-scale v2: fresh hero ≈ a weak Club player
	a.composure = 11.0
	a.attack = 11.0
	a.control = 11.0
	p.attributes = a
	return p


func _card_maxed_season(player: Player, state: CareerState, current: int) -> int:
	# Returns the running value once set; else the current Season-index the
	# moment all 4 attrs hit the cap (0 = not yet).
	if current != 0:
		return current
	var a := player.attributes
	if a.power >= ShopResolver.ATTR_CAP and a.composure >= ShopResolver.ATTR_CAP \
			and a.attack >= ShopResolver.ATTR_CAP and a.control >= ShopResolver.ATTR_CAP:
		return state.seasons_played
	return 0


func _run_arm(climb: String, spend: String, n: int,
		tuning: BallTuning, itun: InningsTuning, etun: EconomyTuning) -> Dictionary:
	var shop_policy := ShopPolicy.preset(spend)
	var completed_seasons: Array = []
	var completed_matches: Array = []
	var maxed: Array = []
	var end_banks: Array = []
	var completes := 0
	for c in range(n):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + c
		var player := _fresh_player()
		var state := CareerResolver.start_career(0)
		var plans := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, rng)
		var matches := 0
		var maxed_season := 0
		while not state.complete and state.seasons_played < SEASON_CAP:
			var tour := CareerPolicy.choose_tour(climb, state)
			var out := CareerResolver.play_season(
				state, player, tour, tuning, itun, etun, rng, plans[0], plans[1], shop_policy)
			matches += 7 + (2 if out["season"].league.made_playoffs else 0)
			maxed_season = _card_maxed_season(player, state, maxed_season)
			if state.complete:
				break
			var off: Offer = CareerPolicy.choose_offer(climb, state, out["offers"], player)
			if off != null:
				CareerResolver.accept_offer(state, player, off)
			else:
				CareerResolver.stay(state, player)
		maxed.append(maxed_season)
		end_banks.append(player.tons_balance)
		if state.complete:
			completes += 1
			completed_seasons.append(state.seasons_played)
			completed_matches.append(matches)
	var med_matches := _median(completed_matches)
	var maxed_nonzero := maxed.filter(func(x): return x > 0)
	return {
		"climb": climb,
		"spend": spend,
		"n": n,
		"completed": completes,
		"completion_pct": snappedf(100.0 * completes / n, 0.1),
		"median_seasons": snappedf(_median(completed_seasons), 0.5),
		"median_matches": int(round(med_matches)),
		"median_hours": snappedf(med_matches * MATCH_MINUTES / 60.0, 0.1),
		"median_maxed_season": snappedf(_median(maxed_nonzero), 0.5),
		"median_end_bank": int(round(_median(end_banks))),
	}


func _init() -> void:
	var quick := OS.get_environment("CAREER_QUICK") == "1"
	var n := 10 if quick else 60
	if OS.get_environment("N") != "":
		n = int(OS.get_environment("N"))
	var climbs: Array = CareerPolicy.KINDS.duplicate()
	var spends: Array = ShopPolicy.KINDS.duplicate()
	if OS.get_environment("CLIMB") != "":
		climbs = [OS.get_environment("CLIMB")]
	if OS.get_environment("SPEND") != "":
		spends = [OS.get_environment("SPEND")]

	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var etun := EconomyTuning.new()

	var arms: Array = []
	for climb in climbs:
		for spend in spends:
			var arm := _run_arm(climb, spend, n, tuning, itun, etun)
			arms.append(arm)
			print("arm %s x %s: %d/%d complete (%.1f%%), median %s seasons / %d matches / %.1fh, maxed S%s, bank %d" % [
				climb, spend, arm["completed"], n, arm["completion_pct"],
				str(arm["median_seasons"]), arm["median_matches"], arm["median_hours"],
				str(arm["median_maxed_season"]), arm["median_end_bank"]])

	# Optimal = fastest (fewest matches) among arms within 5 pts of the best
	# completion rate AND with at least one completion (E4-4).
	var best_completion := 0.0
	for arm in arms:
		best_completion = max(best_completion, arm["completion_pct"])
	var eligible: Array = arms.filter(func(x):
		return x["completed"] > 0 and x["completion_pct"] >= best_completion - 5.0)
	eligible.sort_custom(func(x, y): return x["median_matches"] < y["median_matches"])
	var optimal: Dictionary = eligible[0] if not eligible.is_empty() else {}

	# Dominant = strictly best on BOTH axes by a clear margin: highest completion
	# (>= 2nd-best + 3 pts) AND fewest matches (<= 2nd-fewest * 0.9), same arm.
	var by_completion: Array = arms.duplicate()
	by_completion.sort_custom(func(x, y): return x["completion_pct"] > y["completion_pct"])
	var by_speed: Array = arms.filter(func(x): return x["completed"] > 0)   # all completing arms
	by_speed.sort_custom(func(x, y): return x["median_matches"] < y["median_matches"])
	var dominant := false
	if by_completion.size() >= 2 and by_speed.size() >= 2:
		var top_c: Dictionary = by_completion[0]
		var top_s: Dictionary = by_speed[0]
		var same_arm: bool = top_c["climb"] == top_s["climb"] and top_c["spend"] == top_s["spend"]
		var c_margin: bool = top_c["completion_pct"] >= by_completion[1]["completion_pct"] + 3.0
		var s_margin: bool = top_s["median_matches"] <= by_speed[1]["median_matches"] * 0.9
		dominant = same_arm and c_margin and s_margin

	var data := {
		"n": n,
		"season_cap": SEASON_CAP,
		"arms": arms,
		"optimal": optimal,
		"dominant": dominant,
	}
	print("OPTIMAL ", "%s x %s" % [optimal.get("climb", "?"), optimal.get("spend", "?")],
		" dominant=", dominant)
	print("DATA ", JSON.stringify(data))
	quit()
