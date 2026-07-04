# Scorecard Moments (T10) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mini scorecard strip at match orientation points + a full-scorecard innings-break pause with commentary, on the interactive match screen (spec `docs/superpowers/specs/2026-07-04-scorecard-moments-design.md`, DSC1–DSC10).

**Architecture:** Two pure static read-model functions on `MatchViewBuilder` (`moment_at`, `build_scorecard`) derived from the existing event stream / innings card — nothing added to the stream (DSC1). The scene adds one hidden strip panel above the dock and a third overlay via the existing `_make_overlay_root()` skeleton.

**Tech Stack:** Godot 4.6.3 / GDScript / GUT 9.6. Tabs. Whole-suite runs only (`-gdir=res://tests/unit`); red = parse error or failing assert, green = count climbs + `All tests passed`.

**Test command (every step):**
```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
New scripts under `scripts/` need `--import` once first; test files do NOT get `.uid`s (add only the `.gd`).

---

### Task 1: `MatchViewBuilder.moment_at` (mini-moment triggers, DSC2/DSC3)

**Files:**
- Test: `tests/unit/test_scorecard_moments.gd` (create)
- Modify: `scripts/domain/match_view_builder.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

# T10 scorecard moments (spec 2026-07-04 DSC2/3/7/8/9): moment_at triggers +
# build_scorecard. Uses a real MatchSession so every trigger sits on real data.

func _mk() -> MatchSession:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	return MatchSession.start(a, team, opp, tour, 20260615, 1)

func _first_cursor(ev: Array, innings: int, pred: Callable) -> int:
	for i in range(ev.size()):
		var e: Dictionary = ev[i]
		if e["type"] != "ball" and e["type"] != "over": continue
		if e["innings"] != innings: continue
		if pred.call(e): return i + 1
	return -1

func test_you_bat_fires_at_first_player_batting_event():
	var s := _mk()
	var ev := s.events()
	for innings in [1, 2]:
		var c := _first_cursor(ev, innings, func(e): return e["type"] == "ball" and e.get("player_batting", false))
		if c == -1: continue
		var m := MatchViewBuilder.moment_at(s.result(), s.player(), c)
		assert_eq(m.get("kind", ""), "you_bat", "you_bat fires at the Player's first batting ball (innings %d)" % innings)
		assert_ne(m.get("title", ""), "", "strip title present")

func test_you_bowl_fires_at_first_player_bowling_event():
	var s := _mk()
	var ev := s.events()
	for innings in [1, 2]:
		var c := _first_cursor(ev, innings, func(e): return e["type"] == "ball" and e.get("player_bowling", false))
		if c == -1: continue
		var m := MatchViewBuilder.moment_at(s.result(), s.player(), c)
		assert_eq(m.get("kind", ""), "you_bowl", "you_bowl fires at the Player's first bowling ball (innings %d)" % innings)

func test_powerplay_fires_only_at_innings1_start_when_not_a_player_ball():
	var s := _mk()
	var ev := s.events()
	var e0: Dictionary = ev[0]
	var m1 := MatchViewBuilder.moment_at(s.result(), s.player(), 1)
	if e0["type"] == "ball" and (e0.get("player_batting", false) or e0.get("player_bowling", false)):
		assert_true(m1["kind"] in ["you_bat", "you_bowl"], "player involvement outranks powerplay (DSC2)")
	else:
		assert_eq(m1.get("kind", ""), "powerplay", "powerplay fires at cursor 1")
	# never in innings 2 (DSC3)
	for i in range(ev.size()):
		var m := MatchViewBuilder.moment_at(s.result(), s.player(), i + 1)
		if m.get("kind", "") == "powerplay":
			assert_eq(ev[i]["innings"], 1, "powerplay strip is innings-1 only")

func test_death_fires_at_first_over16_event_per_innings():
	var s := _mk()
	var ev := s.events()
	for innings in [1, 2]:
		var c := _first_cursor(ev, innings, func(e): return e.get("over", 0) >= 16)
		if c == -1: continue
		var m := MatchViewBuilder.moment_at(s.result(), s.player(), c)
		# a same-cursor player-involvement collision legitimately outranks death (DSC2)
		if m.get("kind", "") in ["you_bat", "you_bowl"]: continue
		assert_eq(m.get("kind", ""), "death", "death strip at over 16 (innings %d)" % innings)

