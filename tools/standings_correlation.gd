extends SceneTree

# Star -> league-finish correlation (Nico's Q, 2026-06-13): do stronger teams
# reliably finish higher, and is the spread sane (an underdog gets the odd upset,
# not a sweep)? Runs N seasons of the 8-team league (STAR_LADDER) at a cell and
# reports, per team slot/star: average finishing position (1=top of 8), how often
# it makes the top 4, wins the league (1st), and finishes last. Slot 0 (1.5★)
# carries the statted fresh Player (the real underdog); slots 1-7 are derived.
#
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/standings_correlation.gd
# Env: CELL_LEVEL (0-2) · CELL_TOUR (0-7) · N (default 200) · ALLCELLS=1 (sweep a ladder)

const FRESH := [11.0, 11.0, 11.0, 11.0]


func _one_cell(level: int, tour_i: int, n: int) -> void:
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var spec := DifficultyLadder.spec_for(level, tour_i)
	var pol := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, RandomNumberGenerator.new())
	var build := FRESH.duplicate()
	if OS.get_environment("ATTRS") != "":
		var p := OS.get_environment("ATTRS").split(",")
		build = [float(p[0]), float(p[1]), float(p[2]), float(p[3])]
	var attrs := Attributes.new()
	attrs.power = build[0]; attrs.composure = build[1]; attrs.attack = build[2]; attrs.control = build[3]

	var n_slots := CareerState.TEAMS_PER_LEVEL
	var fin_sum: Array = []; var top4: Array = []; var won: Array = []; var last: Array = []
	for k in range(n_slots):
		fin_sum.append(0.0); top4.append(0); won.append(0); last.append(0)

	# For the star<->finish correlation, accumulate paired (stars, points=9-finish).
	var sx := 0.0; var sy := 0.0; var sxy := 0.0; var sxx := 0.0; var syy := 0.0; var nc := 0

	for s in range(n):
		var rng := RandomNumberGenerator.new(); rng.seed = 4000 + s
		var teams: Array = []
		for k in range(n_slots):
			var t := Team.new(); t.stars = CareerResolver.STAR_LADDER[k]; teams.append(t)
		var opponents: Array = teams.duplicate(); opponents.remove_at(0)
		var tour := spec.make_tour()
		if OS.get_environment("NOISE_FRAC") != "":
			tour.noise_frac = float(OS.get_environment("NOISE_FRAC"))
		var league := LeagueResolver.simulate_league(
			attrs, teams[0], opponents, tour, tuning, itun, rng, pol[0], pol[1], spec, [])
		# standings are ranked best->worst; map team_index -> finishing position (1..8).
		for pos in range(league.standings.size()):
			var ti: int = league.standings[pos].team_index
			var finish := pos + 1
			fin_sum[ti] += finish
			if finish <= 4: top4[ti] += 1
			if finish == 1: won[ti] += 1
			if finish == n_slots: last[ti] += 1
			var stars: float = CareerResolver.STAR_LADDER[ti]
			var pts := float(n_slots - finish)   # 7 for 1st .. 0 for last
			sx += stars; sy += pts; sxy += stars * pts; sxx += stars * stars; syy += pts * pts; nc += 1

	var r := (nc * sxy - sx * sy) / sqrt(maxf(1e-9, (nc * sxx - sx * sx) * (nc * syy - sy * sy)))
	print("\n=== %s %s (d=%.0f), N=%d ===" % [
		DifficultyLadder.LEVEL_NAMES[level], DifficultyLadder.TOUR_NAMES[tour_i], spec.d, n])
	print("star  avg-finish  top4%%  won%%  last%%   (slot)")
	for k in range(n_slots):
		print("%.1f      %.2f      %3.0f   %3.0f   %3.0f      %s" % [
			CareerResolver.STAR_LADDER[k], fin_sum[k] / n,
			100.0 * top4[k] / n, 100.0 * won[k] / n, 100.0 * last[k] / n,
			"slot %d%s" % [k, " = YOU (1.5★ + fresh player)" if k == 0 else ""]])
	print("star->finish correlation r = %.3f  (1.0 = perfectly tight, 0 = stars meaningless)" % r)


func _init() -> void:
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 200
	if OS.get_environment("ALLCELLS") == "1":
		for cell in [[0, 0], [0, 7], [1, 3], [2, 0], [2, 7]]:
			_one_cell(cell[0], cell[1], n)
	else:
		var level := int(OS.get_environment("CELL_LEVEL")) if OS.get_environment("CELL_LEVEL") != "" else 0
		var tour_i := int(OS.get_environment("CELL_TOUR")) if OS.get_environment("CELL_TOUR") != "" else 0
		_one_cell(level, tour_i, n)
	quit()
