# Offers Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** At live-season end the player picks a team offer (or stays) on a new Offers screen, replacing the silent rush-climb auto-promote.

**Architecture:** Split `CareerResolver.advance_after_live_season` into `begin_live_advance` (record season + draw offers) and `finish_live_advance` (apply the pick + transition descriptor) so the UI sits between them; keep the old function as a byte-identical no-UI fallback composing both. New dumb scene `scenes/offers/` emits `offer_picked(offer_or_null)`; `main.gd::_finish_live_season` routes carry-over → Offers → Outcome. Spec: `docs/superpowers/specs/2026-07-02-offers-screen-design.md` (DO1–DO8).

**Tech Stack:** Godot 4.6.3 / GDScript / GUT 9.6. Tabs in `.gd`. Test command (full suite, <1s):
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
After creating any new script/scene, run `--import` once first:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
NEVER run headless Godot with the editor open. Red = a `SCRIPT ERROR: Parse Error` (not a failing assert); green = total test count climbing + `All tests passed`.

---

### Task 1: Domain — two-phase `begin_live_advance` / `finish_live_advance` (DO3/DO4/DO8)

**Files:**
- Modify: `scripts/domain/career_resolver.gd` (replace `advance_after_live_season`, lines ~124–157)
- Test: `tests/unit/test_career_resolver.gd` (append after the existing live-loop block)

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_career_resolver.gd` (helpers `_player()`, `_rng()`, `_season_stub()` already exist in this file):

```gdscript
# --- Two-phase live advance: begin/finish (offers spec 2026-07-02, DO3) ---

func test_begin_records_once_and_returns_offers() -> void:
	var s := CareerResolver.start_career(0)
	var b := CareerResolver.begin_live_advance(s, _season_stub(true, false), 0, 0, _rng(1))
	assert_eq(s.status_of(0, 0), CareerState.CellStatus.BEATEN)
	assert_eq(s.seasons_played, 1)
	assert_eq(s.seasons_at_level, 1)
	assert_gt(b["offers"].size(), 0, "offers drawn for the screen")
	assert_eq(b["from_level"], 0)
	assert_eq(b["from_team_index"], 0)
	assert_false(b["complete"])
	assert_eq(s.current_team_index, 0, "begin does NOT move the team")

func test_finish_stay_bumps_affinity_and_keeps_team() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	var b := CareerResolver.begin_live_advance(s, _season_stub(true, false), 0, 0, _rng(1))
	var t := CareerResolver.finish_live_advance(s, p, b, null)
	assert_eq(p.affinity, 1, "explicit STAY is the loyalty mechanic (DO8)")
	assert_eq(s.current_team_index, 0, "team unchanged")
	assert_false(t["promoted"])
	assert_false(t["team_changed"])
	assert_eq(t["next_tour"], 1, "beat tour 0 -> next is tour 1")

func test_finish_accept_moves_team_and_resets_affinity() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	p.affinity = 3
	var b := CareerResolver.begin_live_advance(s, _season_stub(true, false), 0, 0, _rng(1))
	var same_level_offer = null
	for o in b["offers"]:
		if o.level == 0:
			same_level_offer = o
			break
	assert_not_null(same_level_offer, "a same-Level offer exists at Club")
	var t := CareerResolver.finish_live_advance(s, p, b, same_level_offer)
	assert_eq(s.current_team_index, same_level_offer.team_index, "moved team")
	assert_eq(p.affinity, 0, "accept resets affinity")
	assert_eq(s.seasons_at_level, 0, "accept resets seasons_at_level")
	assert_false(t["promoted"], "same Level is not a promotion")
	assert_true(t["team_changed"])

func test_finish_accept_cross_up_sets_promoted() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	for t0 in range(CareerState.READINESS_TOUR):
		s.mark_beaten(0, t0)
	var b := CareerResolver.begin_live_advance(
		s, _season_stub(true, false), 0, CareerState.READINESS_TOUR, _rng(1))
	var up_offer = null
	for o in b["offers"]:
		if o.level == 1:
			up_offer = o
			break
	assert_not_null(up_offer, "fresh beat guarantees a cross-up offer")
	var t := CareerResolver.finish_live_advance(s, p, b, up_offer)
	assert_true(t["promoted"])
	assert_eq(t["to_level"], 1)
	assert_true(t["team_changed"])
	assert_eq(t["next_level"], 1)

