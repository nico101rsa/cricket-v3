extends GutTest

var tuning: BallTuning
var itun: InningsTuning

func before_each() -> void:
	tuning = BallTuning.new()
	itun = InningsTuning.new()

func _attrs(power: int, comp: int, attack: int, control: int) -> Attributes:
	var a := Attributes.new()
	a.power = power
	a.composure = comp
	a.attack = attack
	a.control = control
	return a

func test_pure_batter_bats_top_order() -> void:
	# 8/8/2/2: batting 16 vs bowling 4 -> share 0.8 -> pos round(9-6.4)=3
	var pos := InningsResolver.player_position(_attrs(8, 8, 2, 2), itun)
	assert_lte(pos, 3, "pure batter opens / top order")

func test_pure_bowler_bats_tail() -> void:
	# 2/2/8/8: share 0.2 -> pos round(9-1.6)=7
	var pos := InningsResolver.player_position(_attrs(2, 2, 8, 8), itun)
	assert_gte(pos, 7, "pure bowler bats the tail")

func test_even_build_bats_middle() -> void:
	var pos := InningsResolver.player_position(_attrs(5, 5, 5, 5), itun)
	assert_eq(pos, 5, "even build -> #5")

func test_position_clamped_to_range() -> void:
	var pos := InningsResolver.player_position(_attrs(8, 8, 1, 1), itun)
	assert_between(pos, 1, 9, "position stays in 1..9")

func test_tail_factor_full_at_top_floors_at_bottom() -> void:
	assert_almost_eq(InningsResolver.partner_factor(1, itun), 1.0, 0.0001, "opener at full strength")
	# pos 11: 1 - 10*0.07 = 0.30, below floor 0.45 -> clamped to floor
	assert_almost_eq(InningsResolver.partner_factor(11, itun), 0.45, 0.0001, "#11 floored")
	assert_gt(InningsResolver.partner_factor(2, itun), InningsResolver.partner_factor(8, itun), "tail weakens down the order")
