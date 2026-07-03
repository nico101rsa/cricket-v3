class_name InningsResolver
extends RefCounted

# Pure resolution of one T20 innings by looping BallResolver.resolve_ball().
# See spec 2026-06-07-innings-sim-design.md and ADR 0004. No member state.

# Build -> batting position (1..9). Higher batting share bats higher up.
static func player_position(attrs: Attributes, itun: InningsTuning) -> int:
	var batting := attrs.power + attrs.composure
	var bowling := attrs.attack + attrs.control
	var share := float(batting) / float(batting + bowling)
	# Competence-gate (fresh-build-equality): weak fresh players don't get promoted
	# into high-leverage slots they can't yet handle; they climb the order as the
	# build levels up. At/above pos_ref_batting this is the original share formula.
	var competence := clampf(float(batting) / itun.pos_ref_batting, 0.0, 1.0)
	var pos := roundi(itun.pos_base - itun.pos_span * share * competence)
	return clampi(pos, 1, 9)

# Weakening-tail scale for a partner at 1-based order position `pos`.
static func partner_factor(pos: int, itun: InningsTuning) -> float:
	return maxf(itun.tail_floor, 1.0 - (pos - 1) * itun.tail_slope)

# Build -> bowling overs (0..bowl_max_overs). Mirror of player_position: the same
# batting/bowling share that pushes a bowler-build down the order also gives them
# more overs. Strawman curve in InningsTuning; harness-tunable.
static func player_overs(attrs: Attributes, itun: InningsTuning) -> int:
	var batting := attrs.power + attrs.composure
	var bowling := attrs.attack + attrs.control
	var share := float(bowling) / float(batting + bowling)
	var overs := roundi(itun.bowl_overs_gain * share + itun.bowl_overs_base)
	return clampi(overs, 0, itun.bowl_max_overs)

# The set of 1-based overs the Player bowls: n overs spaced as evenly as possible
# across total_overs. Returns [] for n <= 0.
static func player_bowling_overs(n: int, total_overs: int) -> Array[int]:
	var overs: Array[int] = []
	for i in range(n):
		overs.append(clampi(roundi((i + 0.5) * float(total_overs) / float(n)), 1, total_overs))
	return overs

# A kind's phase effectiveness bonus for a 1-based over (BB1). Pure.
static func phase_bonus(kind: int, over: int, itun: InningsTuning) -> float:
	var ph := IntentPlan.phase_of(over)
	return itun.pace_phase_bonus[ph] if kind == BowlingPlan.Kind.PACE else itun.spin_phase_bonus[ph]

# The over's effective bowling profile: kind profile + that kind's phase bonus
# on both stats (BB1), floored at 1.0. Pure; unit-tested directly.
static func phased_profile(attack: BowlingAttack, kind: int, over: int, itun: InningsTuning) -> Vector2:
	var prof := attack.profile(kind)
	var bonus := phase_bonus(kind, over, itun)
	return Vector2(maxf(0.5, prof.x + bonus), maxf(0.5, prof.y + bonus))

# Build the 11-strong batting order. With a statted Player (player_attrs != null),
# the Player bats at their build-driven position; every other slot is a derived
# partner scaled by the tail curve. With player_attrs == null (opposition innings),
# all 11 are derived.
static func _build_batters(player_attrs: Attributes, partner_batting: float, itun: InningsTuning,
		roster: Array = [], team_factor: float = 1.0) -> Array:
	var batters: Array = []
	# Roster path (Slice 2 + card-rescale DR5): each slot reads its real Attributes;
	# the Player slot is found by reference identity. A uniform team_factor scales
	# power/composure PROPORTIONALLY (replacing the legacy additive offset + floor-1,
	# which floored every bad team into the same texture-dead card) so a weak league
	# is a scaled-down version of the card shape — fractional values, no floor-out
	# (0.5 is a safety floor only). The synthetic tail curve stays dropped (the
	# archetype order already provides the tail). See spec §8.5 + card-rescale DR5/DR8.
	if not roster.is_empty():
		for order in range(1, 12):  # positions 1..11
			var m: Attributes = roster[order - 1]
			batters.append({
				"position": order,
				"is_player": player_attrs != null and m == player_attrs,
				"power": maxf(0.5, m.power * team_factor),
				"composure": maxf(0.5, m.composure * team_factor),
				"runs": 0, "balls": 0, "out": false,
			})
		return batters
	# Clone path (unchanged): Player at their build-driven position; everyone else a
	# clone of partner_batting scaled by the weakening-tail curve.
	var ppos := -1
	if player_attrs != null:
		ppos = player_position(player_attrs, itun)
	for order in range(1, 12):  # positions 1..11
		if order == ppos:
			batters.append({
				"position": order, "is_player": true,
				"power": player_attrs.power, "composure": player_attrs.composure,
				"runs": 0, "balls": 0, "out": false,
			})
		else:
			var p := maxf(0.5, partner_batting * partner_factor(order, itun))
			batters.append({
				"position": order, "is_player": false,
				"power": p, "composure": p,
				"runs": 0, "balls": 0, "out": false,
			})
	return batters

