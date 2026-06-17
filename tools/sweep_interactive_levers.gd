extends SceneTree

# Interactive-lever balance oracle (spec 2026-06-17-interactive-lever-balance-design.md).
# Measures the PER-MATCH win-rate on the exact matchup Nico plays interactively —
# Club slot-0 (1.5★) reference build vs the seven club opponents (2.0–4.5★), default
# tour Club "Flat & Warm" — through the REAL MatchSession controller, decomposed by
# the three player-only levers (Boost / DRS / Key Moments). The opponent holds none
# of them (faithful: MatchSession._resim passes null opp boost/DRS/intent).
#
# Also prints: (1) the single deterministic BOOT_SEED first-fixture result, to
# reconcile Nico's "always winning the same game" anecdote with the win-rate; and
# (2) a card-growth row (★3 team + strong build) to confirm the card matters.
#
# Quick smoke: ILB_QUICK=1 (~seconds). Full run ~1–3 min, fine in-process.
# /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_interactive_levers.gd

const FULL_N := 600
const QUICK_N := 30

# The actual Club star ladder (CareerResolver.STAR_LADDER). Player starts slot 0.
const PLAYER_STARS := 1.5
const OPP_STARS := [2.0, 2.5, 3.0, 3.0, 3.5, 4.0, 4.5]

const DEF := BallResolver.Intent.DEFENSIVE
const BAL := BallResolver.Intent.BALANCED
const AGG := BallResolver.Intent.AGGRESSIVE


func _init() -> void:
	var quick := OS.get_environment("ILB_QUICK") == "1"
	var n := QUICK_N if quick else FULL_N
	if quick:
		print("[quick mode]")
	var t0 := Time.get_ticks_msec()
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var ref_build := _build(35.0, 30.0, 30.0, 30.0)
	var tour := DifficultyLadder.spec_for(0, 0).make_tour()

	# Lever-decomposition arms (spec D5).
	var arms := [
		{"name": "base",      "boost": false, "drs": false, "km": []},
		{"name": "+boost",    "boost": true,  "drs": false, "km": []},
		{"name": "+drs",      "boost": false, "drs": true,  "km": []},
		{"name": "+km_aggr",  "boost": false, "drs": false, "km": [[7, AGG], [16, AGG]]},
		{"name": "+km_def",   "boost": false, "drs": false, "km": [[7, DEF], [16, BAL]]},
		{"name": "all_aggr",  "boost": true,  "drs": true,  "km": [[7, AGG], [16, AGG]]},
		{"name": "all_def",   "boost": true,  "drs": true,  "km": [[7, DEF], [16, BAL]]},
	]

	print("\n== interactive lever balance — Club slot-0 (1.5★) ref build vs 2.0–4.5★ ==")
	print("   N=%d seasons × 7 fixtures = %d matches per arm\n" % [n, n * 7])
	print("arm          win%    n      (wins/matches)")
	var rows: Array = []
	for arm in arms:
		var r := _run_arm(arm, ref_build, tour, n, tuning, itun)
		rows.append(r)
		print("%-11s %5.1f  %5d   (%d/%d)" % [
			arm["name"], 100.0 * r["win"], r["matches"], r["wins"], r["matches"]])

	var ceiling: float = maxf(_row(rows, "all_aggr"), _row(rows, "all_def"))
	print("\nrealistic player ceiling = max(all_aggr, all_def) = %.1f%%" % (100.0 * ceiling))

	# (D6) Reconcile the anecdote: the one frozen BOOT_SEED first fixture.
	print("\n== the frozen game Nico replays (BOOT_SEED, fixture 0: 1.5★ vs 2.0★) ==")
	var boot_seed := 20260615 + 100 + 0
	var det_base := _one(ref_build, PLAYER_STARS, OPP_STARS[0], tour, boot_seed, tuning, itun,
		{"boost": false, "drs": false, "km": []})
	var det_all := _one(ref_build, PLAYER_STARS, OPP_STARS[0], tour, boot_seed, tuning, itun,
		{"boost": true, "drs": true, "km": [[7, AGG], [16, AGG]]})
	print("  base (no levers): %s" % det_base["text"])
	print("  all levers      : %s" % det_all["text"])

	# (D7) Card-growth check: ★3 team + strong 50/50 build.
	print("\n== card-growth check (★3 team, strong 50/50/30/30 build) ==")
	var strong := _build(50.0, 50.0, 30.0, 30.0)
	var grow: Array = []
	for arm in [{"name": "base", "boost": false, "drs": false, "km": []},
			{"name": "all_aggr", "boost": true, "drs": true, "km": [[7, AGG], [16, AGG]]}]:
		var r := _run_arm_at(arm, strong, 3.0, tour, n, tuning, itun)
		grow.append({"name": arm["name"], "win": r["win"], "matches": r["matches"], "wins": r["wins"]})
		print("%-11s %5.1f  (%d/%d)" % [arm["name"], 100.0 * r["win"], r["wins"], r["matches"]])

	print("\nelapsed %.1f min" % ((Time.get_ticks_msec() - t0) / 60000.0))
	print("DATA = " + JSON.stringify({
		"n": n, "arms": rows, "ceiling": ceiling,
		"deterministic": {"base": det_base["text"], "all": det_all["text"]},
		"growth": grow,
	}))
	quit()


