extends SceneTree

# Deep-dive one Season of the narrated career (shop rung follow-up, Nico
# 2026-06-12): replay the same seeded career as career_narrate.gd (identical
# RNG consumption) and print Season SEASON_NO match-by-match — results, the
# Player's batting/bowling line per match, averages, the Shop log, the Offers
# and the decision. Scores in SA convention (runs/wickets); bowling figures
# wickets/runs.
#
# Run:  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/career_season_log.gd
# Env:  NARRATE_SEED (default 9001) · NARRATE_POLICY (default balanced) · SEASON_NO (default 1)

const SEASON_CAP := 120


func _choose_tour(state: CareerState) -> int:
	var lvl := state.current_level()
	for t in state.playable_cells():
		if state.status_of(lvl, t) != CareerState.CellStatus.BEATEN:
			return t
	return state.playable_cells().back()


func _jname(id: String) -> String:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return g["jname"]
	return id


func _team_label(t: Team, idx: int) -> String:
	return t.team_name if t.team_name != "" else "Team %d" % idx


# One match line from the Player's perspective. opp_name resolved by caller.
func _match_lines(m: MatchResult, opp_name: String, tag: String) -> Array:
	var our_inn: InningsResult = m.innings1
	var their_inn: InningsResult = m.innings2
	if m.innings1.player_line().is_empty():
		our_inn = m.innings2
		their_inn = m.innings1
	var verdict := "TIED"
	if m.outcome == MatchResult.Outcome.PLAYER_WIN:
		if m.margin_runs > 0:
			verdict = "WON by %d runs" % m.margin_runs
		else:
			verdict = "WON by %d wickets (%d balls left)" % [m.margin_wickets, m.balls_remaining]
	elif m.outcome == MatchResult.Outcome.OPPONENT_WIN:
		if m.margin_runs > 0:
			verdict = "LOST by %d runs" % m.margin_runs
		else:
			verdict = "LOST by %d wickets (%d balls left)" % [m.margin_wickets, m.balls_remaining]
	var line: Dictionary = our_inn.player_line()
	var bat := "%d (%d balls)%s" % [int(line.get("runs", 0)), int(line.get("balls", 0)),
		"" if line.get("out", false) else " not out"]
	var bowl := "did not bowl"
	if their_inn.player_bowl_balls > 0:
		bowl = "%d/%d off %.1f overs" % [their_inn.player_bowl_wickets,
			their_inn.player_bowl_runs, their_inn.player_bowl_balls / 6.0]
	var out: Array = []
	out.append("**%s vs %s — %s**" % [tag, opp_name, verdict])
	out.append("  Us %d/%d · Them %d/%d. You: bat %s · bowl %s" % [
		our_inn.total, our_inn.wickets, their_inn.total, their_inn.wickets, bat, bowl])
	return out


