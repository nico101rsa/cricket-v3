extends GutTest

func test_round_robin_count_and_coverage() -> void:
	var fixtures := LeagueResolver.round_robin(8)
	assert_eq(fixtures.size(), 28, "8 teams single round-robin -> 28 fixtures")
	# No self-pairs; no duplicates; each team appears in exactly 7.
	var seen := {}
	var appearances := {}
	for fx in fixtures:
		assert_lt(fx.x, fx.y, "pairs are ordered i < j (no self-pairs)")
		var key := "%d-%d" % [fx.x, fx.y]
		assert_false(seen.has(key), "no duplicate fixture %s" % key)
		seen[key] = true
		appearances[fx.x] = appearances.get(fx.x, 0) + 1
		appearances[fx.y] = appearances.get(fx.y, 0) + 1
	for team in range(8):
		assert_eq(appearances.get(team, 0), 7, "team %d plays 7 games" % team)