func test_each_kind_fires_at_most_once_per_innings_and_non_ball_events_are_empty():
	var s := _mk()
	var ev := s.events()
	var counts := {}
	for i in range(ev.size()):
		var m := MatchViewBuilder.moment_at(s.result(), s.player(), i + 1)
		var t: String = ev[i]["type"]
		if t == "innings_break" or t == "result":
			assert_true(m.is_empty(), "no strip on %s events" % t)
		if m.is_empty(): continue
		var key := "%s|%d" % [m["kind"], ev[i]["innings"]]
		counts[key] = counts.get(key, 0) + 1
	for key in counts:
		assert_eq(counts[key], 1, "%s fires exactly once" % key)
```

- [ ] **Step 2: Run the suite — expect red** (parse error: `moment_at` not declared / not found on `MatchViewBuilder` → GUT logs the failure).

- [ ] **Step 3: Implement `moment_at`** — append to `scripts/domain/match_view_builder.gd`:

```gdscript
# --- T10 scorecard moments (spec 2026-07-04 DSC2/DSC3) ------------------------
# Mini-moment strip trigger for the event just applied (index cursor-1). Derived
# from the stream, never injected into it (DSC1). First-crossing per innings per
# kind; precedence you_bat/you_bowl > powerplay > death. {} = no strip.

const DEATH_FROM_OVER := 16
const _MOMENT_KINDS := ["you_bat", "you_bowl", "powerplay", "death"]
const _MOMENT_COPY := {
	"you_bat": ["YOU'RE IN", "Time to bat"],
	"you_bowl": ["YOU'RE ON", "Your spell begins"],
	"powerplay": ["POWERPLAY", "Field up - first 6 overs"],
	"death": ["FINAL 5 OVERS", "Death overs begin"],
}

static func _moment_matches(e: Dictionary, kind: String) -> bool:
	if e["type"] != "ball" and e["type"] != "over":
		return false
	match kind:
		"you_bat": return e["type"] == "ball" and e.get("player_batting", false)
		"you_bowl": return e["type"] == "ball" and e.get("player_bowling", false)
		"powerplay": return e["innings"] == 1   # first innings-1 event = powerplay start (DSC3)
		"death": return e.get("over", 0) >= DEATH_FROM_OVER
	return false

static func moment_at(mr: MatchResult, player: Player, cursor: int) -> Dictionary:
	var events := build_events(mr, player)
	if cursor < 1 or cursor > events.size():
		return {}
	var e: Dictionary = events[cursor - 1]
	if e["type"] != "ball" and e["type"] != "over":
		return {}
	var innings: int = e["innings"]
	for kind in _MOMENT_KINDS:
		if not _moment_matches(e, kind):
			continue
		var seen := false
		for k in range(cursor - 1):
			var p: Dictionary = events[k]
			if (p["type"] == "ball" or p["type"] == "over") \
					and p["innings"] == innings and _moment_matches(p, kind):
				seen = true
				break
		if not seen:
			return {"kind": kind, "title": _MOMENT_COPY[kind][0], "sub": _MOMENT_COPY[kind][1]}
	return {}
```

- [ ] **Step 4: Run the suite — green, count climbs (+5 tests).**

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_scorecard_moments.gd scripts/domain/match_view_builder.gd
git commit -m "feat: T10 task 1 -- MatchViewBuilder.moment_at mini-moment triggers (DSC2/DSC3)"
```

---

### Task 2: `MatchViewBuilder.build_scorecard` (break card, DSC7/DSC8/DSC9)

**Files:**
- Test: `tests/unit/test_scorecard_moments.gd` (extend)
- Modify: `scripts/domain/match_view_builder.gd`

- [ ] **Step 1: Add the failing tests**

