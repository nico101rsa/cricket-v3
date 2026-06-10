extends GutTest

# E1 (spec D7): the 216-policy enumeration + selection helpers are pure and tiny;
# these tests pin the contract the oracle leans on.


func test_enumerate_returns_216_unique_policies() -> void:
	var ps := PolicySearch.enumerate()
	assert_eq(ps.size(), 216)
	var seen := {}
	for p in ps:
		seen[PolicySearch.label_of(p)] = true
	assert_eq(seen.size(), 216, "labels (and so policies) must be unique")


func test_plan_construction_maps_fields() -> void:
	var p := {
		"pp_intent": BallResolver.Intent.AGGRESSIVE,
		"mid_intent": BallResolver.Intent.DEFENSIVE,
		"death_intent": BallResolver.Intent.BALANCED,
		"pp_bowl": BowlingPlan.Kind.SPIN,
		"mid_bowl": BowlingPlan.Kind.PACE,
		"death_bowl": BowlingPlan.Kind.SPIN,
	}
	var ip := PolicySearch.intent_plan_of(p)
	assert_eq(ip.for_over(3), BallResolver.Intent.AGGRESSIVE)
	assert_eq(ip.for_over(10), BallResolver.Intent.DEFENSIVE)
	assert_eq(ip.for_over(18), BallResolver.Intent.BALANCED)
	var bp := PolicySearch.bowling_plan_of(p)
	assert_eq(bp.for_over(3), BowlingPlan.Kind.SPIN)
	assert_eq(bp.for_over(10), BowlingPlan.Kind.PACE)
	assert_eq(bp.for_over(18), BowlingPlan.Kind.SPIN)


func test_textbook_policy_matches_plan_factories() -> void:
	var t := PolicySearch.textbook()
	var ip := PolicySearch.intent_plan_of(t)
	var ref := IntentPlan.textbook()
	assert_eq(ip.powerplay, ref.powerplay)
	assert_eq(ip.middle, ref.middle)
	assert_eq(ip.death, ref.death)
	var bp := PolicySearch.bowling_plan_of(t)
	var bref := BowlingPlan.textbook()
	assert_eq(bp.powerplay, bref.powerplay)
	assert_eq(bp.middle, bref.middle)
	assert_eq(bp.death, bref.death)


func test_best_index_picks_max_first_on_tie() -> void:
	assert_eq(PolicySearch.best_index([0.40, 0.55, 0.31]), 1)
	assert_eq(PolicySearch.best_index([0.50, 0.42, 0.50]), 0)


func test_random_policy_in_range_and_seeded() -> void:
	var ps := PolicySearch.enumerate()
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	var a := PolicySearch.random_policy(ps, r1)
	var b := PolicySearch.random_policy(ps, r2)
	assert_eq(PolicySearch.label_of(a), PolicySearch.label_of(b), "same seed -> same draw")
	assert_true(ps.has(a))
