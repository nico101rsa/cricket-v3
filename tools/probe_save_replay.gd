extends SceneTree

# Save-replay diagnostic (born as playtest T1, kept for future triage): loads the
# REAL user:// save read-only, replays the live season, prints per-match lines, and
# benchmarks the next fixture's cell (N=300). Run headless with the game closed:
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/probe_save_replay.gd

func _initialize() -> void:
	var player: Player = load("user://player.tres")
	var career: CareerState = load("user://career.tres")
	var state: LiveSeasonState = load("user://live_season.tres")
	if player == null or career == null or state == null:
		print("DATA save missing"); quit(); return
	print("DATA save: level=", state.level, " tour=", state.tour_index, " seed=", state.seed,
		" matches_played=", state.decisions.size(), " form_pts=", player.form_points)
	var my_team: Team = career.teams[career.current_team_index]
	print("DATA my team '", my_team.team_name, "' stars=", my_team.stars)
	var opps := career.opponents_of_current()
	for i in range(mini(3, opps.size())):
		print("DATA opp ", i + 1, " '", (opps[i] as Team).team_name, "' stars=", (opps[i] as Team).stars)

	var sp := SeasonPlay.from_state(state, player, career)
	var n_res: int = sp._player_results.size()
	print("DATA replayed results: ", n_res)
	for i in range(n_res):
		var m: MatchResult = sp._player_results[i]
		var opp_inn: InningsResult = m.innings1 if not m.player_bats_first else m.innings2
		var my_inn: InningsResult = m.innings1 if m.player_bats_first else m.innings2
		print("DATA match ", i + 1, ": my ", my_inn.total, "/", my_inn.wickets, " (", my_inn.balls,
			"b)  opp ", opp_inn.total, "/", opp_inn.wickets, " (", opp_inn.balls,
			"b)  player_bowl ", opp_inn.player_bowl_wickets, "/", opp_inn.player_bowl_runs,
			" in ", opp_inn.player_bowl_balls, "b  won=", m.player_won())

	# Benchmark the match-2 fixture: same teams/tour/spec, no player decisions, vary seed.
	var spec := DifficultyLadder.spec_for(state.level, state.tour_index)
	var tour := spec.make_tour()
	var opp2: Team = opps[1]
	var n := 300
	var low_total := 0
	var many_wkts := 0
	var both := 0
	var sum_t := 0.0
	var sum_w := 0.0
	for k in n:
		var s := MatchSession.start(player.attributes, my_team, opp2, tour,
			state.seed + 100 + 1 + (k + 1) * 7919, -1, null, null, spec, [])
		var m := s.result()
		var oi: InningsResult = m.innings1 if not m.player_bats_first else m.innings2
		sum_t += oi.total; sum_w += oi.wickets
		if oi.total <= 45: low_total += 1
		if oi.wickets >= 9: many_wkts += 1
		if oi.total <= 45 and oi.wickets >= 9: both += 1
	print("DATA cell benchmark (N=", n, ", opp='", opp2.team_name, "' stars=", opp2.stars,
		"): opp innings mean ", "%.1f" % (sum_t / n), "/", "%.1f" % (sum_w / n),
		"  P(total<=45)=", "%.1f" % (100.0 * low_total / n), "%",
		"  P(wkts>=9)=", "%.1f" % (100.0 * many_wkts / n), "%",
		"  P(both)=", "%.1f" % (100.0 * both / n), "%")
	print("DATA done")
	quit()