```gdscript
func test_scorecard_rows_reconcile_with_the_innings():
	var s := _mk()
	var mr := s.result()
	var card := MatchViewBuilder.build_scorecard(mr, s.player(), "Karoo Kings", 0, "Riverside")
	var run_sum := 0
	var outs := 0
	var player_rows := 0
	for r in card["rows"]:
		run_sum += r["runs"]
		if r["out"]: outs += 1
		if r["is_player"]: player_rows += 1
	assert_eq(run_sum, mr.innings1.total, "row runs sum to the innings total")
	assert_eq(outs, mr.innings1.wickets, "out rows match the wicket count")
	assert_eq(player_rows, 1 if mr.player_bats_first else 0, "YOU row iff the Player's team batted first")
	assert_string_contains(card["header"], "%d/%d" % [mr.innings1.total, mr.innings1.wickets])

func test_scorecard_dismissals_match_drs_flavours():
	var s := _mk()
	var mr := s.result()
	var card := MatchViewBuilder.build_scorecard(mr, s.player(), "Karoo Kings", 0, "Riverside")
	var how_by_pos := {}
	for r in card["rows"]:
		if r["out"]: how_by_pos[r["pos"]] = r["how"]
	for f in mr.innings1.fall_of_wickets:
		var ballno: int = f["ball"]
		var over := ((ballno - 1) / 6) + 1
		var bio := ((ballno - 1) % 6) + 1
		var expect := MatchViewBuilder._how_str(DRSMoments.flavour_of(mr.player_bats_first, over, bio))
		assert_eq(how_by_pos.get(f["batter"], ""), expect,
			"scorecard dismissal agrees with the T8 flavour hash (pos %d)" % f["batter"])

func test_scorecard_dnb_and_not_out_rows():
	var s := _mk()
	var mr := s.result()
	var card := MatchViewBuilder.build_scorecard(mr, s.player(), "Karoo Kings", 0, "Riverside")
	var came_in: int = mini(mr.innings1.wickets + 2, 11)
	assert_eq(card["rows"].size(), came_in, "rows = everyone who came to the crease, in order")
	for r in card["rows"]:
		if not r["out"]:
			assert_eq(r["how"], "not out", "in but not dismissed reads not out")
	if came_in < 11:
		assert_ne(card["dnb"], "", "DNB line lists the rest")

func test_scorecard_commentary_carries_real_numbers():
	var s := _mk()
	var mr := s.result()
	var card := MatchViewBuilder.build_scorecard(mr, s.player(), "Karoo Kings", 0, "Riverside")
	var req := (mr.innings1.total + 1) * 6.0 / 120.0
	assert_string_contains(card["commentary"], str(mr.innings1.total), "total quoted")
	assert_string_contains(card["commentary"], "%.1f an over" % req, "required rate quoted (DSC9)")
	assert_false("par" in card["commentary"].to_lower(), "no par judgement (DSC9)")
```

- [ ] **Step 2: Run the suite — expect red** (`build_scorecard` not declared).

- [ ] **Step 3: Implement** — append to `scripts/domain/match_view_builder.gd`:

```gdscript
# Full first-innings scorecard for the innings-break overlay (DSC7/DSC8/DSC9).
# Reads the REAL innings card (runs/balls/out per position) + fall_of_wickets;
# dismissal flavour reuses the T8 hash so the card agrees with any DRS moment
# shown for that ball. Names are flavour (PlayerNames); the Player reads YOU.
static func build_scorecard(mr: MatchResult, _player: Player,
		bat_team: String, bat_code: int, chase_team: String) -> Dictionary:
	var inn: InningsResult = mr.innings1
	var fall_ball := {}
	for f in inn.fall_of_wickets:
		fall_ball[f["batter"]] = f["ball"]
	var came_in: int = mini(inn.wickets + 2, 11)
	var rows: Array = []
	var dnb: Array = []
	var top_pos := -1
	var top_runs := -1
	var player_pos := -1
	var player_row := {}
	for b in inn.batters:
		var pos: int = b["position"]
		var is_player: bool = mr.player_bats_first and b["is_player"]
		if is_player: player_pos = pos
		var nm: String = "YOU" if is_player else PlayerNames.upper(bat_team, bat_code, pos)
		if pos > came_in:
			dnb.append("You" if is_player else PlayerNames.for_position(bat_team, bat_code, pos))
			continue
		var how := "not out"
		if b["out"]:
			var ballno: int = fall_ball.get(pos, 0)
			var over := ((ballno - 1) / 6) + 1
			var bio := ((ballno - 1) % 6) + 1
			how = _how_str(DRSMoments.flavour_of(mr.player_bats_first, over, bio))
		if int(b["runs"]) > top_runs:
			top_runs = b["runs"]; top_pos = pos
		var row := {"pos": pos, "name": nm, "runs": int(b["runs"]), "balls": int(b["balls"]),
			"out": bool(b["out"]), "how": how, "is_player": is_player}
		rows.append(row)
		if is_player: player_row = row
	# Commentary: chase-anchored, no par judgement (DSC9). All numbers real.
	var req := (inn.total + 1) * 6.0 / 120.0
	var first := ("%s are all out for %d" % [bat_team, inn.total]) if inn.wickets >= 10 \
		else ("%s post %d/%d" % [bat_team, inn.total, inn.wickets])
	var lines: Array = ["%s - %s need %.1f an over." % [first, chase_team, req]]
	if top_pos != -1 and top_runs > 0:
		var who := "You" if top_pos == player_pos else PlayerNames.for_position(bat_team, bat_code, top_pos)
		lines.append("%s top-scored with %d." % [who, top_runs])
	if not player_row.is_empty() and top_pos != player_pos:
		lines.append("You made %d off %d." % [player_row["runs"], player_row["balls"]])
	return {
		"header": "%s · %d/%d (%s)" % [bat_team.to_upper(), inn.total, inn.wickets, _overs_from_balls(inn.balls)],
		"rows": rows,
		"dnb": "" if dnb.is_empty() else "Did not bat: %s" % ", ".join(dnb),
		"commentary": " ".join(lines),
	}

# DRS flavour string -> scorecard dismissal text (DSC8).
static func _how_str(flavour: String) -> String:
	match flavour:
		"caught": return "c"
		"caught_behind": return "c behind"
		"bowled": return "b"
		"lbw": return "lbw"
		"run_out": return "run out"
		"stumped": return "st"
	return "out"
```

- [ ] **Step 4: Run the suite — green (+4 tests).**

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_scorecard_moments.gd scripts/domain/match_view_builder.gd
git commit -m "feat: T10 task 2 -- build_scorecard innings-break card (DSC7-DSC9)"
```

---

### Task 3: Scene — mini moment strip (DSC4/DSC5)

**Files:**
- Test: `tests/unit/test_interactive_match_scene.gd` (extend)
- Modify: `scenes/interactive_match/interactive_match.gd`

- [ ] **Step 1: Add the failing tests** (append to `test_interactive_match_scene.gd`)

```gdscript
func _moment_cursor(s: MatchSession, kind: String) -> int:
	for c in range(1, s.events().size() + 1):
		var m := MatchViewBuilder.moment_at(s.result(), s.player(), c)
		if m.get("kind", "") == kind:
			return c
	return -1

func test_moment_strip_shows_on_trigger_step():
	var s := _make_session()
	var c := _moment_cursor(s, "you_bat")
	if c == -1: c = _moment_cursor(s, "you_bowl")
	assert_gt(c, -1, "a player-involvement moment exists")
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(c - 1)
	_scene.step(1)
	await get_tree().process_frame
	assert_true(_scene.moment_strip_visible(), "mini scorecard strip shown at the trigger")
	var strip: Control = _scene._moment_strip
	assert_true(strip.is_visible_in_tree(), "strip visible in tree (not clipped away)")
	assert_gt(strip.size.y, 0.0, "strip not collapsed")

func test_moment_strip_hides_on_next_step():
	var s := _make_session()
	var c := _moment_cursor(s, "death")
	if c == -1: return   # chase ended before over 16 on this seed - covered by the trigger test
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(c - 1)
	_scene.step(1)
	assert_true(_scene.moment_strip_visible(), "strip on")
	_scene.step(1)
	assert_false(_scene.moment_strip_visible(), "strip clears on the next step (DSC4)")
