extends GutTest

# Intent enum values: DEFENSIVE=0, BALANCED=1, AGGRESSIVE=2

func test_for_over_powerplay_phase() -> void:
	var plan := IntentPlan.new()
	plan.powerplay = BallResolver.Intent.AGGRESSIVE
	plan.middle = BallResolver.Intent.BALANCED
	plan.death = BallResolver.Intent.DEFENSIVE
	assert_eq(plan.for_over(1), BallResolver.Intent.AGGRESSIVE, "over 1 -> powerplay band")
	assert_eq(plan.for_over(6), BallResolver.Intent.AGGRESSIVE, "over 6 -> still powerplay (boundary)")

func test_for_over_middle_phase() -> void:
	var plan := IntentPlan.new()
	plan.powerplay = BallResolver.Intent.AGGRESSIVE
	plan.middle = BallResolver.Intent.BALANCED
	plan.death = BallResolver.Intent.DEFENSIVE
	assert_eq(plan.for_over(7), BallResolver.Intent.BALANCED, "over 7 -> middle (boundary)")
	assert_eq(plan.for_over(15), BallResolver.Intent.BALANCED, "over 15 -> still middle (boundary)")

func test_for_over_death_phase() -> void:
	var plan := IntentPlan.new()
	plan.powerplay = BallResolver.Intent.AGGRESSIVE
	plan.middle = BallResolver.Intent.BALANCED
	plan.death = BallResolver.Intent.DEFENSIVE
	assert_eq(plan.for_over(16), BallResolver.Intent.DEFENSIVE, "over 16 -> death (boundary)")
	assert_eq(plan.for_over(20), BallResolver.Intent.DEFENSIVE, "over 20 -> still death (boundary)")

func test_balanced_factory_all_balanced() -> void:
	var plan := IntentPlan.balanced()
	assert_eq(plan.powerplay, BallResolver.Intent.BALANCED, "powerplay balanced")
	assert_eq(plan.middle, BallResolver.Intent.BALANCED, "middle balanced")
	assert_eq(plan.death, BallResolver.Intent.BALANCED, "death balanced")

func test_textbook_factory_attack_build_slog() -> void:
	var plan := IntentPlan.textbook()
	assert_eq(plan.powerplay, BallResolver.Intent.AGGRESSIVE, "textbook powerplay aggressive")
	assert_eq(plan.middle, BallResolver.Intent.BALANCED, "textbook middle balanced")
	assert_eq(plan.death, BallResolver.Intent.AGGRESSIVE, "textbook death aggressive")
