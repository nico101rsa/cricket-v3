extends SceneTree

# One seeded Career, narrated season-by-season (shop rung DK12) — the artefact
# Nico reacts to before the playable-season rung. BALANCED shop policy, the
# preview's naive tour/offer lines. Writes docs/mockups/career-narrative-v1.md.
#
# Run:  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/career_narrate.gd
# Seed via NARRATE_SEED (default 9001); policy via NARRATE_POLICY (default balanced).

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


# Season batting/bowling aggregates from the Player's own scorecards.
func _player_season_line(season: SeasonResult) -> Dictionary:
	var runs := 0
	var wickets := 0
	for m in CareerResolver._player_matches(season):
		for inn in [m.innings1, m.innings2]:
			var line: Dictionary = inn.player_line()
			if not line.is_empty():
				runs += int(line.get("runs", 0))
			wickets += inn.player_bowl_wickets
	return {"runs": runs, "wickets": wickets}


func _init() -> void:
	var seed_env := OS.get_environment("NARRATE_SEED")
	var seed_v := int(seed_env) if seed_env != "" else 9001
	var policy_kind := OS.get_environment("NARRATE_POLICY")
	if policy_kind == "":
		policy_kind = "balanced"
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
	lines.append("# One Career, narrated")
	lines.append("")
	lines.append(("Seed %d, '%s' spending (buy a joker when the next attribute upgrade is " +
		"still covered), naive tour and offer choices. This is the story the game " +
		"will eventually tell on screen — every line below is a real simulated event.") % [seed_v, policy_kind])
	lines.append("")

	while not state.complete and state.seasons_played < SEASON_CAP:
		var lvl := state.current_level()
		var tour := _choose_tour(state)
		var team: Team = state.teams[state.current_team_index]
		var team_label: String = team.team_name if team.team_name != "" else "Team %d" % state.current_team_index
		var out := CareerResolver.play_season(
			state, player, tour, tuning, itun, etun, rng, plans[0], plans[1], policy)
		var season: SeasonResult = out["season"]
		var s_no := state.seasons_played

		lines.append("## Season %d — %s %s, playing for %s (%.1f★)" % [
			s_no, DifficultyLadder.LEVEL_NAMES[lvl], DifficultyLadder.TOUR_NAMES[tour],
			team_label, team.stars])
		var pos: int = season.player_final_position
		var headline := "Finished %d of 8" % pos
		if season.won_final:
			headline = "WON THE FINAL — champions"
		elif pos <= 2:
			headline = "Lost The Final (finished %d)" % pos
		elif pos == 3:
			headline = "Won the 3rd-place playoff (finished 3rd)"
		var pline := _player_season_line(season)
		lines.append("- **%s** — %s. Personal: %d runs, %d wickets across the Season." % [
			headline, "that beats the Season (top 3)" if season.beat else "Season not beaten",
			pline["runs"], pline["wickets"]])
		lines.append("- Paid ₸%d this Season — bank now ₸%d." % [out["pay"], player.tons_balance])
		for e in out["shop_log"]:
			match e["action"]:
				"starter":
					lines.append("- Kit Room: took the free starter joker **%s**." % _jname(e["id"]))
				"carryover_in":
					lines.append("- Kit Room: **%s** carried over from last Season." % _jname(e["id"]))
				"buy":
					lines.append("- Kit Room: bought **%s** for ₸%d." % [_jname(e["id"]), e["tons"]])
				"sell":
					lines.append("- Kit Room: sold **%s**." % _jname(e["id"]))
				"upgrade":
					lines.append("- Kit Room: trained **%s** +1." % e["id"])
				"hold":
					lines.append("- Kit Room: asked the kit man to hold **%s** until next visit." % _jname(e["id"]))
		if state.carryover_joker_id != "":
			lines.append("- Carrying **%s** into next Season." % _jname(state.carryover_joker_id))
		if state.complete:
			lines.append("")
			lines.append("**CAREER COMPLETE** — Province Premier won in %d Seasons." % s_no)
			break
		var up: Offer = null
		for o in out["offers"]:
			if o.level > lvl and state.level_won[lvl]:
				up = o
				break
		if up != null:
			var to_team: Team = state.teams[up.team_index]
			var to_label: String = to_team.team_name if to_team.team_name != "" else "Team %d" % up.team_index
			lines.append("- **Offer accepted** — moving up to %s with %s (%.1f★)." % [
				DifficultyLadder.LEVEL_NAMES[up.level], to_label, up.stars])
			CareerResolver.accept_offer(state, player, up)
		else:
			CareerResolver.stay(state, player)
		lines.append("")

	if not state.complete:
		lines.append("")
		lines.append("**Career ended: Season cap (%d) reached without the Province Premier trophy.**" % SEASON_CAP)
	lines.append("")
	lines.append("_End reason: %s. Attributes finished Power %.0f / Composure %.0f / Attack %.0f / Control %.0f. Final bank ₸%d._" % [
		"complete" if state.complete else "season_cap",
		player.attributes.power, player.attributes.composure,
		player.attributes.attack, player.attributes.control, player.tons_balance])

	var f := FileAccess.open("res://docs/mockups/career-narrative-v1.md", FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("narrative written: %d seasons, %s" % [state.seasons_played,
		"complete" if state.complete else "capped"])
	quit()
