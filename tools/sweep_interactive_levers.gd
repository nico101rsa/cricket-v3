extends SceneTree

# Interactive-lever balance oracle (spec 2026-06-17-interactive-lever-balance-design.md
# + the 2026-06-18 opponent-brain rung). Measures the PER-MATCH win-rate on the exact
# matchup Nico plays interactively — Club slot-0 (1.5★) reference build vs the seven
# club opponents (2.0–4.5★), default tour Club "Flat & Warm" — through the REAL
# MatchSession controller, decomposed by the three player-only levers.
#
# NEW (opponent brain): the interactive AI used to play a brainless all-BALANCED
# default (no Boost, no DRS, no hunt/milk). MatchSession now takes a difficulty
# `opp_spec` and the opponent bats to an OpponentBrain plan. This oracle measures the
# win-rate across opponent brain tiers (matchup held fixed → isolates the brain), so we
# can see whether an adaptive opponent stops "just go aggro" from coasting to ~50%.
#
# Quick smoke: ILB_QUICK=1 (~seconds). Full run ~5 min, fine in-process.
# /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_interactive_levers.gd

const FULL_N := 400
const QUICK_N := 30

# The actual Club star ladder (CareerResolver.STAR_LADDER). Player starts slot 0.
const PLAYER_STARS := 1.5
const OPP_STARS := [2.0, 2.5, 3.0, 3.0, 3.5, 4.0, 4.5]

const DEF := BallResolver.Intent.DEFENSIVE
const BAL := BallResolver.Intent.BALANCED
const AGG := BallResolver.Intent.AGGRESSIVE

const BASE_ARM := {"name": "base", "boost": false, "drs": false, "km": []}
const ALL_AGGR_ARM := {"name": "all_aggr", "boost": true, "drs": true, "km": [[7, AGG], [16, AGG]]}


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
	# What SHIPS: SeasonPlay floors the marquee opponent at competent textbook, so the
	# Club entry tour's raw TEXTBOOK-p0.4 (60% random) plays as full textbook in-game.
	var entry_spec := SeasonPlay._floored_spec(DifficultyLadder.spec_for(0, 0))

	# ---- 1. Opponent-brain sweep (the headline of this rung). Matchup held fixed
	# (1.5★ ref build vs the club field); only the opponent's brain tier varies, so the
	# delta is purely "how much the AI's tactics contest you". `base` = no levers,
	# `all_aggr` = the realistic ceiling (Boost+DRS+aggressive Key Moments).
	var tiers := [
		{"name": "off (null)",       "spec": null},
		{"name": "textbook p0.4*",   "spec": _tier(TourSpec.Tier.TEXTBOOK, 0.4)},  # *the actual Club entry tour
		{"name": "textbook",         "spec": _tier(TourSpec.Tier.TEXTBOOK, 1.0)},
		{"name": "static_eq B/A/B",  "spec": _tier(TourSpec.Tier.STATIC_EQ, 1.0)},
		{"name": "adaptive (hunt/milk)", "spec": _tier(TourSpec.Tier.ADAPTIVE, 1.0)},
	]
	print("\n== opponent-brain sweep — 1.5★ ref build vs club field, N=%d×7=%d matches/cell ==" % [n, n * 7])
	print("opp brain            base    all_aggr   (aggro lift)")
	var brain_rows: Array = []
	for t in tiers:
		var rb := _run_arm_at(BASE_ARM, ref_build, PLAYER_STARS, tour, t["spec"], n, tuning, itun)
		var ra := _run_arm_at(ALL_AGGR_ARM, ref_build, PLAYER_STARS, tour, t["spec"], n, tuning, itun)
		brain_rows.append({"name": t["name"], "base": rb["win"], "all_aggr": ra["win"]})
		print("%-20s %5.1f   %5.1f      (+%4.1f)" % [
			t["name"], 100.0 * rb["win"], 100.0 * ra["win"], 100.0 * (ra["win"] - rb["win"])])

	# ---- 2. Full lever decomposition at the ACTUAL Club entry tour (TEXTBOOK p0.4).
	var arms := [
		BASE_ARM,
		{"name": "+boost",    "boost": true,  "drs": false, "km": []},
		{"name": "+drs",      "boost": false, "drs": true,  "km": []},
		{"name": "+km_aggr",  "boost": false, "drs": false, "km": [[7, AGG], [16, AGG]]},
		{"name": "+km_def",   "boost": false, "drs": false, "km": [[7, DEF], [16, BAL]]},
		ALL_AGGR_ARM,
		{"name": "all_def",   "boost": true,  "drs": true,  "km": [[7, DEF], [16, BAL]]},
	]
	print("\n== lever decomposition @ Club entry tour AS SHIPPED (floored to textbook) ==")
	print("arm          win%    (wins/matches)")
	var rows: Array = []
	for arm in arms:
		var r := _run_arm_at(arm, ref_build, PLAYER_STARS, tour, entry_spec, n, tuning, itun)
		rows.append({"name": arm["name"], "win": r["win"], "matches": r["matches"], "wins": r["wins"]})
		print("%-11s %5.1f   (%d/%d)" % [arm["name"], 100.0 * r["win"], r["wins"], r["matches"]])
	var ceiling: float = maxf(_row(rows, "all_aggr"), _row(rows, "all_def"))

	# ---- 3. Reconcile the anecdote: the frozen BOOT_SEED first fixture (brain on now).
	print("\n== the frozen game Nico replays (BOOT_SEED, fixture 0: 1.5★ vs 2.0★, entry brain) ==")
	var boot_seed := 20260615 + 100 + 0
	var det_base := _one(ref_build, PLAYER_STARS, OPP_STARS[0], tour, entry_spec, boot_seed, tuning, itun, BASE_ARM)
	var det_all := _one(ref_build, PLAYER_STARS, OPP_STARS[0], tour, entry_spec, boot_seed, tuning, itun, ALL_AGGR_ARM)
	print("  base (no levers): %s" % det_base["text"])
	print("  all levers      : %s" % det_all["text"])

	# ---- 4. Card-growth check: ★3 team + strong build, at the entry brain.
	print("\n== card-growth check (★3 team, strong 50/50/30/30 build, entry brain) ==")
	var strong := _build(50.0, 50.0, 30.0, 30.0)
	var grow: Array = []
	for arm in [BASE_ARM, ALL_AGGR_ARM]:
		var r := _run_arm_at(arm, strong, 3.0, tour, entry_spec, n, tuning, itun)
		grow.append({"name": arm["name"], "win": r["win"], "matches": r["matches"], "wins": r["wins"]})
		print("%-11s %5.1f  (%d/%d)" % [arm["name"], 100.0 * r["win"], r["wins"], r["matches"]])

	print("\nelapsed %.1f min" % ((Time.get_ticks_msec() - t0) / 60000.0))
	print("DATA = " + JSON.stringify({
		"n": n, "brain_rows": brain_rows, "arms": rows, "ceiling": ceiling,
		"deterministic": {"base": det_base["text"], "all": det_all["text"]},
		"growth": grow,
	}))
	quit()