func test_finish_accept_down_offer_moves_down() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	# Put the player on a City team with Club still unwon -> a down offer exists.
	s.current_team_index = CareerState.TEAMS_PER_LEVEL   # first City team
	var b := CareerResolver.begin_live_advance(s, _season_stub(false, false), 1, 0, _rng(1))
	var down_offer = null
	for o in b["offers"]:
		if o.level == 0:
			down_offer = o
			break
	assert_not_null(down_offer, "unwon Club yields a down offer (DC16)")
	var t := CareerResolver.finish_live_advance(s, p, b, down_offer)
	assert_eq(t["to_level"], 0)
	assert_true(t["to_level"] < t["from_level"], "moved down")
	assert_false(t["promoted"])

func test_begin_complete_career_has_no_offers_and_finish_skips_stay() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	s.current_team_index = CareerState.TEAMS_PER_LEVEL * 2   # Province
	s.cell_status[s.cell_index(2, CareerState.PREMIER_TOUR)] = CareerState.CellStatus.UNLOCKED
	var b := CareerResolver.begin_live_advance(
		s, _season_stub(true, true), 2, CareerState.PREMIER_TOUR, _rng(1))
	assert_true(b["complete"])
	assert_eq(b["offers"].size(), 0, "no offers once the career completed (DO2)")
	var t := CareerResolver.finish_live_advance(s, p, b, null)
	assert_eq(p.affinity, 0, "no stay bump on the champions path")
	assert_true(t["complete"])
```

- [ ] **Step 2: Run the suite to verify red**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -20`
Expected: `SCRIPT ERROR: Parse Error: ... "begin_live_advance" ...` (function not declared — GUT skips the file; that parse error IS red here).

- [ ] **Step 3: Implement — replace `advance_after_live_season` in `scripts/domain/career_resolver.gd`**

Replace the whole existing `advance_after_live_season` function (keep `next_live_cell` above it) with:

```gdscript
# End-of-Season advance for the LIVE loop — two-phase (offers spec 2026-07-02,
# DO3) so the Offers screen can sit between drawing the offer set and applying
# the pick.

# Phase 1: record the season into the grid + counters, then draw the offer set
# the screen shows (empty once the career completed, DO2). Mutates grid and
# counters only — the team move waits for finish_live_advance.
static func begin_live_advance(
		state: CareerState, result: SeasonResult,
		level: int, tour: int, rng: RandomNumberGenerator) -> Dictionary:
	state.record_outcome(level, tour, result.beat, result.won_final)
	state.seasons_played += 1
	state.seasons_at_level += 1
	var offers: Array = []
	if not state.complete:
		offers = generate_offers(state, result.beat, rng)
	return {
		"offers": offers,
		"beat": result.beat,
		"from_level": level,
		"from_team_index": state.current_team_index,
		"tour": tour,
		"complete": state.complete,
	}


# Phase 2: apply the pick — an Offer row, or null = STAY (affinity +1, DO8;
# skipped when the career is complete: there is no next season to be loyal
# into). Returns the transition descriptor the Outcome screen reads.
static func finish_live_advance(
		state: CareerState, player: Player, begin: Dictionary, offer) -> Dictionary:
	if offer != null:
		accept_offer(state, player, offer)
	elif not begin["complete"]:
		stay(state, player)
	return _live_transition(state, begin)


# The Outcome descriptor (extends the 2026-06-24 shape with team_changed;
# promoted = landed on a higher Level than the season was played at).
static func _live_transition(state: CareerState, begin: Dictionary) -> Dictionary:
	var nxt := next_live_cell(state)
	return {
		"beat": begin["beat"],
		"promoted": state.current_level() > int(begin["from_level"]),
		"from_level": begin["from_level"],
		"tour": begin["tour"],
		"to_level": state.current_level(),
		"complete": state.complete,
		"team_changed": state.current_team_index != int(begin["from_team_index"]),
		"next_level": nxt["level"],
		"next_tour": nxt["tour"],
	}


# The NO-UI fallback (headless tests / harnesses): begin + the rush auto-cross
# (accept the first cross-up offer once every climb tour at the Level is
# beaten). Byte-identical to the pre-offers behaviour — DO4: no stay() bump on
# the no-promotion path. The live game routes through begin/finish instead.
static func advance_after_live_season(
		state: CareerState, player: Player, result: SeasonResult,
		level: int, tour: int, rng: RandomNumberGenerator) -> Dictionary:
	var begin := begin_live_advance(state, result, level, tour, rng)
	if not state.complete:
		var cur := state.current_level()
		var up := cur + 1
		if state.next_climb_tour(cur) == -1 and up < CareerState.LEVELS \
				and state.any_unlocked_at(up):
			for o in begin["offers"]:
				if o.level == up:
					accept_offer(state, player, o)
					break
	return _live_transition(state, begin)
```