func _init() -> void:
	var seed_env := OS.get_environment("NARRATE_SEED")
	var seed_v := int(seed_env) if seed_env != "" else 9001
	var policy_kind := OS.get_environment("NARRATE_POLICY")
	if policy_kind == "":
		policy_kind = "balanced"
	var target_env := OS.get_environment("SEASON_NO")
	var target_season := int(target_env) if target_env != "" else 1

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var etun := EconomyTuning.new()
	var player := Player.new()
	var a := Attributes.new()
	a.power = 35.0
	a.composure = 30.0
	a.attack = 30.0
	a.control = 30.0
	player.attributes = a
	var state := CareerResolver.start_career(0)
	var policy := ShopPolicy.preset(policy_kind)
	var plans := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, rng)

	var lines: Array = []
	while not state.complete and state.seasons_played < SEASON_CAP:
		var lvl := state.current_level()
		var tour := _choose_tour(state)
		# Snapshot BEFORE the season: team labels move under mutate_stars after.
		var my_team: Team = state.teams[state.current_team_index]
		var my_label := _team_label(my_team, state.current_team_index)
		var opponents: Array = state.opponents_of_current()
		var opp_labels: Array = []
		for i in range(opponents.size()):
			opp_labels.append(opponents[i].team_name)
		var out := CareerResolver.play_season(
			state, player, tour, tuning, itun, etun, rng, plans[0], plans[1], policy)
		var season: SeasonResult = out["season"]
		var s_no := state.seasons_played

		if s_no == target_season:
			lines.append("# Season %d in full — %s %s, %s (%.1f★)" % [
				s_no, DifficultyLadder.LEVEL_NAMES[lvl], DifficultyLadder.TOUR_NAMES[tour],
				my_label, my_team.stars])
			lines.append("")
			lines.append("Seed %d, '%s' spending — the same career as career-narrative-v1.md, zoomed in." % [seed_v, policy_kind])
			lines.append("")
			lines.append("## The matches")
			lines.append("")
			# League fixtures: round_robin order is (0,1)..(0,7) -> opponents[k].
			var pms: Array = season.league.player_matches
			for k in range(pms.size()):
				lines.append_array(_match_lines(pms[k], opp_labels[k], "Match %d" % (k + 1)))
			# Knockouts the Player featured in.
			var ko := [["Semi-final", season.semi1], ["Semi-final", season.semi2],
				["The Final", season.final_match], ["3rd-place playoff", season.third_place]]
			for pair in ko:
				var m: MatchResult = pair[1]
				if not m.innings1.player_line().is_empty() or not m.innings2.player_line().is_empty():
					lines.append_array(_match_lines(m, "(playoff opponent)", pair[0]))
			lines.append("")
			lines.append("## Season totals and averages (the Player)")
			lines.append("")
			var runs := 0
			var balls := 0
			var outs := 0
			var innings := 0
			var best := 0
			var wkts := 0
			var conceded := 0
			var bowl_balls := 0
			var all_pm: Array = CareerResolver._player_matches(season)
			for m in all_pm:
				for inn in [m.innings1, m.innings2]:
					var l: Dictionary = inn.player_line()
					if not l.is_empty():
						innings += 1
						runs += int(l.get("runs", 0))
						balls += int(l.get("balls", 0))
						best = maxi(best, int(l.get("runs", 0)))
						if l.get("out", false):
							outs += 1
					wkts += inn.player_bowl_wickets
					conceded += inn.player_bowl_runs
					bowl_balls += inn.player_bowl_balls
			lines.append("- Batting: **%d runs** in %d innings, average **%s**, strike rate **%.0f**, best **%d**" % [
				runs, innings,
				("%.1f" % (float(runs) / outs)) if outs > 0 else "no dismissals",
				(100.0 * runs / balls) if balls > 0 else 0.0, best])
			lines.append("- Bowling: **%d wickets**, %d runs conceded off %.1f overs, economy **%.2f**" % [
				wkts, conceded, bowl_balls / 6.0,
				(6.0 * conceded / bowl_balls) if bowl_balls > 0 else 0.0])
			lines.append("- League finish: position %d of 8 after the playoffs · %s" % [
				season.player_final_position,
				"beat the Season (top 3)" if season.beat else "Season not beaten"])
			lines.append("- Paid ₸%d (game fees + performance + win prizes + season prizes) — bank after shopping ₸%d" % [
				out["pay"], player.tons_balance])
			lines.append("")
			lines.append("## The Kit Room log (in visit order)")
			lines.append("")
			for e in out["shop_log"]:
				match e["action"]:
					"starter":
						lines.append("- Free starter pick: **%s**" % _jname(e["id"]))
					"carryover_in":
						lines.append("- Carried in from last Season: **%s**" % _jname(e["id"]))
					"buy":
						lines.append("- Bought **%s** for ₸%d" % [_jname(e["id"]), e["tons"]])
					"sell":
						lines.append("- Sold **%s**" % _jname(e["id"]))
					"upgrade":
						lines.append("- Trained **%s** +1" % e["id"])
					"hold":
						lines.append("- Held **%s** for the next visit" % _jname(e["id"]))
			lines.append("- Jokers in the bag at Season end: %s" % (
				", ".join(out["shop_owned"].map(_jname)) if out["shop_owned"].size() > 0 else "none"))
			lines.append("")
			lines.append("## The Offers, and the decision")
			lines.append("")
			if out["offers"].is_empty():
				lines.append("- No Offers arrived.")
			for o in out["offers"]:
				var t: Team = state.teams[o.team_index]
				lines.append("- Offer: join **%s** (%s, %.1f★)" % [
					_team_label(t, o.team_index), DifficultyLadder.LEVEL_NAMES[o.level], o.stars])

		# Same decision rule as career_narrate.gd (identical RNG consumption).
		if state.complete:
			break
		var up: Offer = null
		for o in out["offers"]:
			if o.level > lvl and state.level_won[lvl]:
				up = o
				break
		if s_no == target_season:
			if up != null:
				var t2: Team = state.teams[up.team_index]
				lines.append("- **Decision: accepted** the move to %s (%s)." % [
					_team_label(t2, up.team_index), DifficultyLadder.LEVEL_NAMES[up.level]])
			else:
				lines.append("- **Decision: stayed** with %s (the naive line never moves before winning its League; Affinity ticks +1)." % my_label)
		if up != null:
			CareerResolver.accept_offer(state, player, up)
		else:
			CareerResolver.stay(state, player)
		if s_no >= target_season:
			break

	var path := "res://docs/mockups/career-s%d-detail-v1.md" % target_season
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("\n".join(lines))
	quit()
