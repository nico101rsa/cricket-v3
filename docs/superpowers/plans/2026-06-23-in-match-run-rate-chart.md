# In-Match Run-Rate Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the locked hi-fi run-rate chart (per-over bars + CRR worm + target/par line + stadium backdrop) and wire it into the interactive match screen, replacing the numeric "RUN RATE" placeholder.

**Architecture:** Two units on the existing pure-builder/dumb-view seam. (1) A pure `MatchViewBuilder._build_chart()` helper produces a `chart` dict on `MatchView` by walking the active innings' ball-log — fully unit-tested. (2) A standalone custom-drawn `RunRateChart` Control renders it in `_draw()` — presence/visibility tested + eyeballed. Pure presentation: no sim/tuning/ledger files touched.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Custom 2D drawing (`_draw`, `draw_rect`/`draw_circle`/`draw_polyline`/`draw_dashed_line`/`draw_string`). Colours from `Palette`, font from `ThemeDB.fallback_font`.

---

## File structure

- **Modify** `scripts/data/match_view.gd` — add `var chart: Dictionary = {}`.
- **Modify** `scripts/domain/match_view_builder.gd` — add `PAR_RR` const, `_build_chart()` static helper, assign `v.chart` in `build_rich`.
- **Create** `scenes/interactive_match/run_rate_chart.gd` — `class_name RunRateChart`, the custom-drawn Control.
- **Modify** `scenes/interactive_match/interactive_match.gd` — replace the numeric run-rate panel (`:187-197`) with a `RunRateChart`; bind in `_render`.
- **Create** `tests/unit/test_match_chart_data.gd` — pure data tests.
- **Create** `tests/unit/test_run_rate_chart_scene.gd` — render presence/visibility.
- **Modify** `tests/unit/test_interactive_match_scene.gd` — assert the chart node is present + visible.
- **Create** `tools/preview_run_rate_chart.gd` — render 4 eyeball PNGs.
- **Create** `docs/design-inbox/in-match-chart-REQUEST.md` — post-build fidelity review.

**Test running (CLAUDE.md):** never run with the Godot editor open. Always reimport before a run in a fresh tree:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
Full suite (the `-gtest` flag does NOT filter here — run the whole suite, judge red by a `Parse Error` for a not-yet-declared `class_name`, green by total count climbing + `All tests passed`):
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Chain `--import && <test>` in one command. Indentation is TABS.

---

## Ball-log entry shape (input to the data helper)

Each entry in `mr.ball_log_innings1/2` (from `InningsResolver`, one per legal ball):
```
{ "over": int (1-based), "ball_in_over": int (1-6), "striker_pos": int,
  "is_player": bool, "player_batting": bool, "player_bowling": bool,
  "intent": int, "boost_pressed": bool,
  "wicket": bool, "runs": int (0 on a wicket ball),
  "total": int (cumulative), "wickets": int (cumulative) }
```

---

## Task 1: Chart data — `MatchView.chart` + `_build_chart()` helper

**Files:**
- Modify: `scripts/data/match_view.gd`
- Modify: `scripts/domain/match_view_builder.gd`
- Test: `tests/unit/test_match_chart_data.gd`

- [ ] **Step 1: Add the `chart` field to `MatchView`**

In `scripts/data/match_view.gd`, add alongside the other fields (e.g. after `var commentary`):
```gdscript
var chart: Dictionary = {}          # run-rate chart read-model (see MatchViewBuilder._build_chart)
```

- [ ] **Step 2: Write the failing data tests**

