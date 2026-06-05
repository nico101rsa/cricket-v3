# Hall of Fame Real Screen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Phase-7 Hall-of-Fame stub with the real screen — a hero card with a live career-arc beat (startRole → endRole), an "Earlier Legends" list, and honest zero-stub career stats.

**Architecture:** Extend `LegendEntry` with additive zero-stub fields plus derived `start_role()`/`end_role()` methods (computed from the Player snapshot via `Classifier`, not stored). Build a new `scenes/hall_of_fame/hall_of_fame.{tscn,gd}` scene with a testable `render_archive(arc)` method, and repoint `main.gd`'s router at it. Skeleton-styled; Theme 6 does visual polish.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6 (headless). Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`.

**Spec:** `docs/superpowers/specs/2026-06-05-hall-of-fame-build-design.md`

**Conventions (project `CLAUDE.md`):** tabs in `.gd`; run `--import` once after adding scripts; never run headless Godot while the editor is open; commit `*.gd.uid`; zsh shell (use `$pipestatus` not `$PIPESTATUS`). Test run:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

---

### Task 1: LegendEntry — stub fields + derived arc roles

**Files:**
- Modify: `scripts/data/legend_entry.gd`
- Test: `tests/unit/test_legend_entry.gd` (create)

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_legend_entry.gd`:

```gdscript
extends GutTest

const LegendEntry = preload("res://scripts/data/legend_entry.gd")
const Player = preload("res://scripts/data/player.gd")
const Attributes = preload("res://scripts/data/attributes.gd")
const ClassifierLabel = preload("res://scripts/domain/classifier_label.gd")

func _player(spw, sco, sat, sct, fpw, fco, fat, fct) -> Player:
	var p := Player.new()
	var s := Attributes.new()
	s.power = spw; s.composure = sco; s.attack = sat; s.control = sct
	var f := Attributes.new()
	f.power = fpw; f.composure = fco; f.attack = fat; f.control = fct
	p.starting_attributes = s
	p.attributes = f
	return p

func test_start_role_reads_starting_attributes():
	var e := LegendEntry.new()
	e.player = _player(8, 8, 2, 2, 8, 8, 2, 2)  # batter-shaped start
	assert_eq(e.start_role(), ClassifierLabel.Kind.BATTER)

func test_end_role_reads_final_attributes_and_can_differ():
	var e := LegendEntry.new()
	e.player = _player(8, 8, 2, 2, 2, 2, 8, 8)  # batter start, bowler-drifted end
	assert_eq(e.start_role(), ClassifierLabel.Kind.BATTER)
	assert_eq(e.end_role(), ClassifierLabel.Kind.BOWLER)

func test_new_stub_fields_default_to_zero_and_gold():
	var e := LegendEntry.new()
	assert_eq(e.levels_won, 0)
	assert_eq(e.retired_season, 0)
	assert_true(e.immortalised)
```

- [ ] **Step 2: Import, then run the test to verify it fails**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_legend_entry.gd -gexit
```
Expected: FAIL — `start_role` / `levels_won` etc. do not exist yet (invalid call / invalid index).

- [ ] **Step 3: Implement the fields + methods**

Replace the body of `scripts/data/legend_entry.gd` with:

```gdscript
class_name LegendEntry
extends Resource

# One archived Player. See spec §6.3 and the HoF build spec §2.

const END_REASON_WON := "won"
const END_REASON_RETIRED := "retired"

@export var player: Player                 # full snapshot at archive time
@export var end_reason: String = ""        # "won" or "retired"
@export var ended_at: int = 0              # Unix epoch seconds
@export var seasons_played: int = 0
@export var levels_won: int = 0            # NEW (HoF spec §2.1) — stub until the Season loop
@export var retired_season: int = 0        # NEW (HoF spec §2.1) — stub until the Season loop
@export var immortalised: bool = true      # NEW (HoF spec §2.1) — V1 always gold
# career_stats deferred — Career Records spec (ADR 0011) owns the schema

# Arc roles are DERIVED from the snapshot, never stored: the Player already holds
# both starting_attributes and (final) attributes, so storing the labels would
# duplicate derivable data and risk drift. Single source of truth = the snapshot.
func start_role() -> int:    # ClassifierLabel.Kind
	return Classifier.classify(player.starting_attributes)

func end_role() -> int:      # ClassifierLabel.Kind
	return Classifier.classify(player.attributes)
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_legend_entry.gd -gexit
```
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/legend_entry.gd scripts/data/legend_entry.gd.uid tests/unit/test_legend_entry.gd tests/unit/test_legend_entry.gd.uid
git commit -m "LegendEntry: stub stat fields + derived start_role/end_role"
```

---

### Task 2: New LegendEntry fields persist through SaveManager

**Files:**
- Modify: `tests/unit/test_save_manager.gd` (add one test)

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_save_manager.gd` (uses the same path-save/restore isolation pattern the file already uses):

```gdscript
func test_archived_legend_new_fields_round_trip():
	var original := SaveManager.legends_save_path
	SaveManager.legends_save_path = "user://_test_hof_fields.tres"
	SaveManager.clear_legends()

	var p := Player.new()
	var n := NamePair.new()
	n.first_name = "Faf"; n.surname = "Keeper"
	p.name = n
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	p.attributes = a
	p.starting_attributes = a.duplicate_typed()

	SaveManager.archive_to_legends(p, LegendEntry.END_REASON_RETIRED, 0)
	var arc := SaveManager.load_legends()
	var e: LegendEntry = arc.entries[0]
	assert_eq(e.levels_won, 0)
	assert_eq(e.retired_season, 0)
	assert_true(e.immortalised)

	SaveManager.clear_legends()
	SaveManager.legends_save_path = original
```

If `Player`, `NamePair`, `Attributes`, or `LegendEntry` are not already `preload`-ed as consts at the top of `test_save_manager.gd`, add the missing ones (check the file's existing const block first; they are `class_name`-typed so bare references also resolve — only add a preload if the file's style uses them).

- [ ] **Step 2: Run the test to verify it passes immediately**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_save_manager.gd -gexit
```
Expected: PASS — this is a verification test (Task 1 already made the fields `@export`, so they serialize). If it FAILS with the fields missing/zeroed unexpectedly, confirm Task 1's fields use `@export` (plain `var` would not persist).

- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_save_manager.gd
git commit -m "Test: new LegendEntry stat fields round-trip through SaveManager"
```

---

### Task 3: The real Hall of Fame scene

**Files:**
- Create: `scenes/hall_of_fame/hall_of_fame.gd`
- Create: `scenes/hall_of_fame/hall_of_fame.tscn`
- Test: `tests/unit/test_hall_of_fame_scene.gd` (create)

- [ ] **Step 1: Write the failing scene test**

Create `tests/unit/test_hall_of_fame_scene.gd`:

```gdscript
extends GutTest

const HallOfFame = preload("res://scenes/hall_of_fame/hall_of_fame.tscn")
const LegendsArchive = preload("res://scripts/data/legends_archive.gd")
const LegendEntry = preload("res://scripts/data/legend_entry.gd")
const Player = preload("res://scripts/data/player.gd")
const Attributes = preload("res://scripts/data/attributes.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func _legend(first: String, surname: String, pw: int, co: int, at: int, ct: int) -> LegendEntry:
	var p := Player.new()
	var n := NamePair.new()
	n.first_name = first; n.surname = surname
	p.name = n
	p.appearance = Appearance.Bucket.WHITE
	var s := Attributes.new()
	s.power = pw; s.composure = co; s.attack = at; s.control = ct
	p.starting_attributes = s
	p.attributes = s.duplicate_typed()
	var e := LegendEntry.new()
	e.player = p
	return e

func _archive(entries: Array) -> LegendsArchive:
	var a := LegendsArchive.new()
	for e in entries:
		a.entries.append(e)
	return a

func test_hero_is_most_recent_and_count_reflects_size():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	# archive is oldest-first; the bowler is appended last → hero
	hof.render_archive(_archive([
		_legend("Jonty", "Springer", 8, 8, 2, 2),   # oldest, batter
		_legend("Dale", "Steyner", 2, 2, 8, 8),       # newest, bowler
	]))
	assert_eq(hof._count.text, "2 Legends")
	assert_string_contains(hof._hero_name.text, "DALE STEYNER")
	assert_string_contains(hof._hero_arc.text, "BOWLER")

func test_earlier_list_has_n_minus_one_rows():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	hof.render_archive(_archive([
		_legend("A", "One", 8, 8, 2, 2),
		_legend("B", "Two", 8, 8, 2, 2),
		_legend("C", "Three", 2, 2, 8, 8),
	]))
	assert_eq(hof._earlier_list.get_child_count(), 2)

func test_single_legend_has_zero_earlier_rows():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	hof.render_archive(_archive([_legend("A", "One", 8, 8, 2, 2)]))
	assert_eq(hof._earlier_list.get_child_count(), 0)

func test_new_player_button_emits_signal():
	var hof = HallOfFame.instantiate()
	add_child_autofree(hof)
	await get_tree().process_frame
	watch_signals(hof)
	hof._new_player_btn.pressed.emit()
	assert_signal_emitted(hof, "begin_new_player")
```

- [ ] **Step 2: Write the scene script**

Create `scenes/hall_of_fame/hall_of_fame.gd`:

```gdscript
extends Control

# Real Hall of Fame. Replaces the Phase-7 stub. See HoF build spec §3.
# Skeleton-styled (Theme 6 polishes visuals). The one live element is the
# career-arc beat (startRole → endRole), derived from each Legend's snapshot.

signal begin_new_player()

const BADGE_GOLD := Color("d4af37")

@onready var _count: Label = $Layout/Header/Count
@onready var _hero: VBoxContainer = $Layout/Hero
@onready var _hero_portrait: ColorRect = $Layout/Hero/HeroPortrait
@onready var _hero_badge: Label = $Layout/Hero/Badge
@onready var _hero_name: Label = $Layout/Hero/HeroName
@onready var _hero_meta: Label = $Layout/Hero/Meta
@onready var _hero_arc: Label = $Layout/Hero/Arc
@onready var _hero_strip: Label = $Layout/Hero/Strip
@onready var _earlier_header: Label = $Layout/EarlierHeader
@onready var _earlier_list: VBoxContainer = $Layout/EarlierScroll/EarlierList
@onready var _new_player_btn: Button = $Layout/NewPlayerBtn

func _ready() -> void:
	_new_player_btn.pressed.connect(func(): begin_new_player.emit())
	_hero_badge.add_theme_color_override("font_color", BADGE_GOLD)
	render_archive(SaveManager.load_legends())

# Pure render from an archive — injectable for tests. The archive is stored
# oldest-first (SaveManager appends), so the hero is the last entry and the
# earlier list walks backwards from the second-to-last down to index 0.
func render_archive(arc: LegendsArchive) -> void:
	_count.text = "%d Legends" % arc.entries.size()
	for c in _earlier_list.get_children():
		c.queue_free()

	if arc.entries.is_empty():
		_hero.visible = false
		_earlier_header.visible = false
		return

	_hero.visible = true
	_render_hero(arc.entries.back())

	var earlier_count := arc.entries.size() - 1
	_earlier_header.visible = earlier_count > 0
	for i in range(arc.entries.size() - 2, -1, -1):
		_earlier_list.add_child(_make_row(arc.entries[i]))

func _render_hero(e: LegendEntry) -> void:
	_hero_portrait.color = AppearancePicker.placeholder_tint(e.player.appearance)
	_hero_badge.text = _badge_text(e)
	_hero_name.text = e.player.name.display_caps()
	_hero_meta.text = "%d Seasons played · %d Levels won" % [e.seasons_played, e.levels_won]
	_hero_arc.text = "%s   →   %s" % [_role(e.start_role()), _role(e.end_role())]
	_hero_strip.text = "%d Seasons · %d Levels won · ₸%d" % [e.seasons_played, e.levels_won, e.player.tons_balance]

func _badge_text(e: LegendEntry) -> String:
	# Drop the "· S{n}" suffix while there is no Season system to make it meaningful.
	if e.retired_season > 0:
		return "★ Immortalised · S%d" % e.retired_season
	return "★ Immortalised"

func _role(kind: int) -> String:
	return ClassifierLabel.display_name(kind)

func _make_row(e: LegendEntry) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(40, 40)
	swatch.color = AppearancePicker.placeholder_tint(e.player.appearance)
	row.add_child(swatch)
	var label := Label.new()
	label.text = "%s    %s → %s    %d Seasons" % [
		e.player.name.display_caps(), _role(e.start_role()), _role(e.end_role()), e.seasons_played]
	row.add_child(label)
	return row
```

