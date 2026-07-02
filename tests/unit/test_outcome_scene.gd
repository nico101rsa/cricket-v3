extends GutTest

# Season Outcome screen (live-season-loop Slice 2). Shown when the live SeasonPlay
# finishes — surfaces final position + ₸ banked, with a Continue button.

const OutcomeScene = preload("res://scenes/outcome/outcome.tscn")

func _result(pos: int) -> SeasonResult:
	var sr := SeasonResult.new()
	sr.player_final_position = pos
	sr.beat = pos <= 3
	sr.won_final = pos == 1
	return sr

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_renders_position_and_pay() -> void:
	var screen = OutcomeScene.instantiate()
	add_child_autofree(screen)
	screen.set_outcome(_result(1), 412, 8)
	await get_tree().process_frame
	var labels := _all_label_text(screen)
	assert_true(labels.contains("CHAMPIONS"), "champion headline shown for 1st")
	assert_true(labels.contains("412"), "₸ banked shown")
	assert_true(labels.contains("8 of 9 won"), "record shows wins of games (top-4 plays 9)")
	var cta := screen.find_child("ContinueBtn", true, false)
	assert_not_null(cta, "continue button present")
	assert_gt(cta.size.y, 0.0, "continue button not collapsed")

func test_missed_playoffs_headline_and_seven_games() -> void:
	var screen = OutcomeScene.instantiate()
	add_child_autofree(screen)
	screen.set_outcome(_result(6), 300, 3)
	await get_tree().process_frame
	var labels := _all_label_text(screen)
	assert_true(labels.contains("MISSED THE PLAYOFFS"), "missed-playoffs headline for 6th")
	assert_true(labels.contains("3 of 7 won"), "5th-8th played 7 league games only")
	assert_true(labels.contains("6th"), "ordinal finish shown")

func test_continue_emits() -> void:
	var screen = OutcomeScene.instantiate()
	add_child_autofree(screen)
	screen.set_outcome(_result(2), 200, 6)
	await get_tree().process_frame
	watch_signals(screen)
	var cta := screen.find_child("ContinueBtn", true, false)
	cta.pressed.emit()
	assert_signal_emitted(screen, "continue_pressed")


# --- Career-transition banner / next-up / CTA (live career advance, 2026-06-24) ---

func _show(result: SeasonResult, transition: Dictionary):
	var screen = OutcomeScene.instantiate()
	add_child_autofree(screen)
	screen.set_outcome(result, 60, 4, null, transition)
	return screen

func test_promoted_banner_visible_and_named() -> void:
	var s = _show(_result(1), {"promoted": true, "to_level": 1, "complete": false,
		"next_level": 1, "next_tour": 0, "beat": true, "from_level": 0, "tour": 5})
	await get_tree().process_frame
	var banner: Label = s.find_child("Banner", true, false)
	assert_not_null(banner, "banner present")
	assert_true(banner.is_visible_in_tree(), "banner visible")
	assert_gt(banner.size.y, 0.0, "banner not collapsed")
	assert_true(banner.text.contains("CITY"), "promotion names the new Level")

# --- Offers-era banners: moved down / signed same-Level (spec 2026-07-02) ---

func test_moved_down_banner_names_level() -> void:
	var s = _show(_result(2), {"promoted": false, "to_level": 0, "from_level": 1,
		"complete": false, "team_changed": true, "next_level": 0, "next_tour": 2,
		"beat": true, "tour": 0})
	await get_tree().process_frame
	var banner: Label = s.find_child("Banner", true, false)
	assert_true(banner.text.contains("MOVED DOWN TO CLUB"),
		"a down move names the Level, not a promotion/cleared line")

func test_signed_same_level_banner_names_team() -> void:
	var career := CareerResolver.start_career(0)
	career.current_team_index = 1   # the team the pick landed on
	var screen = OutcomeScene.instantiate()
	add_child_autofree(screen)
	screen.set_outcome(_result(5), 60, 2, career,
		{"promoted": false, "to_level": 0, "from_level": 0, "complete": false,
		"team_changed": true, "next_level": 0, "next_tour": 0, "beat": false, "tour": 0})
	await get_tree().process_frame
	var banner: Label = screen.find_child("Banner", true, false)
	assert_true(banner.text.contains(career.teams[1].team_name.to_upper()),
		"a same-Level move names the new team")

func test_cleared_banner_names_tour_one_indexed() -> void:
	var s = _show(_result(2), {"promoted": false, "to_level": 0, "complete": false,
		"next_level": 0, "next_tour": 5, "beat": true, "from_level": 0, "tour": 4})
	await get_tree().process_frame
	var banner: Label = s.find_child("Banner", true, false)
	assert_true(banner.text.contains("TOUR 5"), "tour 4 displays 1-indexed as TOUR 5")

func test_complete_routes_to_hall_of_fame() -> void:
	var s = _show(_result(1), {"promoted": false, "to_level": 2, "complete": true,
		"next_level": 2, "next_tour": 7, "beat": true, "from_level": 2, "tour": 7})
	await get_tree().process_frame
	var nextup: Label = s.find_child("NextUp", true, false)
	assert_true(nextup.text.contains("HALL OF FAME"), "complete points at the Hall of Fame")
	var cta := s.find_child("ContinueBtn", true, false)
	assert_true(cta.text.contains("HALL OF FAME"), "CTA reads enter the Hall of Fame")

func test_no_emoji_in_banner() -> void:
	# Barlow tofus emoji — the banner must stay text-only.
	var s = _show(_result(1), {"promoted": false, "to_level": 2, "complete": true,
		"next_level": 2, "next_tour": 7, "beat": true, "from_level": 2, "tour": 7})
	await get_tree().process_frame
	var banner: Label = s.find_child("Banner", true, false)
	for ch in "🏆🏏↑▶":
		assert_false(banner.text.contains(ch), "no emoji glyphs (Barlow tofu)")
