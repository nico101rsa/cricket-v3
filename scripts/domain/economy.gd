class_name Economy
extends RefCounted

# Pure ₸ calculators (spec 2026-06-10-tons-economy-7cD §5.2 + the performance-
# contract re-design of the same day, spec §10.2). No state, no RNG — the Shop
# screen and the harness both call these. KMs are not in the sim yet (DE3).
#
# match_pay = game fee (~50% of the take-home, by Team ★) + a 5-component
# performance bonus:
#   1. batting runs            runs_rate × runs
#   2. strike-rate tempo       sr_rate × runs above a par-SR baseline (clamped ≥0)
#   3. milestones              fifty_bonus at 50+, ton_bonus on top at 100+
#   4. wickets taken           wicket_rate × wickets
#   5. economy, scaled by overs econ_rate × runs saved vs a baseline RR over the
#      spell (more overs → bigger stake; clamped ≥0)

const MIN_BASE_PAY := 10


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
	var runs := int(line.get("runs", 0))
	var balls := int(line.get("balls", 0))

	var perf_f := tuning.runs_rate * runs
	if balls > 0:
		# Tempo: runs above what par strike-rate would have scored off the same balls.
		perf_f += tuning.sr_rate * maxf(0.0, runs - tuning.sr_par_pay / 100.0 * balls)
	if runs >= 50:
		perf_f += tuning.fifty_bonus
	if runs >= 100:
		perf_f += tuning.ton_bonus
	perf_f += tuning.wicket_rate * bowl_inn.player_bowl_wickets
	if bowl_inn.player_bowl_balls > 0:
		# Economy: runs saved vs the baseline RR over the whole spell — the same
		# spell quality pays double over twice the overs.
		perf_f += tuning.econ_rate * maxf(0.0,
			tuning.rr_par_pay / 6.0 * bowl_inn.player_bowl_balls - bowl_inn.player_bowl_runs)
	var perf := int(round(perf_f))
	return {"base": base, "perf": perf, "total": base + perf}


static func attr_upgrade_cost(current_value: int, tuning: EconomyTuning) -> int:
	return int(round(tuning.attr_cost_base * current_value))


static func sell_refund(price: int, tuning: EconomyTuning) -> int:
	return int(floor(price * tuning.sell_refund_frac))