Note the byte-identical guarantee (DO4): the old code only *called* `generate_offers` under the rush gate, but the rng is fresh-seeded per call (`play.seed()+7` in main; `_rng(1)` in tests) and offers are its only consumer, so always-drawing in `begin` changes no observable state. The four existing live-advance tests (`test_advance_marks_beaten_and_bumps_counters`, `test_advance_not_beaten_is_grid_noop_same_cell`, `test_advance_auto_crosses_when_readiness_beaten`, `test_advance_completes_on_province_premier_win`) must pass **unmodified**.

- [ ] **Step 4: Run the suite to verify green**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -6`
Expected: `All tests passed` and the test count climbed by 6 (771 → 777).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/career_resolver.gd tests/unit/test_career_resolver.gd
git commit -m "feat: two-phase live season advance (begin/finish) for the Offers pick"
```

---

### Task 2: The Offers scene (DO6)

**Files:**
- Create: `scenes/offers/offers.gd`
- Create: `scenes/offers/offers.tscn`
- Test: `tests/unit/test_offers_scene.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_offers_scene.gd`:

```gdscript
extends GutTest

# The Offers screen (spec 2026-07-02, DO6): season end — pick a team offer or
# stay. Dumb screen: renders what it is given, emits the pick.

const OffersScene = preload("res://scenes/offers/offers.tscn")

func _career() -> CareerState:
	return CareerResolver.start_career(0)

func _offer(team_index: int, level: int, stars: float) -> Offer:
	var o := Offer.new()
	o.team_index = team_index
	o.level = level
	o.stars = stars
	return o

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_renders_one_button_per_offer_plus_stay() -> void:
	var screen = OffersScene.instantiate()
	add_child_autofree(screen)
	var c := _career()
	screen.set_offers(c, [_offer(8, 1, 3.0), _offer(1, 0, 2.0), _offer(2, 0, 2.5)])
	await get_tree().process_frame
	for i in range(3):
		var b = screen.find_child("OfferBtn%d" % i, true, false)
		assert_not_null(b, "offer button %d present" % i)
		assert_gt(b.size.y, 0.0, "offer button %d not collapsed" % i)
	var stay = screen.find_child("StayBtn", true, false)
	assert_not_null(stay, "stay button present")
	assert_gt(stay.size.y, 0.0, "stay button not collapsed")

func test_offer_rows_name_team_level_and_step_up_tag() -> void:
	var screen = OffersScene.instantiate()
	add_child_autofree(screen)
	var c := _career()
	screen.set_offers(c, [_offer(8, 1, 3.0)])
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains(c.teams[8].team_name), "offer names the team")
	assert_true(text.contains("CITY"), "offer names the Level word")
	assert_true(text.contains("STEP UP"), "cross-up offer tagged STEP UP")
	assert_true(text.contains(c.teams[c.current_team_index].team_name),
		"current team named on the stay row")

func test_tapping_an_offer_emits_that_offer() -> void:
	var screen = OffersScene.instantiate()
	add_child_autofree(screen)
	var up := _offer(8, 1, 3.0)
	screen.set_offers(_career(), [up, _offer(1, 0, 2.0)])
	await get_tree().process_frame
	watch_signals(screen)
	var b: Button = screen.find_child("OfferBtn0", true, false)
	b.pressed.emit()
	assert_signal_emitted_with_parameters(screen, "offer_picked", [up])

func test_stay_emits_null() -> void:
	var screen = OffersScene.instantiate()
	add_child_autofree(screen)
	screen.set_offers(_career(), [_offer(1, 0, 2.0)])
	await get_tree().process_frame
	watch_signals(screen)
	var stay: Button = screen.find_child("StayBtn", true, false)
	stay.pressed.emit()
	assert_signal_emitted_with_parameters(screen, "offer_picked", [null])
```

