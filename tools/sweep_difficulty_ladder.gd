extends SceneTree

# E3 oracle (spec 2026-06-12-difficulty-ladder-7cE3-design.md §3.5): the
# reference creation build (35/30/30/30, Team ★3) plays N Seasons at every
# Career-grid cell -> beat-rate + win-Final-rate per cell, plus a
# brain-isolation pair (same strength, naive vs adaptive) at mid-City.
# Quick smoke: E3_QUICK=1. Full run ~20-40 min: nohup-detach + a watcher that
# greps the LOG for the final DATA line (never pgrep the script name).
# /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_difficulty_ladder.gd

const FULL_N := 200
const QUICK_N := 20


func _init() -> void:
	var quick := OS.get_environment("E3_QUICK") == "1"
	var n := QUICK_N if quick else FULL_N
	if quick:
		print("[quick mode]")
	var t0 := Time.get_ticks_msec()
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()

	var cells: Array = []
	for spec in DifficultyLadder.all():
		var r := _run_cell(spec, n, tuning, itun, 0)
		cells.append(r)
		print("%-22s d=%4.1f tier=%d blend=%.1f  beat %5.1f%%  win-final %5.1f%%  game-win %5.1f%%" % [
			spec.cell_name, spec.d, spec.brain_tier, spec.blend,
			100.0 * r["beat"], 100.0 * r["won"], 100.0 * r["game_win"]])

	# Brain isolation: same strength (City Home winter), naive vs adaptive.
	print("\n== brain isolation (City Home winter strength) ==")
	var iso: Array = []
	for tier in [TourSpec.Tier.NAIVE, TourSpec.Tier.ADAPTIVE]:
		var spec := DifficultyLadder.spec_for(1, 2)
		spec.brain_tier = tier
		spec.blend = 1.0
		var r := _run_cell(spec, n, tuning, itun, 777)
		iso.append(r)
		print("tier %d: beat %5.1f%%  player-game win %5.1f%%" % [
			tier, 100.0 * r["beat"], 100.0 * r["game_win"]])

	print("\nelapsed %.1f min" % ((Time.get_ticks_msec() - t0) / 60000.0))
	print("DATA = " + JSON.stringify({"n": n, "cells": cells, "iso": iso}))
	quit()


func _run_cell(spec: TourSpec, n: int, tuning: BallTuning, itun: InningsTuning, seed_base: int) -> Dictionary:
	var beat := 0
	var won := 0
	var games := 0
	var game_wins := 0
	for k in range(n):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + seed_base + k
		var attrs := Attributes.new()
		attrs.power = 35.0
		attrs.composure = 30.0
		attrs.attack = 30.0
		attrs.control = 30.0
		var player_team := Team.new()
		player_team.stars = 3.0
		var opponents: Array = []
		for s in spec.opp_stars:
			var t := Team.new()
			t.stars = s
			opponents.append(t)
		var season := SeasonResolver.simulate_season(
			attrs, player_team, opponents, spec.make_tour(),
			tuning, itun, rng,
			IntentPlan.textbook(), BowlingPlan.textbook(), spec)
		if season.beat:
			beat += 1
		if season.won_final:
			won += 1
		for m in season.league.player_matches:
			games += 1
			if m.player_won():
				game_wins += 1
	return {
		"cell": spec.cell_name, "level": spec.level, "tour": spec.tour_index,
		"d": spec.d, "tier": spec.brain_tier, "blend": spec.blend,
		"beat": float(beat) / float(n), "won": float(won) / float(n),
		"game_win": float(game_wins) / float(games),
	}