Create `tests/unit/test_match_chart_data.gd`:
```gdscript
extends GutTest

# Pure run-rate chart data (MatchViewBuilder._build_chart). Hand-built ball-logs →
# per-over bars/worm/flags + the target/par line. No sim, no RNG.

# One legal-ball log entry; only the fields _build_chart reads.
func _ball(over: int, runs: int, total: int, wicket := false, wkts := 0) -> Dictionary:
	return {"over": over, "ball_in_over": 0, "striker_pos": 1, "is_player": false,
		"player_batting": false, "player_bowling": false, "intent": 0,
		"boost_pressed": false, "wicket": wicket, "runs": runs,
		"total": total, "wickets": wkts}

# A full over (6 balls) of flat singles starting from running total `from`.
func _over_singles(over: int, from: int) -> Array:
	var out: Array = []
	var t := from
	for b in range(6):
		t += 1
		out.append(_ball(over, 1, t))
	return out

func test_per_over_runs_and_crr_series() -> void:
	var log: Array = []
	log.append_array(_over_singles(1, 0))    # over 1: 6 runs, total 6
	log.append_array(_over_singles(2, 6))    # over 2: 6 runs, total 12
	var chart := MatchViewBuilder._build_chart(log, log.size(), 1, 0)
	assert_eq(chart["overs"].size(), 2, "two completed overs")
	assert_eq(chart["overs"][0]["runs"], 6, "over 1 = 6 runs")
	assert_eq(chart["overs"][1]["runs"], 6, "over 2 = 6 runs")
	# CRR at end of over 2 = 12 runs in 12 balls = 6.0
	assert_almost_eq(chart["overs"][1]["crr"], 6.0, 0.01, "cumulative CRR")
	assert_false(chart["overs"][0]["now"], "completed over not flagged now")

func test_boundary_and_wicket_flags() -> void:
	var log: Array = []
	# over 1: a four on ball 1 then five singles
	log.append(_ball(1, 4, 4))
	var t := 4
	for b in range(5):
		t += 1; log.append(_ball(1, 1, t))
	# over 2: a wicket on ball 1 (runs 0) then five singles
	log.append(_ball(2, 0, t, true, 1))
	for b in range(5):
		t += 1; log.append(_ball(2, 1, t, false, 1))
	var chart := MatchViewBuilder._build_chart(log, log.size(), 1, 0)
	assert_true(chart["overs"][0]["has_boundary"], "over 1 had a boundary")
	assert_false(chart["overs"][0]["has_wicket"], "over 1 had no wicket")
	assert_true(chart["overs"][1]["has_wicket"], "over 2 had a wicket")

func test_now_over_partial() -> void:
	var log: Array = []
	log.append_array(_over_singles(1, 0))   # over 1 complete (6)
	log.append(_ball(2, 4, 10))             # over 2 ball 1 only (partial)
	var chart := MatchViewBuilder._build_chart(log, log.size(), 1, 0)
	assert_eq(chart["overs"].size(), 2, "in-progress over included")
	assert_true(chart["overs"][1]["now"], "current over flagged now")
	assert_eq(chart["overs"][1]["runs"], 4, "partial over runs so far")

func test_no_now_on_over_boundary() -> void:
	var log := _over_singles(1, 0)          # exactly one complete over
	var chart := MatchViewBuilder._build_chart(log, log.size(), 1, 0)
	assert_false(chart["overs"][chart["overs"].size() - 1]["now"], "no partial over at a boundary")

func test_target_rr_second_innings() -> void:
	# first_total 160 → target 161 → 161*6/120 = 8.05
	var chart := MatchViewBuilder._build_chart(_over_singles(1, 0), 6, 2, 160)
	assert_almost_eq(chart["target_rr"], 8.05, 0.01, "chase RR over 20 overs")
	assert_eq(chart["innings"], 2, "innings tag 2")

func test_par_rr_first_innings() -> void:
	var chart := MatchViewBuilder._build_chart(_over_singles(1, 0), 6, 1, 0)
	assert_almost_eq(chart["target_rr"], MatchViewBuilder.PAR_RR, 0.01, "1st-innings par benchmark")
	assert_eq(chart["innings"], 1, "innings tag 1")

func test_empty_innings_no_crash() -> void:
	var chart := MatchViewBuilder._build_chart([], 0, 1, 0)
	assert_eq(chart["overs"].size(), 0, "no overs")
	assert_gt(chart["y_max"], 0.0, "y_max sane even with no data")
```

