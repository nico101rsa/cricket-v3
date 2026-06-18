# Season Hub hi-fi v1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Season Hub the locked hi-fi look (styled panels, broadcast topbar, horizontal fixtures chain, §16.3 portrait frame, rarity joker bench, affinity bar, gold CTA) on a small reusable `Palette` + `UIStyle` design-system foundation — with zero change to the data shown or any simulation behaviour.

**Architecture:** A pure-constants `Palette` (`scripts/data/`) + a code-built `UIStyle` stylebox factory (`scripts/ui/`) become the shared design system. `season_hub.tscn` is rebuilt into the mockup §1 block stack as styled `PanelContainer`s wrapping leaf nodes whose names stay stable; `season_hub.gd`'s `_render_*` functions are rewritten to populate + style them via `Palette`/`UIStyle`. The data contract (`SeasonView` + `SeasonViewBuilder`) and the scene's public API/signals are untouched.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Run the whole suite each step (`--import && gut -gdir=res://tests/unit`); the `-gtest` filter does not work here — judge red by a parse-error on the new `class_name`, green by total count climbing + `All tests passed`.

**Reference:** spec `docs/superpowers/specs/2026-06-18-season-hub-hifi-design.md`. Mockup `docs/mockups/around-the-match-v1.html §1`. Palette/portrait `docs/DESIGN_HANDOFF.md §8 / §16.3`.

---

## File Structure

- **Create** `scripts/data/palette.gd` (`class_name Palette`) — colour constants + `skill_bg()`/`form_glow()` helpers. Pure data.
- **Create** `scripts/ui/ui_style.gd` (`class_name UIStyle`) — static StyleBoxFlat factory (`panel`, `pill`, `chip`, `cta`, `portrait_frame`, `bar_track`, `bar_fill`). Depends on `Palette`.
- **Create** `tests/unit/test_palette.gd`, `tests/unit/test_ui_style.gd`.
- **Modify** `scenes/season_hub/season_hub.tscn` — rebuild `Root` into PanelContainer blocks (leaf names stable).
- **Modify** `scenes/season_hub/season_hub.gd` — rewrite `_render_*` to style + populate via `Palette`/`UIStyle`. Public API/signals unchanged.
- **Modify** `tests/unit/test_season_hub_scene.gd`, `tests/unit/test_season_hub_open_match.gd` — update node paths to the new tree + add new-block visibility asserts.
- **Create** `docs/mockups/season-hub-hifi-built-v1.png` (screenshot deliverable, Task 4).

---

## Task 1: `Palette` colour constants

**Files:**
- Create: `scripts/data/palette.gd`
- Test: `tests/unit/test_palette.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# Palette — the single source of truth for colour (DESIGN_HANDOFF §8 / §16.3).

func test_core_constants_present() -> void:
	assert_eq(Palette.GOLD, Color("ffd166"))
	assert_eq(Palette.BG, Color("1a1a22"))
	assert_eq(Palette.LEGENDARY, Color("ffc23c"))

func test_skill_bg_tiers_by_stars() -> void:
	assert_eq(Palette.skill_bg(4.5), Palette.SKILL_4, "elite")
	assert_eq(Palette.skill_bg(3.0), Palette.SKILL_3, "default 3-star")
	assert_eq(Palette.skill_bg(2.0), Palette.SKILL_2, "2-star")
	assert_eq(Palette.skill_bg(1.0), Palette.SKILL_1, "rookie")

func test_form_glow_maps_each_band() -> void:
	# form ints: >=2 hot, ==1 steady, ==0 tired, <0 cold (display-only mapping).
	assert_eq(Palette.form_glow(3), Palette.FORM_HOT)
	assert_eq(Palette.form_glow(1), Palette.FORM_STEADY)
	assert_eq(Palette.form_glow(0), Palette.FORM_TIRED)
	assert_eq(Palette.form_glow(-1), Palette.FORM_COLD)
```

- [ ] **Step 2: Run suite — verify RED**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `SCRIPT ERROR: Parse Error: Identifier "Palette" not declared` (test file skipped).

- [ ] **Step 3: Implement `Palette`**

