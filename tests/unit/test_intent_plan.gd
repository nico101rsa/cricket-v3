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

# --- E2 state rules (spec 2026-06-11-stateaware-policy-7cE2-design.md §3) ---

func test_for_state_disabled_rules_equals_for_over() -> void:
	var plan := IntentPlan.textbook()
	for over in [1, 6, 7, 15, 16, 20]:
		assert_eq(plan.for_state(over, 50, 3, (over - 1) * 6, 160, 120),
			plan.for_over(over), "rules off -> identical to for_over (over %d)" % over)

func test_for_state_chase_up_escalates() -> void:
	var plan := IntentPlan.balanced()
	plan.chase_up_rr = 10.0
	# chasing: need 120 off 60 balls = req RR 12 >= 10 -> B steps up to A
	assert_eq(plan.for_state(11, 40, 2, 60, 160, 120), BallResolver.Intent.AGGRESSIVE)

func test_for_state_chase_up_clamps_at_aggressive() -> void:
	var plan := IntentPlan.textbook()  # death = AGGRESSIVE
	plan.chase_up_rr = 10.0
	assert_eq(plan.for_state(18, 40, 2, 105, 160, 120), BallResolver.Intent.AGGRESSIVE)

func test_for_state_chase_down_deescalates_and_clamps() -> void:
	var plan := IntentPlan.balanced()
	plan.chase_down_rr = 6.0
	# cruising: need 10 off 60 balls = req RR 1 <= 6 -> B steps down to D
	assert_eq(plan.for_state(11, 150, 2, 60, 160, 120), BallResolver.Intent.DEFENSIVE)
	var d := IntentPlan.new()
	d.middle = BallResolver.Intent.DEFENSIVE
	d.chase_down_rr = 6.0
	assert_eq(d.for_state(11, 150, 2, 60, 160, 120), BallResolver.Intent.DEFENSIVE, "clamped at DEFENSIVE")

func test_for_state_collapse_protects_both_innings() -> void:
	var plan := IntentPlan.balanced()
	plan.collapse_wkts = 4
	# setting innings (target 0): 5 down -> B steps down to D
	assert_eq(plan.for_state(11, 80, 5, 60, 0, 120), BallResolver.Intent.DEFENSIVE)
	# chasing innings, no chase rule set: collapse still applies
	assert_eq(plan.for_state(11, 80, 5, 60, 160, 120), BallResolver.Intent.DEFENSIVE)

func test_for_state_chase_up_suppresses_collapse() -> void:
	var plan := IntentPlan.balanced()
	plan.chase_up_rr = 10.0
	plan.collapse_wkts = 4
	# behind AND collapsed: the chase wins (DS2a) -> net +1, not 0/-1
	assert_eq(plan.for_state(11, 40, 5, 60, 160, 120), BallResolver.Intent.AGGRESSIVE)

func test_for_state_chase_rules_inert_without_target() -> void:
	var plan := IntentPlan.balanced()
	plan.chase_up_rr = 0.0  # would always fire if evaluated
	assert_eq(plan.for_state(11, 40, 2, 60, 0, 120), BallResolver.Intent.BALANCED)

func test_for_state_zero_balls_remaining_safe() -> void:
	var plan := IntentPlan.balanced()
	plan.chase_up_rr = 0.0
	# balls == max_balls: no div-by-zero, chase rules skipped
	assert_eq(plan.for_state(20, 40, 2, 120, 160, 120), BallResolver.Intent.BALANCED)

func test_key_moments_override_for_over() -> void:
	var km := KeyMomentPlan.new()
	km.overrides.append({"from_over": 7, "band": BallResolver.Intent.AGGRESSIVE})
	var plan := IntentPlan.new()  # all phases BALANCED
	plan.key_moments = km
	assert_eq(plan.for_over(6), BallResolver.Intent.BALANCED, "powerplay unaffected")
	assert_eq(plan.for_over(7), BallResolver.Intent.AGGRESSIVE, "override drives the middle")

func test_null_key_moments_is_phase_band() -> void:
	var plan := IntentPlan.new()
	plan.middle = BallResolver.Intent.DEFENSIVE
	assert_eq(plan.for_over(10), BallResolver.Intent.DEFENSIVE, "no km => plain phase band")