- [ ] **Step 3: Write the scene file**

Create `scenes/hall_of_fame/hall_of_fame.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/hall_of_fame/hall_of_fame.gd" id="1"]

[node name="HallOfFame" type="Control"]
anchors_preset = 15
script = ExtResource("1")

[node name="Layout" type="VBoxContainer" parent="."]
anchors_preset = 15
offset_left = 16.0
offset_top = 24.0
offset_right = -16.0
offset_bottom = -24.0
theme_override_constants/separation = 12

[node name="Header" type="HBoxContainer" parent="Layout"]

[node name="Title" type="Label" parent="Layout/Header"]
size_flags_horizontal = 3
text = "HALL OF FAME"

[node name="Count" type="Label" parent="Layout/Header"]
text = "0 Legends"

[node name="Hero" type="VBoxContainer" parent="Layout"]
theme_override_constants/separation = 6

[node name="HeroPortrait" type="ColorRect" parent="Layout/Hero"]
custom_minimum_size = Vector2(120, 120)
color = Color(0.2, 0.2, 0.2, 1)

[node name="Badge" type="Label" parent="Layout/Hero"]
text = "★ Immortalised"

[node name="HeroName" type="Label" parent="Layout/Hero"]
text = "—"

[node name="Meta" type="Label" parent="Layout/Hero"]
text = "0 Seasons played · 0 Levels won"

[node name="Arc" type="Label" parent="Layout/Hero"]
text = "—   →   —"

[node name="Strip" type="Label" parent="Layout/Hero"]
text = "0 Seasons · 0 Levels won · ₸0"

[node name="EarlierHeader" type="Label" parent="Layout"]
text = "Earlier Legends"

[node name="EarlierScroll" type="ScrollContainer" parent="Layout"]
size_flags_vertical = 3

[node name="EarlierList" type="VBoxContainer" parent="Layout/EarlierScroll"]
size_flags_horizontal = 3
theme_override_constants/separation = 8

[node name="NewPlayerBtn" type="Button" parent="Layout"]
text = "NEW PLAYER ▶"
```

- [ ] **Step 4: Import, then run the scene test**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_hall_of_fame_scene.gd -gexit
```
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add scenes/hall_of_fame/ tests/unit/test_hall_of_fame_scene.gd tests/unit/test_hall_of_fame_scene.gd.uid
git commit -m "Add real Hall of Fame scene (hero card + arc beat + earlier legends)"
```

---

### Task 4: Route the router at the real scene; delete the stub

**Files:**
- Modify: `scenes/main.gd:9`
- Delete: `scenes/stubs/hall_of_fame_stub.tscn`, `scenes/stubs/hall_of_fame_stub.gd`, `scenes/stubs/hall_of_fame_stub.gd.uid`

