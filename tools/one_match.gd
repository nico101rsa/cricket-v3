extends SceneTree

# ONE cricket match, narrated ball-by-ball (Nico 2026-06-13). Creates a player,
# picks a 4-joker loadout, plays a single T20 on the fidelity sim, and writes
# every delivery + every Boost press + the full scorecards to
# docs/mockups/one-match-v1.md. Not a season, not a career — one game.
#
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/one_match.gd
# Env: MATCH_SEED (default 7) · CELL_LEVEL/CELL_TOUR (default 0,3 = Club Day Mixed,
#      a competitive mid-Club cell) · LOADOUT (comma ids; default a sensible 4)

var _desc := {}


func _load_descriptions() -> void:
	var f := FileAccess.open("res://docs/joker-pool-v1.md", FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var cols := f.get_line().split("|")
		if cols.size() < 7:
			continue
		var d := cols[5].strip_edges()
		if d.begins_with("*") and d.ends_with("*"):
			_desc[cols[2].strip_edges()] = d.substr(1, d.length() - 2).strip_edges()
	f.close()


func _jname(id: String) -> String:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return g["jname"]
	return id


func _rarity(id: String) -> String:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return g["rarity"]
	return "?"


func _intent_word(i: int) -> String:
	match i:
		BallResolver.Intent.DEFENSIVE: return "Defensive"
		BallResolver.Intent.AGGRESSIVE: return "Aggressive"
		_: return "Balanced"


# Render one innings' ball log into over-by-over prose.
func _render_innings(log: Array, inn: InningsResult, batting_name: String, bowling_name: String, chase_target: int) -> Array:
	var out: Array = []
	out.append("**%s batting%s — final %d/%d off %.1f overs**" % [
		batting_name,
		(" (chasing %d)" % chase_target) if chase_target > 0 else "",
		inn.total, inn.wickets, inn.balls / 6.0])
	out.append("")
	var cur_over := 0
	var over_runs := 0
	var over_balls: Array = []
	for b in log:
		if b["over"] != cur_over:
			if cur_over != 0:
				out.append("- **Over %d:** %s  → %d run%s (score %s)" % [
					cur_over, "  ".join(over_balls), over_runs, "" if over_runs == 1 else "s",
					_score_at(log, cur_over)])
			cur_over = b["over"]
			over_runs = 0
			over_balls = []
			if b["boost_pressed"]:
				out.append("  ⚡ **Manager Boost pressed** at the start of over %d (%s, while %s)" % [
					cur_over, _intent_word(b["intent"]),
					"batting" if b["player_batting"] else "bowling"])
		var face := "you" if b["is_player"] else "#%d" % (b["striker_pos"] + 1)
		var ev := ""
		if b["wicket"]:
			ev = "%s W" % face
		elif b["runs"] == 0:
			ev = "%s ·" % face
		else:
			ev = "%s %d" % [face, b["runs"]]
			over_runs += b["runs"]
		over_balls.append(ev)
	if cur_over != 0:
		out.append("- **Over %d:** %s  → %d run%s (score %s)" % [
			cur_over, "  ".join(over_balls), over_runs, "" if over_runs == 1 else "s",
			_score_at(log, cur_over)])
	out.append("")
	# Batting card.
	out.append("Batting card:")
	for row in inn.batters:
		if int(row.get("balls", 0)) == 0 and not row.get("out", false):
			continue
		out.append("- %s: %d (%d)%s" % [
			"YOU" if row.get("is_player", false) else "#%d" % (int(row.get("position", 0)) + 1),
			int(row.get("runs", 0)), int(row.get("balls", 0)),
			"" if row.get("out", false) else " not out"])
	if inn.player_bowl_balls > 0:
		out.append("- YOUR bowling: %d/%d off %.1f overs" % [
			inn.player_bowl_wickets, inn.player_bowl_runs, inn.player_bowl_balls / 6.0])
	out.append("")
	return out


func _score_at(log: Array, over: int) -> String:
	var last := {}
	for b in log:
		if b["over"] == over:
			last = b
	return "%d/%d" % [int(last["total"]), int(last["wickets"])]


func _init() -> void:
	_load_descriptions()
	var seed_v := int(OS.get_environment("MATCH_SEED")) if OS.get_environment("MATCH_SEED") != "" else 23
	var lvl := int(OS.get_environment("CELL_LEVEL")) if OS.get_environment("CELL_LEVEL") != "" else 1
	var tour := int(OS.get_environment("CELL_TOUR")) if OS.get_environment("CELL_TOUR") != "" else 7
	var loadout_env := OS.get_environment("LOADOUT")
	var loadout := ["powerplay_punch", "the_chase_master", "snicko", "tight_lines"]
	if loadout_env != "":
		loadout = Array(loadout_env.split(","))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()

	# Create the player — a mid-career batting all-rounder (a few Seasons of
	# Kit Room training in), so a top-tour match is a real contest.
	var attrs := Attributes.new()
	attrs.power = 55.0
	attrs.composure = 50.0
	attrs.attack = 45.0
	attrs.control = 40.0

	# The two teams (mid-Club competitive cell, both ~3★ so it is a real contest).
	var spec := DifficultyLadder.spec_for(lvl, tour)
	var my_team := Team.new(); my_team.stars = 3.0; my_team.team_name = "Karoo Kings"
	var opp_team := Team.new(); opp_team.stars = 3.0; opp_team.team_name = "Dusty Plains"
	var tour_dist := spec.make_tour()

	var jokers := JokerCatalog.effects_of_ids(loadout)
	var jplans := ShopResolver.plans_for(jokers)
	var boost := BoostPlan.at([1, 10, 16])
	var brain := OpponentBrain.draw_plans(spec.brain_tier, spec.blend, rng)

	var log1: Array = []
	var log2: Array = []
	var m := MatchResolver.simulate_match_teams(
		attrs, my_team, opp_team, tour_dist, tuning, itun, rng,
		brain[0], brain[1], jokers, jplans["field"], null, brain[0],
		boost, DRSPolicy.new(), null, null, DRSPolicy.new(), -1, brain[1], log1, log2)

	var L: Array = []
	L.append("# One match, ball by ball")
	L.append("")
	L.append("Seed %d · %s %s · a single T20. This is one game start to finish — no season, no career." % [
		seed_v, DifficultyLadder.LEVEL_NAMES[lvl], DifficultyLadder.TOUR_NAMES[tour]])
	L.append("")
	L.append("## Your player")
	L.append("- **Power %.0f / Composure %.0f / Attack %.0f / Control %.0f** (/100 card scale)" % [
		attrs.power, attrs.composure, attrs.attack, attrs.control])
	L.append("- A batting all-rounder: bats **No.%d**, bowls a **%d-over** quota." % [
		InningsResolver.player_position(attrs, itun), InningsResolver.player_overs(attrs, itun)])
	L.append("")
	L.append("## Your 4 jokers this match")
	for id in loadout:
		L.append("- **%s** (%s, ₸%d) — %s" % [_jname(id), _rarity(id), JokerCatalog.price(id),
			_desc.get(_jname(id), "(see pool doc)")])
	L.append("")
	L.append("Manager Boost is set to press at the start of overs **1, 10 and 16**.")
	L.append("")
	L.append("## The two teams")
	L.append("- **Karoo Kings (you, 3.0★)**")
	L.append("- **Dusty Plains (them, 3.0★)**")
	L.append("- Tour mean card %.1f/100; opponent captain brain tier %d." % [
		spec.d * 0 + TourSpec.mean_frac(spec.d) * TourSpec.MID_MEAN, spec.brain_tier])
	L.append("")
	var we_first := m.player_bats_first
	L.append("## Toss: %s bat first." % ("we" if we_first else "they"))
	L.append("")
	L.append("Legend: `you`/`#n` = striker · number = runs · `·` = dot · `W` = wicket · ⚡ = Boost press.")
	L.append("")
	L.append("## First innings")
	L.append("")
	if we_first:
		L.append_array(_render_innings(log1, m.innings1, "Karoo Kings (you)", "Dusty Plains", 0))
	else:
		L.append_array(_render_innings(log1, m.innings1, "Dusty Plains", "Karoo Kings (you)", 0))
	L.append("## Second innings")
	L.append("")
	if we_first:
		L.append_array(_render_innings(log2, m.innings2, "Dusty Plains", "Karoo Kings (you)", m.innings1.total + 1))
	else:
		L.append_array(_render_innings(log2, m.innings2, "Karoo Kings (you)", "Dusty Plains", m.innings1.total + 1))

	var verdict := "tie"
	if m.outcome == MatchResult.Outcome.PLAYER_WIN:
		verdict = ("**WE WON** by %d runs" % m.margin_runs) if m.margin_runs > 0 else ("**WE WON** by %d wickets (%d balls to spare)" % [m.margin_wickets, m.balls_remaining])
	elif m.outcome == MatchResult.Outcome.OPPONENT_WIN:
		verdict = ("We lost by %d runs" % m.margin_runs) if m.margin_runs > 0 else ("We lost by %d wickets (%d balls left)" % [m.margin_wickets, m.balls_remaining])
	L.append("## Result: %s" % verdict)

	var f := FileAccess.open("res://docs/mockups/one-match-v1.md", FileAccess.WRITE)
	f.store_string("\n".join(L))
	f.close()
	print("\n".join(L))
	quit()