- [ ] **Step 3: Run the suite to verify RED**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -15`
Expected: `Parse Error: ... "_build_chart" ... not declared` (GUT skips the file) — RED.

- [ ] **Step 4: Implement `PAR_RR` + `_build_chart` and wire into `build_rich`**

In `scripts/domain/match_view_builder.gd`, add near the top of the class (after the class doc / before the first `static func`):
```gdscript
const PAR_RR := 8.0   # 1st-innings benchmark RR (no chase yet) — anchored to the
                      # sim's real-T20 scoring env (~RR 8.1). 2nd innings uses the
                      # real chase RR instead.
```

Add this static helper (place it after `build_rich`, before `_ball_kind`):
```gdscript
# Pure run-rate chart read-model: walk the active innings' ball-log up to `n`
# legal balls into per-over bars + a cumulative-CRR worm + the target/par line.
# innings_no 1 → par line (PAR_RR); 2 → chase RR from first_total. Used by build_rich.
static func _build_chart(log: Array, n: int, innings_no: int, first_total: int) -> Dictionary:
	var overs: Array = []
	var cur_over := 0
	var over_runs := 0
	var over_boundary := false
	var over_wicket := false
	var over_first_ball := 0   # index of the first ball of cur_over (for now-flag)
	var max_over_rr := 0.0
	var count: int = mini(n, log.size())
	for i in range(count):
		var b: Dictionary = log[i]
		var o: int = b["over"]
		if o != cur_over:
			if cur_over != 0:
				overs.append(_close_over(cur_over, over_runs, over_boundary, over_wicket,
					log[i - 1]["total"], i, false))
				max_over_rr = maxf(max_over_rr, overs[overs.size() - 1]["bar_rr"])
			cur_over = o
			over_runs = 0; over_boundary = false; over_wicket = false; over_first_ball = i
		over_runs += b["runs"]
		if b["runs"] == 4 or b["runs"] == 6: over_boundary = true
		if b["wicket"]: over_wicket = true
	# flush the last over — `now` true iff it's still in progress (last ball isn't ball 6)
	if cur_over != 0:
		var last: Dictionary = log[count - 1]
		var in_progress: bool = last["ball_in_over"] != 6
		overs.append(_close_over(cur_over, over_runs, over_boundary, over_wicket,
			last["total"], count, in_progress))
		max_over_rr = maxf(max_over_rr, overs[overs.size() - 1]["bar_rr"])

	var target_rr: float = (PAR_RR if innings_no == 1
		else (first_total + 1) * 6.0 / 120.0)
	var y_max: float = clampf(maxf(target_rr, max_over_rr) * 1.15, 10.0, 18.0)
	return {"overs": overs, "target_rr": target_rr, "y_max": y_max, "innings": innings_no}

# One over's chart entry. balls_so_far = legal balls bowled in the innings up to and
# including this over's last counted ball → cumulative CRR. bar_rr = this over's RR.
static func _close_over(over: int, runs: int, boundary: bool, wicket: bool,
		cum_total: int, balls_so_far: int, now: bool) -> Dictionary:
	var balls_in_over: int = balls_so_far - (over - 1) * 6
	return {
		"over": over, "runs": runs,
		"crr": (cum_total * 6.0 / balls_so_far) if balls_so_far > 0 else 0.0,
		"bar_rr": (runs * 6.0 / balls_in_over) if balls_in_over > 0 else 0.0,
		"has_boundary": boundary, "has_wicket": wicket, "now": now,
	}
```

Then in `build_rich`, assign the chart. Find the existing run-rate block (it computes `crr_f` and `n`, `innings_no`):
```gdscript
	# Run rate (real) + the bowler row (flavour name, real ★/economy).
	var crr_f := (total * 6.0 / n) if n > 0 else 0.0
	v.crr = "%.1f" % crr_f
```
Immediately AFTER `v.crr = "%.1f" % crr_f`, add:
```gdscript
	v.chart = _build_chart(log, n, innings_no, mr.innings1.total)
