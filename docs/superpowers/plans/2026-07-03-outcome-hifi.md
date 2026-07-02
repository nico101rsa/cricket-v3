# Outcome Hi-Fi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin the season-end Outcome screen to the design language (country-gradient header band, gold celebration strip, stat tiles, next-up pill) with zero behaviour change.

**Architecture:** Presentation-only rebuild of `scenes/outcome/outcome.gd` (code-built scene, same file) on the shared `Palette`/`UIStyle`/`Fonts` foundation. `set_outcome` gains an optional trailing `country: int` param; `scenes/main.gd` threads the live player's country through. Spec: `docs/superpowers/specs/2026-07-03-outcome-hifi-design.md` (DO1–DO6).

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Tabs in `.gd`. No emoji (Barlow tofu). Test command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` (whole suite, <1s; judge green by count climbing + `All tests passed`).

---

### Task 1: Hi-fi guard tests (red)

**Files:**
- Modify: `tests/unit/test_outcome_scene.gd` (append)

- [ ] **Step 1: Append the failing hi-fi guards**

```gdscript
# --- Hi-fi skin guards (outcome-hifi spec 2026-07-03, DO2/DO5/DO6) ---

func _promoted_t() -> Dictionary:
	return {"promoted": true, "to_level": 1, "complete": false, "next_level": 1,
		"next_tour": 0, "beat": true, "from_level": 0, "tour": 5}

func test_header_band_visible_not_collapsed() -> void:
	var s = _show(_result(1), _promoted_t())
	await get_tree().process_frame
	var band: PanelContainer = s.find_child("HeaderBand", true, false)
	assert_not_null(band, "country-gradient header band present")
	if band == null:
		return
	assert_true(band.is_visible_in_tree(), "header band visible")
	assert_gt(band.size.y, 0.0, "header band not collapsed")

func test_promoted_transition_strip_is_gold() -> void:
	var s = _show(_result(1), _promoted_t())
	await get_tree().process_frame
	var strip: PanelContainer = s.find_child("TransitionStrip", true, false)
	assert_not_null(strip, "transition strip present")
	if strip == null:
		return
	var sb: StyleBoxFlat = strip.get_theme_stylebox("panel")
	assert_eq(sb.bg_color, Palette.GOLD, "promotion celebrates on the gold panel")

func test_missed_transition_strip_not_gold() -> void:
	var s = _show(_result(6), {"promoted": false, "to_level": 1, "from_level": 1,
		"complete": false, "next_level": 1, "next_tour": 2, "beat": false, "tour": 2})
	await get_tree().process_frame
	var strip: PanelContainer = s.find_child("TransitionStrip", true, false)
	assert_not_null(strip, "transition strip present")
	if strip == null:
		return
	var sb: StyleBoxFlat = strip.get_theme_stylebox("panel")
	assert_ne(sb.bg_color, Palette.GOLD, "a miss does not celebrate")

func test_country_param_rethemes_header() -> void:
	var screen = OutcomeScene.instantiate()
	add_child_autofree(screen)
	screen.set_outcome(_result(2), 100, 5, null, _promoted_t(), Country.Code.AUS)
	await get_tree().process_frame
	var band: PanelContainer = screen.find_child("HeaderBand", true, false)
	assert_not_null(band, "header band present")
	if band == null:
		return
	var sb: StyleBoxFlat = band.get_theme_stylebox("panel")
	assert_eq(sb.bg_color, Palette.COUNTRY_1_AUS.lerp(Palette.COUNTRY_2_AUS, 0.45),
		"AUS country param re-themes the header gradient")

func test_stat_tiles_present() -> void:
	var s = _show(_result(2), _promoted_t())
	await get_tree().process_frame
	var labels := _all_label_text(s)
	for cap in ["FINISHED", "RECORD", "BANKED"]:
		assert_true(labels.contains(cap), "stat tile caption %s shown" % cap)
```

- [ ] **Step 2: Run the suite — verify red**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -15`
Expected: failing asserts (HeaderBand/TransitionStrip null; the AUS call fails — `set_outcome` takes 5 args today). NOT a parse error — no new class_name involved. Do not commit red.

### Task 2: Re-skin `outcome.gd` + country pass-through (green)

**Files:**
- Modify: `scenes/outcome/outcome.gd` (rewrite `set_outcome` + helpers; keep `_headline`, `_banner_for`, `_next_up_text`, `_cta_text`, `_new_team_name`, `_level_word`, `_ordinal` unchanged)
- Modify: `scenes/main.gd:244` + `:272` (thread the country)

- [ ] **Step 1: Rewrite the presentation part of `scenes/outcome/outcome.gd`**

Replace the file header comment, `set_outcome`, and `_stat_row` with the following (the pure-text helpers listed above stay byte-identical):

