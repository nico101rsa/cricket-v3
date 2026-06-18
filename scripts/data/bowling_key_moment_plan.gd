class_name BowlingKeyMomentPlan
extends RefCounted

# A bowling Key Moment decision = a per-over bowler-kind override (spec D3,
# 2026-06-18-bowling-key-moments-design.md). Exact mirror of KeyMomentPlan: the
# captain's call appends an {from_over, kind} entry; the effective kind for any over is
# the latest override at-or-before it (highest from_over <= over), falling back to the
# base BowlingPlan rotation. Pure + deterministic. Empty overrides => base kind
# unchanged (byte-identical to a no-bowling-Key-Moment match).

var overrides: Array = []  # of {from_over:int, kind:int} ; kind = BowlingPlan.Kind

func effective_for_over(over: int, base_kind: int) -> int:
	var best_from := -1
	var result := base_kind
	for o in overrides:
		var f: int = o["from_over"]
		if f <= over and f > best_from:
			best_from = f
			result = o["kind"]
	return result