# Simulate one innings. Deterministic given rng (resolve_ball owns the draw order).
# player_attrs may be null (opposition innings -> all derived). target > 0 adds a
# chase stop: the innings ends the instant total >= target. target == 0 = no chase.
static func simulate_innings(
		player_attrs: Attributes,
		partner_batting: float,
		opp_attack: float,
		opp_control: float,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator,
		target: int = 0,
		intent_plan: IntentPlan = null,
		bowling_attack: BowlingAttack = null,
		bowling_plan: BowlingPlan = null,
		player_bowler_attack: float = 0.0,
		player_bowler_control: float = 0.0,
		player_bowler_overs: int = 0,
		jokers: Array = [],
		player_is_batting: bool = true,
		field_plan: FieldPlan = null,
		bowl_intent_plan: IntentPlan = null,
		boost_plan: BoostPlan = null,
		drs_policy: DRSPolicy = null,
		opp_field_plan: FieldPlan = null,
		batting_roster: Array = [],
		team_bat_factor: float = 1.0,
		opp_boost_plan: BoostPlan = null,
		opp_drs_policy: DRSPolicy = null,
		ball_log = null,
		form_state: FormState = null
) -> InningsResult:
	var batters := _build_batters(player_attrs, partner_batting, itun, batting_roster, team_bat_factor)
	var max_balls := itun.over_limit * 6
	var striker := 0
	var nonstriker := 1
	var next_in := 2
	var wickets := 0
	var balls := 0
	var total := 0
	var fall: Array = []
	var phase_runs: Array = [0, 0, 0]  # BB11 — runs per [PP, middle, death]
	var player_overs_set: Array[int] = []
	if player_bowler_overs > 0:
		player_overs_set = player_bowling_overs(player_bowler_overs, itun.over_limit)
	var pb_wickets := 0  # Player-as-bowler figures for this innings
	var pb_runs := 0
	var pb_balls := 0
	var runtime := JokerRuntime.new()  # C2c — per-innings windowed-buff state
	if drs_policy != null:
		runtime.init_reviews(jokers, drs_policy.base_reviews)  # C2f — DRS resource
	var opp_is_batting := not player_is_batting   # DF2 — the opponent's perspective
	var opp_runtime := JokerRuntime.new()         # DF2 — opponent base captain tools (no jokers)
	if opp_drs_policy != null:
		opp_runtime.init_reviews([], opp_drs_policy.base_reviews)
	var prev_intent := -1       # C2g — for intent-switch Form sources
	var def_streak := 0          # C2g — consecutive Player Defensive balls (Building Phase)
	var intent_override := -1    # C2g — Boundary Hunter snaps intent to Aggressive
	var is_chase := target > 0   # C2h — the chasing innings carries a target (Chase Master)

	while balls < max_balls and wickets < 10 and (target == 0 or total < target):
		var s: Dictionary = batters[striker]
		var over := balls / 6 + 1  # 1-based over of the ball about to be bowled
		var intent := BallResolver.Intent.BALANCED
		if intent_plan != null:
			# E2: batting intent reads the match state (req-RR chase pressure +
			# collapse protection). Static plans (rules off) are byte-identical.
			intent = intent_plan.for_state(over, total, wickets, balls, target, max_balls)
		if intent_override != -1:
			intent = intent_override  # C2g — Boundary Hunter latch
		# C2g — intent-switch Form source at over start (Player batting only).
		if player_is_batting and balls == (over - 1) * 6:
			if intent != prev_intent:
				if intent == BallResolver.Intent.BALANCED:
					runtime.fire_form_source(jokers, true, JokerEffect.FormSource.ON_BALANCED, balls + 1)
				elif intent == BallResolver.Intent.AGGRESSIVE:
					runtime.fire_form_source(jokers, true, JokerEffect.FormSource.ON_AGGRESSIVE, balls + 1)
			prev_intent = intent
		var bat_attack := opp_attack
		var bat_control := opp_control
		var bowler_type := -1  # current over's BowlingPlan.Kind (C2d/BB3); -1 = no rotation
		if bowling_plan != null:
			bowler_type = bowling_plan.for_over(over)
		if bowling_attack != null and bowling_plan != null:
			var prof := phased_profile(bowling_attack, bowler_type, over, itun)
			bat_attack = prof.x
			bat_control = prof.y
		var player_bowling := player_bowler_overs > 0 and player_overs_set.has(over)
		if player_bowling:
			bat_attack = player_bowler_attack
			bat_control = player_bowler_control
			# BB4 (reversed 2026-06-11): the hero bowls WITHIN the rotation — their
			# overs inherit the plan kind's phase bonus, or the team pays a hidden
			# ~3.5-run/match tax on bowling-capable builds (measured, spec §10).
			# The Player's own pace/spin identity stays deferred (D4).
			if bowling_plan != null:
				var pb := phase_bonus(bowler_type, over, itun)
				bat_attack = maxf(0.5, bat_attack + pb)
				bat_control = maxf(0.5, bat_control + pb)
		var field_mode := FieldPlan.Mode.NEUTRAL
		if field_plan != null:
			field_mode = field_plan.for_over(over)
		# C2h — while batting, the readable field is the OPPOSITION's (for #9 Field
		# Restrictions). While bowling, it stays the Player's field_plan (above).
		if player_is_batting and opp_field_plan != null:
			field_mode = opp_field_plan.for_over(over)
		var bowl_intent := -1  # the bowling captain's intent (C2b); -1 = none set
		if bowl_intent_plan != null:
			bowl_intent = bowl_intent_plan.for_over(over)
		# C2d — a setNextBowler event fires at each spell start (overs 1/7/16) while
		# the Player captains the bowling (opposition batting innings), pushing buffs
		# that apply from this over onward (so before tick_mults below).
		if bowling_plan != null and not player_is_batting and balls == (over - 1) * 6 and (over == 1 or over == 7 or over == 16):
			runtime.on_bowling_change(jokers, bowler_type, field_mode)
		# C2e — a Manager Boost press at this over's start fires a side-aware buff.
		var boost_pressed_now := false
		if boost_plan != null and balls == (over - 1) * 6 and boost_plan.presses_on(over):
			runtime.on_boost_press(jokers, player_is_batting, intent, boost_plan.base_mult, boost_plan.base_n, balls + 1)
			boost_pressed_now = true
		# DF4 — the opponent presses its own Boost (base buff, no jokers), side-aware.
		if opp_boost_plan != null and balls == (over - 1) * 6 and opp_boost_plan.presses_on(over):
			opp_runtime.on_boost_press([], opp_is_batting, intent, opp_boost_plan.base_mult, opp_boost_plan.base_n, balls + 1)
		var jm := JokerResolver.roll_mults(jokers, player_is_batting, intent, balls + 1, field_mode, bowl_intent, bowler_type, is_chase)
		var win := runtime.tick_mults(player_is_batting)  # C2c — active windowed buffs
		var opp_win := opp_runtime.tick_mults(opp_is_batting)  # DF2 — opponent base buffs
		# DF2/DF5 -- the Player's effective attributes carry Form x Affinity. Player-only:
		# teammates and opponents roll at their plain strengths (DF8).
		var bat_fmult := 1.0
		var bowl_fmult := 1.0
		if form_state != null:
			if player_is_batting and s["is_player"]:
				bat_fmult = form_state.mult()
			elif player_bowling:
				bowl_fmult = form_state.mult()
		var o := BallResolver.resolve_ball(
			s["power"] * bat_fmult, s["composure"] * bat_fmult,
			bat_attack * bowl_fmult, bat_control * bowl_fmult,
			intent, tuning, rng, jm.x * win.x * opp_win.x, jm.y * win.y * opp_win.y,
			bowler_type)
		# C2f — DRS: a review can overturn a close decision (see below).
		# A review mutates o, then the existing wicket/runs handling takes over.
		# RNG is consumed only when a review is actually attempted (a policy +
		# reviews_left remaining).
		# Both sides hold base DRS: the BATTING side reviews a wicket to survive; the
		# BOWLING side reviews a dot to claim a wicket. Both reviews are TEAM-WIDE on
		# every over (Nico's ruling 2026-06-10: the hero is just part of the team) —
		# the Player's runtime carries the team's jokers; the opponent's is base-only
		# (empty jokers, no payoffs). Gate on the *original* outcome so a survived
		# wicket can't be instantly re-claimed (no review "tennis") — at most one
		# review fires per ball.
		var orig_wicket := o.wicket
		var orig_dot := (not o.wicket) and o.runs == 0
		if orig_wicket:
			if player_is_batting and drs_policy != null:
				# DI3 — scripted mode (review_balls non-null): only review the listed
				# [over, ball_in_over] deliveries; auto mode (null) = byte-identical.
				var bio := balls % 6 + 1
				var do_review: bool = drs_policy.review_balls == null or drs_policy.review_balls.has([over, bio])
				if do_review and runtime.try_review(jokers, true, intent, drs_policy.base_p, balls + 1, rng):
					o = BallOutcome.new(false, 0)
			elif (not player_is_batting) and opp_drs_policy != null:
				if opp_runtime.try_review([], true, intent, opp_drs_policy.base_p, balls + 1, rng):
					o = BallOutcome.new(false, 0)
		elif orig_dot:
			if (not player_is_batting) and drs_policy != null:
				if runtime.try_review(jokers, false, intent, drs_policy.base_p, balls + 1, rng):
					o = BallOutcome.new(true, 0)
			elif player_is_batting and opp_drs_policy != null:
				if opp_runtime.try_review([], false, intent, opp_drs_policy.base_p, balls + 1, rng):
					o = BallOutcome.new(true, 0)
		balls += 1
		s["balls"] += 1
		if player_bowling:
			pb_balls += 1
			if o.wicket:
				pb_wickets += 1
			else:
				pb_runs += o.runs
		# C2c — a Player Form event: a Player boundary (batting) or a Player wicket
		# (bowling). Fires/decays windowed buffs. Runs every ball so buffs decay.
		var formed := false
		if player_is_batting:
			formed = s["is_player"] and not o.wicket and (o.runs == 4 or o.runs == 6)
		elif player_bowling:
			formed = o.wicket
		# DF3 -- per-ball Form ticks, Player-only (batting: the Player on strike;
		# bowling: the Player's own overs).
		if form_state != null:
			if player_is_batting and s["is_player"]:
				if o.wicket:
					form_state.on_player_dismissed()
				elif o.runs == 4 or o.runs == 6:
					form_state.on_player_boundary()
				elif o.runs == 0:
					form_state.on_player_dot()
				else:
					form_state.on_player_run()
			elif player_bowling:
				if o.wicket:
					form_state.on_player_wicket()
				elif o.runs == 4 or o.runs == 6:
					form_state.on_player_conceded_boundary()
		runtime.on_ball_end(jokers, player_is_batting, balls, formed)
		opp_runtime.on_ball_end([], opp_is_batting, balls, false)  # DF2 — decay opponent buffs
		# C2g — Building Phase: count consecutive Player Defensive balls -> Form every 6.
		if player_is_batting and s["is_player"]:
			if intent == BallResolver.Intent.DEFENSIVE and not o.wicket:
				def_streak += 1
				if def_streak % 6 == 0:
					runtime.fire_form_source(jokers, true, JokerEffect.FormSource.ON_DEFENSIVE_OVER, balls)
			else:
				def_streak = 0
		# C2g — Boundary Hunter: a Form event latches the Player's intent to Aggressive.
		if formed and player_is_batting and intent_override == -1:
			for j in jokers:
				if j.snaps_intent != -1:
					intent_override = j.snaps_intent
					break
		if o.wicket:
			s["out"] = true
			wickets += 1
			fall.append({"wicket": wickets, "score": total, "batter": s["position"], "ball": balls})
			if wickets >= 10:
				break
			striker = next_in
			next_in += 1
		else:
			s["runs"] += o.runs
			total += o.runs
			phase_runs[IntentPlan.phase_of(over)] += o.runs
			if o.runs % 2 == 1:
				var tmp := striker
				striker = nonstriker
				nonstriker = tmp
		# Opt-in ball-by-ball log (default off → zero overhead, no behaviour change).
		# Records what a viewer would see this delivery: who faced it, the intent,
		# whether a Boost was pressed at the over start, and the outcome.
		if ball_log != null:
			ball_log.append({
				"over": over, "ball_in_over": ((balls - 1) % 6) + 1,
				"striker_pos": s["position"], "is_player": s["is_player"],
				"player_batting": player_is_batting, "player_bowling": player_bowling,
				"intent": intent, "boost_pressed": boost_pressed_now,
				"wicket": o.wicket, "runs": (0 if o.wicket else o.runs),
				"total": total, "wickets": wickets,
			})
		# end of over: swap strike (skip if the innings just ended)
		if balls % 6 == 0 and wickets < 10:
			var tmp2 := striker
			striker = nonstriker
			nonstriker = tmp2

	return InningsResult.new(total, wickets, balls, fall, batters, pb_wickets, pb_runs, pb_balls, phase_runs)
