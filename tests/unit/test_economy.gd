extends GutTest

# Rung 7c-D (spec 2026-06-10-tons-economy-7cD §5.2/§7): pure ₸ calculators.

var _etun: EconomyTuning


func before_each() -> void:
	_etun = EconomyTuning.new()


# A MatchResult where the Player batted in innings `bat_first ? 1 : 2` scoring
# `runs` off `bat_balls` (default: a run-a-ball), and bowled `bowl_balls` in the
# other innings taking `wkts` for `bowl_runs` conceded.
func _result(runs: int, wkts: int, bat_first: bool = true, bowl_balls: int = 0,
		bowl_runs: int = 0, bat_balls: int = -1) -> MatchResult:
	if bat_balls < 0:
		bat_balls = maxi(runs, 1)
	var player_batters := [{"position": 3, "is_player": true, "runs": runs, "balls": bat_balls, "out": false}]
	var opp_batters := [{"position": 1, "is_player": false, "runs": 30, "balls": 25, "out": true}]
	var player_inn := InningsResult.new(150, 4, 120, [], player_batters)
	var opp_inn := InningsResult.new(140, 6, 120, [], opp_batters, wkts, bowl_runs, bowl_balls)
	var m := MatchResult.new()
	m.player_bats_first = bat_first
	m.innings1 = player_inn if bat_first else opp_inn
	m.innings2 = opp_inn if bat_first else player_inn
	m.outcome = MatchResult.Outcome.PLAYER_WIN
	return m


func test_base_pay_at_star3_is_the_base_dial() -> void:
	var pay := Economy.match_pay(_result(0, 0), 3.0, _etun)
	assert_eq(pay["base"], int(round(_etun.base_pay)))


func test_stronger_team_pays_less_base() -> void:
	var weak: int = Economy.match_pay(_result(0, 0), 1.0, _etun)["base"]
	var even: int = Economy.match_pay(_result(0, 0), 3.0, _etun)["base"]
	var strong: int = Economy.match_pay(_result(0, 0), 5.0, _etun)["base"]
	assert_gt(weak, even)
	assert_gt(even, strong)


func test_base_pay_floors_at_minimum() -> void:
	_etun.star_pay_slope = 30.0  # ★5 would be 50 - 60 = -10 without the floor
	var pay := Economy.match_pay(_result(0, 0), 5.0, _etun)
	assert_eq(pay["base"], Economy.MIN_BASE_PAY)


func test_perf_pays_runs_and_wickets_monotonically() -> void:
	var quiet: int = Economy.match_pay(_result(10, 0), 3.0, _etun)["perf"]
	var batted: int = Economy.match_pay(_result(50, 0), 3.0, _etun)["perf"]
	var starred: int = Economy.match_pay(_result(50, 3), 3.0, _etun)["perf"]
	assert_gt(batted, quiet)
	assert_gt(starred, batted)


func test_breakdown_sums_to_total() -> void:
	var pay := Economy.match_pay(_result(42, 2), 3.0, _etun)
	assert_eq(pay["total"], pay["base"] + pay["perf"])


func test_zero_performance_still_pays_base() -> void:
	var pay := Economy.match_pay(_result(0, 0), 3.0, _etun)
	assert_eq(pay["perf"], 0)
	assert_gt(pay["total"], 0)


func test_pay_reads_player_innings_when_batting_second() -> void:
	var first := Economy.match_pay(_result(42, 2, true), 3.0, _etun)
	var second := Economy.match_pay(_result(42, 2, false), 3.0, _etun)
	assert_eq(first["perf"], second["perf"])


func test_economy_pays_a_tight_spell_without_a_wicket() -> void:
	# 4 overs, 24 conceded (RR 6) vs club par: saved = rr_par_pay/6*24 - 24.
	var idle: int = Economy.match_pay(_result(0, 0, true, 0), 3.0, _etun)["perf"]
	var tight: int = Economy.match_pay(_result(0, 0, true, 24, 24, 0), 3.0, _etun)["perf"]
	assert_eq(idle, 0)
	assert_eq(tight, int(round(_etun.econ_rate * (_etun.rr_par_pay / 6.0 * 24 - 24))))


func test_economy_scales_with_overs_bowled() -> void:
	# The same spell quality (RR 6) over twice the overs pays twice the savings.
	var two_overs: int = Economy.match_pay(_result(0, 0, true, 12, 12, 0), 3.0, _etun)["perf"]
	var four_overs: int = Economy.match_pay(_result(0, 0, true, 24, 24, 0), 3.0, _etun)["perf"]
	assert_almost_eq(four_overs, two_overs * 2, 1)


