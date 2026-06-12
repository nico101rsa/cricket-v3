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
	# Versatility: doing both jobs pays, scaled by the MINOR discipline's
	# involvement (its balls count more) — equalizes mean pay across builds.
	var bat_inv := minf(1.0, balls / tuning.bat_ref_balls)
	var bowl_inv := minf(1.0, bowl_inn.player_bowl_balls / tuning.bowl_ref_balls)
	perf_f += tuning.versatility_rate * minf(bat_inv, bowl_inv)
	var perf := int(round(perf_f))
	return {"base": base, "perf": perf, "total": base + perf}


static func attr_upgrade_cost(current_value: float, tuning: EconomyTuning) -> int:
	return int(round(tuning.attr_cost_base * current_value))


static func sell_refund(price: int, tuning: EconomyTuning) -> int:
	return int(floor(price * tuning.sell_refund_frac))

# ₸ bonus per Player-team WIN (league or playoff), scaling with Level —
# career-loop rung DC10. match_pay is deliberately untouched.
static func win_bonus(level: int, tuning: EconomyTuning) -> int:
	return int(round(tuning.win_bonus_base + tuning.win_bonus_level_step * level))


# --- Prize escalation + prize objects (difficulty-sheet v2, spec DV7-DV9) ----
# Escalation scales the match-prize objects only (Nico's ruling) — never the
# game fee or performance pay. All are team outcomes: build-independent.

static func match_win_prize(level: int, tour: int, tuning: EconomyTuning) -> int:
	return int(round(win_bonus(level, tuning) * tuning.prize_escalation[tour]))


static func playoff_win_bonus(level: int, tour: int, tuning: EconomyTuning) -> int:
	return int(round((tuning.playoff_win_base + tuning.playoff_win_level_step * level)
		* tuning.prize_escalation[tour]))


static func final_appearance_bonus(level: int, tour: int, tuning: EconomyTuning) -> int:
	return int(round((tuning.final_appearance_base + tuning.final_appearance_level_step * level)
		* tuning.prize_escalation[tour]))


static func grand_final_prize(level: int, tour: int, tuning: EconomyTuning) -> int:
	return int(round((tuning.grand_final_base + tuning.grand_final_level_step * level)
		* tuning.prize_escalation[tour]))


# Flat by Level, not escalated (DV8): only payable at T8, so escalation would
# just fold into the dial.
static func premier_super_prize(level: int, tuning: EconomyTuning) -> int:
	return int(round(tuning.premier_super_base + tuning.premier_super_level_step * level))


# The Season-level payout from a final table position (DV9). final_pos is
# 1..8 (0 = unknown -> nothing). Positions 1-2 played The Final (a semi win);
# position 3 won the 3rd-place playoff.
static func season_prizes(final_pos: int, won_final: bool, level: int, tour: int,
		tuning: EconomyTuning) -> int:
	var total := 0
	if final_pos >= 1 and final_pos <= 2:
		total += final_appearance_bonus(level, tour, tuning)
		total += playoff_win_bonus(level, tour, tuning)
	elif final_pos == 3:
		total += playoff_win_bonus(level, tour, tuning)
	if won_final:
		total += grand_final_prize(level, tour, tuning)
		if tour == CareerState.PREMIER_TOUR:
			total += premier_super_prize(level, tuning)
	return total