- [ ] **Step 2: Create the scene script `scenes/offers/offers.gd`**

```gdscript
extends Control

# The Offers screen (spec 2026-07-02-offers-screen-design.md, DO6) — season
# end, between the carry-over election and the Outcome: pick a team offer or
# stay. Low-fi in-house skin (Palette/UIStyle/Fonts), code-built like the
# Outcome screen. Dumb: renders what it is given, emits the pick, no domain
# math. No emoji (Barlow tofus them).

signal offer_picked(offer)   # the tapped Offer row, or null = STAY

func set_offers(career: CareerState, offers: Array) -> void:
	var current: Team = career.teams[career.current_team_index]
	var cur_level := career.current_level()

	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(320, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var kicker := Label.new()
	kicker.name = "Kicker"
	kicker.text = "OFF-SEASON"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_color_override("font_color", Palette.WHITE_DIM)
	kicker.add_theme_font_size_override("font_size", 11)
	Fonts.weigh(kicker, Fonts.W_BOLD)
	col.add_child(kicker)

	var title := Label.new()
	title.name = "Title"
	title.text = "Offers are in"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Palette.WHITE)
	title.add_theme_font_size_override("font_size", 26)
	Fonts.weigh(title, Fonts.W_HEADLINE)
	col.add_child(title)

	var cur := Label.new()
	cur.name = "CurrentTeam"
	cur.text = "You're with %s · %s" % [current.team_name, _level_word(cur_level)]
	cur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cur.add_theme_color_override("font_color", Palette.WHITE_DIM)
	cur.add_theme_font_size_override("font_size", 12)
	Fonts.weigh(cur, Fonts.W_MEDIUM)
	col.add_child(cur)

	for i in range(offers.size()):
		col.add_child(_offer_button(i, offers[i], cur_level, career))

	col.add_child(_stay_button(current))

# One offer row: team name over "LEVEL · n.n★ [· TAG]". Gold skin on a step up.
func _offer_button(i: int, offer: Offer, cur_level: int, career: CareerState) -> Button:
	var team: Team = career.teams[offer.team_index]
	var up := offer.level > cur_level
	var tag := ""
	if up:
		tag = " · STEP UP"
	elif offer.level < cur_level:
		tag = " · DROP DOWN"
	var sub := "%s · %.1f★%s" % [_level_word(offer.level).to_upper(), offer.stars, tag]
	var b := _two_line_btn(team.team_name, sub,
		Palette.GOLD if up else Palette.WHITE,
		UIStyle.cta(Palette.GOLD) if up else UIStyle.panel())
	b.name = "OfferBtn%d" % i
	if up:
		for l in [b.get_child(0).get_child(0), b.get_child(0).get_child(1)]:
			l.add_theme_color_override("font_color", Palette.BG)
	b.pressed.connect(func(): offer_picked.emit(offer))
	return b

func _stay_button(current: Team) -> Button:
	var b := _two_line_btn("Stay with %s" % current.team_name, "LOYALTY +1",
		Palette.WHITE_DIM, UIStyle.panel())
	b.name = "StayBtn"
	b.pressed.connect(func(): offer_picked.emit(null))
	return b

# A Button whose face is two stacked Labels (a bare Button doesn't wrap \n).
func _two_line_btn(top: String, sub: String, top_col: Color, box: StyleBox) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, box)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_l := Label.new()
	top_l.text = top
	top_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_l.add_theme_color_override("font_color", top_col)
	top_l.add_theme_font_size_override("font_size", 14)
	top_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Fonts.weigh(top_l, Fonts.W_BOLD)
	vb.add_child(top_l)
	var sub_l := Label.new()
	sub_l.text = sub
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_l.add_theme_color_override("font_color", Palette.WHITE_DIM)
	sub_l.add_theme_font_size_override("font_size", 10)
	sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Fonts.weigh(sub_l, Fonts.W_MEDIUM)
	vb.add_child(sub_l)
	b.add_child(vb)
	return b

func _level_word(level: int) -> String:
	return ["Club", "City", "Province"][clampi(level, 0, 2)]
```

