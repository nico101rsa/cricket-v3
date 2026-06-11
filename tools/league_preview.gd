extends SceneTree

# Throwaway diagnostic: sweep the Player team's stars against a RANDOM 7-opponent
# field (re-drawn each Season from the 0.5..5.0 half-star set), run N seeded
# Seasons (league phase) per star, and print CSV:
#   player_stars,seasons,made_playoffs_rate,avg_finish
# A random field per Season avoids the threshold artefacts of a fixed field and
# answers the realistic question: "given my star rating, how often do I make the
# top 4 of a randomly-composed league?"
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/league_preview.gd

const STAR_SET := [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]

func _init() -> void:
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var tour := TourDistribution.new()
	tour.mean = 31.25
	tour.spread = 9.375
	tour.noise = 1
	var player := Attributes.new()
	player.power = 31.25
	player.composure = 31.25
	player.attack = 31.25
	player.control = 31.25

	var n := 150
	print("player_stars,seasons,made_playoffs_rate,avg_finish")
	for ps in STAR_SET:
		var qualified := 0
		var pos_sum := 0
		for sv in range(1, n + 1):
			var rng := _rng(sv + int(ps * 1000))
			var field: Array = []
			for k in range(7):
				field.append(_team(STAR_SET[rng.randi_range(0, STAR_SET.size() - 1)]))
			var r := LeagueResolver.simulate_league(player, _team(ps), field, tour, tuning, itun, rng)
			if r.made_playoffs:
				qualified += 1
			pos_sum += r.player_position
		print("%.1f,%d,%.4f,%.3f" % [ps, n, float(qualified) / float(n), float(pos_sum) / float(n)])
	quit()

func _team(stars: float) -> Team:
	var tm := Team.new()
	tm.stars = stars
	return tm

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r