```
(`log`, `n`, `innings_no` are all already in scope in `build_rich`.)

- [ ] **Step 5: Run the suite to verify GREEN**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -8`
Expected: total tests climb by 7, `All tests passed`.

- [ ] **Step 6: Commit**

```bash
git add scripts/data/match_view.gd scripts/data/match_view.gd.uid scripts/domain/match_view_builder.gd scripts/domain/match_view_builder.gd.uid tests/unit/test_match_chart_data.gd
git commit -m "feat: run-rate chart data read-model (per-over bars + CRR worm + target/par line)"
```

---

## Task 2: `RunRateChart` custom-drawn Control

**Files:**
- Create: `scenes/interactive_match/run_rate_chart.gd`
- Test: `tests/unit/test_run_rate_chart_scene.gd`

- [ ] **Step 1: Write the failing render-presence test**

Create `tests/unit/test_run_rate_chart_scene.gd`:
```gdscript
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
```

- [ ] **Step 2: Run the suite to verify RED**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -12`
Expected: `Parse Error: ... "RunRateChart" ... not declared` — RED.

- [ ] **Step 3: Implement the chart Control**

Create `scenes/interactive_match/run_rate_chart.gd`:
```gdscript
class_name RunRateChart
extends Control

# The hi-fi in-match run-rate chart (design: docs/mockups/in-match-hi-fi-v1.html
# .chart). Pure renderer: set_data(chart) where `chart` is MatchViewBuilder's
# read-model. Paints back-to-front in _draw(): stadium backdrop → per-over bars →
# CRR worm → target/par line → axis + legend. Gently pulses the current over.

const SKY_TOP := Color("1a2740")
const SKY_BOT := Color("24492f")     # horizon → grass
const GRASS := Color("16321f")
const MOON := Color(1, 1, 1, 0.85)
const PAD := 12.0                    # plot inset
const TOP_PAD := 22.0                # headroom above the tallest bar
const BOT_PAD := 18.0                # axis strip

var _chart: Dictionary = {}
var _accent: Color = Palette.GOLD
var _pulse := 0.0

func set_data(chart: Dictionary, accent: Color = Palette.GOLD) -> void:
	_chart = chart
	_accent = accent
	queue_redraw()

func _process(delta: float) -> void:
	# Only animate while a current over is on screen.
	if _chart.get("overs", []).is_empty():
		return
	_pulse += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	_draw_backdrop(w, h)
	var plot := Rect2(PAD, TOP_PAD, w - PAD * 2.0, h - TOP_PAD - BOT_PAD)
	var y_max: float = _chart.get("y_max", 12.0)
	if y_max <= 0.0:
		y_max = 12.0
	_draw_target(plot, y_max)
	var overs: Array = _chart.get("overs", [])
	if not overs.is_empty():
		_draw_bars(plot, overs, y_max)
		_draw_worm(plot, overs, y_max)
	_draw_axis_legend(plot)

func _y(plot: Rect2, rr: float, y_max: float) -> float:
	return plot.position.y + plot.size.y * (1.0 - clampf(rr / y_max, 0.0, 1.0))

# x-centre of over slot `over` (1..20) across the plot width.
func _x(plot: Rect2, over: int) -> float:
	var slots := 20.0
	var slot_w := plot.size.x / slots
	return plot.position.x + (over - 0.5) * slot_w