```gdscript
extends Control

# Season Outcome screen, hi-fi skin (outcome-hifi spec 2026-07-03, DO1-DO6).
# Shown when the live SeasonPlay finishes (after the Offers pick, before the
# Career Grid): country-gradient header band (kicker + headline), the career
# transition strip (gold celebration on promoted/complete), season stat tiles,
# next-up pill, gold Continue. Presentation only — banner wording, routing and
# the continue_pressed signal are the PR #101/#104/#107 behaviour, unchanged.
# Built in code; the .tscn is just the root Control + this script. No emoji.

signal continue_pressed()

func set_outcome(result: SeasonResult, pay: int, wins: int,
		career: CareerState = null, transition: Dictionary = {},
		country: int = Country.Code.SA) -> void:
	var pos := result.player_final_position
	var made_playoffs := pos <= 4
	var games := 7 + (2 if made_playoffs else 0)
	var cset := Palette.country_set(country)

	# Background fills the screen so nothing from the prior scene shows through.
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(340, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	col.add_child(_header_band(pos, cset))
	col.add_child(_transition_strip(transition, career))
	col.add_child(_stat_tiles(pos, wins, games, pay))
	col.add_child(_next_up_pill(transition))

	# Continue CTA.
	var cta := Button.new()
	cta.name = "ContinueBtn"
	cta.text = _cta_text(transition)
	cta.custom_minimum_size = Vector2(0, 52)
	cta.add_theme_stylebox_override("normal", UIStyle.cta(Palette.GOLD))
	cta.add_theme_stylebox_override("hover", UIStyle.cta(Palette.GOLD.lightened(0.05)))
	cta.add_theme_stylebox_override("pressed", UIStyle.cta(Palette.GOLD_DEEP))
	cta.add_theme_color_override("font_color", Palette.BG)
	cta.add_theme_font_size_override("font_size", 15)
	Fonts.weigh(cta, Fonts.W_BOLD)
	cta.pressed.connect(func(): continue_pressed.emit())
	col.add_child(cta)

# Country-gradient band: kicker over the big finish headline (Identity/hub idiom).
func _header_band(pos: int, cset: Dictionary) -> Control:
	var band := PanelContainer.new()
	band.name = "HeaderBand"
	band.add_theme_stylebox_override("panel",
		UIStyle.header(cset["grad1"], cset["grad2"], cset["glow"]))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var kicker := _centered("SEASON COMPLETE", 11, Palette.WHITE_SOFT, Fonts.W_LABEL)
	kicker.name = "Kicker"
	v.add_child(kicker)
	var head := _centered(_headline(pos), 26,
		Palette.GOLD if pos <= 3 else Palette.WHITE, Fonts.W_HEADLINE)
	head.name = "Headline"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(head)
	band.add_child(v)
	return band

# The career-consequence strip. Promoted/complete celebrate on the gold panel
# (Result-screen champion idiom, dark text); everything else is a surface strip
# in the banner's own colour (DO2). Wording from _banner_for, unchanged.
func _transition_strip(transition: Dictionary, career: CareerState) -> Control:
	var b := _banner_for(transition, career)
	var celebrate: bool = transition.get("complete", false) \
		or transition.get("promoted", false)
	var strip := PanelContainer.new()
	strip.name = "TransitionStrip"
	strip.add_theme_stylebox_override("panel",
		UIStyle.cta(Palette.GOLD) if celebrate else UIStyle.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	var banner := _centered(b["text"], 15,
		Palette.BG if celebrate else b["color"], Fonts.W_BOLD)
	banner.name = "Banner"
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(banner)
	if celebrate:
		var sub := _centered("CAREER COMPLETE" if transition.get("complete", false)
			else "YOUR CAREER MOVES UP", 9, Palette.BG, Fonts.W_MEDIUM)
		v.add_child(sub)
	strip.add_child(v)
	return strip

# Season stat tiles: value-over-label cells (Result perf-grid idiom, DO6).
func _stat_tiles(pos: int, wins: int, games: int, pay: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "StatsPanel"
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	for spec: Array in [[_ordinal(pos), "FINISHED", Palette.WHITE],
			["%d of %d won" % [wins, games], "RECORD", Palette.WHITE],
			["₸ %d" % pay, "BANKED", Palette.GOLD]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val := _centered(spec[0], 16, spec[2], Fonts.W_BOLD)
		Fonts.weigh(val, Fonts.W_BOLD, true)
		cell.add_child(val)
		cell.add_child(_centered(spec[1], 8, Palette.WHITE_DIM, Fonts.W_LABEL))
		grid.add_child(cell)
	panel.add_child(grid)
	return panel

# Where Continue takes you, as a centred pill chip.
func _next_up_pill(transition: Dictionary) -> Control:
	var wrap := CenterContainer.new()
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UIStyle.pill(Palette.SURFACE_2))
	var l := _centered(_next_up_text(transition), 11, Palette.WHITE_DIM, Fonts.W_MEDIUM)
	l.name = "NextUp"
	pill.add_child(l)
	wrap.add_child(pill)
	return wrap

func _centered(txt: String, size: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	Fonts.weigh(l, weight)
	return l
```

