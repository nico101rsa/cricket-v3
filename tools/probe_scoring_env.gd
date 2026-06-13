extends SceneTree

# Scoring-environment oracle (BB11, bowling-balance spec §6.5): is the sim's
# run environment real-T20-shaped? Nico's benchmarks (2026-06-11): first-innings
# mean 150–167, run rate ~8–9 per over, ~5–7 wickets down; death the fastest
# phase. Textbook-vs-textbook team-vs-team (even ★3, standard XIs, no jokers /
# Boost / DRS — the pure environment), mirroring the E1 oracle's derivation.
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/probe_scoring_env.gd

const N := 2000

func _init() -> void:
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var tour := TourDistribution.new()
	tour.mean = 31.25
	tour.spread = 9.375
	# League-band probe (card-rescale DR6 / E3): override the tour mean to read
	# the scoring environment at any league level, e.g. ENV_TOUR_MEAN=7.8125
	# (band 1, factor 0.25) or 40.625 (band 5, factor 1.3).
	var mean_override := OS.get_environment("ENV_TOUR_MEAN")
	if mean_override != "":
		tour.mean = float(mean_override)
	var pol := PolicySearch.textbook()
	var totals: Array = []
	var wkts := 0.0
	var balls := 0.0
	var all_out := 0
	var phase := [0.0, 0.0, 0.0]
	for i in range(N):
		var rng := RandomNumberGenerator.new()
		rng.seed = 424242 + i
		var a_bats_first := rng.randf() < 0.5
		var pt := Team.new()
		pt.stars = 3.0
		var ot := Team.new()
		ot.stars = 3.0
		var a_bat := pt.batting_strength(tour, rng)
		var a_bowl := pt.bowling_strength(tour, rng)
		var b_bat := ot.batting_strength(tour, rng)
		var b_bowl := ot.bowling_strength(tour, rng)
		var m := MatchResolver.simulate_match(
			null,
			a_bat, a_bowl, a_bowl,
			b_bat, b_bowl, b_bowl,
			a_bats_first, tuning, itun, rng,
			PolicySearch.intent_plan_of(pol), PolicySearch.bowling_plan_of(pol),
			[], null, null,
			PolicySearch.intent_plan_of(pol), null, null, null,
			Team.standard_xi(), Team.standard_xi(), a_bat / MatchResolver.REF_SCALAR, b_bat / MatchResolver.REF_SCALAR,
			null, null,
			PolicySearch.bowling_plan_of(pol))
		var inn: InningsResult = m.innings1
		totals.append(float(inn.total))
		wkts += inn.wickets
		balls += inn.balls
		if inn.wickets >= 10:
			all_out += 1
		for p in range(3):
			phase[p] += inn.phase_runs[p]
	var d := Distribution.new(totals)
	var rr := d.mean() / (balls / N / 6.0)
	print("scoring environment (first innings, textbook mirror, N=%d)" % N)
	print("  mean total   %6.1f  (benchmark 150-167)" % d.mean())
	print("  sd           %6.1f" % d.sd())
	print("  min/max      %d / %d" % [int(d.minimum()), int(d.maximum())])
	print("  run rate     %6.2f  (benchmark 8-9)" % rr)
	print("  wickets      %6.2f  (sanity 5-7)" % (wkts / N))
	print("  all-out%%     %6.1f" % (100.0 * all_out / N))
	print("  phase RR     PP %.2f | mid %.2f | death %.2f  (death fastest)" % [
		phase[0] / N / 6.0, phase[1] / N / 9.0, phase[2] / N / 5.0])
	quit()
