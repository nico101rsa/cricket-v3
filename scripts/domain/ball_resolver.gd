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