# Run one arm at the default start (player 1.5★) across all 7 club opponents × n seeds.
func _run_arm(arm: Dictionary, build: Attributes, tour: TourDistribution,
		n: int, tuning: BallTuning, itun: InningsTuning) -> Dictionary:
	return _run_arm_at(arm, build, PLAYER_STARS, tour, n, tuning, itun)


# Same, parametrised on the player team's stars (D7 reuses it at ★3).
func _run_arm_at(arm: Dictionary, build: Attributes, player_stars: float,
		tour: TourDistribution, n: int, tuning: BallTuning, itun: InningsTuning) -> Dictionary:
	var wins := 0
	var matches := 0
	for i in range(n):
		for j in range(OPP_STARS.size()):
			# Paired seed: identical for the same (i,j) across every arm, so arm
			# deltas aren't RNG noise (mirrors Sweep's paired-seed contract).
			var seed := 700000 + i * 977 + j
			var o := _one(build, player_stars, OPP_STARS[j], tour, seed, tuning, itun, arm)
			matches += 1
			if o["win"]:
				wins += 1
	return {"name": arm["name"], "win": float(wins) / float(matches),
		"wins": wins, "matches": matches}


# One interactive match through the real MatchSession, with the arm's levers applied.
func _one(build: Attributes, player_stars: float, opp_stars: float, tour: TourDistribution,
		seed: int, tuning: BallTuning, itun: InningsTuning, arm: Dictionary) -> Dictionary:
	var pt := Team.new(); pt.stars = player_stars
	var ot := Team.new(); ot.stars = opp_stars
	var s := MatchSession.start(build, pt, ot, tour, seed, -1, tuning, itun)
	_apply(s, arm)
	var res := s.result()
	return {"win": res.player_won(), "tie": res.is_tie(),
		"text": "%s, %s" % [_outcome_word(res), res.margin_text()]}


# Drive the levers through MatchSession's public API in an engaged-player order:
# Boost (death overs) → Key Moments → DRS (review the first 2 dismissals that remain
# after the re-sims). Each decide_* re-sims the whole match.
func _apply(s: MatchSession, arm: Dictionary) -> void:
	var inn := 1 if s.result().player_bats_first else 2
	if arm.get("boost", false):
		s.decide_boost(inn, 16)
		s.decide_boost(inn, 18)
	for km in arm.get("km", []):
		s.decide_key_moment(km[0], km[1])
	if arm.get("drs", false):
		var res := s.result()
		var log: Array = res.ball_log_innings1 if res.player_bats_first else res.ball_log_innings2
		var done := 0
		for b in log:
			if done >= 2:
				break
			if b.get("wicket", false):
				s.decide_review([b["over"], b["ball_in_over"]])
				done += 1


func _build(p: float, c: float, a: float, ctrl: float) -> Attributes:
	var at := Attributes.new()
	at.power = p; at.composure = c; at.attack = a; at.control = ctrl
	return at


func _outcome_word(res: MatchResult) -> String:
	if res.is_tie():
		return "TIE"
	return "PLAYER WIN" if res.player_won() else "OPPONENT WIN"


func _row(rows: Array, name: String) -> float:
	for r in rows:
		if r["name"] == name:
			return r["win"]
	return 0.0
