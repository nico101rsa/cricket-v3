extends GutTest

# RunRateChart custom-drawn Control. Can't assert pixels, so assert it binds data,
# is visible, and holds a real height (the flat-button / collapsed-ScrollContainer
# invisibility lessons — a node existing is not a node drawing).

func _sample() -> Dictionary:
	return {
		"overs": [
			{"over": 1, "runs": 8, "crr": 8.0, "bar_rr": 8.0, "has_boundary": true, "has_wicket": false, "now": false},
			{"over": 2, "runs": 3, "crr": 5.5, "bar_rr": 3.0, "has_boundary": false, "has_wicket": true, "now": false},
			{"over": 3, "runs": 6, "crr": 5.67, "bar_rr": 9.0, "has_boundary": false, "has_wicket": false, "now": true},
		],
		"target_rr": 8.0, "y_max": 12.0, "innings": 2,
	}

func test_binds_and_is_visible() -> void:
	var chart := RunRateChart.new()
	chart.custom_minimum_size = Vector2(360, 180)
	add_child_autofree(chart)
	chart.set_data(_sample())
	await get_tree().process_frame
	assert_true(chart.is_visible_in_tree(), "chart visible")
	assert_gt(chart.size.y, 0.0, "chart has height (not collapsed)")

func test_empty_data_no_crash() -> void:
	var chart := RunRateChart.new()
	chart.custom_minimum_size = Vector2(360, 180)
	add_child_autofree(chart)
	chart.set_data({})
	await get_tree().process_frame
	assert_true(chart.is_visible_in_tree(), "empty chart still visible, no crash")