func test_expensive_spell_pays_zero_not_negative() -> void:
	# 2 overs for 30 (RR 15, above club par) earns nothing — and costs nothing.
	var pay := Economy.match_pay(_result(0, 0, true, 12, 30, 0), 3.0, _etun)
	assert_eq(pay["perf"], 0)


func test_fast_runs_pay_more_than_slow_runs() -> void:
	var slow: int = Economy.match_pay(_result(40, 0, true, 0, 0, 60), 3.0, _etun)["perf"]
	var fast: int = Economy.match_pay(_result(40, 0, true, 0, 0, 20), 3.0, _etun)["perf"]
	assert_gt(fast, slow)


func test_fifty_milestone_pays_a_flat_bonus() -> void:
	# Same balls faced so the tempo term moves by one run at most.
	var forty_nine: int = Economy.match_pay(_result(49, 0, true, 0, 0, 60), 3.0, _etun)["perf"]
	var fifty: int = Economy.match_pay(_result(50, 0, true, 0, 0, 60), 3.0, _etun)["perf"]
	assert_gte(float(fifty - forty_nine), _etun.fifty_bonus)


func test_a_ton_stacks_the_fifty_and_hundred_bonuses() -> void:
	var ninety_nine: int = Economy.match_pay(_result(99, 0, true, 0, 0, 60), 3.0, _etun)["perf"]
	var ton: int = Economy.match_pay(_result(100, 0, true, 0, 0, 60), 3.0, _etun)["perf"]
	assert_gte(float(ton - ninety_nine), _etun.ton_bonus)


func test_versatility_pays_for_doing_both_jobs() -> void:
	# Same outputs, but doing both disciplines earns the versatility bonus on
	# top of the component pay (Nico 2026-06-10: the minor discipline's balls
	# count more, so any build earns ~equal).
	var bat_only: int = Economy.match_pay(_result(20, 0, true, 0, 0, 20), 3.0, _etun)["perf"]
	var bowl_part: int = Economy.match_pay(_result(20, 0, true, 12, 24, 20), 3.0, _etun)["perf"]
	var expected_bonus := _etun.versatility_rate * minf(20.0 / _etun.bat_ref_balls, 12.0 / _etun.bowl_ref_balls)
	var expected_econ := _etun.econ_rate * (_etun.rr_par_pay / 6.0 * 12 - 24)
	assert_almost_eq(float(bowl_part - bat_only), expected_bonus + expected_econ, 1.0)


func test_versatility_scales_with_the_minor_discipline() -> void:
	# More balls in the minor discipline (bowling here) → bigger bonus. Conceded
	# runs sit exactly at club par so the economy term stays 0 in both arms.
	var par_6 := int(round(_etun.rr_par_pay / 6.0 * 6))
	var par_12 := int(round(_etun.rr_par_pay / 6.0 * 12))
	var one_over: int = Economy.match_pay(_result(20, 0, true, 6, par_6, 20), 3.0, _etun)["perf"]
	var two_overs: int = Economy.match_pay(_result(20, 0, true, 12, par_12, 20), 3.0, _etun)["perf"]
	assert_gt(two_overs, one_over)


func test_no_versatility_for_a_single_discipline() -> void:
	# A pure batting match (no bowling) earns no versatility bonus: perf is
	# exactly the batting components.
	var pay := Economy.match_pay(_result(30, 0, true, 0, 0, 30), 3.0, _etun)
	assert_eq(pay["perf"], int(round(_etun.runs_rate * 30)))


func test_attr_upgrade_cost_scales_with_current_value() -> void:
	var low := Economy.attr_upgrade_cost(12.5, _etun)
	var high := Economy.attr_upgrade_cost(43.75, _etun)
	assert_gt(high, low)
	assert_eq(low, int(round(_etun.attr_cost_base * 12.5)))

func test_attr_upgrade_cost_is_a_career_horizon_sink() -> void:
	# Career-pacing DP3 (Nico's ruling 2026-06-12, supersedes the DR11/DE7
	# legacy-ROI pin): attributes are the Career-long ₸ sink. Pin the dial so a
	# +1 at a mid card (40) costs hundreds of ₸ (vs ~₸10 pre-ruling) — a Season's
	# income (~₸1.5k) buys a few points, not the whole tree.
	assert_eq(Economy.attr_upgrade_cost(40.0, _etun), int(round(_etun.attr_cost_base * 40.0)))
	assert_between(Economy.attr_upgrade_cost(40.0, _etun), 300, 900,
		"mid-card +1 costs a meaningful slice of a Season's pay")


