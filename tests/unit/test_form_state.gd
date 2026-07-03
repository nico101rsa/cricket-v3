extends GutTest

# DF2/DF3/DF4/DF7 -- the pure Form state: tick table, clamps, multiplier anchors.

func test_multiplier_anchors() -> void:
	assert_almost_eq(FormState.form_mult(0.0), 1.0, 0.0001, "steady = neutral")
	assert_almost_eq(FormState.form_mult(3.0), 1.15, 0.0001, "hot cap (CONTEXT x1.15)")
	assert_almost_eq(FormState.form_mult(-3.0), 0.8, 0.0001, "cold floor (CONTEXT x0.8)")
	assert_almost_eq(FormState.form_mult(1.0), 1.05, 0.0001)
	assert_almost_eq(FormState.form_mult(-1.5), 0.9, 0.0001)

func test_tick_table() -> void:
	var f := FormState.make(0.0)
	f.on_player_boundary()
	assert_almost_eq(f.points, 0.25, 0.0001, "boundary +0.25")
	f.on_player_dismissed()
	assert_almost_eq(f.points, -0.75, 0.0001, "dismissed -1.0")
	f.on_player_wicket()
	assert_almost_eq(f.points, -0.25, 0.0001, "bowling wicket +0.5")
	f.on_player_conceded_boundary()
	assert_almost_eq(f.points, -0.5, 0.0001, "conceded boundary -0.25")

func test_dot_streak_fires_every_6_and_resets_on_a_run() -> void:
	var f := FormState.make(0.0)
	for i in 5:
		f.on_player_dot()
	assert_almost_eq(f.points, 0.0, 0.0001, "5 dots: no tick yet")
	f.on_player_dot()
	assert_almost_eq(f.points, -0.25, 0.0001, "6th consecutive dot ticks -0.25")
	for i in 6:
		f.on_player_dot()
	assert_almost_eq(f.points, -0.5, 0.0001, "streak counter reset after firing; 12 dots = 2 ticks")
	f.on_player_run()
	for i in 5:
		f.on_player_dot()
	f.on_player_boundary()
	for i in 5:
		f.on_player_dot()
	assert_almost_eq(f.points, -0.25, 0.0001, "any run/boundary resets the streak (only the boundary +0.25 landed)")

func test_clamps() -> void:
	var f := FormState.make(2.9)
	for i in 10:
		f.on_player_boundary()
	assert_almost_eq(f.points, 3.0, 0.0001, "clamped at +3")
	var g := FormState.make(-2.5)
	g.on_player_dismissed()
	g.on_player_dismissed()
	assert_almost_eq(g.points, -3.0, 0.0001, "clamped at -3")

func test_affinity_base_mult_composes() -> void:
	assert_almost_eq(FormState.affinity_mult(0), 1.0, 0.0001)
	assert_almost_eq(FormState.affinity_mult(3), 1.03, 0.0001)
	assert_almost_eq(FormState.affinity_mult(9), 1.05, 0.0001, "capped at +5% (AFF_FULL 5)")
	var f := FormState.make(3.0, FormState.affinity_mult(5))
	assert_almost_eq(f.mult(), 1.15 * 1.05, 0.0001, "mult() = base_mult x form_mult(points)")
