class_name InningsResolver
extends RefCounted

# Pure resolution of one T20 innings by looping BallResolver.resolve_ball().
# See spec 2026-06-07-innings-sim-design.md and ADR 0004. No member state.

# Build -> batting position (1..9). Higher batting share bats higher up.
static func player_position(attrs: Attributes, itun: InningsTuning) -> int:
	var batting := attrs.power + attrs.composure
	var bowling := attrs.attack + attrs.control
	var share := float(batting) / float(batting + bowling)
	var pos := roundi(itun.pos_base - itun.pos_span * share)
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

# Build the 11-strong batting order. With a statted Player (player_attrs != null),
# the Player bats at their build-driven position; every other slot is a derived
# partner scaled by the tail curve. With player_attrs == null (opposition innings),
# all 11 are derived.
static func _build_batters(player_attrs: Attributes, partner_batting: int, itun: InningsTuning) -> Array:
	var ppos := -1
	if player_attrs != null:
		ppos = player_position(player_attrs, itun)
	var batters: Array = []
	for order in range(1, 12):  # positions 1..11
		if order == ppos:
			batters.append({
				"position": order, "is_player": true,
				"power": player_attrs.power, "composure": player_attrs.composure,
				"runs": 0, "balls": 0, "out": false,
			})
		else:
			var p := maxi(1, roundi(partner_batting * partner_factor(order, itun)))
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
		partner_batting: int,
		opp_attack: int,
		opp_control: int,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator,
		target: int = 0,
		intent_plan: IntentPlan = null,
		bowling_attack: BowlingAttack = null,
		bowling_plan: BowlingPlan = null,
		player_bowler_attack: int = 0,
		player_bowler_control: int = 0,
		player_bowler_overs: int = 0,
		jokers: Array = [],
		player_is_batting: bool = true,
		field_plan: FieldPlan = null,
		bowl_intent_plan: IntentPlan = null,
		boost_plan: BoostPlan = null,
		drs_policy: DRSPolicy = null
) -> InningsResult:
	var batters := _build_batters(player_attrs, partner_batting, itun)
	var max_balls := itun.over_limit * 6
	var striker := 0
	var nonstriker := 1
	var next_in := 2
	var wickets := 0
	var balls := 0
	var total := 0
	var fall: Array = []
	var player_overs_set: Array[int] = []
	if player_bowler_overs > 0:
		player_overs_set = player_bowling_overs(player_bowler_overs, itun.over_limit)
	var pb_wickets := 0  # Player-as-bowler figures for this innings
	var pb_runs := 0
	var pb_balls := 0
	var runtime := JokerRuntime.new()  # C2c — per-innings windowed-buff state
	if drs_policy != null:
		runtime.init_reviews(jokers, drs_policy.base_reviews)  # C2f — DRS resource
	var prev_intent := -1       # C2g — for intent-switch Form sources
	var def_streak := 0          # C2g — consecutive Player Defensive balls (Building Phase)
	var intent_override := -1    # C2g — Boundary Hunter snaps intent to Aggressive

	while balls < max_balls and wickets < 10 and (target == 0 or total < target):
		var s: Dictionary = batters[striker]
		var over := balls / 6 + 1  # 1-based over of the ball about to be bowled
		var intent := BallResolver.Intent.BALANCED
		if intent_plan != null:
			intent = intent_plan.for_over(over)
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
		if bowling_attack != null and bowling_plan != null:
			var prof := bowling_attack.profile(bowling_plan.for_over(over))
			bat_attack = prof.x
			bat_control = prof.y
		var player_bowling := player_bowler_overs > 0 and player_overs_set.has(over)
		if player_bowling:
			bat_attack = player_bowler_attack
			bat_control = player_bowler_control
		var field_mode := FieldPlan.Mode.NEUTRAL
		if field_plan != null:
			field_mode = field_plan.for_over(over)
		var bowl_intent := -1  # the bowling captain's intent (C2b); -1 = none set
		if bowl_intent_plan != null:
			bowl_intent = bowl_intent_plan.for_over(over)
		var bowler_type := -1  # current over's BowlingPlan.Kind (C2d); -1 = no rotation
		if bowling_plan != null:
			bowler_type = bowling_plan.for_over(over)
		# C2d — a setNextBowler event fires at each spell start (overs 1/7/16) while
		# the Player captains the bowling (opposition batting innings), pushing buffs
		# that apply from this over onward (so before tick_mults below).
		if bowling_plan != null and not player_is_batting and balls == (over - 1) * 6 and (over == 1 or over == 7 or over == 16):
			runtime.on_bowling_change(jokers, bowler_type, field_mode)
		# C2e — a Manager Boost press at this over's start fires a side-aware buff.
		if boost_plan != null and balls == (over - 1) * 6 and boost_plan.presses_on(over):
			runtime.on_boost_press(jokers, player_is_batting, intent, boost_plan.base_mult, boost_plan.base_n, balls + 1)
		var jm := JokerResolver.roll_mults(jokers, player_is_batting, intent, balls + 1, field_mode, bowl_intent, bowler_type)
		var win := runtime.tick_mults(player_is_batting)  # C2c — active windowed buffs
		var o := BallResolver.resolve_ball(
			s["power"], s["composure"], bat_attack, bat_control,
			intent, tuning, rng, jm.x * win.x, jm.y * win.y)
		# C2f — DRS: a Player review can overturn a close decision. Batting: a Player
		# dismissal -> survive (dot). Bowling: a Player-bowled dot -> claim a wicket.
		# Mutates o so the existing wicket/runs handling takes over. RNG is consumed
		# only when a review is actually attempted (gated on drs_policy + reviews_left).
		if drs_policy != null:
			if player_is_batting and o.wicket and s["is_player"]:
				if runtime.try_review(jokers, player_is_batting, intent, drs_policy.base_p, balls + 1, rng):
					o = BallOutcome.new(false, 0)
			elif (not player_is_batting) and player_bowling and not o.wicket and o.runs == 0:
				if runtime.try_review(jokers, player_is_batting, intent, drs_policy.base_p, balls + 1, rng):
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
		runtime.on_ball_end(jokers, player_is_batting, balls, formed)
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
			if o.runs % 2 == 1:
				var tmp := striker
				striker = nonstriker
				nonstriker = tmp
		# end of over: swap strike (skip if the innings just ended)
		if balls % 6 == 0 and wickets < 10:
			var tmp2 := striker
			striker = nonstriker
			nonstriker = tmp2

	return InningsResult.new(total, wickets, balls, fall, batters, pb_wickets, pb_runs, pb_balls)
