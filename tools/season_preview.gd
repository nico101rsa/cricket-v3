extends SceneTree

# Throwaway diagnostic + first seed of the 7c balance harness. Sweeps the star
# gap (playerStars - oppStars), runs N seeded simulate_match_teams per matchup
# against a fixed Tour, pools by rounded gap, and prints CSV to stdout:
#   star_gap,matches,player_wins,win_rate
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/season_preview.gd
# (capture stdout; paste the rows into docs/mockups/star-winrate-v1.html)

func _init() -> void:
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var tour := TourDistribution.new()
	tour.mean = 5
	tour.spread = 3
	tour.noise = 1
	var player := Attributes.new()
	player.power = 5
	player.composure = 5
	player.attack = 5
	player.control = 5

	var stars := [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
	var n := 300
	print("star_gap,matches,player_wins,win_rate")
	var wins_by_gap := {}
	var total_by_gap := {}
	for ps in stars:
		for os in stars:
			var gap: float = snappedf(ps - os, 0.5)
			var pt := Team.new()
			pt.stars = ps
			var ot := Team.new()
			ot.stars = os
			for sv in range(1, n + 1):
				var seed_value := sv + int(ps * 100) + int(os * 10000)
				var r := MatchResolver.simulate_match_teams(player, pt, ot, tour, tuning, itun, _rng(seed_value))
				total_by_gap[gap] = total_by_gap.get(gap, 0) + 1
				if r.outcome == MatchResult.Outcome.PLAYER_WIN:
					wins_by_gap[gap] = wins_by_gap.get(gap, 0) + 1
	var keys := total_by_gap.keys()
	keys.sort()
	for k in keys:
		var w: int = wins_by_gap.get(k, 0)
		var tot: int = total_by_gap[k]
		print("%.1f,%d,%d,%.4f" % [k, tot, w, float(w) / float(tot)])
	quit()

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r
