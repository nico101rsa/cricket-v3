extends SceneTree

# Joker on/off sweep for 7c-C/C2a: hold both teams even (★3) and the Player build
# balanced (5/5/5/5) so the jokers are the only lever. Arms = baseline (no jokers)
# + each implemented joker group individually + a batting stack + a field-defensive
# stack. Prints JSON of the player-runs distribution + win-rate per arm for
# docs/mockups/distribution-viewer-v1.html.
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_jokers.gd

var _tuning: BallTuning
var _itun: InningsTuning
var _tour: TourDistribution

func _init() -> void:
	_tuning = BallTuning.new()
	_itun = InningsTuning.new()
	_tour = TourDistribution.new()
	_tour.mean = 5
	_tour.spread = 1.5
	_tour.noise = 1

	var groups := JokerCatalog.implemented_groups()
	var batting_stack: Array = []
	var field_def_stack: Array = []
	var bowl_intent_ids := {"attack_the_stumps": true, "pressure_cooker": true, "choke_hold": true}
	var bowl_intent_stack: Array = []
	var form_ids := {"ride_the_wave": true, "hot_streak": true, "match_winners_vigil": true}
	var form_window_stack: Array = []
	var wicket_hunter_ids := {"pace_pack": true, "spinners_web": true,
		"first_change_specialist": true, "the_strike_bowler": true, "the_trap": true}
	var wicket_hunter_stack: Array = []
	var boost_stack: Array = []
	var reviewer_stack: Array = []
	# C2g — Form sources are enablers; pair them with the Form consumers (Ride the
	# Wave / Hot Streak) so the combo shows the synergy a solo source can't.
	var form_combo_ids := {"the_sheet_anchor": true, "captains_statement": true,
		"building_phase": true, "boundary_hunter": true,
		"ride_the_wave": true, "hot_streak": true}
	var form_combo: Array = []
	var full_pool: Array = []
	for g in groups:
		if bowl_intent_ids.has(g["id"]):
			bowl_intent_stack.append_array(g["effects"])
		if form_ids.has(g["id"]):
			form_window_stack.append_array(g["effects"])
		if wicket_hunter_ids.has(g["id"]):
			wicket_hunter_stack.append_array(g["effects"])
		if g["effects"][0].boost_role != JokerEffect.BoostRole.NONE:
			boost_stack.append_array(g["effects"])
		if g["effects"][0].drs_role != JokerEffect.DRSRole.NONE:
			reviewer_stack.append_array(g["effects"])
		if form_combo_ids.has(g["id"]):
			form_combo.append_array(g["effects"])
		full_pool.append_array(g["effects"])
		for e in g["effects"]:
			if e.side == JokerEffect.Side.BATTING and e.trigger == JokerEffect.Trigger.NONE:
				batting_stack.append(e)
			elif e.field_req == FieldPlan.Mode.DEFENSIVE:
				field_def_stack.append(e)

	var arms: Array = [{"name": "Baseline (no jokers)", "config": []}]
	for g in groups:
		arms.append({"name": g["jname"], "config": g["effects"]})
	arms.append({"name": "Batting stack", "config": batting_stack})
	arms.append({"name": "Field-defensive stack", "config": field_def_stack})
	arms.append({"name": "Bowling-intent stack", "config": bowl_intent_stack})
	arms.append({"name": "Form-window stack", "config": form_window_stack})
	arms.append({"name": "Wicket-Hunter stack", "config": wicket_hunter_stack})
	arms.append({"name": "Boost-stack stack", "config": boost_stack})
	arms.append({"name": "Reviewer stack", "config": reviewer_stack})
	arms.append({"name": "Form-source combo", "config": form_combo})
	arms.append({"name": "Full pool (all 45)", "config": full_pool})

	var n := 2000
	var swept := Sweep.run(arms, n, _scenario)

	var palette := ["#888888", "#5ac77a", "#4a90d9", "#f2b134", "#e0607e", "#9b59b6",
		"#1abc9c", "#e67e22", "#3498db", "#2ecc71", "#e74c3c", "#f39c12", "#16a085", "#c0392b"]
	var baseline_win := 0.0
	var baseline_margin := 0.0
	var arms_json: Array = []
	var ai := 0
	for arm in swept:
		var runs := Sweep.values_of(arm["records"], "player_runs")
		var wins := Sweep.values_of(arm["records"], "won")
		var margins := Sweep.values_of(arm["records"], "margin")
		var dist := Distribution.new(runs)
		var win_sum := 0
		for w in wins:
			win_sum += w
		var win_rate := float(win_sum) / runs.size()
		var margin_sum := 0.0
		for mg in margins:
			margin_sum += mg
		var mean_margin := margin_sum / margins.size()
		if ai == 0:
			baseline_win = win_rate
			baseline_margin = mean_margin
		var stride: int = maxi(1, runs.size() / 400)
		var sampled: Array = []
		var k := 0
		while k < runs.size():
			sampled.append(runs[k])
			k += stride
		arms_json.append({
			"name": arm["name"],
			"color": palette[ai % palette.size()],
			"values": sampled,
			"stats": dist.to_dict(),
			"win_rate": win_rate,
			"win_delta": win_rate - baseline_win,
			"mean_margin": mean_margin,
			"margin_delta": mean_margin - baseline_margin,
		})
		ai += 1

	print(JSON.stringify({"metric": "player_runs", "arms": arms_json}))
	quit()