func _draw_backdrop(w: float, h: float) -> void:
	# sky → grass gradient as three stacked bands (cheap, no texture).
	var horizon := h * 0.62
	draw_rect(Rect2(0, 0, w, horizon * 0.5), SKY_TOP)
	draw_rect(Rect2(0, horizon * 0.5, w, horizon * 0.5), SKY_BOT)
	draw_rect(Rect2(0, horizon, w, h - horizon), GRASS)
	# moon, upper-right
	draw_circle(Vector2(w * 0.72, h * 0.22), 9.0, MOON)
	draw_circle(Vector2(w * 0.72, h * 0.22), 14.0, Color(1, 1, 1, 0.10))
	# two floodlight poles + glow
	for fx in [w * 0.10, w * 0.90]:
		draw_line(Vector2(fx, horizon), Vector2(fx, h * 0.10), Color(1, 1, 1, 0.18), 1.5)
		draw_rect(Rect2(fx - 6, h * 0.06, 12, 5), Color(1, 1, 1, 0.25))
		draw_circle(Vector2(fx, h * 0.085), 10.0, Color(1, 1, 0.85, 0.08))
	# sparse crowd silhouette strip just above the horizon
	var cy := horizon - 4.0
	var x := 6.0
	while x < w - 6.0:
		draw_circle(Vector2(x, cy), 2.0, Color(0, 0, 0, 0.30))
		x += 9.0

func _draw_bars(plot: Rect2, overs: Array, y_max: float) -> void:
	var slot_w := plot.size.x / 20.0
	var bw := slot_w * 0.6
	for o in overs:
		var cx := _x(plot, o["over"])
		var top := _y(plot, o["bar_rr"], y_max)
		var rect := Rect2(cx - bw * 0.5, top, bw, plot.position.y + plot.size.y - top)
		var col := Palette.BLUE
		if o["has_wicket"]:
			col = Palette.RED
		elif o["has_boundary"]:
			col = Palette.GOLD
		if o["now"]:
			col = col.lerp(Color.WHITE, 0.35 + 0.25 * sin(_pulse * 4.0))
		draw_rect(rect, col)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color(1, 1, 1, 0.25))  # top sheen

func _draw_worm(plot: Rect2, overs: Array, y_max: float) -> void:
	var pts: PackedVector2Array = []
	for o in overs:
		pts.append(Vector2(_x(plot, o["over"]), _y(plot, o["crr"], y_max)))
	if pts.size() >= 2:
		draw_polyline(pts, Color.WHITE, 2.0, true)
	for i in range(pts.size()):
		var is_last := i == pts.size() - 1
		if is_last:
			draw_circle(pts[i], 5.0 + sin(_pulse * 4.0), Color(_accent.r, _accent.g, _accent.b, 0.4))
			draw_circle(pts[i], 4.0, _accent)
		else:
			draw_circle(pts[i], 2.5, Color.WHITE)

func _draw_target(plot: Rect2, y_max: float) -> void:
	var ty := _y(plot, _chart.get("target_rr", 8.0), y_max)
	draw_dashed_line(Vector2(plot.position.x, ty), Vector2(plot.position.x + plot.size.x, ty),
		Color(Palette.RED.r, Palette.RED.g, Palette.RED.b, 0.6), 1.2, 4.0)
	var font := ThemeDB.fallback_font
	var label := ("par %.1f" if _chart.get("innings", 1) == 1 else "target %.1f") % _chart.get("target_rr", 8.0)
	draw_string(font, Vector2(plot.position.x + plot.size.x - 56, ty - 3), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.RED)

func _draw_axis_legend(plot: Rect2) -> void:
	var font := ThemeDB.fallback_font
	for ov in [1, 5, 10, 15, 20]:
		draw_string(font, Vector2(_x(plot, ov) - 4, plot.position.y + plot.size.y + 12),
			str(ov), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.WHITE_DIM)
	# legend bottom-left
	var ly := plot.position.y + plot.size.y + 12
	draw_line(Vector2(plot.position.x, ly - 3), Vector2(plot.position.x + 10, ly - 3), Color.WHITE, 2.0)
	draw_string(font, Vector2(plot.position.x + 13, ly), "CRR", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.WHITE_MID)
```

- [ ] **Step 4: Run the suite to verify GREEN**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -8`
Expected: tests climb by 2, `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scenes/interactive_match/run_rate_chart.gd scenes/interactive_match/run_rate_chart.gd.uid tests/unit/test_run_rate_chart_scene.gd
git commit -m "feat: RunRateChart custom-drawn Control (bars + worm + target line + stadium backdrop)"
```