```gdscript
class_name Palette
extends RefCounted

# Single source of truth for colour (DESIGN_HANDOFF §8 + §16.3). Pure constants
# + two display helpers; no scene/logic dependency. Every screen reads from here
# so the look is consistent and changing a hex changes it everywhere.

# --- core surfaces ---
const BG := Color("1a1a22")            # app background (dark slate)
const SURFACE := Color("212129")       # raised panel bg (opaque approx of white@4%)
const BORDER := Color("2c2c36")        # subtle panel border / divider
const WHITE := Color("f2f2f5")
const WHITE_DIM := Color("9a9aa6")     # secondary label text

# --- accents ---
const GOLD := Color("ffd166")          # primary "wow" / Tons / player highlight
const WARN := Color("f5a623")
const DANGER := Color("ef6c6c")        # loss / opponent
const BLUE := Color("4a90e2")
const GREEN := Color("2ecc71")         # positive action

# --- country accent (ADR 0001) ---
const SA := Color("1f7a4d")
const AUS := Color("e3a008")

# --- joker rarity (matches the existing scene constants) ---
const COMMON := Color("e8e8e8")
const RARE := Color("4f8cff")
const LEGENDARY := Color("ffc23c")

# --- §16.3 portrait skill-tier background ---
const SKILL_4 := Color("f5cb50")       # elite gold
const SKILL_3 := Color("4a90e2")       # default sky blue
const SKILL_2 := Color("9aa0a6")       # silver
const SKILL_1 := Color("3a3a44")       # rookie charcoal

# --- §16.3 Form glow (portrait frame colour) ---
const FORM_HOT := GOLD
const FORM_STEADY := GREEN
const FORM_TIRED := Color("b8860b")
const FORM_COLD := Color("808080")

# Skill tier background from a team/player star rating.
static func skill_bg(stars: float) -> Color:
	if stars >= 3.5: return SKILL_4
	if stars >= 2.5: return SKILL_3
	if stars >= 1.5: return SKILL_2
	return SKILL_1

# Form glow colour from the SeasonView.form int (display-only banding).
static func form_glow(form: int) -> Color:
	if form >= 2: return FORM_HOT
	if form == 1: return FORM_STEADY
	if form == 0: return FORM_TIRED
	return FORM_COLD
```

- [ ] **Step 4: Run suite — verify GREEN**

Run the same command as Step 2. Expected: total test count up by 3, `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/palette.gd tests/unit/test_palette.gd
git commit -m "feat: Palette — shared colour constants (DESIGN_HANDOFF §8/§16.3)"
```

---

## Task 2: `UIStyle` stylebox factory

**Files:**
- Create: `scripts/ui/ui_style.gd`
- Test: `tests/unit/test_ui_style.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# UIStyle — code-built StyleBoxFlat factory (testable; chosen over a .tres Theme).

func test_panel_box_uses_surface_and_radius() -> void:
	var sb := UIStyle.panel()
	assert_true(sb is StyleBoxFlat)
	assert_eq(sb.bg_color, Palette.SURFACE)
	assert_eq(sb.corner_radius_top_left, 8)

func test_cta_box_takes_accent() -> void:
	var sb := UIStyle.cta(Palette.SA)
	assert_eq(sb.bg_color, Palette.SA)
	assert_eq(sb.corner_radius_top_left, 10)

func test_chip_border_colour_by_rarity() -> void:
	assert_eq(UIStyle.chip("Legendary").border_color, Palette.LEGENDARY)
	assert_eq(UIStyle.chip("Rare").border_color, Palette.RARE)
	assert_eq(UIStyle.chip("Common").border_color, Palette.COMMON)

func test_portrait_frame_bg_and_glow() -> void:
	var sb := UIStyle.portrait_frame(Palette.SKILL_3, Palette.FORM_HOT)
	assert_eq(sb.bg_color, Palette.SKILL_3, "skill bg fill")
	assert_eq(sb.border_color, Palette.FORM_HOT, "form glow border")

func test_bar_fill_takes_accent() -> void:
	assert_eq(UIStyle.bar_fill(Palette.AUS).bg_color, Palette.AUS)
```

- [ ] **Step 2: Run suite — verify RED**

Expected: `Parse Error: Identifier "UIStyle" not declared`.

- [ ] **Step 3: Implement `UIStyle`**