func test_sell_refund_is_floored_fraction() -> void:
	assert_eq(Economy.sell_refund(45, _etun), int(floor(45 * _etun.sell_refund_frac)))
	assert_eq(Economy.sell_refund(0, _etun), 0)


func test_loadout_cap_dial_is_four() -> void:
	assert_eq(_etun.loadout_cap, 4)


# --- win_bonus (career-loop rung, DC10) ---

func test_win_bonus_scales_with_level() -> void:
	assert_eq(Economy.win_bonus(0, _etun), 5, "Club win bonus")
	assert_eq(Economy.win_bonus(1, _etun), 10, "City win bonus")
	assert_eq(Economy.win_bonus(2, _etun), 15, "Province win bonus")


func test_win_bonus_follows_dials() -> void:
	var t := EconomyTuning.new()
	t.win_bonus_base = 8.0
	t.win_bonus_level_step = 2.0
	assert_eq(Economy.win_bonus(2, t), 12, "8 + 2x2")


# --- prize escalation + prize objects (difficulty-sheet v2, DV7-DV9) ---

func test_prize_escalation_defaults() -> void:
	# Per-tour absolute multipliers vs the T1 base (Nico 2026-06-12: T8 = 1.6x).
	assert_eq(_etun.prize_escalation.size(), 8)
	assert_almost_eq(_etun.prize_escalation[0], 1.0, 0.0001)
	assert_almost_eq(_etun.prize_escalation[3], 1.1, 0.0001)
	assert_almost_eq(_etun.prize_escalation[7], 1.6, 0.0001)


func test_match_win_prize_escalates_with_tour() -> void:
	assert_eq(Economy.match_win_prize(0, 0, _etun), 5, "Club T1 = win_bonus base")
	assert_eq(Economy.match_win_prize(0, 7, _etun), 8, "Club Premier 5 x 1.6")
	assert_eq(Economy.match_win_prize(2, 7, _etun), 24, "Province Premier 15 x 1.6")


func test_playoff_and_final_bonuses_escalate() -> void:
	assert_eq(Economy.playoff_win_bonus(0, 0, _etun), 15, "base 15")
	assert_eq(Economy.playoff_win_bonus(1, 4, _etun), 33, "(15+10) x 1.3 = 32.5 -> 33")
	assert_eq(Economy.final_appearance_bonus(0, 0, _etun), 25)
	assert_eq(Economy.grand_final_prize(2, 7, _etun), 224, "(60+80) x 1.6")


func test_premier_super_prize_flat_by_level() -> void:
	# Not escalated (spec DV8): the T8-only trophy payout.
	assert_eq(Economy.premier_super_prize(0, _etun), 250)
	assert_eq(Economy.premier_super_prize(1, _etun), 500)
	assert_eq(Economy.premier_super_prize(2, _etun), 750)


func test_season_prizes_by_finish_position() -> void:
	# Runner-up: reached The Final (semi won) but no grand-final prize.
	assert_eq(Economy.season_prizes(2, false, 0, 0, _etun), 25 + 15)
	# 3rd: won the 3rd-place playoff only.
	assert_eq(Economy.season_prizes(3, false, 0, 0, _etun), 15)
	# 4th or below the playoffs: nothing.
	assert_eq(Economy.season_prizes(4, false, 0, 0, _etun), 0)
	assert_eq(Economy.season_prizes(7, false, 0, 0, _etun), 0)


func test_season_prizes_champion_and_premier_super() -> void:
	# Champion off-Premier: appearance + playoff win + grand final.
	assert_eq(Economy.season_prizes(1, true, 0, 0, _etun), 25 + 15 + 60)
	# Champion at Club Premier: all of it x1.6 (rounded each) + the super prize.
	var expected := int(round(25 * 1.6)) + int(round(15 * 1.6)) \
		+ int(round(60 * 1.6)) + 250
	assert_eq(Economy.season_prizes(1, true, 0, 7, _etun), expected)

func test_joker_price_scales_with_level_and_tour() -> void:
	var etun := EconomyTuning.new()
	var base := JokerCatalog.price("dead_bat")            # 30
	assert_eq(Economy.joker_price("dead_bat", 0, 0, etun), base)
	assert_eq(Economy.joker_price("dead_bat", 1, 0, etun), int(round(base * 1.5)))
	assert_eq(Economy.joker_price("dead_bat", 2, 7, etun), int(round(base * 2.0 * 1.6)))