---

## Task 3: Wire the chart into the interactive match screen

**Files:**
- Modify: `scenes/interactive_match/interactive_match.gd`
- Test: `tests/unit/test_interactive_match_scene.gd`

- [ ] **Step 1: Add a chart-presence assertion to the existing scene test**

Open `tests/unit/test_interactive_match_scene.gd`. Find a test that builds the scene and calls `set_session(...)` then `boot()` (there is at least one; reuse its setup). At the END of that test body, add:
```gdscript
	# Run-rate chart present + visible (the numeric placeholder is replaced).
	var chart := scene.find_child("RunRateChart", true, false)
	assert_not_null(chart, "run-rate chart mounted in the match screen")
	assert_gt(chart.size.y, 0.0, "chart not collapsed")
```
If the local scene variable is named differently (e.g. `screen`/`s`), match the existing name. `find_child` matches by node name — set that name in Step 3.

- [ ] **Step 2: Run the suite to verify RED**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -A2 -i "run-rate chart\|RunRateChart" | head`
Expected: the new assertion FAILS (`run-rate chart mounted` — null), because nothing named `RunRateChart` is mounted yet.

- [ ] **Step 3: Replace the numeric run-rate panel with the chart**

In `scenes/interactive_match/interactive_match.gd`:

(a) Replace the declaration `var _crr_big: Label; var _req_big: Label` (≈ line 44) with:
```gdscript
var _chart: RunRateChart
```

(b) Replace the "Run rate viz" block (≈ lines 187-197):
```gdscript
	# Run rate viz
	var rr := _panel(UIStyle.panel())
	var rv := VBoxContainer.new()
	rv.add_child(_lbl("RUN RATE", 9, Palette.WHITE_DIM, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_LABEL))
	var rrh := HBoxContainer.new()
	_crr_big = _lbl("0.0", 34, Palette.GOLD, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_BOLD, true)
	_req_big = _lbl("", 21, Palette.RED, HORIZONTAL_ALIGNMENT_RIGHT, Fonts.W_BOLD, true)
	rrh.add_child(_crr_big); rrh.add_child(_spacer()); rrh.add_child(_req_big)
	rv.add_child(rrh)
	rr.add_child(rv)
	_body_vbox.add_child(rr)
```
with:
```gdscript
	# Run-rate chart (hero viz) — replaces the old numeric run-rate panel. The CRR
	# number still lives in the scorebar meta (v.score_meta "… CRR x.x").
	var rr := _panel(UIStyle.panel())
	var rv := VBoxContainer.new()
	rv.add_child(_lbl("RUN RATE", 9, Palette.WHITE_DIM, HORIZONTAL_ALIGNMENT_LEFT, Fonts.W_LABEL))
	_chart = RunRateChart.new()
	_chart.name = "RunRateChart"
	_chart.custom_minimum_size = Vector2(0, 180)
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_child(_chart)
	rr.add_child(rv)
	_body_vbox.add_child(rr)
```

(c) In `_render` (the method that writes `_crr_big.text`, ≈ lines 773-774), replace:
```gdscript
	# Run rate
	_crr_big.text = v.crr
```
(and any sibling `_req_big.text = ...` line in that block) with:
```gdscript
	# Run-rate chart
	var chart_accent: Color = Palette.country_set(v.my_code)["accent"]
	_chart.set_data(v.chart, chart_accent)
```
If a `_req_big.text` assignment exists elsewhere in `_render`, delete it (the field is gone). Search the file for `_crr_big` and `_req_big` and remove every remaining reference.

- [ ] **Step 4: Run the suite to verify GREEN**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -8`
Expected: `All tests passed` (no `_crr_big`/`_req_big` parse errors, chart assertion passes).

- [ ] **Step 5: Commit**

```bash
git add scenes/interactive_match/interactive_match.gd tests/unit/test_interactive_match_scene.gd
git commit -m "feat: mount the run-rate chart in the interactive match screen (replaces numeric panel)"
```

---