```

- [ ] **Step 2: Run the suite — expect red** (`moment_strip_visible` not found).

- [ ] **Step 3: Implement the strip** in `interactive_match.gd`:

Add node refs beside the existing ones (top of file):
```gdscript
var _moment_strip: PanelContainer; var _moment_title: Label; var _moment_sub: Label; var _moment_score: Label
```

In `_build_body()`, insert BEFORE `_build_dock()` (after the `_body_vbox.add_child(_spacer())` line):
```gdscript
	# T10 mini scorecard strip (DSC4/DSC5) — hidden until a moment fires.
	_moment_strip = _panel(UIStyle.goal_panel())
	_moment_strip.visible = false
	var mh := HBoxContainer.new(); mh.add_theme_constant_override("separation", 10)
	var mv := VBoxContainer.new()
	_moment_title = _lbl("", 13, Palette.GOLD)
	_moment_sub = _lbl("", 10, Palette.WHITE_MID, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_MEDIUM)
	mv.add_child(_moment_title); mv.add_child(_moment_sub)
	_moment_score = _lbl("", 15, Palette.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, Fonts.W_BOLD, true)
	mh.add_child(mv); mh.add_child(_spacer()); mh.add_child(_moment_score)
	_moment_strip.add_child(mh)
	_body_vbox.add_child(_moment_strip)
```

In `step()`, after the DRS offer block and before the flash-hold block, add:
```gdscript
		var m := MatchViewBuilder.moment_at(_session.result(), _session.player(), _cursor)
		if not m.is_empty():
			_show_moment_strip(m)
			if _playing:
				_tick.stop()
				_flash_timer.start(FLASH_HOLD)
				return
```

In `_render()`, right after `_flash = v.highlight_text`, add:
```gdscript
	_moment_strip.visible = false
```

New methods (beside the boost helpers):
```gdscript
# T10 mini scorecard strip: title/sub from moment_at, live score + context from
# the already-built MatchView (DSC5 - no new numbers).
func _show_moment_strip(m: Dictionary) -> void:
	var v := MatchViewBuilder.build_rich(_session.result(), _session.player(), _cursor,
		_team_name, _opp_name, _my_stars, _opp_stars, _my_code, _opp_code)
	_moment_title.text = m["title"]
	var ctx := ""
	if m["kind"] == "you_bowl":
		ctx = v.current_line
	elif not v.striker.is_empty() and not v.nonstriker.is_empty():
		ctx = "%s %d* & %s %d*" % [v.striker["name"], v.striker["runs"],
			v.nonstriker["name"], v.nonstriker["runs"]]
	_moment_sub.text = m["sub"] if ctx == "" else "%s · %s" % [m["sub"], ctx]
	_moment_score.text = "%s (%s)" % [v.score_big, v.score_meta.get_slice(" · ", 0)]
	_moment_strip.visible = true

func moment_strip_visible() -> bool:
	return _moment_strip.visible
```

- [ ] **Step 4: Run the suite — green (+2 tests).**

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_interactive_match_scene.gd scenes/interactive_match/interactive_match.gd
git commit -m "feat: T10 task 3 -- mini scorecard strip at orientation moments (DSC4/DSC5)"
```

---

### Task 4: Scene — innings-break overlay (DSC6)

**Files:**
- Test: `tests/unit/test_interactive_match_scene.gd` (extend)
- Modify: `scenes/interactive_match/interactive_match.gd`

- [ ] **Step 1: Add the failing tests**