# A fixed intent plan shared by every arm, chosen to exercise all three bands so
# the intent-gated jokers actually fire: AGGRESSIVE powerplay+death (Powerplay
# Punch, Slog Over Specialist) and DEFENSIVE middle (Dead Bat, Carry Your Bat).
func _intent_plan() -> IntentPlan:
	var p := IntentPlan.new()
	p.powerplay = BallResolver.Intent.AGGRESSIVE
	p.middle = BallResolver.Intent.DEFENSIVE
	p.death = BallResolver.Intent.AGGRESSIVE
	return p

# A fixed field plan shared by every arm (constant across arms -> win-delta is the
# joker's effect, not the field). Exercises both field modes: CATCHING powerplay+
# death (Cordon Killer fires) and DEFENSIVE middle (Tight Lines, Dot Ball Pressure).
func _field_plan() -> FieldPlan:
	var f := FieldPlan.new()
	f.powerplay = FieldPlan.Mode.CATCHING
	f.middle = FieldPlan.Mode.DEFENSIVE
	f.death = FieldPlan.Mode.CATCHING
	return f

# C2b — the Player's bowling-captain intent, shared across arms. AGGRESSIVE
# powerplay+death (Attack the Stumps fires) and DEFENSIVE middle (which, with the
# DEFENSIVE field in _field_plan's middle, fires Choke Hold).
func _bowl_intent_plan() -> IntentPlan:
	var p := IntentPlan.new()
	p.powerplay = BallResolver.Intent.AGGRESSIVE
	p.middle = BallResolver.Intent.DEFENSIVE
	p.death = BallResolver.Intent.AGGRESSIVE
	return p

# C2b — the opposition's AI batting intent, shared across arms. DEFENSIVE middle
# (Pressure Cooker fires), BALANCED elsewhere. Held constant so the win-delta is
# the joker, not the opposition's tempo.
func _opp_intent_plan() -> IntentPlan:
	var p := IntentPlan.new()
	p.powerplay = BallResolver.Intent.BALANCED
	p.middle = BallResolver.Intent.DEFENSIVE
	p.death = BallResolver.Intent.BALANCED
	return p

# C2d — the Player's bowling plan, shared across arms. PACE powerplay, SPIN middle
# + death. With _field_plan (CATCHING/DEFENSIVE/CATCHING), setNextBowler fires at
# overs 1 (pace, catching), 7 (spin, defensive), 16 (spin, catching) -> Pace Pack,
# Spinner's Web, First-Change, Strike Bowler all fire; the death spin+catching
# phase fires The Trap. Turning on rotation also enables per-over pace/spin tilt.
func _bowling_plan() -> BowlingPlan:
	var p := BowlingPlan.new()
	p.powerplay = BowlingPlan.Kind.PACE
	p.middle = BowlingPlan.Kind.SPIN
	p.death = BowlingPlan.Kind.SPIN
	return p

# C2e — the Manager Boost presses, shared across arms (so the base Boost is in
# every arm; the Boost-stack jokers' win-delta is the modifier). Three presses
# (overs 1, 10, 16) so The Comeback Press's 3rd-press payoff can fire.
func _boost_plan() -> BoostPlan:
	return BoostPlan.at([1, 10, 16])

# C2f — the DRS policy, shared across arms (so the base review-to-survive is in
# every arm; the Reviewer jokers' win-delta is the modifier).
func _drs_policy() -> DRSPolicy:
	return DRSPolicy.new()

# C2h — the opposition's field during the Player's batting innings (for #9 Field
# Restrictions). Catching in the powerplay/death (mirror of _field_plan).
func _opp_field_plan() -> FieldPlan:
	var f := FieldPlan.new()
	f.powerplay = FieldPlan.Mode.CATCHING
	f.middle = FieldPlan.Mode.NEUTRAL
	f.death = FieldPlan.Mode.CATCHING
	return f

# DF1/DF4/DF5 — the opponent runs the same base game-plan: same intent (below, via
# _intent_plan), and its own base captain tools (boost + DRS), minus jokers, so the
# no-joker baseline is a fair fight.
func _opp_boost_plan() -> BoostPlan:
	return BoostPlan.at([1, 10, 16])

func _opp_drs_policy() -> DRSPolicy:
	return DRSPolicy.new()

func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	# DF1 — the opponent bats with the same intent plan as the Player (symmetric tempo).
	var m := MatchResolver.simulate_match_teams(a, pt, ot, _tour, _tuning, _itun, rng, _intent_plan(), _bowling_plan(), config, _field_plan(), _bowl_intent_plan(), _intent_plan(), _boost_plan(), _drs_policy(), _opp_field_plan(), _opp_boost_plan(), _opp_drs_policy())
	var p_inn := m.innings1 if not m.innings1.player_line().is_empty() else m.innings2
	var o_inn := m.innings2 if p_inn == m.innings1 else m.innings1
	var line := p_inn.player_line()
	var player_runs := int(line.get("runs", 0))
	var won := 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0
	var margin := p_inn.total - o_inn.total   # DM2 — Player team total minus opponent total
	return {"player_runs": player_runs, "won": won, "margin": margin}
