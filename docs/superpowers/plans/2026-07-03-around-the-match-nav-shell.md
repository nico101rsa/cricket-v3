# Around-the-Match Nav Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the three missing screens of ADR 0010's nav shell — Pre-Match, Result, Career Grid — and wire them into `main.gd`'s live routing, translating `docs/mockups/around-the-match-v1.html`.

**Architecture:** Three dumb, code-built screens on the `Palette`/`UIStyle`/`Fonts` foundation (clone the `scenes/offers/offers.gd` pattern: `.tscn` = bare root + script, `set_*()` renders given data, one signal out, no domain math beyond formatting). Routing changes live entirely in `scenes/main.gd`. Spec: `docs/superpowers/specs/2026-07-03-around-the-match-nav-shell-design.md` (DN1–DN10).

**Tech Stack:** Godot 4.6.3 / GDScript / GUT 9.6. Tabs. No emoji. Test cmd:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
After each new script: `--import` first. Red = parse error for the new `class_name`/scene; green = count climbs + `All tests passed`.

**Execution mode:** inline (executing-plans) — heavy shared-convention UI work; each slice = one PR to `main`.

---

## Slice 1 — Pre-Match screen (PR a)

### Task 1: Pre-Match scene

**Files:**
- Create: `scenes/pre_match/pre_match.gd`, `scenes/pre_match/pre_match.tscn`
- Test: `tests/unit/test_pre_match_scene.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# Pre-Match screen (nav-shell spec 2026-07-03, Slice 1): the versus moment
# between hub PLAY and the match. Dumb: renders SeasonView + opponent info,
# emits start_pressed. DN1 every number real; DN2 no home/away; DN4 no back.

const PreMatchScene = preload("res://scenes/pre_match/pre_match.tscn")

func _view() -> SeasonView:
	var v := SeasonView.new()
	v.team_name = "Cape Gulls"
	v.team_stars = 2.5
	v.tour_name = "Club Flat & Warm"
	v.country = Country.Code.SA
	v.player_name = "K. Mthembu"
	v.power = 40.0
	v.composure = 35.0
	v.attack = 30.0
	v.control = 20.0
	v.affinity = 3
	v.jokers = [{"id": "j1", "name": "Review Master", "rarity": "common"}]
	return v

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_versus_header_names_both_teams() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("Cape Gulls"), "your team named")
	assert_true(text.contains("Karoo Kings"), "opponent named")
	assert_true(text.contains("Match 4"), "league match number shown")

func test_stakes_and_conditions_lines() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("Top 4 advance"), "league stakes line")
	assert_true(text.contains("Club Flat & Warm"), "conditions = real tour name")

func test_playoff_stage_replaces_match_number() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(),
		{"name": "Karoo Kings", "team_index": 3, "stage": "semi"}, 3.5, 8)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("Semi-Final"), "semi named")
	assert_true(text.contains("Win to reach The Final"), "semi stakes line")

func test_captain_panel_shows_real_attrs_and_affinity() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("40"), "power value shown")
	assert_true(text.contains("K. Mthembu"), "player named")
	assert_true(text.contains("AFFINITY"), "affinity row present")

func test_danger_man_is_flavour_name_with_team_stars() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var danger = screen.find_child("DangerName", true, false)
	assert_not_null(danger, "danger-man label present")
	assert_eq(danger.text, PlayerNames.upper("Karoo Kings", Country.Code.SA, 0),
		"deterministic flavour surname")

func test_build_strip_counts_jokers() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("Review Master"), "owned joker named in build strip")

func test_cta_visible_and_emits_start() -> void:
	var screen = PreMatchScene.instantiate()
	add_child_autofree(screen)
	screen.set_matchup(_view(), {"name": "Karoo Kings", "team_index": 3}, 3.5, 4)
	await get_tree().process_frame
	var cta: Button = screen.find_child("StartBtn", true, false)
	assert_not_null(cta, "start button present")
	assert_true(cta.is_visible_in_tree(), "start button visible")
	assert_gt(cta.size.y, 0.0, "start button not collapsed")
	watch_signals(screen)
	cta.pressed.emit()
	assert_signal_emitted(screen, "start_pressed")
```

- [ ] **Step 2: Run to verify it fails** — `--import && <test cmd>`. Expected: `Parse Error` / scene-load failure for `pre_match.tscn` logged, count unchanged.

- [ ] **Step 3: Implement the scene**

`scenes/pre_match/pre_match.tscn`: root `Control` named `PreMatch`, full-rect, script attached (copy `offers.tscn` structure).

`scenes/pre_match/pre_match.gd`:

```gdscript
extends Control

# Pre-Match screen (nav-shell spec 2026-07-03, Slice 1; mockup section 2,
# Q2-locked single opponent portrait). The versus moment between hub PLAY and
# the match. Dumb: renders what it is given, emits start_pressed. DN1: every
# number real (attrs, stars, tour); the danger man is flavour-only. DN2: no
# home/away (the sim has none). DN4: no back — forward flow. No emoji.

signal start_pressed()

const MATCHES := 7   # league fixtures (stakes line denominator)

# view = the hub's SeasonView (real player/team/tour/joker data).
# opp = SeasonPlay.next_player_opponent() ({name, team_index[, stage]}).
# opp_stars = the opponent Team's stars. match_no = played_count()+1 (1-based).
func set_matchup(view: SeasonView, opp: Dictionary, opp_stars: float, match_no: int) -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(340, 0)
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	col.add_child(_versus_header(view, opp, opp_stars, match_no))
	col.add_child(_line("Stakes", _stakes_text(opp, match_no), Palette.GOLD, 12))
	col.add_child(_line("Conditions", view.tour_name, Palette.WHITE_DIM, 11))
	col.add_child(_panels(view, opp))
	col.add_child(_build_strip(view))

	var cta := Button.new()
	cta.name = "StartBtn"
	cta.text = "TAP TO START"
	cta.custom_minimum_size = Vector2(0, 52)
	for state in ["normal", "hover", "pressed"]:
		cta.add_theme_stylebox_override(state, UIStyle.cta(Palette.GOLD))
	cta.add_theme_color_override("font_color", Palette.BG)
	cta.add_theme_font_size_override("font_size", 16)
	Fonts.weigh(cta, Fonts.W_HEADLINE)
	cta.pressed.connect(func(): start_pressed.emit())
	col.add_child(cta)

# You | VS | them — team names + star strings + the match tag.
func _versus_header(view: SeasonView, opp: Dictionary, opp_stars: float, match_no: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_versus_side("YOU PLAY FOR", view.team_name, _stars(view.team_stars), true))
	var vs := _lbl("VS", 22, Palette.GOLD, Fonts.W_HEADLINE)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vs)
	row.add_child(_versus_side(_match_tag(opp, match_no), str(opp.get("name", "")), _stars(opp_stars), false))
	return row

func _versus_side(kicker: String, team: String, stars: String, left: bool) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var a := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	for spec in [[kicker, 9, Palette.WHITE_DIM, Fonts.W_LABEL],
			[team, 16, Palette.WHITE, Fonts.W_HEADLINE],
			[stars, 11, Palette.GOLD, Fonts.W_MEDIUM]]:
		var l := _lbl(spec[0], spec[1], spec[2], spec[3])
		l.horizontal_alignment = a
		v.add_child(l)
	return v

func _match_tag(opp: Dictionary, match_no: int) -> String:
	match opp.get("stage", ""):
		"semi": return "SEMI-FINAL"
		"final": return "THE FINAL"
		"third": return "3RD-PLACE MATCH"
		_: return "MATCH %d" % match_no

func _stakes_text(opp: Dictionary, match_no: int) -> String:
	match opp.get("stage", ""):
		"semi": return "Semi-Final · Win to reach The Final"
		"final": return "The Final · Winner takes the season"
		"third": return "3rd-Place Match"
		_: return "League Match %d of %d · Top 4 advance" % [match_no, MATCHES]

# Your captain (real attrs + affinity) vs their danger man (flavour name + team stars).
func _panels(view: SeasonView, opp: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var you := _panel_box("YOUR CAPTAIN")
	you.get_child(0).add_child(_lbl(view.player_name, 14, Palette.WHITE, Fonts.W_BOLD))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	for pair in [["POW", view.power], ["COM", view.composure],
			["ATK", view.attack], ["CTL", view.control]]:
		var cell := VBoxContainer.new()
		cell.add_child(_lbl("%d" % int(round(pair[1])), 13, Palette.WHITE, Fonts.W_BOLD))
		cell.add_child(_lbl(pair[0], 8, Palette.WHITE_DIM, Fonts.W_LABEL))
		grid.add_child(cell)
	you.get_child(0).add_child(grid)
	you.get_child(0).add_child(_lbl("AFFINITY %d" % view.affinity, 9, Palette.WHITE_DIM, Fonts.W_LABEL))
	row.add_child(you)
	var them := _panel_box("THEIR DANGER MAN")
	var danger := _lbl(PlayerNames.upper(str(opp.get("name", "")), view.country, 0),
		14, Palette.WHITE, Fonts.W_BOLD)
	danger.name = "DangerName"
	them.get_child(0).add_child(danger)
	row.add_child(them)
	return row

func _panel_box(kicker: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UIStyle.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(_lbl(kicker, 9, Palette.WHITE_DIM, Fonts.W_LABEL))
	p.add_child(v)
	return p

func _build_strip(view: SeasonView) -> Control:
	var names: Array = []
	for j in view.jokers:
		names.append(str(j.get("name", "")))
	var txt := "BUILD · " + (" · ".join(names) if not names.is_empty() else "no jokers")
	var strip := _line("", txt + " · BOOST READY", Palette.WHITE_DIM, 10)
	return strip

func _line(_cap: String, txt: String, col: Color, size: int) -> Label:
	var l := _lbl(txt, size, col, Fonts.W_MEDIUM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l

func _lbl(txt: String, size: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	Fonts.weigh(l, weight)
	return l

func _stars(stars: float) -> String:
	var n := int(round(stars))
	return "★".repeat(maxi(n, 1)) + " · %.1f" % stars
```

