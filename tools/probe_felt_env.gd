extends SceneTree

# Felt scoring environment at a Career-grid cell (env-span rung, Nico's
# 2026-06-12 ruling: Club T1 should average ~100, Province Premier ~155).
# Unlike probe_scoring_env (even-★3 textbook mirror), this measures what the
# Player actually SEES on the scorecard: first-innings totals of the Player's
# own league matches, in real career conditions — the STAR_LADDER team field,
# the underdog 1.5★ start, the cell's opponent brain, a fresh-creation build,
# textbook player plans (the preview bot's line).
#
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/probe_felt_env.gd
# Env: CELL_LEVEL (0-2, default 0) · CELL_TOUR (0-7, default 0)
#      FRAC (override mean_frac; "" = use the live dial) · N_SEASONS (default 100)
#      JOKERS (comma-separated catalog ids for the Player loadout; "" = none)
#      ATTRS ("p,c,a,c" build override, default 35,30,30,30) · PLAYER_SLOT (STAR_LADDER slot 0-7, default 0)
#      SPREAD_ABS (force tour spread to an absolute value) · BRAIN (TEXTBOOK forces textbook opp brains)

func _init() -> void:
	var level := int(OS.get_environment("CELL_LEVEL")) if OS.get_environment("CELL_LEVEL") != "" else 0
	var tour_i := int(OS.get_environment("CELL_TOUR")) if OS.get_environment("CELL_TOUR") != "" else 0
	var frac_env := OS.get_environment("FRAC")
	var n := int(OS.get_environment("N_SEASONS")) if OS.get_environment("N_SEASONS") != "" else 100
	var jokers: Array = []
	var jokers_env := OS.get_environment("JOKERS")
	if jokers_env != "":
		jokers = JokerCatalog.effects_of_ids(Array(jokers_env.split(",")))
	var attrs_env := OS.get_environment("ATTRS")
	var build := [35.0, 30.0, 30.0, 30.0]
	if attrs_env != "":
		var parts := attrs_env.split(",")
		build = [float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])]
	var player_slot := int(OS.get_environment("PLAYER_SLOT")) if OS.get_environment("PLAYER_SLOT") != "" else 0

	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var spec := DifficultyLadder.spec_for(level, tour_i)
	if OS.get_environment("BRAIN") == "TEXTBOOK":
		spec.brain_tier = TourSpec.Tier.TEXTBOOK
		spec.blend = 1.0
	var pol_ip := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, RandomNumberGenerator.new())

	var totals: Array = []
	var wkts := 0.0
	var balls := 0.0
	var n_inns := 0
	for s in range(n):
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + s
		# The career's team field: STAR_LADDER, Player on the 1.5★ underdog.
		var teams: Array = []
		for k in range(CareerState.TEAMS_PER_LEVEL):
			var t := Team.new()
			t.stars = CareerResolver.STAR_LADDER[k]
			teams.append(t)
		var player_team: Team = teams[player_slot]
		var opponents: Array = teams.duplicate()
		opponents.remove_at(player_slot)
		var attrs := Attributes.new()
		attrs.power = build[0]
		attrs.composure = build[1]
		attrs.attack = build[2]
		attrs.control = build[3]
		var tour := spec.make_tour()
		if frac_env != "":
			tour.mean = float(frac_env) * TourSpec.MID_MEAN
			tour.spread = TourSpec.SPREAD_RATIO * tour.mean
		if OS.get_environment("SPREAD_ABS") != "":
			tour.spread = float(OS.get_environment("SPREAD_ABS"))
		var league := LeagueResolver.simulate_league(
			attrs, player_team, opponents, tour, tuning, itun, rng,
			pol_ip[0], pol_ip[1], spec, jokers)
		for m in league.player_matches:
			totals.append(m.innings1.total)
			wkts += m.innings1.wickets
			balls += m.innings1.balls
			n_inns += 1

	totals.sort()
	var sum := 0.0
	for t in totals:
		sum += t
	var mean := sum / totals.size()
	var med: float = totals[totals.size() / 2]
	var p10: float = totals[int(totals.size() * 0.1)]
	var p90: float = totals[int(totals.size() * 0.9)]
	print("FELT cell=(%d,%d) slot=%d d=%.0f frac=%s jokers=%d n_inns=%d | first-inns mean %.1f median %.0f p10 %.0f p90 %.0f | RR %.2f | wkts %.2f" % [
		level, tour_i, player_slot, spec.d, frac_env if frac_env != "" else "live(%.3f)" % TourSpec.mean_frac(spec.d),
		jokers.size(), n_inns, mean, med, p10, p90, mean / (balls / n_inns / 6.0), wkts / n_inns])
	quit()