```gdscript
class_name UIStyle
extends RefCounted

# Code-built StyleBoxFlat factory + theme helpers (spec DH1). Static so any scene
# calls UIStyle.panel() etc. without an instance. Every colour comes from Palette.

static func _box(bg: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	return sb

# Raised surface panel (8px radius, subtle border, breathing-room margins).
static func panel() -> StyleBoxFlat:
	var sb := _box(Palette.SURFACE, 8)
	sb.set_border_width_all(1)
	sb.border_color = Palette.BORDER
	sb.content_margin_left = 11; sb.content_margin_right = 11
	sb.content_margin_top = 9; sb.content_margin_bottom = 9
	return sb

# Rounded chip / pill (position pill, fixture dots, team badge).
static func pill(bg: Color) -> StyleBoxFlat:
	var sb := _box(bg, 8)
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 3; sb.content_margin_bottom = 3
	return sb

# Joker chip with a rarity-coloured border (left accent).
static func chip(rarity: String) -> StyleBoxFlat:
	var col: Color = {
		"Common": Palette.COMMON, "Rare": Palette.RARE, "Legendary": Palette.LEGENDARY,
	}.get(rarity, Palette.WHITE)
	var sb := _box(Palette.SURFACE, 8)
	sb.border_width_left = 4
	sb.border_color = col
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 5; sb.content_margin_bottom = 5
	return sb

# Primary CTA tile (solid accent; the "Next Match ▶" button).
static func cta(accent: Color) -> StyleBoxFlat:
	var sb := _box(accent, 10)
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	return sb

# §16.3 portrait: skill-tier bg fill + Form-coloured glow border.
static func portrait_frame(skill_bg: Color, glow: Color) -> StyleBoxFlat:
	var sb := _box(skill_bg, 12)
	sb.set_border_width_all(3)
	sb.border_color = glow
	return sb

# Affinity bar track + fill.
static func bar_track() -> StyleBoxFlat:
	return _box(Palette.BORDER, 4)

static func bar_fill(accent: Color) -> StyleBoxFlat:
	return _box(accent, 4)
```

- [ ] **Step 4: Run suite — verify GREEN**

Expected: count up by 5, `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/ui_style.gd tests/unit/test_ui_style.gd
git commit -m "feat: UIStyle — code-built StyleBoxFlat factory on Palette"
```

---

## Task 3: Rebuild the Season Hub scene with the hi-fi layout

**Files:**
- Modify: `scenes/season_hub/season_hub.tscn` (rebuild `Root` block stack)
- Modify: `scenes/season_hub/season_hub.gd` (rewrite `_render_*`; public API + signals unchanged)
- Modify: `tests/unit/test_season_hub_scene.gd`, `tests/unit/test_season_hub_open_match.gd` (new node paths + visibility asserts)

**New `Root` node tree (PanelContainer blocks; leaf names the code/tests use stay stable):**

```
Scroll/Margin/Root (VBoxContainer, theme separation 10)
├ TopbarPanel (PanelContainer)         → Header (HBox): Badge(Label) · TeamId(VBox: TitleLabel, StarsLabel) · PosPill(Label)
├ TonsPanel (PanelContainer)           → TonsRow (HBox): TonsCol(VBox: TonsCap Label, TonsChip Label) · ContextCol(VBox: ContextLabel, ProgressLabel)
├ FixturesPanel (PanelContainer)       → FixturesWrap (VBox): FixHeader(Label) · FixturesBox (HBoxContainer of fixture Buttons)
├ CardPanel (PanelContainer)           → PlayerCard (HBox): Portrait(PanelContainer: NumLabel, StarsCorner Label, FaceSlot Control) · CardInfo(VBox: NameLabel, OvrFormRow HBox, CareerLabel, AttrLabel)
├ JokersPanel (PanelContainer)         → JokersWrap (VBox): JokHeader(Label) · JokersBox (HBoxContainer)
├ AffinityPanel (PanelContainer)       → AffinityWrap (VBox): AffinityLabel · AffinityBar (PanelContainer track: Fill PanelContainer)
├ PlayNextBtn (Button)                  ← code-added direct child of Root (kept here so has_play_control()'s get_node_or_null("PlayNextBtn") still finds it)
└ ScrubPanel (PanelContainer)          → ScrubBar (HBox): PrevBtn · ScrubLabel · NextBtn
```

`StandingsBox` (the league table — real functionality, kept) lives in its own `StandingsPanel/StandingsWrap/StandingsBox` between AffinityPanel and PlayNextBtn.

- [ ] **Step 1: Update the scene tests to the new tree (RED)**

In `tests/unit/test_season_hub_scene.gd`, replace the node paths and add visibility asserts. New `test_scene_renders_view_and_panels_are_visible`:

```gdscript
func test_scene_renders_view_and_panels_are_visible() -> void:
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	hub.set_view(_view())
	await get_tree().process_frame
	var root := hub.get_node("Scroll/Margin/Root")
	# data still renders
	assert_true(root.get_node("TonsPanel/TonsRow/TonsCol/TonsChip").text.contains("120"), "tons shows balance")
	assert_eq(root.get_node("FixturesPanel/FixturesWrap/FixturesBox").get_child_count(), 7, "7 fixture nodes")
	assert_true(root.get_node("CardPanel/PlayerCard/CardInfo/NameLabel").is_visible_in_tree(), "name visible")
	assert_true(root.get_node("ScrubPanel/ScrubBar/ScrubLabel").text.contains("0"), "scrub readout")
	# new blocks render visible + non-collapsed (StyleBox/ScrollContainer traps)
	for p in ["TopbarPanel", "TonsPanel", "FixturesPanel", "CardPanel", "JokersPanel", "AffinityPanel"]:
		assert_true(root.get_node(p).is_visible_in_tree(), p + " visible")
		assert_gt(root.get_node(p).size.y, 0.0, p + " not collapsed")
	# §16.3 portrait frame present with a swap-in face slot
	assert_true(root.get_node("CardPanel/PlayerCard/Portrait").is_visible_in_tree(), "portrait frame visible")
	assert_not_null(root.get_node_or_null("CardPanel/PlayerCard/Portrait/FaceSlot"), "face swap-in slot exists")
```

Update `test_next_advances_scrub_and_grows_card`'s label path to `Scroll/Margin/Root/ScrubPanel/ScrubBar/ScrubLabel`.
Update `test_live_play_renders_running_table_and_play_control`'s standings path to `StandingsPanel/StandingsWrap/StandingsBox` (keep the `>= 9` and `"1/7"` asserts); `PlayNextBtn` stays at `Scroll/Margin/Root/PlayNextBtn`.
In `tests/unit/test_season_hub_open_match.gd`, update the box path to `Scroll/Margin/Root/FixturesPanel/FixturesWrap/FixturesBox` (still `get_child(0).pressed.emit()` → fixture buttons are the only children of `FixturesBox`).

- [ ] **Step 2: Run suite — verify RED**