(Adjust against the real `Fonts.weigh` weight constants and stars conventions of `season_hub.gd` while building — reuse, don't fork.)

- [ ] **Step 4: `--import && <test cmd>`** — expected: count +7, `All tests passed`.

- [ ] **Step 5: Commit** — `git add scenes/pre_match/ tests/unit/test_pre_match_scene.gd && git commit -m "feat: Pre-Match screen (versus moment, in-house skin)"` (remember `pre_match.gd.uid`; the test has no `.uid`).

### Task 2: Route hub PLAY through Pre-Match

**Files:**
- Modify: `scenes/main.gd:75-98` (`_play_next`)

- [ ] **Step 1: Split `_play_next`** — everything after the Kit Room gate moves into `_start_match(play, career, team_index)`; `_play_next` instead pushes Pre-Match and connects `start_pressed` to it. The hub is freed by `_push`, so capture `play`/`career`/`team_index` first (established closure pattern):

```gdscript
const PRE_MATCH := preload("res://scenes/pre_match/pre_match.tscn")

func _play_next(team_index: int) -> void:
	var hub = _slot.get_child(0)
	var play: SeasonPlay = hub.live_play()
	if play == null or play.next_player_opponent().is_empty():
		return
	var career: CareerState = hub.current_career()
	if not play.pending_shop_visit().is_empty():
		_show_kit_room(play, career)
		return
	var view: SeasonView = hub.current_view()
	var opp_info := play.next_player_opponent()
	var opp_team: Team = career.opponents_of_current()[team_index - 1]
	var screen := PRE_MATCH.instantiate()
	screen.start_pressed.connect(func(): _start_match(play, career, team_index))
	_push(screen)
	screen.set_matchup(view, opp_info, opp_team.stars, play.played_count() + 1)

# The body that used to follow the Kit Room gate — builds the session and
# pushes the interactive match. Unchanged except the hub reads moved up.
func _start_match(play: SeasonPlay, career: CareerState, team_index: int) -> void:
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[team_index - 1]
	var session := play.make_session()
	var screen := INTERACTIVE_MATCH.instantiate()
	screen.back.connect(func(): _commit_and_return(play, session, career))
	_push(screen)
	screen.set_session(session, team.team_name, opp.team_name,
		team.stars, opp.stars, Country.Code.SA, Country.Code.AUS)
	screen.boot()
```

- [ ] **Step 2: Full suite green** (routing is exercised by eyeball; no headless main test exists — precedent).
- [ ] **Step 3: Commit** — `feat: hub PLAY routes through the Pre-Match screen`.

### Task 3: Pre-Match render harness + eyeball + PR

**Files:**
- Create: `tools/preview_pre_match.gd` (clone `tools/preview_offers.gd`: build a real career + SeasonPlay, push the screen in a 390×844 window, screenshot both league and semi states)

- [ ] **Step 1: Harness renders `docs/mockups/pre-match-v1.png`** (+ `pre-match-semi-v1.png`).
- [ ] **Step 2: Eyeball in a real window** (flat-button/ScrollContainer traps).
- [ ] **Step 3: Full suite green; commit; PR "Pre-Match screen (nav shell slice 1)"; merge; sync main; re-branch for slice 2.**

---

## Slice 2 — Result screen (PR b)

### Task 4: `SeasonPlay.pay_context()` (read-only getter)

**Files:**
- Modify: `scripts/domain/season_play.gd` (after `pay_player()`)
- Test: `tests/unit/test_season_play.gd` (append)

- [ ] **Step 1: Failing test**

```gdscript
func test_pay_context_exposes_settle_inputs() -> void:
	var play := _play_with_pay()   # reuse the file's existing enable_pay fixture helper
	var ctx := play.pay_context()
	assert_eq(ctx["level"], 0, "level exposed")
	assert_eq(ctx["tour"], 0, "tour exposed")
	assert_true(ctx["stars"] > 0.0, "stars exposed")
	assert_not_null(ctx["etun"], "economy tuning exposed")
```

(Match the file's existing fixture names when appending — reuse its `enable_pay` setup.)

- [ ] **Step 2: Red (missing method).**
- [ ] **Step 3: Implement**

```gdscript
# The _settle inputs, read-only — lets the Result screen recompute the pay
# breakdown for display with the exact ints _settle banked (nav-shell spec
# 2026-07-03, Slice 2). {} until enable_pay().
func pay_context() -> Dictionary:
	if _etun == null:
		return {}
	return {"stars": _pay_stars, "level": _pay_level, "tour": _pay_tour, "etun": _etun}
```

- [ ] **Step 4: Green. Commit** — `feat: SeasonPlay.pay_context() read-only settle inputs`.

### Task 5: Result scene

**Files:**
- Create: `scenes/result/result.gd`, `scenes/result/result.tscn`
- Test: `tests/unit/test_result_scene.gd`

- [ ] **Step 1: Failing test**

```gdscript
extends GutTest

# Result screen (nav-shell spec 2026-07-03, Slice 2; mockup section 5): the
# post-match payoff — verdict, scoreline, your numbers, the tons earned, and a
# handoff CTA naming the destination. DN7: no KM recap / delta bars (not in the
# domain). DN5: champion variant on a Final win. No emoji.

const ResultScene = preload("res://scenes/result/result.tscn")

func _mr(player_won := true) -> MatchResult:
	var bat := InningsResult.new(174, 6, 120, [], [
		{"is_player": true, "runs": 68, "balls": 41, "out": false}])
	var bowl := InningsResult.new(151, 8, 120, [], [], 1, 19, 24)
	var m := MatchResult.new()
	m.innings1 = bat
	m.innings2 = bowl
	m.player_bats_first = true
	m.outcome = MatchResult.Outcome.PLAYER_WIN if player_won else MatchResult.Outcome.OPPONENT_WIN
	m.margin_runs = 23
	return m

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func _pay() -> Dictionary:
	return {"base": 50, "perf": 18, "prize": 0, "total": 68}

func test_verdict_scoreline_and_perf_grid() -> void:
	var screen = ResultScene.instantiate()
	add_child_autofree(screen)
	screen.set_result(_mr(), "Cape Gulls", "Karoo Kings", 4, "", _pay(), 1308, "", {})
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("You won by 23 runs"), "verdict from result_line_for_player")
	assert_true(text.contains("174/6"), "your scoreline")
	assert_true(text.contains("151/8"), "their scoreline")
	assert_true(text.contains("68"), "runs tile")
	assert_true(text.contains("165"), "strike rate tile (68 off 41)")
	assert_true(text.contains("1/19"), "bowling figures wickets/runs")

func test_tons_earned_breakdown_and_bank() -> void:
	var screen = ResultScene.instantiate()
	add_child_autofree(screen)
	screen.set_result(_mr(), "Cape Gulls", "Karoo Kings", 4, "",
		{"base": 50, "perf": 18, "prize": 55, "total": 123}, 1308, "", {})
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("base 50 + perf 18"), "pay breakdown")
	assert_true(text.contains("win prize 55"), "win prize named on a win")
	assert_true(text.contains("1,308") or text.contains("1308"), "bank total shown")

func test_cta_names_destination_and_emits() -> void:
	var screen = ResultScene.instantiate()
	add_child_autofree(screen)
	screen.set_result(_mr(), "Cape Gulls", "Karoo Kings", 4, "", _pay(), 0, "KIT ROOM", {})
	await get_tree().process_frame
	var cta: Button = screen.find_child("ContinueBtn", true, false)
	assert_not_null(cta)
	assert_true(cta.is_visible_in_tree() and cta.size.y > 0.0, "CTA visible")
	assert_true(cta.text.contains("KIT ROOM"), "destination named")
	watch_signals(screen)
	cta.pressed.emit()
	assert_signal_emitted(screen, "continue_pressed")

func test_champion_panel_only_on_final_win() -> void:
	var screen = ResultScene.instantiate()
	add_child_autofree(screen)
	screen.set_result(_mr(), "Cape Gulls", "Karoo Kings", 0, "final", _pay(), 0,
		"SEASON END", {"level_word": "Club", "tour_name": "Club Premier"})
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("CHAMPIONS"), "champion banner on Final win")
	var plain = ResultScene.instantiate()
	add_child_autofree(plain)
	plain.set_result(_mr(), "Cape Gulls", "Karoo Kings", 4, "", _pay(), 0, "", {})
	await get_tree().process_frame
	assert_false(_all_label_text(plain).contains("CHAMPIONS"), "no banner on a league win")

func test_loss_verdict_is_red_styled_text() -> void:
	var screen = ResultScene.instantiate()
	add_child_autofree(screen)
	screen.set_result(_mr(false), "Cape Gulls", "Karoo Kings", 4, "", _pay(), 0, "", {})
	await get_tree().process_frame
	assert_true(_all_label_text(screen).contains("Opponent won by"), "loss names the opponent")
```

(`InningsResult.new` positional args — pin to the real `_init` signature when writing; the bowl innings carries `player_bowl_wickets=1, player_bowl_runs=19, player_bowl_balls=24`.)

- [ ] **Step 2: Red.**
- [ ] **Step 3: Implement `scenes/result/result.gd`**

```gdscript
extends Control

# Result screen (nav-shell spec 2026-07-03, Slice 2; mockup section 5). The
# post-match payoff moment: verdict, broadcast scoreline, the Player's numbers,
# the tons earned (base + perf [+ win prize] = total, bank), and a handoff CTA
# that names where Continue goes (Kit Room / season end / hub). Dumb: renders
# what it is given. DN5 champion variant on a Final win; DN7 no KM recap or
# delta bars (no such domain concepts). No emoji.

signal continue_pressed()

# mr: the committed match. match_no: 1-based league number (0 in playoffs).
# stage: "" | "semi" | "final" | "third". pay: {"base","perf","prize","total"}
# (prize 0 on a loss). bank: Player.tons_balance after banking. dest: "" |
# "KIT ROOM" | "SEASON END". champion: {} or {level_word, tour_name} (DN5).
func set_result(mr: MatchResult, team_name: String, opp_name: String,
		match_no: int, stage: String, pay: Dictionary, bank: int,
		dest: String, champion: Dictionary) -> void:
	# kicker "MATCH 4 · RESULT" (or stage word) → verdict (green/red W_HEADLINE,
	# mr.result_line_for_player().to_upper()) → scoreline row (both teams,
	# "%d/%d (%s ov)" via _overs) → champion gold panel when champion not empty
	# ("CHAMPIONS · CLUB · CLUB PREMIER" + "Season beaten") → perf grid
	# (Runs/Balls/SR/Bowl tiles from mr player line + player_bowl_*) → tons panel
	# ("+%d" gold hero, "base %d + perf %d [+ win prize %d]" and "bank now %s")
	# → ContinueBtn ("CONTINUE" or "CONTINUE — %s" % dest), gold CTA, emits
	# continue_pressed. Layout/factory pattern identical to offers.gd
	# (_lbl/_panel_box helpers, CenterContainer + 340px VBox).
	...

```

Full bodies follow the offers.gd factory pattern (see Task 1's helpers — same `_lbl`, panel, CTA construction). Perf values: bat line = the innings where `player_line()` is non-empty; SR = `int(round(runs * 100.0 / balls))`; bowling = `"%d/%d" % [player_bowl_wickets, player_bowl_runs]` (wickets/runs convention). Thousands separator for bank via `String.num_int64` formatting helper (simple manual insert — no locale API).

- [ ] **Step 4: `--import && <test cmd>` green. Commit** — `feat: the Result screen (verdict / scoreline / tons earned, in-house skin)`.

### Task 6: Route match-back through Result + relabel in-match CTA

**Files:**
- Modify: `scenes/main.gd` (`_play_next`/`_start_match` closure gains `stage`; `_commit_and_return` pushes Result; new `_after_result` holds the old fork)
- Modify: `scenes/interactive_match/interactive_match.gd:853` (`"PLAY AGAIN ▶"` → `"CONTINUE ▶"`)

- [ ] **Step 1: `_commit_and_return` becomes:** commit + persist player (existing code, unchanged), then compute display context and push Result; the old kit-room/season-end/hub fork moves verbatim into `_after_result(play, career)` and is connected to `continue_pressed`:

```gdscript
const RESULT := preload("res://scenes/result/result.tscn")

func _commit_and_return(play: SeasonPlay, session: MatchSession, career: CareerState) -> void:
	var stage := str(play.next_player_opponent().get("stage", ""))   # read BEFORE commit
	var match_no := play.played_count() + 1
	play.commit_player_result(session.result(), session.export_decisions())
	var player: Player = play.pay_player()
	if player == null:
		player = SaveManager.load_player()
	if player != null:
		SaveManager.save_player(player)
	var mr := session.result()
	var pay := _display_pay(play, mr)
	var dest := ""
	if play.season_done():
		dest = "SEASON END"
	elif not play.pending_shop_visit().is_empty():
		dest = "KIT ROOM"
	var champion := {}
	if stage == "final" and mr.player_won():
		var cell := CareerResolver.next_live_cell(career)
		champion = {"level_word": ["Club", "City", "Province"][cell["level"]],
			"tour_name": DifficultyLadder.TOUR_NAMES[cell["tour"]]}
	var team: Team = career.teams[career.current_team_index]
	var opp_name := ""   # capture at _start_match time and pass through (see step 2)
	var screen := RESULT.instantiate()
	screen.continue_pressed.connect(func(): _after_result(play, career))
	_push(screen)
	screen.set_result(mr, team.team_name, opp_name, (0 if stage != "" else match_no),
		stage, pay, (player.tons_balance if player != null else 0), dest, champion)

# Display-only recompute of what _settle banked (same pure functions, same ints).
func _display_pay(play: SeasonPlay, mr: MatchResult) -> Dictionary:
	var ctx := play.pay_context()
	if ctx.is_empty():
		return {"base": 0, "perf": 0, "prize": 0, "total": 0}
	var p: Dictionary = Economy.match_pay(mr, ctx["stars"], ctx["etun"])
	var prize := 0
	if mr.player_won():
		prize = Economy.match_win_prize(ctx["level"], ctx["tour"], ctx["etun"])
	return {"base": p["base"], "perf": p["perf"], "prize": prize, "total": p["total"] + prize}

func _after_result(play: SeasonPlay, career: CareerState) -> void:
	# ← the entire old post-persist body of _commit_and_return, verbatim:
	# season_done? carry-over election / _finish_live_season : save + kit-room/hub.
	...
```

**Watch-outs:** `stage`/`match_no` must be read **before** `commit_player_result` (commit advances the fixture pointer); `opp_name` is captured in `_start_match`'s closure and passed as a parameter (`_commit_and_return(play, session, career, opp_name)`). The champion cell must be derived before `_after_result` runs the advance (it is — `_finish_live_season` only runs on Continue).

- [ ] **Step 2: Thread `opp_name` through the `_start_match` closure.**
- [ ] **Step 3: Relabel the in-match result CTA** `"PLAY AGAIN ▶"` → `"CONTINUE ▶"`.
- [ ] **Step 4: Full suite green** (existing tests must be untouched — commit/persist order is unchanged).
- [ ] **Step 5: Commit** — `feat: match hands off through the Result screen (tons earned, named destination)`.

### Task 7: Result harness + eyeball + PR

- [ ] Create `tools/preview_result.gd` → `docs/mockups/result-v1.png` (league win) + `result-final-v1.png` (champion variant). Eyeball in a real window. Full suite green. PR "Result screen (nav shell slice 2)"; merge; sync; re-branch.

---

## Slice 3 — Career Grid screen (PR c)

### Task 8: Ladder map widget

**Files:**
- Create: `scenes/career_grid/ladder_map.gd` (`class_name LadderMap`, custom `_draw` — RunRateChart precedent)
- Test: `tests/unit/test_ladder_map.gd`

- [ ] **Step 1: Failing test**

```gdscript
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
```

- [ ] **Step 2: Red (`Identifier "LadderMap" not declared`).**
- [ ] **Step 3: Implement**

```gdscript
class_name LadderMap
extends Control

# The career map (nav-shell spec 2026-07-03, Slice 3): 3 Levels × 8 Tours as
# rising diagonals — each Level a bottom-left→up-right row, the next Level
# starting at the left at the height the previous topped out (mockup Q3 reco).
# Node states from CareerState.cell_status; the current cell pulses in the
# accent. Pure presentation — reads, never mutates.

const LEVELS := 3
const TOURS := 8
const R := 9.0            # node radius
const PAD := Vector2(26, 20)

var _status: Array = []
var _level_won: Array = []
var _current := {}
var _accent: Color = Palette.GOLD

func set_state(cell_status: Array, level_won: Array, current: Dictionary,
		accent: Color = Palette.GOLD) -> void:
	_status = cell_status.duplicate()
	_level_won = level_won.duplicate()
	_current = current
	_accent = accent
	queue_redraw()

func current_cell() -> Dictionary:
	return _current

# Geometry: the full climb spans the widget height; each Level's diagonal rises
# rise_per_level; level L's row starts at the height level L-1 ended.
func node_center(level: int, tour: int) -> Vector2:
	var w := size.x - PAD.x * 2.0
	var h := size.y - PAD.y * 2.0
	var rise_per_level := h / float(LEVELS)
	var x := PAD.x + w * float(tour) / float(TOURS - 1)
	var base_y := size.y - PAD.y - rise_per_level * float(level)
	var y := base_y - rise_per_level * float(tour) / float(TOURS - 1)
	return Vector2(x, y)

func _draw() -> void:
	if _status.is_empty():
		return
	for lvl in range(LEVELS):
		for t in range(TOURS - 1):
			draw_line(node_center(lvl, t), node_center(lvl, t + 1),
				Palette.WHITE_DIM * Color(1, 1, 1, 0.35), 2.0)
		if lvl < LEVELS - 1:   # promotion link: level top → next level start
			draw_line(node_center(lvl, TOURS - 1), node_center(lvl + 1, 0),
				_accent * Color(1, 1, 1, 0.5), 2.0)
	for lvl in range(LEVELS):
		for t in range(TOURS):
			_draw_node(lvl, t)

func _draw_node(lvl: int, t: int) -> void:
	var c := node_center(lvl, t)
	var status: int = _status[lvl * TOURS + t]
	var here: bool = (not _current.is_empty()
		and _current.get("level", -1) == lvl and _current.get("tour", -1) == t)
	if here:
		draw_circle(c, R + 3.0, _accent * Color(1, 1, 1, 0.35))
		draw_circle(c, R, _accent)
	elif t == TOURS - 1 and lvl < _level_won.size() and _level_won[lvl]:
		draw_circle(c, R, Palette.GOLD)          # Premier won: gold
	elif status == CareerState.CellStatus.BEATEN:
		draw_circle(c, R, Palette.GREEN)
		_draw_check(c)
	elif status == CareerState.CellStatus.UNLOCKED:
		draw_arc(c, R, 0.0, TAU, 24, Palette.WHITE, 2.0)
	else:
		draw_circle(c, R * 0.55, Palette.WHITE_DIM * Color(1, 1, 1, 0.3))

func _draw_check(c: Vector2) -> void:
	var col := Palette.BG
	draw_line(c + Vector2(-4, 0), c + Vector2(-1, 3), col, 2.0)
	draw_line(c + Vector2(-1, 3), c + Vector2(4, -3), col, 2.0)
```

- [ ] **Step 4: `--import && <test cmd>` green (new class_name → import first). Commit** — `feat: LadderMap career-map widget (diagonal ladder)`.

### Task 9: Career Grid scene

**Files:**
- Create: `scenes/career_grid/career_grid.gd`, `scenes/career_grid/career_grid.tscn`
- Test: `tests/unit/test_career_grid_scene.gd`

- [ ] **Step 1: Failing test**

```gdscript
extends GutTest

# Career Grid screen (nav-shell spec 2026-07-03, Slice 3): the between-Seasons
# home (ADR 0010) — career header, the ladder map, START SEASON. DN8: no node
# picking (the domain plays exactly next_live_cell). DN9: no career-stats
# block (no career aggregates exist). Header counters are all real.

const GridScene = preload("res://scenes/career_grid/career_grid.tscn")

func _all_label_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += " " + node.text
	for c in node.get_children():
		out += _all_label_text(c)
	return out

func test_header_shows_real_career_counters() -> void:
	var screen = GridScene.instantiate()
	add_child_autofree(screen)
	var c := CareerResolver.start_career(0)
	c.seasons_played = 7
	var p := Player.new()
	p.tons_balance = 1520
	p.country = Country.Code.SA
	screen.set_career(c, p)
	await get_tree().process_frame
	var text := _all_label_text(screen)
	assert_true(text.contains("South Africa"), "country named")
	assert_true(text.contains("7"), "seasons played")
	assert_true(text.contains(c.teams[c.current_team_index].team_name), "current team")
	assert_true(text.contains("0 / 3"), "levels won")
	assert_true(text.contains("1,520") or text.contains("1520"), "tons balance")

func test_ladder_map_present_and_not_collapsed() -> void:
	var screen = GridScene.instantiate()
	add_child_autofree(screen)
	screen.set_career(CareerResolver.start_career(0), Player.new())
	await get_tree().process_frame
	var map = screen.find_child("Map", true, false)
	assert_not_null(map, "ladder map mounted")
	assert_true(map.is_visible_in_tree(), "map visible")
	assert_gt(map.size.y, 0.0, "map not collapsed")

func test_cta_names_the_next_cell_and_emits() -> void:
	var screen = GridScene.instantiate()
	add_child_autofree(screen)
	screen.set_career(CareerResolver.start_career(0), Player.new())
	await get_tree().process_frame
	var cta: Button = screen.find_child("StartBtn", true, false)
	assert_not_null(cta)
	assert_true(cta.text.contains("CLUB"), "level named on the CTA")
	assert_true(cta.text.contains("FLAT & WARM"), "tour named on the CTA")
	watch_signals(screen)
	cta.pressed.emit()
	assert_signal_emitted(screen, "start_season")
```

- [ ] **Step 2: Red.**
- [ ] **Step 3: Implement `career_grid.gd`** — offers.gd pattern: header panel (country display name via `Country.display_name`, ₸ via the same formatting helper as Result, three counter tiles), a `LadderMap` named `Map` (`custom_minimum_size = Vector2(340, 300)` — the collapse trap), legend row (ColorRect swatches + labels: BEATEN green / WON gold / HERE accent / LOCKED dim — swatches, not glyphs), gold `StartBtn` `"START SEASON — %s · %s" % [level_word.to_upper(), TOUR_NAMES[tour].to_upper()]`, emitting `start_season()`.

- [ ] **Step 4: Green. Commit** — `feat: Career Grid screen (between-season home, in-house skin)`.

### Task 10: Between-seasons routing

**Files:**
- Modify: `scenes/main.gd` (`_ready`, `_on_build_confirmed` picker hookup, `_show_outcome`)

- [ ] **Step 1: Add `_push_career_grid` and reroute:**

```gdscript
const CAREER_GRID := preload("res://scenes/career_grid/career_grid.tscn")

func _ready() -> void:
	LifecycleManager.career_ended.connect(_on_career_ended)
	if not SaveManager.has_player():
		_start_creation()
	elif SaveManager.has_live_season():
		_push_hub()            # mid-season resume, unchanged
	else:
		_push_career_grid()    # between seasons: the career map is home (ADR 0010)

# The between-Seasons home. Read-only: create-if-absent mirrors hub.boot's
# career bootstrapping (DN10) so a fresh career renders without booting a
# season; the season itself still only starts on hub.boot().
func _push_career_grid() -> void:
	var player := SaveManager.load_player()
	var career: CareerState = SaveManager.load_career() if SaveManager.has_career() \
		else CareerResolver.start_career(0)
	SaveManager.save_career(career)
	var screen := CAREER_GRID.instantiate()
	screen.start_season.connect(_push_hub)
	_push(screen)
	screen.set_career(career, player)
```

- Starting-team picker: `picker.proceed_to_season.connect(_push_career_grid)` (was `_push_hub`).
- Outcome: `screen.continue_pressed.connect(_push_career_grid)` on the not-complete branch (was `_push_hub`); the career-complete branch keeps `LifecycleManager.win_out()`.

- [ ] **Step 2: Full suite green** (hub.boot untouched — resume path byte-identical).
- [ ] **Step 3: Commit** — `feat: Career Grid is the between-seasons home (boot + outcome routing)`.

### Task 11: Grid harness + eyeball + full-game launch + PR

- [ ] Create `tools/preview_career_grid.gd` → `docs/mockups/career-grid-v1.png` (mid-career state: some beaten cells + a won level, so all node states render). Eyeball in a real window.
- [ ] **Whole-flow eyeball:** launch the real game (`/Applications/Godot.app/Contents/MacOS/Godot --path .`) and walk grid → start season → hub → PLAY → Pre-Match → match → Result → hub.
- [ ] Full suite green. PR "Career Grid screen + between-season routing (nav shell slice 3)"; merge; sync main.
- [ ] Update `PROJECT_ROADMAP.md` (rung closed; next = basic-gameplay item (4) Outcome hi-fi) and commit.

---

## Self-review notes

- Spec coverage: Slice 1 → Tasks 1–3; Slice 2 → Tasks 4–7 (incl. the PLAY AGAIN relabel and pay_context plumbing); Slice 3 → Tasks 8–11; deferred list needs no tasks. Routing spec points (Kit Room gate before Pre-Match; persist order unchanged in `_commit_and_return`; career-complete skips grid) are embedded in Tasks 2/6/10.
- Type consistency: `set_matchup(view, opp, opp_stars, match_no)` / `set_result(mr, team_name, opp_name, match_no, stage, pay, bank, dest, champion)` / `set_career(career, player)` / `set_state(cell_status, level_won, current, accent)` used consistently.
- Known code-time pins (flagged, not placeholders): `InningsResult.new` positional signature; the exact `Palette` constant names (`WHITE_DIM`, `GREEN`, `RED`, `GOLD`, `BG`); `Fonts` weight constants; `preview_offers.gd` harness shape. Each is "open the named file and match it" — the file is named in the task.
