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
		player_bowler_overs: int = 0
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

	while balls < max_balls and wickets < 10 and (target == 0 or total < target):
		var s: Dictionary = batters[striker]
		var over := balls / 6 + 1  # 1-based over of the ball about to be bowled
		var intent := BallResolver.Intent.BALANCED
		if intent_plan != null:
			intent = intent_plan.for_over(over)
		var bat_attack := opp_attack
		var bat_control := opp_control
		if bowling_attack != null and bowling_plan != null:
			var prof := bowling_attack.profile(bowling_plan.for_over(over))
			bat_attack = prof.x
			bat_control = prof.y
		if player_bowler_overs > 0 and player_overs_set.has(over):
			bat_attack = player_bowler_attack
			bat_control = player_bowler_control
		var o := BallResolver.resolve_ball(
			s["power"], s["composure"], bat_attack, bat_control,
			intent, tuning, rng)
		balls += 1
		s["balls"] += 1
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

	return InningsResult.new(total, wickets, balls, fall, batters)
