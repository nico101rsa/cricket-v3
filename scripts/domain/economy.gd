class_name Economy
extends RefCounted

# Pure ₸ calculators (spec 2026-06-10-tons-economy-7cD §5.2). No state, no RNG —
# the Shop screen and the harness both call these. KMs are not in the sim yet,
# so perf pay reads runs + wickets only (DE3).

const MIN_BASE_PAY := 10


# ₸ earned by one match: Team base (stronger Teams pay less) + performance
# bonus. Returns the breakdown because the Result screen displays it
# ("base 50 + perf 18 = 68 ₸").
static func match_pay(result: MatchResult, team_stars: float, tuning: EconomyTuning) -> Dictionary:
	var base := int(round(tuning.base_pay - tuning.star_pay_slope * (team_stars - 3.0)))
	base = maxi(base, MIN_BASE_PAY)
	# The Player bats in their team's innings and bowls in the other one.
	var bat_inn := result.innings1
	var bowl_inn := result.innings2
	if result.innings1.player_line().is_empty():
		bat_inn = result.innings2
		bowl_inn = result.innings1
	var line := bat_inn.player_line()
	var perf := int(round(tuning.runs_rate * int(line.get("runs", 0))
		+ tuning.wicket_rate * bowl_inn.player_bowl_wickets))
	return {"base": base, "perf": perf, "total": base + perf}


static func attr_upgrade_cost(current_value: int, tuning: EconomyTuning) -> int:
	return int(round(tuning.attr_cost_base * current_value))


static func sell_refund(price: int, tuning: EconomyTuning) -> int:
	return int(floor(price * tuning.sell_refund_frac))