```gdscript
func _break_index(s: MatchSession) -> int:
	var ev := s.events()
	for i in range(ev.size()):
		if ev[i]["type"] == "innings_break":
			return i
	return -1

func test_break_overlay_pauses_on_step():
	var s := _make_session()
	var bi := _break_index(s)
	assert_gt(bi, -1, "innings break exists")
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(bi)
	_scene.play()
	_scene.step(1)
	await get_tree().process_frame
	assert_true(_scene.break_overlay_visible(), "full scorecard overlay at the break")
	assert_false(_scene._playing, "playback paused (DSC6)")
	var card: Control = _scene._break_overlay.get_node("Center/Card")
	assert_gt(card.size.y, 0.0, "card not collapsed")

func test_break_continue_resumes():
	var s := _make_session()
	var bi := _break_index(s)
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(bi)
	_scene.play()
	_scene.step(1)
	_scene.break_continue()
	assert_false(_scene.break_overlay_visible(), "overlay hides on CONTINUE")
	assert_true(_scene._playing, "playback resumes")

func test_scrub_to_break_shows_card_without_playing():
	var s := _make_session()
	var bi := _break_index(s)
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(bi + 1)
	assert_true(_scene.break_overlay_visible(), "scrubbing onto the break shows the card")
	assert_false(_scene._playing, "scrub never auto-plays")
```

- [ ] **Step 2: Run the suite — expect red** (`break_overlay_visible` not found).

- [ ] **Step 3: Implement the overlay** in `interactive_match.gd`:

Refs + flag (top of file, beside `_km_overlay`):
```gdscript
var _break_overlay: Control; var _break_banner: Label; var _break_body: VBoxContainer
var _resume_after_break := false
```

In `_build_overlays()` append:
```gdscript
	_break_overlay = _make_overlay_root()
	add_child(_break_overlay)
	_break_body = _break_overlay.get_node("Center/Card/V") as VBoxContainer
	_break_body.add_theme_constant_override("separation", 4)
	_break_banner = _break_overlay.get_node("Center/Banner") as Label
	_break_overlay.visible = false
```

In `step()`, after the DRS offer block and BEFORE the Task-3 moment-strip block:
```gdscript
		if _cursor >= 1 and _session.events()[_cursor - 1]["type"] == "innings_break":
			_resume_after_break = _playing
			_show_break_overlay()
			pause()
			return
```

In `seek_to()`, add `_break_overlay.visible = false` beside the other two clears, and at the end (after the DRS check):
```gdscript
	if _cursor >= 1 and _cursor <= _session.events().size() \
			and _session.events()[_cursor - 1]["type"] == "innings_break":
		_show_break_overlay()
```

New section (after the Key Moment section):
```gdscript
# ---------------------------------------------------------------- innings break

# Full first-innings scorecard + commentary (T10, DSC6-DSC9). Text-only banner
# (DSC10 - no emoji in new copy).
func _show_break_overlay() -> void:
	_break_banner.text = "INNINGS BREAK"
	_break_banner.add_theme_stylebox_override("normal", UIStyle.banner("moment"))
	_break_overlay.get_node("Center/Card").add_theme_stylebox_override("panel", UIStyle.moment_card("moment"))
	for c in _break_body.get_children(): c.queue_free()
	var mr := _session.result()
	var bat_team := _team_name if mr.player_bats_first else _opp_name
	var bat_code := _my_code if mr.player_bats_first else _opp_code
	var chase_team := _opp_name if mr.player_bats_first else _team_name
	var card := MatchViewBuilder.build_scorecard(mr, _session.player(), bat_team, bat_code, chase_team)
	_break_body.add_child(_lbl(card["header"], 13, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for r in card["rows"]:
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8)
		var nm := _lbl(r["name"], 11, Palette.GOLD if r["is_player"] else Palette.WHITE_SOFT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(_lbl(r["how"], 9, Palette.WHITE_DIM, HORIZONTAL_ALIGNMENT_RIGHT, Fonts.W_MEDIUM))
		var sc := _lbl("%d (%d)" % [r["runs"], r["balls"]], 11, Palette.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, Fonts.W_BOLD, true)
		sc.custom_minimum_size = Vector2(58, 0)
		h.add_child(sc)
		_break_body.add_child(h)
	if card["dnb"] != "":
		_break_body.add_child(_lbl(card["dnb"], 9, Palette.WHITE_DIM))
	var narr := RichTextLabel.new()
	narr.bbcode_enabled = true; narr.fit_content = true; narr.scroll_active = false
	narr.autowrap_mode = TextServer.AUTOWRAP_WORD
	narr.add_theme_font_size_override("normal_font_size", 12)
	narr.add_theme_font_override("normal_font", Fonts.italic())
	narr.add_theme_color_override("default_color", Palette.WHITE_SOFT)
	narr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	narr.text = "[center]%s[/center]" % card["commentary"]
	_break_body.add_child(narr)
	_break_body.add_child(_two_line_btn("CONTINUE", "Start the chase", Palette.GOLD, break_continue))
	_break_overlay.visible = true

func break_continue() -> void:
	_break_overlay.visible = false
	_render()
	if _resume_after_break and _cursor < _event_count:
		_resume_after_break = false
		play()

func break_overlay_visible() -> bool:
	return _break_overlay.visible
```

