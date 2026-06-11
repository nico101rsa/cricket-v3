class_name BallResolver
extends RefCounted

# Pure resolution of a single delivery — see spec 2026-06-06-ball-resolution-design.md
# and ADR 0004. No member state; everything is static.

enum Intent { DEFENSIVE, BALANCED, AGGRESSIVE }  # indices align to BallTuning intent arrays

# Stage 2 core: blend the defensive and aggressive anchor distributions by
# scoring strength s in [0,1], then normalise so the result sums to 1.
static func blended_distribution(s: float, tuning: BallTuning) -> Array[float]:
	var weights: Array[float] = []
	var total := 0.0
	for i in BallTuning.RUN_VALUES.size():
		var w := lerpf(tuning.def_dist[i], tuning.agg_dist[i], s)
		weights.append(w)
		total += w
	for i in weights.size():
		weights[i] /= total
	return weights

static func _sigmoid(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))

# Resolve one delivery. Consumes rng in fixed order: wicket roll always; runs
# roll only if the ball is survived. Same seed + same inputs -> same outcome.
static func resolve_ball(
		bat_power: int,
		bat_composure: int,
		bowl_attack: float,
		bowl_control: float,
		intent: Intent,
		tuning: BallTuning,
		rng: RandomNumberGenerator,
		wicket_mult: float = 1.0,
		runs_mult: float = 1.0,
		bowler_kind: int = -1
) -> BallOutcome:
	# Stage 1 — wicket roll (Composure vs Attack), in log-odds; jokers scale p_wicket.
	# bowler_kind (BowlingPlan.Kind, -1 = unknown) adds the intent x kind matchup
	# term (BB3) — e.g. slogging spin carries extra wicket risk.
	var matchup := 0.0
	if bowler_kind == BowlingPlan.Kind.PACE:
		matchup = tuning.matchup_w_pace[intent]
	elif bowler_kind == BowlingPlan.Kind.SPIN:
		matchup = tuning.matchup_w_spin[intent]
	var logit_w := tuning.base_w + tuning.k_w * (bowl_attack - bat_composure) + tuning.intent_w[intent] + matchup
	var p_wicket := clampf(_sigmoid(logit_w) * wicket_mult, 0.0, 1.0)
	if rng.randf() < p_wicket:
		return BallOutcome.new(true, 0)

	# Stage 2 — runs roll (Power vs Control); jokers scale the scoring strength s.
	var s := clampf(_sigmoid(tuning.base_r + tuning.k_r * (bat_power - bowl_control) + tuning.intent_r[intent]) * runs_mult, 0.0, 1.0)
	return BallOutcome.new(false, _sample_runs(s, tuning, rng))

static func _sample_runs(s: float, tuning: BallTuning, rng: RandomNumberGenerator) -> int:
	var probs := blended_distribution(s, tuning)
	var roll := rng.randf()
	var acc := 0.0
	for i in probs.size():
		acc += probs[i]
		if roll < acc:
			return BallTuning.RUN_VALUES[i]
	return BallTuning.RUN_VALUES[BallTuning.RUN_VALUES.size() - 1]  # float-rounding safety
