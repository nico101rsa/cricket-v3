class_name KeyMomentPlan
extends RefCounted

# A Key Moment decision = a per-over batting-Intent override (spec D3,
# 2026-06-16-key-moments-match-design.md). The captain's call appends an
# {from_over, band} entry; the effective Intent for any over is the latest override
# at-or-before it (highest from_over <= over), falling back to the base band. Pure +
# deterministic — fed into IntentPlan, which is fed into the sim. Empty overrides =>
# returns the base band unchanged (byte-identical to a no-Key-Moment match).

var overrides: Array = []  # of {from_over:int, band:int} ; band = BallResolver.Intent

func effective_for_over(over: int, base_band: int) -> int:
	var best_from := -1
	var result := base_band
	for o in overrides:
		var f: int = o["from_over"]
		if f <= over and f > best_from:
			best_from = f
			result = o["band"]
	return result