# A bare brain spec (tier + blend) — strength/opponents stay the caller's, so a brain
# sweep isolates tactics from team strength.
func _tier(tier: int, blend: float) -> TourSpec:
	var s := TourSpec.new()
	s.brain_tier = tier
	s.blend = blend
	return s


# Run one arm across all 7 club opponents × n seeds, at player team `player_stars`,
# against opponent brain `spec` (null = brainless default).
func _run_arm_at(arm: Dictionary, build: Attributes, player_stars: float,
		tour: TourDistribution, spec, n: int, tuning: BallTuning, itun: InningsTuning) -> Dictionary:
	var wins := 0
	var matches := 0
	for i in range(n):
		for j in range(OPP_STARS.size()):
			# Paired seed: identical for the same (i,j) across every arm AND brain tier,
			# so deltas aren't RNG noise (mirrors Sweep's paired-seed contract).
			var seed := 700000 + i * 977 + j
			var o := _one(build, player_stars, OPP_STARS[j], tour, spec, seed, tuning, itun, arm)
			matches += 1
			if o["win"]:
				wins += 1
	return {"name": arm["name"], "win": float(wins) / float(matches),
		"wins": wins, "matches": matches}


# One interactive match through the real MatchSession, with the arm's levers applied
# and the opponent playing brain `spec`.
func _one(build: Attributes, player_stars: float, opp_stars: float, tour: TourDistribution,
		spec, seed: int, tuning: BallTuning, itun: InningsTuning, arm: Dictionary) -> Dictionary:
	var pt := Team.new(); pt.stars = player_stars
	var ot := Team.new(); ot.stars = opp_stars
	var s := MatchSession.start(build, pt, ot, tour, seed, -1, tuning, itun, spec)
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
