extends SceneTree

# Narrate the START of one Season + its first match in full detail (Nico's
# 2026-06-12 ask): the team, the Kit Room decisions WITH the options that were
# on the table (starter choices, offers + shelf prices), the full scorecard of
# Match 1, and a mechanical note on every joker encountered. Replays the same
# seeded career as career_narrate.gd (identical RNG consumption).
#
# Run:  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/career_match_detail.gd
# Env:  NARRATE_SEED (default 9001) · NARRATE_POLICY (default balanced) · SEASON_NO (default 2)

const SEASON_CAP := 120


func _choose_tour(state: CareerState) -> int:
	var lvl := state.current_level()
	for t in state.playable_cells():
		if state.status_of(lvl, t) != CareerState.CellStatus.BEATEN:
			return t
	return state.playable_cells().back()


func _group_of(id: String) -> Dictionary:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return g
	return {}


func _jname(id: String) -> String:
	var g := _group_of(id)
	return g.get("jname", id)


# Mechanical one-liner for a joker from its effect rows.
func _mechanics(id: String) -> String:
	var g := _group_of(id)
	var bits: Array = []
	for e in g.get("effects", []):
		var side := "batting" if e.side == JokerEffect.Side.BATTING else "bowling"
		var target := "runs" if e.target == JokerEffect.Target.RUNS else "wicket chance"
		var dir := "+" if e.mult > 1.0 else "-"
		bits.append("%s: %s %s%d%%" % [side, target, dir, absi(int(round((e.mult - 1.0) * 100)))])
	if bits.is_empty():
		return "special/stateful effect (see pool doc)"
	return " · ".join(bits)


func _scorecard(inn: InningsResult, label: String) -> Array:
	var lines: Array = []
	lines.append("**%s — %d/%d off %.1f overs** (Powerplay %d · middle %d · death %d)" % [
		label, inn.total, inn.wickets, inn.balls / 6.0,
		inn.phase_runs[0], inn.phase_runs[1], inn.phase_runs[2]])
	for b in inn.batters:
		if int(b.get("balls", 0)) == 0 and not b.get("out", false):
			continue
		var who := "YOU" if b.get("is_player", false) else "No.%d" % (int(b.get("position", 0)) + 1)
		lines.append("- %s: %d (%d)%s" % [who, int(b.get("runs", 0)), int(b.get("balls", 0)),
			"" if b.get("out", false) else " not out"])
	if inn.player_bowl_balls > 0:
		lines.append("- YOUR bowling in this innings: %d/%d off %.1f overs" % [
			inn.player_bowl_wickets, inn.player_bowl_runs, inn.player_bowl_balls / 6.0])
	if not inn.fall_of_wickets.is_empty():
		var fow: Array = []
		for f in inn.fall_of_wickets:
			fow.append(str(f.get("total", f)) if f is Dictionary else str(f))
		lines.append("- Fall of wickets: %s" % ", ".join(fow))
	return lines