Expected: the season-hub scene tests FAIL (node paths don't exist yet) — assertion failures / `get_node: Node not found`.

- [ ] **Step 3: Rebuild `season_hub.tscn`**

Author the new `Root` tree above. Each `*Panel` is a `PanelContainer`; apply `UIStyle.panel()` in code (Step 4) rather than embedding styleboxes in the `.tscn` (keeps colour in one place). Set the `Control` `FaceSlot` `custom_minimum_size = Vector2(56, 72)` so the portrait frame has size even with no face. Give `FixturesBox` and `JokersBox` `HBoxContainer` type. Keep `Scroll`/`Margin` wrapper as-is. Preserve `PrevBtn`/`NextBtn`/`ScrubLabel` names under `ScrubBar`.

- [ ] **Step 4: Rewrite `season_hub.gd` render functions**

Keep all existing public funcs (`boot`, `set_view`, `set_source`, `set_play`, `step`, `scrub_index`, `season`, `current_view`, `live_play`, `current_career`, `has_play_control`) and signals (`open_match`, `play_next`) byte-for-byte in behaviour. Rewrite only the `_render*` block to:
  - `_ready`: connect `ScrubPanel/ScrubBar/PrevBtn|NextBtn` (new paths); apply `UIStyle.panel()` to each `*Panel`; set `self`/Root bg via a `ColorRect` or `Root` theme (set the SeasonHub Control's bg by adding a full-rect `ColorRect(Palette.BG)` behind Scroll, or `RenderingServer`-free: a `Panel` with `_box(Palette.BG,0)`).
  - `_render`: topbar (badge = team initials, `TitleLabel` accent, `StarsLabel` = ★ from `team_stars`, `PosPill` = "{ordinal} · {pts} pts" from `player_final_position` + player's standings points); `TonsCap`="TONS BANKED", `TonsChip`="₸ %d", `ContextLabel`, `ProgressLabel`="MATCH n / 7"; then `_render_fixtures` (horizontal buttons, W/L/●/Mn styling via `UIStyle.pill`, behaviour: played→`open_match`, else→`_rebuild`), `_render_play_next` (CTA via `UIStyle.cta(accent)`, same `play_next.emit`), `_render_card` (portrait frame via `UIStyle.portrait_frame(Palette.skill_bg(team_stars), Palette.form_glow(form))`, `NumLabel`, `StarsCorner`, `NameLabel`, OVR pill, form chip with emoji, batting/bowling stat groups; preserve "no matches yet"), `_render_jokers` (chips via `UIStyle.chip(rarity)` + empty slots to 4), `_render_affinity` (bar fill width = `clampf(affinity/AFF_MAX, 0, 1)` with `AFF_MAX := 100`), `_render_standings` (unchanged logic, styled rows), `_render_scrub`.
  - Form→label helper (display-only): `_form_chip(form) -> String` → {`>=2`:"🔥 Hot", `==1`:"✓ Steady", `==0`:"· Tired", else "❄ Cold"}.
  - Ordinal helper `_ordinal(n)` → "1st/2nd/3rd/Nth".

- [ ] **Step 5: Run suite — verify GREEN**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: all season-hub scene tests pass; total count = prior + 8 (Task1) + 5 (Task2), `All tests passed`. Also clean any iCloud `" 2"` junk first if GUT fails to load (`find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot`).

- [ ] **Step 6: Commit**

```bash
git add scenes/season_hub/season_hub.tscn scenes/season_hub/season_hub.gd scenes/season_hub/season_hub.gd.uid tests/unit/test_season_hub_scene.gd tests/unit/test_season_hub_open_match.gd
git commit -m "feat: Season Hub hi-fi — styled panels, topbar, fixtures chain, §16.3 portrait frame, joker bench, affinity bar, gold CTA"
```

---

## Task 4: Eyeball, screenshot, launch, fill spec §10

**Files:**
- Create: `docs/mockups/season-hub-hifi-built-v1.png`
- Modify: `docs/superpowers/specs/2026-06-18-season-hub-hifi-design.md` (§10 Results)

- [ ] **Step 1: Eyeball in a real 390×844 window**

Quit the Godot editor if open. Launch the game (`/Applications/Godot.app/Contents/MacOS/Godot --path .`) — main routes on a saved player → hub. If no save, run `tools/seed_demo_save.gd` first. Verify against mockup §1: panels have surface bg + radius (NOT default grey), topbar badge/stars/pos pill, ₸ band big-gold, horizontal fixtures chain (W/L/●), portrait frame shows skill-tier colour + form glow + cap number, joker chips rarity-coloured, affinity bar fills, gold "Next Match ▶". Confirm nothing clips or renders invisible (the StyleBox/ScrollContainer traps). Fix in `season_hub.gd`/`.tscn` and re-run the suite if anything is off.

- [ ] **Step 2: Capture the screenshot deliverable**

Save a window screenshot to `docs/mockups/season-hub-hifi-built-v1.png` (live hub, real seeded season).

- [ ] **Step 3: Fill spec §10 + commit**

Record test-count delta, the screenshot path, and the one-line "what to eyeball". Then:

```bash
git add docs/mockups/season-hub-hifi-built-v1.png docs/superpowers/specs/2026-06-18-season-hub-hifi-design.md
git commit -m "docs: Season Hub hi-fi built — screenshot + spec §10 results"
```

- [ ] **Step 4: Launch the playable app for Nico**

Leave the game running (or relaunch) so Nico can navigate the live hub himself (the "launch the playable app, not a screenshot" preference). Report what to look at.

---

## Self-Review

**Spec coverage:** §4.1 Palette → Task 1. §4.2 UIStyle → Task 2. §5 seam (data contract + public API unchanged) → Task 3 Step 4 (explicit). §6 block mapping (all 7 + standings) → Task 3 Steps 3–4. §7 testing (unit + visibility + eyeball + launch) → Tasks 1–2 tests, Task 3 Step 1, Task 4. §3 cuts (frame-only portrait `FaceSlot`, no motion, keep ScrollContainer) → Task 3. §9 decisions reflected. No gap.

**Placeholder scan:** No TBD/TODO/"handle edge cases". §10 of the *spec* is filled in Task 4 (intended). Code blocks present for every code step.

**Type consistency:** `Palette.skill_bg`/`form_glow`, `UIStyle.panel/pill/chip/cta/portrait_frame/bar_track/bar_fill` used identically in tests and the scene. Node paths consistent between the tree diagram, the test updates, and the render rewrite (`FixturesPanel/FixturesWrap/FixturesBox`, `CardPanel/PlayerCard/Portrait/FaceSlot`, `ScrubPanel/ScrubBar/ScrubLabel`, `StandingsPanel/StandingsWrap/StandingsBox`, `PlayNextBtn` direct child of Root for `has_play_control()`).