- [ ] **Step 4: Run the suite — green (+3 tests). The pre-existing suite must be untouched-green.**

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_interactive_match_scene.gd scenes/interactive_match/interactive_match.gd
git commit -m "feat: T10 task 4 -- innings-break pause with full scorecard + commentary (DSC6)"
```

---

### Task 5: Render harness + eyeball

**Files:**
- Create: `tools/preview_scorecard_moments.gd`
- Output: `docs/mockups/scorecard-moment-strip-v1.png`, `docs/mockups/innings-break-v1.png`

- [ ] **Step 1: Write the harness** (pattern = `tools/preview_interactive_match.gd`: SceneTree script, 390×844 root, inject in `_process` frame 2, `get_viewport().get_texture().get_image().save_png()` after a couple of frames per state):

```gdscript
extends SceneTree

# Renders the T10 scorecard moments for eyeballing: (1) the mini strip at the
# Player's first involvement, (2) the innings-break full scorecard overlay.
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_scorecard_moments.gd
const OUT_STRIP := "res://docs/mockups/scorecard-moment-strip-v1.png"
const OUT_BREAK := "res://docs/mockups/innings-break-v1.png"

var _scene
var _session
var _frames := 0

func _initialize() -> void:
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	_session = MatchSession.start(a, team, opp, tour, 20260615, 1)
	get_root().size = Vector2i(390, 844)
	_scene = load("res://scenes/interactive_match/interactive_match.tscn").instantiate()
	get_root().add_child(_scene)

func _save(path: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)

func _process(_dt: float) -> bool:
	_frames += 1
	if _frames == 2:
		_scene.set_session(_session, "Karoo Kings", "Riverside")
		_scene.boot()
		var c := -1
		for k in range(1, _session.events().size() + 1):
			var m := MatchViewBuilder.moment_at(_session.result(), _session.player(), k)
			if not m.is_empty():
				c = k; break
		_scene.seek_to(c - 1)
		_scene.step(1)
	elif _frames == 6:
		_save(OUT_STRIP)
		var ev := _session.events()
		for i in range(ev.size()):
			if ev[i]["type"] == "innings_break":
				_scene.seek_to(i + 1)
				break
	elif _frames == 10:
		_save(OUT_BREAK)
		quit()
	return false
```

- [ ] **Step 2: Run it (editor CLOSED, no --headless), then LOOK at both PNGs** with the Read tool: strip visible above the dock, not clipped; break card rows all readable inside the card, CONTINUE reachable, commentary not overflowing. Fix layout in the scene (row font sizes / card margins) if anything clips, re-render.

- [ ] **Step 3: Run the full suite once more (green), then commit**

```bash
git add tools/preview_scorecard_moments.gd docs/mockups/scorecard-moment-strip-v1.png docs/mockups/innings-break-v1.png
git commit -m "feat: T10 task 5 -- preview harness + render proof for scorecard moments"
```

---

### Task 6: PR + docs

- [ ] Full suite green; push branch; `gh pr create` (summary = spec DSC list + renders); merge; `git pull` on main; re-run suite once on merged main (parallel-PR rule).
- [ ] Close T10 in `docs/PLAYTEST-NOTES.md` (✅ DONE line, spec pointer); refresh the roadmap "Next session" block (next = T11 city clubs design brief or resolver-signature refactor / iOS export per Nico's plan).
