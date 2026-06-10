extends GutTest

# Bowling-balance rung (spec 2026-06-11-bowling-balance-design.md).

func test_phase_of_maps_boundaries() -> void:
	assert_eq(IntentPlan.phase_of(1), 0, "over 1 -> powerplay")
	assert_eq(IntentPlan.phase_of(6), 0, "over 6 -> powerplay (boundary)")
	assert_eq(IntentPlan.phase_of(7), 1, "over 7 -> middle (boundary)")
	assert_eq(IntentPlan.phase_of(15), 1, "over 15 -> middle (boundary)")
	assert_eq(IntentPlan.phase_of(16), 2, "over 16 -> death (boundary)")
	assert_eq(IntentPlan.phase_of(20), 2, "over 20 -> death")

func test_for_over_unchanged_by_refactor() -> void:
	var t := IntentPlan.textbook()
	assert_eq(t.for_over(6), BallResolver.Intent.AGGRESSIVE, "textbook over 6 aggressive")
	assert_eq(t.for_over(7), BallResolver.Intent.BALANCED, "textbook over 7 balanced")
	assert_eq(t.for_over(16), BallResolver.Intent.AGGRESSIVE, "textbook over 16 aggressive")
