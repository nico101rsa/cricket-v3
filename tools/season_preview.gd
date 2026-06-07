extends SceneTree

# Throwaway diagnostic + first seed of the 7c balance harness. Sweeps the star
# gap (playerStars - oppStars), runs N seeded simulate_match_teams per matchup
# against a fixed Tour, pools by rounded gap, and prints three CSV blocks:
#   #summary  gap,matches,wins,win_rate,win_sd,win_se
#   #scatter  gap,outcome            (a strided sample of raw matches, for dots)
#   #scores   gap,score_mean,score_sd  (Player innings total spread)
# win_sd = sqrt(p*(1-p)) (spread of a single win/loss outcome);
# win_se = win_sd / sqrt(matches) (uncertainty of the pooled win-rate estimate).
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/season_preview.gd
# (capture stdout; paste the rows into docs/mockups/star-winrate-v1.html)

const DOTS_PER_GAP := 40   # how many raw matches to sample per gap for the scatter

func _init() -> void:
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var tour := TourDistribution.new()
	tour.mean = 5
	tour.spread = 1.5   # matches the tuned default (flatter underdog drop-off)
	tour.noise = 1
	var player := Attributes.new()
	player.power = 5
	player.composure = 5
	player.attack = 5
	player.control = 5

	var stars := [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
	var n := 300
	var wins := {}        # gap -> player wins
	var total := {}       # gap -> matches played
	var score_sum := {}   # gap -> sum of Player innings totals
	var score_sqsum := {} # gap -> sum of squares
	var outcomes := {}    # gap -> Array of 0/1 (all, strided at print time)

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
				var won := 1 if r.outcome == MatchResult.Outcome.PLAYER_WIN else 0
				var pscore: int = r.innings1.total if r.player_bats_first else r.innings2.total
				total[gap] = total.get(gap, 0) + 1
				wins[gap] = wins.get(gap, 0) + won
				score_sum[gap] = score_sum.get(gap, 0.0) + pscore
				score_sqsum[gap] = score_sqsum.get(gap, 0.0) + float(pscore) * float(pscore)
				if not outcomes.has(gap):
					outcomes[gap] = []
				outcomes[gap].append(won)

	var keys := total.keys()
	keys.sort()

	print("#summary")
	print("gap,matches,wins,win_rate,win_sd,win_se")
	for k in keys:
		var w: int = wins.get(k, 0)
		var tot: int = total[k]
		var p := float(w) / float(tot)
		var sd := sqrt(p * (1.0 - p))
		var se := sd / sqrt(float(tot))
		print("%.1f,%d,%d,%.4f,%.4f,%.4f" % [k, tot, w, p, sd, se])

	# Strided real sample per gap, reported as ones/total so the chart can draw
	# that many win-dots and loss-dots (outcomes are exchangeable — order is moot).
	print("#scatter")
	print("gap,sample_ones,sample_total")
	for k in keys:
		var arr: Array = outcomes[k]
		var stride := maxi(1, arr.size() / DOTS_PER_GAP)
		var ones := 0
		var taken := 0
		var i := 0
		while i < arr.size():
			ones += int(arr[i])
			taken += 1
			i += stride
		print("%.1f,%d,%d" % [k, ones, taken])

	print("#scores")
	print("gap,score_mean,score_sd")
	for k in keys:
		var tot: int = total[k]
		var mean: float = score_sum[k] / float(tot)
		var variance: float = maxf(0.0, score_sqsum[k] / float(tot) - mean * mean)
		print("%.1f,%.1f,%.1f" % [k, mean, sqrt(variance)])

	quit()

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r