- [ ] **Step 3: Create `scenes/offers/offers.tscn`** (mirror `scenes/kit_room/kit_room.tscn` — root Control + script):

```
[gd_scene load_steps=2 format=3 uid="uid://cs0offers00001"]

[ext_resource type="Script" path="res://scenes/offers/offers.gd" id="1_offers"]

[node name="Offers" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_offers")
```

- [ ] **Step 4: Import, then run the suite**

New script + scene → import first, chained (ONE Godot process at a time):

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -6`
Expected: `All tests passed`, count climbed by 4 (777 → 781).
(If you want to see red first, run the suite before Step 2/3 — the missing scene preload fails that test file with a load error.)

- [ ] **Step 5: Commit** (note: `offers.gd.uid` is generated for `scenes/` scripts — add it; the test file has no `.uid`)

```bash
git add scenes/offers/ tests/unit/test_offers_scene.gd
git commit -m "feat: the Offers screen (pick a team offer or stay, in-house skin)"
```

---

### Task 3: `main.gd` routing — carry-over → Offers → Outcome (DO1/DO2/DO5/DO7)

**Files:**
- Modify: `scenes/main.gd` (`_finish_live_season`, lines ~139–152, + preload consts)
- Test: `tests/unit/test_main_router.gd`

- [ ] **Step 1: Write the failing test**

In `tests/unit/test_main_router.gd`, extend `before_each`/`after_each` to sandbox the career + live-season saves (the existing body only redirects player/legends), and append the routing test with its helpers:

```gdscript
# added fields at the top, beside the existing ones
var _original_career_path: String
var _original_live_path: String
```

`before_each` additions (after the existing redirects):

```gdscript
	_original_career_path = SaveManager.career_save_path
	_original_live_path = SaveManager.live_season_save_path
	SaveManager.career_save_path = "user://_test_main_career.tres"
	SaveManager.live_season_save_path = "user://_test_main_live.tres"
	SaveManager.clear_career()
	SaveManager.clear_live_season()
```

`after_each` additions (before the path restores, then restore):

```gdscript
	SaveManager.clear_career()
	SaveManager.clear_live_season()
	SaveManager.career_save_path = _original_career_path
	SaveManager.live_season_save_path = _original_live_path
```

Appended test + helpers:

```gdscript
# --- Season end routes through the Offers screen (offers spec 2026-07-02) ---

func _opps() -> Array:
	var out: Array = []
	for k in range(7):
		var t := Team.new()
		t.team_name = "Opp %d" % (k + 1)
		t.stars = 2.5
		out.append(t)
	return out

func _done_play() -> SeasonPlay:
	var team := Team.new()
	team.team_name = "My XI"
	team.stars = 2.5
	var sp := SeasonPlay.start(Attributes.new(), team, _opps(),
		TourDistribution.new(), BallTuning.new(), InningsTuning.new(), 42)
	while not sp.season_done() and not sp.next_player_opponent().is_empty():
		sp.commit_player_result(sp.make_session().result())
	return sp

func test_finish_live_season_routes_offers_then_outcome():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var p := Player.new()
	p.attributes = Attributes.new()
	SaveManager.save_player(p)
	var career := CareerResolver.start_career(0)
	var play := _done_play()
	main._finish_live_season(play, career)
	await get_tree().process_frame
	var screen = main._slot.get_child(0)
	assert_true(screen.has_signal("offer_picked"), "the Offers screen mounts at season end")
	screen.offer_picked.emit(null)   # STAY
	await get_tree().process_frame
	var outcome = main._slot.get_child(0)
	assert_true(outcome.has_signal("continue_pressed"), "the pick lands on the Outcome")
	assert_true(SaveManager.has_career(), "career persisted after the pick")
```

- [ ] **Step 2: Run the suite to verify red**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -12`
Expected: the new test FAILS — `has_signal("offer_picked")` is false (the old `_finish_live_season` jumps straight to Outcome).

- [ ] **Step 3: Implement the routing in `scenes/main.gd`**

Add beside the other preloads:

```gdscript
const OFFERS := preload("res://scenes/offers/offers.tscn")
```

Replace the whole `_finish_live_season` function with:

```gdscript
# The season-end advance, now two-phase around the Offers screen (offers spec
# 2026-07-02, DO1): record the season + draw offers (begin), let the player
# pick a team or stay, then apply + persist (finish). Derives the played cell
# FIRST (the grid must not have advanced yet). Career complete -> no offers,
# straight to the Outcome (DO2). Nothing is saved until the pick lands (DO5),
# so a quit on the Offers screen resumes from the last live-season save and
# re-draws the same offers (rng is seeded, offers are its only consumer).
func _finish_live_season(play: SeasonPlay, career: CareerState) -> void:
	var cell := CareerResolver.next_live_cell(career)
	var player: Player = play.pay_player()
	if player == null:
		player = SaveManager.load_player()
	var rng := RandomNumberGenerator.new()
	rng.seed = play.seed() + 7   # distinct from strength (_seed) / AI (+1) / playoff (+2)
	var begin := CareerResolver.begin_live_advance(
		career, play.season_result(), cell["level"], cell["tour"], rng)
	if begin["offers"].is_empty():
		_apply_offer_pick(play, career, player, begin, null)
		return
	var screen := OFFERS.instantiate()
	screen.offer_picked.connect(func(offer):
		_apply_offer_pick(play, career, player, begin, offer))
	_push(screen)
	screen.set_offers(career, begin["offers"])

# The pick lands: apply it, persist atomically (career + player + the cleared
# live season), then show the Outcome.
func _apply_offer_pick(play: SeasonPlay, career: CareerState, player: Player,
		begin: Dictionary, offer) -> void:
	var transition := CareerResolver.finish_live_advance(career, player, begin, offer)
	SaveManager.save_career(career)
	SaveManager.clear_live_season()
	if player != null:
		SaveManager.save_player(player)   # affinity moved on stay AND accept
	_show_outcome(play, career, transition)
```

- [ ] **Step 4: Run the suite to verify green**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -6`
Expected: `All tests passed`, count climbed by 1 (781 → 782).

- [ ] **Step 5: Commit**

```bash
git add scenes/main.gd tests/unit/test_main_router.gd
git commit -m "feat: season end routes through the Offers screen (pick replaces auto-cross)"
```

---

### Task 4: Outcome banner — moved-down + signed-for cases (DO8 of the spec's banner section)

**Files:**
- Modify: `scenes/outcome/outcome.gd` (`set_outcome` career param + `_banner_for`)
- Test: `tests/unit/test_outcome_scene.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_outcome_scene.gd`:

```gdscript
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
```

- [ ] **Step 2: Run the suite to verify red**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -12`
Expected: both new tests FAIL (the old banner falls through to TOUR CLEARED / MISSED OUT).

- [ ] **Step 3: Implement in `scenes/outcome/outcome.gd`**

Rename the unused param in `set_outcome` from `_career` to `career` and pass it into the banner call:

```gdscript
func set_outcome(result: SeasonResult, pay: int, wins: int,
		career: CareerState = null, transition: Dictionary = {}) -> void:
```

and where the banner is built:

```gdscript
	var b := _banner_for(transition, career)
```

Replace `_banner_for` with (two new cases between promoted and beat):

```gdscript
# The career-transition banner (spec 2026-06-24; offers cases 2026-07-02).
# Reads the descriptor returned by CareerResolver.finish_live_advance. Tours
# are 1-indexed for display.
func _banner_for(t: Dictionary, career: CareerState) -> Dictionary:
	if t.get("complete", false):
		return {"text": "PROVINCE CHAMPIONS · CAREER COMPLETE", "color": Palette.GOLD}
	if t.get("promoted", false):
		return {"text": "PROMOTED TO %s" % _level_word(t.get("to_level", 0)).to_upper(),
			"color": Palette.GOLD}
	if int(t.get("to_level", 0)) < int(t.get("from_level", 0)):
		return {"text": "MOVED DOWN TO %s" % _level_word(t.get("to_level", 0)).to_upper(),
			"color": Palette.WHITE}
	if t.get("team_changed", false):
		return {"text": "SIGNED FOR %s" % _new_team_name(career), "color": Palette.WHITE}
	if t.get("beat", false):
		return {"text": "%s · TOUR %d CLEARED" %
			[_level_word(t.get("from_level", 0)).to_upper(), int(t.get("tour", 0)) + 1],
			"color": Palette.WHITE}
	return {"text": "MISSED OUT · ANOTHER GO", "color": Palette.WHITE_DIM}

func _new_team_name(career: CareerState) -> String:
	if career == null:
		return "A NEW TEAM"
	return career.teams[career.current_team_index].team_name.to_upper()
```

