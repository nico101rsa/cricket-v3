class_name LeagueResolver
extends RefCounted

# Resolves a Season's league phase: an 8-team single round-robin, every game
# simulated, into a points+NRR table. See spec
# 2026-06-07-season-league-7b2a-design.md and ADR 0002/0004/0009. No member state.

const NUM_TEAMS := 8
const PLAYOFF_CUTOFF := 4

# Every unique unordered pair (i, j) with i < j. 8 teams -> 28 fixtures.
static func round_robin(num_teams: int) -> Array:
	var fixtures: Array = []
	for i in range(num_teams):
		for j in range(i + 1, num_teams):
			fixtures.append(Vector2i(i, j))
	return fixtures
