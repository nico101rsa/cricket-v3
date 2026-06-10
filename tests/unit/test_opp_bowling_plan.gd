extends GutTest

# E1 seam (spec 2026-06-10-selfplay-baseline-7cE1-design.md D6): opp_bowling_plan
# lets the opponent rotate a caller-supplied pace/spin plan instead of the
# hardcoded textbook default. Null == textbook (when rotating) == today.

var _tuning := BallTuning.new()
var _itun := InningsTuning.new()


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 5
	a.composure = 5
	a.attack = 5
	a.control = 5
	return a


func _match(seed_v: int, bats_first: bool, player_plan: BowlingPlan, opp_plan: BowlingPlan) -> MatchResult:
	return MatchResolver.simulate_match(
		_attrs(), 5, 5.0, 5.0, 5, 5.0, 5.0, bats_first, _tuning, _itun, _rng(seed_v),
		null, player_plan, [], null, null, null, null, null, null,
		[], [], 0, 0, null, null, opp_plan)


# Null opp plan must equal an explicit textbook opp plan — the current behaviour.
func test_null_opp_plan_equals_textbook() -> void:
	for s in range(11, 16):
		var a := _match(s, true, BowlingPlan.textbook(), null)
		var b := _match(s, true, BowlingPlan.textbook(), BowlingPlan.textbook())
		assert_eq(a.innings1.total, b.innings1.total, "innings1 total seed %d" % s)
		assert_eq(a.innings2.total, b.innings2.total, "innings2 total seed %d" % s)
		assert_eq(a.innings1.wickets, b.innings1.wickets, "innings1 wkts seed %d" % s)
		assert_eq(a.innings2.wickets, b.innings2.wickets, "innings2 wkts seed %d" % s)


# Player bats SECOND -> innings1 = Player's team bowling (opp plan irrelevant
# there), innings2 = opponent bowling at the Player's batting. So varying the
# opp plan must leave innings1 byte-identical (isolation) and must move
# innings2 for at least one seed (the lever is real).
func test_opp_plan_routes_to_opponents_bowling_innings_only() -> void:
	var moved := 0
	for s in range(21, 31):
		var pace := _match(s, false, BowlingPlan.textbook(), BowlingPlan.pace_only())
		var spin := _match(s, false, BowlingPlan.textbook(), BowlingPlan.spin_only())
		assert_eq(pace.innings1.total, spin.innings1.total, "innings1 isolated seed %d" % s)
		assert_eq(pace.innings1.wickets, spin.innings1.wickets, "innings1 wkts isolated seed %d" % s)
		if pace.innings2.total != spin.innings2.total or pace.innings2.wickets != spin.innings2.wickets:
			moved += 1
	assert_gt(moved, 0, "opp plan never moved the opponent's bowling innings")


# Opp plan set with NO player plan: rotation still activates (either side's
# plan turns it on), deterministically.
func test_opp_plan_alone_activates_rotation_deterministically() -> void:
	var a := _match(7, true, null, BowlingPlan.spin_only())
	var b := _match(7, true, null, BowlingPlan.spin_only())
	assert_eq(a.innings1.total, b.innings1.total)
	assert_eq(a.innings2.total, b.innings2.total)
	assert_eq(a.outcome, b.outcome)