## Task 4: Eyeball harness — 4 PNGs + launch

**Files:**
- Create: `tools/preview_run_rate_chart.gd`

- [ ] **Step 1: Write the preview harness**

Create `tools/preview_run_rate_chart.gd`:
```gdscript
extends SceneTree

# Dev preview for the in-match run-rate chart. Renders four states to PNGs.
# Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_run_rate_chart.gd

var _chart
var _frames := 0
var _shot := 0
var _cases: Array = []

func _initialize() -> void:
	root.size = Vector2i(390, 220)
	_chart = RunRateChart.new()
	_chart.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_chart)
	_cases = [
		["res://docs/mockups/in-match-chart-1st-innings-v1.png", _first_innings()],
		["res://docs/mockups/in-match-chart-chase-v1.png", _chase()],
		["res://docs/mockups/in-match-chart-boundary-over-v1.png", _boundary()],
		["res://docs/mockups/in-match-chart-wicket-over-v1.png", _wicket()],
	]

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_chart.set_data(_cases[_shot][1])
	if _frames >= 8:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_cases[_shot][0])
		print("SAVED ", _cases[_shot][0])
		_shot += 1
		_frames = 0
		if _shot >= _cases.size():
			print("PREVIEW_SAVED")
			return true
	return false

func _ov(over: int, runs: int, crr: float, bar_rr: float, b := false, w := false, now := false) -> Dictionary:
	return {"over": over, "runs": runs, "crr": crr, "bar_rr": bar_rr,
		"has_boundary": b, "has_wicket": w, "now": now}

func _first_innings() -> Dictionary:
	return {"overs": [_ov(1, 8, 8.0, 8.0, true), _ov(2, 5, 6.5, 5.0), _ov(3, 9, 7.3, 9.0, true),
		_ov(4, 6, 7.0, 6.0, false, false, true)], "target_rr": 8.0, "y_max": 12.0, "innings": 1}

func _chase() -> Dictionary:
	return {"overs": [_ov(1, 10, 10.0, 10.0, true), _ov(2, 4, 7.0, 4.0), _ov(3, 12, 8.7, 12.0, true),
		_ov(4, 5, 7.75, 5.0), _ov(5, 8, 7.8, 8.0, true, false, true)],
		"target_rr": 8.6, "y_max": 13.0, "innings": 2}

func _boundary() -> Dictionary:
	return {"overs": [_ov(1, 6, 6.0, 6.0), _ov(2, 18, 12.0, 18.0, true, false, true)],
		"target_rr": 8.0, "y_max": 18.0, "innings": 1}

func _wicket() -> Dictionary:
	return {"overs": [_ov(1, 7, 7.0, 7.0), _ov(2, 1, 4.0, 1.0, false, true, true)],
		"target_rr": 8.0, "y_max": 12.0, "innings": 1}
```

- [ ] **Step 2: Render the PNGs**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_run_rate_chart.gd 2>&1 | grep -E "SAVED|PREVIEW|error"`
Expected: four `SAVED …` lines + `PREVIEW_SAVED`.

- [ ] **Step 3: Eyeball every PNG (REQUIRED — invisibility is invisible to tests)**

Open and visually verify each of the four `docs/mockups/in-match-chart-*-v1.png`:
- bars present + correctly coloured (boundary=gold, wicket=red, normal=blue, now=lighter);
- the white CRR worm with a gold "now" dot;
- the dashed target/par line at the right RR with the right label (`par`/`target`);
- the stadium backdrop (gradient, moon, floodlights, crowd) reads as atmosphere not noise;
- axis numbers + CRR legend legible.
If anything is collapsed/clipped/wrong-coloured, fix `run_rate_chart.gd` and re-render before moving on.

- [ ] **Step 4: Launch the real interactive match (CLAUDE.md: launch the playable app, not just a screenshot)**

Run (background): `nohup /Applications/Godot.app/Contents/MacOS/Godot --path . > /tmp/cricket_run.log 2>&1 &`
Play a match; confirm the chart fills in live, over by over, and the worm tracks the target line.

- [ ] **Step 5: Commit**

```bash
git add tools/preview_run_rate_chart.gd tools/preview_run_rate_chart.gd.uid docs/mockups/in-match-chart-1st-innings-v1.png docs/mockups/in-match-chart-chase-v1.png docs/mockups/in-match-chart-boundary-over-v1.png docs/mockups/in-match-chart-wicket-over-v1.png
git commit -m "test: run-rate chart eyeball preview (4 states) + renders"
```

---

## Task 5: Post-build design-fidelity review request

**Files:**
- Create: `docs/design-inbox/in-match-chart-REQUEST.md`

- [ ] **Step 1: Write the review request**

Create `docs/design-inbox/in-match-chart-REQUEST.md`:
```markdown
# Design review — In-Match run-rate chart (build fidelity)

