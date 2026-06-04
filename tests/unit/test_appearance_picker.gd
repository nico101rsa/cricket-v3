extends GutTest

const AppearancePickerScene = preload("res://scenes/player_creation/appearance_picker.tscn")
const Appearance = preload("res://scripts/domain/appearance.gd")

func test_picker_creates_four_buttons():
	var picker = AppearancePickerScene.instantiate()
	add_child_autofree(picker)
	await get_tree().process_frame
	assert_eq(picker.get_child_count(), 4)

func test_emits_signal_on_select():
	var picker = AppearancePickerScene.instantiate()
	add_child_autofree(picker)
	await get_tree().process_frame
	watch_signals(picker)
	picker._on_pressed(Appearance.Bucket.INDIAN)
	assert_signal_emitted_with_parameters(picker, "appearance_selected", [Appearance.Bucket.INDIAN])
	assert_eq(picker.selected_bucket(), Appearance.Bucket.INDIAN)

func test_set_selected_silent_updates_state_without_emitting():
	var picker = AppearancePickerScene.instantiate()
	add_child_autofree(picker)
	await get_tree().process_frame
	watch_signals(picker)
	picker.set_selected_silent(Appearance.Bucket.BLACK)
	assert_eq(picker.selected_bucket(), Appearance.Bucket.BLACK)
	assert_signal_not_emitted(picker, "appearance_selected", "silent select must not re-roll the name")

func test_set_enabled_toggles_button_disabled_state():
	var picker = AppearancePickerScene.instantiate()
	add_child_autofree(picker)
	await get_tree().process_frame
	picker.set_enabled(false)
	for child in picker.get_children():
		assert_true((child as Button).disabled, "all thumbnails disabled")
	picker.set_enabled(true)
	for child in picker.get_children():
		assert_false((child as Button).disabled, "all thumbnails re-enabled")

func test_initial_selection_is_unset():
	var picker = AppearancePickerScene.instantiate()
	add_child_autofree(picker)
	await get_tree().process_frame
	assert_eq(picker.selected_bucket(), -1, "picker starts with the unset sentinel")

func test_placeholder_tint_is_distinct_per_bucket():
	var white := AppearancePicker.placeholder_tint(Appearance.Bucket.WHITE)
	var mixed := AppearancePicker.placeholder_tint(Appearance.Bucket.MIXED)
	var indian := AppearancePicker.placeholder_tint(Appearance.Bucket.INDIAN)
	var black := AppearancePicker.placeholder_tint(Appearance.Bucket.BLACK)
	# Exact spec values.
	assert_eq(white, Color(0.95, 0.86, 0.76), "WHITE tint matches spec")
	assert_eq(mixed, Color(0.78, 0.62, 0.48), "MIXED tint matches spec")
	assert_eq(indian, Color(0.62, 0.45, 0.33), "INDIAN tint matches spec")
	assert_eq(black, Color(0.36, 0.24, 0.18), "BLACK tint matches spec")
	# Mutually distinct.
	var tints := [white, mixed, indian, black]
	for i in range(tints.size()):
		for j in range(i + 1, tints.size()):
			assert_ne(tints[i], tints[j], "tints %d and %d must differ" % [i, j])