Delete the old `_stat_row` (superseded by `_stat_tiles`). Keep `_headline`, `_banner_for`, `_next_up_text`, `_cta_text`, `_new_team_name`, `_level_word`, `_ordinal` exactly as they are.

- [ ] **Step 2: Thread the country through `scenes/main.gd`**

At the `_apply_offer_pick` call site (line ~244) and `_show_outcome` (line ~272):

```gdscript
	_show_outcome(play, career, transition, player)
```

```gdscript
func _show_outcome(play: SeasonPlay, career: CareerState, transition: Dictionary,
		player: Player = null) -> void:
	var screen := OUTCOME.instantiate()
	if transition.get("complete", false):
		screen.continue_pressed.connect(func(): LifecycleManager.win_out())
	else:
		# Between seasons the Career Grid is home (ADR 0010) — the next season
		# only starts from its START SEASON.
		screen.continue_pressed.connect(_push_career_grid)
	_push(screen)
	screen.set_outcome(play.season_result(), play.pay_so_far(), play.season_wins(),
		career, transition,
		player.country if player != null else Country.Code.SA)
```

- [ ] **Step 3: Run the suite — verify green, count climbed**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -6`
Expected: `All tests passed` and total tests ≥ 809 (804 + the 5 new guards). All 9 pre-existing outcome tests untouched and passing.

- [ ] **Step 4: Commit**

```bash
git add tests/unit/test_outcome_scene.gd scenes/outcome/outcome.gd scenes/main.gd
git commit -m "feat: Outcome screen hi-fi skin (header band, gold celebration, stat tiles)"
```

### Task 3: Harness re-render + real-window eyeball

**Files:**
- Modify: `tools/preview_outcome.gd`

- [ ] **Step 1: Add the CTRY=aus variant to the harness**

In `_initialize`, after `root.size = ...`:

```gdscript
	if OS.get_environment("CTRY").to_lower() == "aus":
		_country = Country.Code.AUS
		_suffix = "-aus"
		_states = _states.slice(1, 2)   # promoted only — header + celebration proof
```

Add the two vars beside `_stage`:

```gdscript
var _country := Country.Code.SA
var _suffix := ""
```

Pass the country in `_mount` (last arg) and the suffix in the save path:

```gdscript
	_outcome.set_outcome(sr, st["pay"], st["wins"], null, st["t"], _country)
```

```gdscript
		var path := "res://docs/mockups/outcome-%s%s-v1.png" % [st["name"], _suffix]
```

Note: `_states` is populated in `_initialize` before the env check, so slice AFTER assignment (the code above already assumes that order).

- [ ] **Step 2: Render both variants (editor closed; one Godot at a time, sequential)**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_outcome.gd && \
CTRY=aus /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_outcome.gd
```

Expected: `SAVED` ×4 (cleared/promoted/champion/missed, same v1 paths) then `SAVED` ×1 (`outcome-promoted-aus-v1.png`), each run ending `PREVIEW_SAVED`.

- [ ] **Step 3: Eyeball the renders**

Read the 5 PNGs. Check: header band has the gradient + glow and is not collapsed; gold strip readable (dark text on gold); tiles evenly spread; pill centred; nothing clipped (ScrollContainer/flat-button traps don't apply — no ScrollContainer, CTA is a styled non-flat Button).

- [ ] **Step 4: Commit**

```bash
git add tools/preview_outcome.gd docs/mockups/outcome-*.png
git commit -m "tools: Outcome preview country variant + hi-fi renders"
```

### Task 4: Review, PR, merge

- [ ] Run the code-review skill on the branch diff; fix anything real.
- [ ] Push, open PR, merge to `main`, sync local, delete branch (finishing-a-development-branch flow).
- [ ] Update `PROJECT_ROADMAP.md` Next-session block (item 4 done → next = portrait pipeline (5)); commit on `main`.
- [ ] Launch the real game (`/Applications/Godot.app/Contents/MacOS/Godot --path .`) so Nico can play through to a season end.

## Self-review

Spec coverage: header band (T2), transition strip DO2 (T2), stat tiles DO6 (T1/T2), pill (T2), country DO5 (T1/T2 main.gd), contract DO3 (old tests untouched), harness + aus proof (T3), eyeball + launch (T3/T4). Types consistent: `set_outcome(..., country: int = Country.Code.SA)` matches the AUS test call and main.gd pass-through; `_centered` signature matches all call sites.
