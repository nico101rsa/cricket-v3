extends GutTest

# Rung 7c-D (spec 2026-06-10-tons-economy-7cD §5.2/§7): pure ₸ calculators.

var _etun: EconomyTuning


func before_each() -> void:
	_etun = EconomyTuning.new()


# A MatchResult where the Player batted in innings `bat_first ? 1 : 2` scoring
# `runs`, and bowled `bowl_balls` in the other innings taking `wkts`.
func _result(runs: int, wkts: int, bat_first: bool = true, bowl_balls: int = 0) -> MatchResult:
	var player_batters := [{"position": 3, "is_player": true, "runs": runs, "balls": maxi(runs, 1), "out": false}]
	var opp_batters := [{"position": 1, "is_player": false, "runs": 30, "balls": 25, "out": true}]
	var player_inn := InningsResult.new(150, 4, 120, [], player_batters)
	var opp_inn := InningsResult.new(140, 6, 120, [], opp_batters, wkts, 24, bowl_balls)
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


func test_bowling_workload_pays_without_a_wicket() -> void:
	var idle: int = Economy.match_pay(_result(0, 0, true, 0), 3.0, _etun)["perf"]
	var four_overs: int = Economy.match_pay(_result(0, 0, true, 24), 3.0, _etun)["perf"]
	assert_eq(idle, 0)
	assert_eq(four_overs, int(round(_etun.bowl_balls_rate * 24)))


func test_attr_upgrade_cost_scales_with_current_value() -> void:
	var low := Economy.attr_upgrade_cost(2, _etun)
	var high := Economy.attr_upgrade_cost(7, _etun)
	assert_gt(high, low)
	assert_eq(low, int(round(_etun.attr_cost_base * 2)))


func test_sell_refund_is_floored_fraction() -> void:
	assert_eq(Economy.sell_refund(45, _etun), int(floor(45 * _etun.sell_refund_frac)))
	assert_eq(Economy.sell_refund(0, _etun), 0)


func test_loadout_cap_dial_is_four() -> void:
	assert_eq(_etun.loadout_cap, 4)