func _init() -> void:
	var seed_env := OS.get_environment("NARRATE_SEED")
	var seed_v := int(seed_env) if seed_env != "" else 9001
	var policy_kind := OS.get_environment("NARRATE_POLICY")
	if policy_kind == "":
		policy_kind = "balanced"
	var target_env := OS.get_environment("SEASON_NO")
	var target_season := int(target_env) if target_env != "" else 2

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
	var inner := ShopPolicy.preset(policy_kind)
	var seen: Array = []   # recorded shop ctxs for the target season
	var recording := [false]
	var policy := func(ctx: Dictionary) -> Dictionary:
		var decision: Dictionary = inner.call(ctx)
		if recording[0]:
			seen.append({"ctx": {
				"kind": ctx["kind"],
				"offer": ctx.get("offer"),
				"owned": ctx["shop"].owned_ids.duplicate() if ctx.has("shop") else [],
				"bank": ctx["player"].tons_balance if ctx.has("player") else 0,
			}, "decision": decision})
		return decision
	var plans := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, rng)

	var lines: Array = []
	while not state.complete and state.seasons_played < SEASON_CAP:
		var lvl := state.current_level()
		var tour := _choose_tour(state)
		var my_team: Team = state.teams[state.current_team_index]
		var my_label: String = my_team.team_name
		recording[0] = (state.seasons_played + 1) == target_season
		var out := CareerResolver.play_season(
			state, player, tour, tuning, itun, etun, rng, plans[0], plans[1], policy)
		var s_no := state.seasons_played

		if s_no == target_season:
			var season: SeasonResult = out["season"]
			var jokers_seen: Array = []
			lines.append("# Season %d, opened up: the Kit Room and Match 1" % s_no)
			lines.append("")
			lines.append("Same career as career-narrative-v1.md (seed %d, '%s' spending). Team: **%s** (%.1f★), %s %s." % [
				seed_v, policy_kind, my_label, my_team.stars,
				DifficultyLadder.LEVEL_NAMES[lvl], DifficultyLadder.TOUR_NAMES[tour]])
			lines.append("")
			lines.append("## Season start — the Kit Room (visit 0, before any cricket)")
			lines.append("")
			for rec in seen:
				var ctx: Dictionary = rec["ctx"]
				var dec: Dictionary = rec["decision"]
				match ctx["kind"]:
					"starter":
						lines.append("Owned coming in: %s. Bank ₸%d." % [
							("none" if ctx["owned"].is_empty() else ", ".join(ctx["owned"].map(_jname))), ctx["bank"]])
						lines.append("")
						lines.append("**Free starter — pick one of three Commons:**")
						for id in ctx["offer"]:
							lines.append("- %s%s — %s" % [_jname(id),
								" ← PICKED" if dec.get("pick", "") == id else "", _mechanics(id)])
							jokers_seen.append(id)
					"visit":
						var offer: Dictionary = ctx["offer"]
						lines.append("")
						lines.append("**Kit Room visit** (bank ₸%d, owned: %s):" % [
							ctx["bank"], ", ".join(ctx["owned"].map(_jname))])
						for r in ["common", "rare", "legendary"]:
							var id2: String = offer[r]
							var tagbits: Array = []
							if dec.get("buy", "") == id2:
								tagbits.append("BOUGHT")
							if dec.get("hold", "") == id2:
								tagbits.append("HELD")
							lines.append("- %s %s — ₸%d%s — %s" % [r.capitalize(), _jname(id2),
								offer["prices"][id2],
								(" ← " + " + ".join(tagbits)) if not tagbits.is_empty() else "",
								_mechanics(id2)])
							jokers_seen.append(id2)
						if dec.get("upgrade", "") != "":
							lines.append("- Also trained **%s** +1." % dec["upgrade"])
			# Match 1 detail.
			var m: MatchResult = season.league.player_matches[0]
			var opp_name: String = state.opponents_of_current()[0].team_name
			lines.append("")
			lines.append("## Match 1 vs %s — ball-for-ball summary" % opp_name)
			lines.append("")
			lines.append("Toss: %s bat first." % ("we" if m.player_bats_first else "they"))
			var our_first := m.player_bats_first
			lines.append("")
			lines.append_array(_scorecard(m.innings1, ("Our innings" if our_first else "Their innings") + " (batting first)"))
			lines.append("")
			lines.append_array(_scorecard(m.innings2, ("Their chase" if our_first else "Our chase")))
			lines.append("")
			var verdict := "tie"
			if m.outcome == MatchResult.Outcome.PLAYER_WIN:
				verdict = ("won by %d runs" % m.margin_runs) if m.margin_runs > 0 else ("won by %d wickets with %d balls to spare" % [m.margin_wickets, m.balls_remaining])
			elif m.outcome == MatchResult.Outcome.OPPONENT_WIN:
				verdict = ("lost by %d runs" % m.margin_runs) if m.margin_runs > 0 else ("lost by %d wickets with %d balls left" % [m.margin_wickets, m.balls_remaining])
			lines.append("**Result: we %s.** Jokers active in this match: %s." % [verdict,
				", ".join(out["shop_owned"].map(_jname)) if not out["shop_owned"].is_empty() else "from the season log"])
			lines.append("")
			lines.append("## Joker reference (everything encountered above)")
			lines.append("")
			var listed: Array = []
			for id3 in jokers_seen:
				if id3 in listed:
					continue
				listed.append(id3)
				var g := _group_of(id3)
				lines.append("- **%s** (%s, catalog ₸%d) — %s" % [_jname(id3), g.get("rarity", "?"),
					JokerCatalog.price(id3), _mechanics(id3)])
			break

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

	var path := "res://docs/mockups/career-match-detail-v1.md"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("\n".join(lines))
	quit()
