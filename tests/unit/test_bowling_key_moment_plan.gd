extends GutTest

# BowlingKeyMomentPlan — the per-over bowler-kind override policy (spec §3, D3).
# Exact mirror of KeyMomentPlan; kind = BowlingPlan.Kind (PACE/SPIN).

func test_empty_returns_base_kind():
	var p := BowlingKeyMomentPlan.new()
	assert_eq(p.effective_for_over(7, BowlingPlan.Kind.SPIN), BowlingPlan.Kind.SPIN)

func test_override_applies_from_its_over_onward():
	var p := BowlingKeyMomentPlan.new()
	p.overrides.append({"from_over": 7, "kind": BowlingPlan.Kind.SPIN})
	assert_eq(p.effective_for_over(6, BowlingPlan.Kind.PACE), BowlingPlan.Kind.PACE, "before the override = base")
	assert_eq(p.effective_for_over(7, BowlingPlan.Kind.PACE), BowlingPlan.Kind.SPIN, "from the override over")
	assert_eq(p.effective_for_over(12, BowlingPlan.Kind.PACE), BowlingPlan.Kind.SPIN, "still applies later")

func test_latest_wins_on_overlap():
	var p := BowlingKeyMomentPlan.new()
	p.overrides.append({"from_over": 7, "kind": BowlingPlan.Kind.SPIN})
	p.overrides.append({"from_over": 16, "kind": BowlingPlan.Kind.PACE})
	assert_eq(p.effective_for_over(15, BowlingPlan.Kind.PACE), BowlingPlan.Kind.SPIN, "over 15 = the over-7 override")
	assert_eq(p.effective_for_over(18, BowlingPlan.Kind.SPIN), BowlingPlan.Kind.PACE, "over 18 = the latest (over-16) override")
