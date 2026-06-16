extends GutTest

# KeyMomentPlan — the per-over batting-Intent override policy (spec §3, D3).

func test_empty_returns_base_band():
	var p := KeyMomentPlan.new()
	assert_eq(p.effective_for_over(7, BallResolver.Intent.BALANCED), BallResolver.Intent.BALANCED)

func test_override_applies_from_its_over_onward():
	var p := KeyMomentPlan.new()
	p.overrides.append({"from_over": 7, "band": BallResolver.Intent.AGGRESSIVE})
	assert_eq(p.effective_for_over(6, BallResolver.Intent.BALANCED), BallResolver.Intent.BALANCED, "before the override = base")
	assert_eq(p.effective_for_over(7, BallResolver.Intent.BALANCED), BallResolver.Intent.AGGRESSIVE, "from the override over")
	assert_eq(p.effective_for_over(12, BallResolver.Intent.BALANCED), BallResolver.Intent.AGGRESSIVE, "still applies later")

func test_latest_wins_on_overlap():
	var p := KeyMomentPlan.new()
	p.overrides.append({"from_over": 7, "band": BallResolver.Intent.AGGRESSIVE})
	p.overrides.append({"from_over": 12, "band": BallResolver.Intent.DEFENSIVE})
	assert_eq(p.effective_for_over(11, BallResolver.Intent.BALANCED), BallResolver.Intent.AGGRESSIVE, "over 11 = the over-7 override")
	assert_eq(p.effective_for_over(14, BallResolver.Intent.BALANCED), BallResolver.Intent.DEFENSIVE, "over 14 = the latest (over-12) override")
