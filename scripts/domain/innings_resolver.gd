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

# Build the 11-strong batting order: Player (real attrs) at their build-driven
# position; every other slot a derived partner scaled by the tail curve.
static func _build_batters(player_attrs: Attributes, partner_batting: int, itun: InningsTuning) -> Array:
	var ppos := player_position(player_attrs, itun)
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
static func simulate_innings(
		player_attrs: Attributes,
		partner_batting: int,
		opp_attack: int,
		opp_control: int,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator
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

	while balls < max_balls and wickets < 10:
		var s: Dictionary = batters[striker]
		var o := BallResolver.resolve_ball(
			s["power"], s["composure"], opp_attack, opp_control,
			BallResolver.Intent.BALANCED, tuning, rng)
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