- [ ] **Step 4: Run the suite to verify green**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -6`
Expected: `All tests passed`, count climbed by 2 (782 → 784).

- [ ] **Step 5: Commit**

```bash
git add scenes/outcome/outcome.gd tests/unit/test_outcome_scene.gd
git commit -m "feat: Outcome banner reads the offers pick (moved down / signed for)"
```

---

### Task 5: Render harness + proof PNG

**Files:**
- Create: `tools/preview_offers.gd`
- Output: `docs/mockups/offers-v1.png`

- [ ] **Step 1: Create `tools/preview_offers.gd`** (pattern of `tools/preview_live_season_finish.gd` — WITH rendering, not `--headless`):

```gdscript
extends SceneTree

# Dev preview for the Offers screen (spec 2026-07-02): renders the season-end
# offer pick with a real drawn offer set (cross-up + down + same-Level rows).
# Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_offers.gd
# Output: docs/mockups/offers-v1.png

var _frames := 0

func _initialize() -> void:
	var career := CareerResolver.start_career(0)
	# Beat every Club climb tour -> a guaranteed cross-up offer; leave Club unwon
	# is impossible here, so hop the player to City with Club unwon for a DROP
	# DOWN row too? No — keep the canonical starter case: Club, readiness beaten.
	for t in range(CareerState.READINESS_TOUR):
		career.mark_beaten(0, t)
	var sr := SeasonResult.new()
	sr.beat = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260702 + 7
	var begin := CareerResolver.begin_live_advance(
		career, sr, 0, CareerState.READINESS_TOUR, rng)
	root.size = Vector2i(390, 844)
	var screen := load("res://scenes/offers/offers.tscn").instantiate()
	root.add_child(screen)
	screen.set_offers(career, begin["offers"])
	print("OFFERS: ", begin["offers"].size())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 8:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://docs/mockups/offers-v1.png"))
		print("SAVED docs/mockups/offers-v1.png")
		return true
	return false
```

(Note: the comment block inside `_initialize` must be cleaned to a single truthful line when writing the file — no self-argument comments. Use: `# Beat every Club climb tour -> the drawn set holds a guaranteed cross-up row.`)

- [ ] **Step 2: Import + render**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_offers.gd`
Expected: `SAVED docs/mockups/offers-v1.png`, process exits. Open the PNG (Read tool) and eyeball: kicker/title/current line/offer rows (gold STEP UP row first if drawn)/STAY row — nothing collapsed or invisible (the ScrollContainer/flat-button traps).

- [ ] **Step 3: Full suite once more**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -4`
Expected: `All tests passed` (784).

- [ ] **Step 4: Commit**

```bash
git add tools/preview_offers.gd tools/preview_offers.gd.uid docs/mockups/offers-v1.png
git commit -m "tools: Offers screen render harness + proof PNG"
```

---

### Task 6: PR + roadmap

- [ ] **Step 1:** Push the branch, open a PR titled "Offers screen — choose your team at season end", merge it (per the always-commit policy), sync local `main`, delete the branch.
- [ ] **Step 2:** Update `PROJECT_ROADMAP.md` — mark basic-gameplay item (2) done, write the new Session Handoff (next = item (3) around-the-match nav shell), commit + push on `main`.

## Self-review notes

- Spec coverage: DO1/DO2/DO5/DO7 → Task 3 · DO3/DO4/DO8 → Task 1 · DO6 → Task 2 · banner section → Task 4 · render proof → Task 5. No gaps.
- Type consistency: `begin` dict keys (`offers/beat/from_level/from_team_index/tour/complete`) match between Tasks 1 and 3; `offer_picked(offer)` arity matches Tasks 2 and 3; `set_offers(career, offers)` matches Tasks 2, 3, 5.
- Test-count arithmetic assumes the current 771; if the base differs, judge green by `All tests passed` + the count climbing by the task's delta.