- [ ] **Step 1: Repoint the preload**

In `scenes/main.gd`, change line 9 from:

```gdscript
const HALL_OF_FAME := preload("res://scenes/stubs/hall_of_fame_stub.tscn")
```
to:
```gdscript
const HALL_OF_FAME := preload("res://scenes/hall_of_fame/hall_of_fame.tscn")
```

The `_on_career_ended` body and the `begin_new_player.connect(...)` wiring stay exactly as-is — the new scene exposes the same `begin_new_player` signal with the same (zero) arity.

- [ ] **Step 2: Delete the stub files**

```bash
git rm scenes/stubs/hall_of_fame_stub.tscn scenes/stubs/hall_of_fame_stub.gd scenes/stubs/hall_of_fame_stub.gd.uid
```

- [ ] **Step 3: Import, then run the FULL suite**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing Tests|All tests passed|fail"
```
Expected: all tests pass (69 prior + 3 LegendEntry + 1 SaveManager + 4 scene = 77), `---- All tests passed! ----`. If the router test references the deleted stub, update its preload to the new path (a pre-check found no such reference, but confirm).

- [ ] **Step 4: Commit**

```bash
git add scenes/main.gd scenes/main.gd.uid
git commit -m "Route career-end at the real Hall of Fame; remove the stub"
```

---

### Task 5: Manual eyeball in a real window

Unit tests are blind to invisibility (the Phase-5 `flat`-Button-`modulate` lesson — see project `CLAUDE.md`). This step is mandatory; do not mark the feature done on green tests alone.

- [ ] **Step 1: Quit the Godot editor if open** (⌘Q). Two headless+editor instances importing at once deadlock.

- [ ] **Step 2: Launch the app and walk the loop**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```
In the window (390×844):
1. If a save exists you land on the Season hub; if not, create a Player first (Identity → Build → Confirm → Starting Team → Season hub).
2. From the Season hub, trigger an end-state (`[DEV]` win cheat, or Manual-retire confirm).
3. **On the Hall of Fame, confirm by eye:** hero card visible · **gold** `★ Immortalised` badge · **both arc pills/labels render** (e.g. `ALL-ROUNDER → ALL-ROUNDER`) · portrait tint shows (not black) · `0 Seasons · 0 Levels won · ₸0` strip reads honestly · Legend count correct.
4. Tap **NEW PLAYER** → routes to Identity. Create a second Player, end that career too → the Hall of Fame now shows the newest as hero **and one row under "Earlier Legends"**.
5. Quit and relaunch → ending a third career still shows all prior Legends (persistence holds).

- [ ] **Step 3: Note any visual defects.** Stub cosmetics (skeleton spacing, no real portrait art) are expected and NOT defects — those are Theme 6. A defect is: a missing/black element, an empty arc beat, a wrong count, or a crash.

---

## Self-review notes

- **Spec coverage:** §2.1 fields → Task 1; §2.2 derived roles → Task 1; §3 screen (header/hero/badge/arc/strip/earlier/button) → Task 3; §3.2 edge cases (empty archive hides hero; single legend = 0 earlier rows) → Task 3 tests; §4 router swap + stub delete → Task 4; §5 tests incl. eyeball → Tasks 1–5. `lifetime_tons` from `player.tons_balance` → Task 3 `_hero_strip`. Badge "drop S0" rule → Task 3 `_badge_text`.
- **Type consistency:** `render_archive`, `start_role`/`end_role`, `placeholder_tint`, `display_caps`, `ClassifierLabel.display_name`, `ClassifierLabel.Kind.*`, `Classifier.classify` all match their real signatures verified against the codebase.
- **Ordering:** archive is oldest-first (`append`); hero = `entries.back()`, earlier walks `size-2 .. 0`. Tests encode this explicitly.
