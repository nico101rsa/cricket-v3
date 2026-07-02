extends GutTest

# LadderMap (nav-shell spec 2026-07-03, Slice 3; mockup section 6, Q3 reco
# diagonal ladder): 3 rising diagonal rows of 8 tour nodes, drawn from
# CareerState.cell_status. Geometry is exposed via node_center() so the rising
# shape is testable without pixels.

func _map() -> LadderMap:
	var m := LadderMap.new()
	m.custom_minimum_size = Vector2(340, 300)
	add_child_autofree(m)
	m.size = m.custom_minimum_size
	var c := CareerResolver.start_career(0)
	m.set_state(c.cell_status, c.level_won, CareerResolver.next_live_cell(c))
	return m

func test_nodes_rise_left_to_right_within_a_level() -> void:
	var m := _map()
	var a := m.node_center(0, 0)
	var b := m.node_center(0, 7)
	assert_gt(b.x, a.x, "tours advance rightward")
	assert_lt(b.y, a.y, "tours rise (screen y decreases)")

func test_next_level_starts_where_last_topped_out() -> void:
	var m := _map()
	var club_top := m.node_center(0, 7)
	var city_start := m.node_center(1, 0)
	assert_lt(city_start.x, club_top.x, "next level restarts at the left")
	assert_lt(city_start.y, club_top.y + 1.0, "next level starts at/above the last top")

func test_current_cell_is_exposed() -> void:
	var m := _map()
	assert_eq(m.current_cell(), {"level": 0, "tour": 0}, "fresh career sits at Club tour 0")