**Built 2026-06-23.** The run-rate chart from `docs/mockups/in-match-hi-fi-v1.html`
(the `.chart` block) is now implemented in the interactive match screen — it was
previously missing (a plain CRR number stood in for it). Pure presentation; no
sim/balance change.

**Please compare the build to your mockup and flag any deltas:**

- Rendered build (4 states):
  - `docs/mockups/in-match-chart-1st-innings-v1.png` (par line)
  - `docs/mockups/in-match-chart-chase-v1.png` (target line)
  - `docs/mockups/in-match-chart-boundary-over-v1.png`
  - `docs/mockups/in-match-chart-wicket-over-v1.png`
- Locked design: `docs/mockups/in-match-hi-fi-v1.html`

**Specific questions:**
1. **Worm** — stroke weight / glow / dot sizing vs the mockup's white worm?
2. **Bars** — blue/gold(boundary)/red(wicket) palette + the "now" pulse read right?
3. **Backdrop** — moon/floodlights/crowd atmosphere close enough, or too sparse/busy?
4. **Target/par line** — colour, dash, and label placement (`par 8.0` 1st inns /
   `target 8.x` 2nd inns) acceptable?
5. **Axis/legend** — over numbers + CRR legend legible at phone size?

**Decisions already baked (flag if you disagree):**
- 1st innings shows a fixed **par RR (8.0)** line (no chase yet); 2nd innings the real chase RR.
- Win-probability corner indicator deferred (not built this rung).
- Bar colour priority: wicket > boundary > normal.
```

- [ ] **Step 2: Commit**

```bash
git add docs/design-inbox/in-match-chart-REQUEST.md
git commit -m "docs: file in-match chart build-fidelity review for the design track"
```

---

## Done criteria

- All data tests + render-presence tests green; full suite `All tests passed`.
- Four chart PNGs rendered + eyeballed; real match launched and the chart fills live.
- Design-fidelity review filed.
- No sim/tuning/ledger file touched (grep the diff: only `scripts/data/match_view.gd`, `scripts/domain/match_view_builder.gd`, `scenes/interactive_match/*`, `tests/`, `tools/`, `docs/`).
- Then: open the PR, merge to `main`, update `PROJECT_ROADMAP.md` (per the commit/merge policy).

## Self-review notes

- **Spec coverage:** bars/worm/target-or-par/axis/legend/backdrop (Task 2 `_draw`); data incl. boundary/wicket/now/target_rr/y_max (Task 1); integration replacing the numeric panel (Task 3); 4-state eyeball + launch (Task 4); post-build design review (Task 5). All spec sections covered.
- **Type consistency:** the `chart` dict keys (`overs`/`over`/`runs`/`crr`/`bar_rr`/`has_boundary`/`has_wicket`/`now`/`target_rr`/`y_max`/`innings`) are identical across Task 1 (producer), Task 2 (consumer), and Task 4 (preview fixtures).
- **`bar_rr` note:** added to the read-model (not in the spec's sketch) so bars scale by per-over RR on the same `y_max` as the worm — keeps bars and worm on one vertical scale (spec §architecture intent). Documented in `_close_over`.
```
