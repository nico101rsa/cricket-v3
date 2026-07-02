# Portrait Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the shared `hero-cap.png` placeholder with a 16-face portrait system (4 appearance buckets × 4 form bands) built from the recovered design deliverable, wired into Identity, Season Hub, and Hall of Fame.

**Architecture:** A Python tool derives the 16 runtime PNGs from design's `clean/face-*` tiles (skin-tone remap per bucket). A `FormBand` domain helper is the single form-banding seam (fixes the fresh-player-reads-TIRED bug); `PortraitLibrary` maps (bucket, form) → cached `Texture2D`. Consumers swap their placeholder for library lookups. Spec: `docs/superpowers/specs/2026-07-03-portrait-pipeline-design.md` (DP1–DP10).

**Tech Stack:** Godot 4.6.3 / GDScript (tabs), GUT 9.6, Python 3 + Pillow (tool only).

**Conventions that bite here:** run `--import` after adding scripts/PNGs before tests; never run headless Godot with the editor open; whole-suite runs only (`-gdir=res://tests/unit`); red = parse error for a missing `class_name`, green = count climbing + `All tests passed`; test `.gd` files have no `.uid`; enum values cross class boundaries as `int`.

---

### Task 1: Generate the 16 runtime portraits

**Files:**
- Create: `tools/gen_portraits.py`
- Create (generated): `assets/portraits/{white,mixed,indian,black}-{hot,steady,tired,cold}.png`
- Create (generated): `docs/mockups/portraits-grid-v1.png` (4×4 contact sheet)

- [ ] **Step 1: Write the generator**

```python
#!/usr/bin/env python3
"""Derive the 16 runtime portraits (bucket x form band) from the design drop.

Source tiles: docs/design-drop/portraits/clean/face-<expr>.png (light skin).
WHITE = source untouched. Other buckets: skin pixels (warm hue mask) are
scaled per-channel toward the bucket's target mean tone (the appearance
picker's placeholder tints), preserving the cartoon shading.
Stopgap per spec DP4 -- replaced when design answers the tones brief.
Run from the repo root:  python3 tools/gen_portraits.py
"""
import colorsys
import pathlib

from PIL import Image

SRC = pathlib.Path("docs/design-drop/portraits/clean")
OUT = pathlib.Path("assets/portraits")
GRID = pathlib.Path("docs/mockups/portraits-grid-v1.png")

# DP2 -- form band -> design expression
BAND_EXPR = {"hot": "confident", "steady": "neutral", "tired": "disappointed", "cold": "angry"}
# DP4 -- target mean skin tone per bucket (appearance_picker.placeholder_tint)
WHITE_MEAN = (0.95, 0.86, 0.76)  # design's light skin ~= the WHITE tint
BUCKET_MEAN = {
    "white": None,  # untouched
    "mixed": (0.78, 0.62, 0.48),
    "indian": (0.62, 0.45, 0.33),
    "black": (0.36, 0.24, 0.18),
}

def is_skin(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    deg = h * 360
    # warm skin hues; excludes green cap, white shirt (low sat), navy bg, gold roundel (>=42deg)
    return 8 <= deg <= 42 and s >= 0.22 and v >= 0.25

def remap(im, mean):
    ratio = tuple(mean[i] / WHITE_MEAN[i] for i in range(3))
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if is_skin(r, g, b):
                px[x, y] = (
                    min(255, round(r * ratio[0])),
                    min(255, round(g * ratio[1])),
                    min(255, round(b * ratio[2])),
                    a,
                )
    return im

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = {}
    for bucket, mean in BUCKET_MEAN.items():
        for band, expr in BAND_EXPR.items():
            im = Image.open(SRC / f"face-{expr}.png").convert("RGBA")
            if mean is not None:
                im = remap(im, mean)
            dest = OUT / f"{bucket}-{band}.png"
            im.save(dest)
            tiles[(bucket, band)] = im
            print("wrote", dest)
    # contact sheet: rows = buckets, cols = bands
    w, h = tiles[("white", "hot")].size
    sheet = Image.new("RGBA", (w * 4, h * 4))
    for r, bucket in enumerate(BUCKET_MEAN):
        for c, band in enumerate(BAND_EXPR):
            sheet.paste(tiles[(bucket, band)], (c * w, r * h))
    GRID.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(GRID)
    print("wrote", GRID)

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it**

Run: `python3 tools/gen_portraits.py`
Expected: 16 `wrote assets/portraits/<bucket>-<band>.png` lines + the grid.

- [ ] **Step 3: Eyeball the contact sheet** (Read `docs/mockups/portraits-grid-v1.png`). Check: 4 distinct skin tones lightest→darkest per row; expressions read confident/neutral/disappointed/angry per column; no banding/bleed on cap, shirt, or background. Iterate the hue mask if the cap roundel or lips shifted. **DP4 fallback if unfixable:** ship the 4 `white-*` faces for all buckets (`mean=None` everywhere) and note it in the roadmap.

- [ ] **Step 4: Commit**

```bash
git add tools/gen_portraits.py assets/portraits/*.png docs/mockups/portraits-grid-v1.png
git commit -m "feat: generate the 16 runtime portraits from the design drop (DP1/DP2/DP4)"
```

---

### Task 2: FormBand — the canonical form banding

**Files:**
- Create: `scripts/domain/form_band.gd` (+ commit its `.gd.uid`)
- Modify: `scripts/data/palette.gd:84-89` (`form_glow` delegates)
- Modify: `tests/unit/test_palette.gd:16-21` (re-pin per DP3)
- Test: `tests/unit/test_form_band.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# DP3: canonical banding -- HOT >=2, STEADY 0..1, TIRED == -1, COLD <= -2.
# Fixes the latent bug where a fresh player (form 0) displayed as TIRED.

func test_banding_table() -> void:
	assert_eq(FormBand.of(3), FormBand.Band.HOT)
	assert_eq(FormBand.of(2), FormBand.Band.HOT)
	assert_eq(FormBand.of(1), FormBand.Band.STEADY)
	assert_eq(FormBand.of(0), FormBand.Band.STEADY, "fresh player reads STEADY")
	assert_eq(FormBand.of(-1), FormBand.Band.TIRED)
	assert_eq(FormBand.of(-2), FormBand.Band.COLD)

func test_keys_and_labels() -> void:
	assert_eq(FormBand.key(FormBand.Band.HOT), "hot")
	assert_eq(FormBand.key(FormBand.Band.STEADY), "steady")
	assert_eq(FormBand.key(FormBand.Band.TIRED), "tired")
	assert_eq(FormBand.key(FormBand.Band.COLD), "cold")
	assert_eq(FormBand.label(FormBand.Band.HOT), "HOT")
	assert_eq(FormBand.label(FormBand.Band.COLD), "COLD")

func test_palette_glow_follows_formband() -> void:
	assert_eq(Palette.form_glow(0), Palette.FORM_STEADY, "0 is STEADY now, not TIRED")
	assert_eq(Palette.form_glow(-1), Palette.FORM_TIRED)
	assert_eq(Palette.form_glow(-2), Palette.FORM_COLD)
	assert_eq(Palette.form_glow(2), Palette.FORM_HOT)
```

- [ ] **Step 2: Import + run — verify red** (parse error `Identifier "FormBand" not declared`)

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && \
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

- [ ] **Step 3: Implement `scripts/domain/form_band.gd`**

```gdscript
class_name FormBand
extends RefCounted

# The single form-banding seam (spec DP3). Display + portrait consumers band a raw
# Player.form int here; the future Form-mechanic rung re-tunes ticks against this.
# Fresh players (form 0) are STEADY -- 0 used to read TIRED in the hub chip.
enum Band { COLD = 0, TIRED = 1, STEADY = 2, HOT = 3 }

static func of(form: int) -> int:
	if form >= 2: return Band.HOT
	if form >= 0: return Band.STEADY
	if form == -1: return Band.TIRED
	return Band.COLD

static func key(band: int) -> String:
	match band:
		Band.HOT: return "hot"
		Band.STEADY: return "steady"
		Band.TIRED: return "tired"
		_: return "cold"

static func label(band: int) -> String:
	return key(band).to_upper()
```

- [ ] **Step 4: Delegate `Palette.form_glow` (scripts/data/palette.gd)**

```gdscript
# Form glow colour from the raw form int (banding lives in FormBand -- DP3).
static func form_glow(form: int) -> Color:
	match FormBand.of(form):
		FormBand.Band.HOT: return FORM_HOT
		FormBand.Band.STEADY: return FORM_STEADY
		FormBand.Band.TIRED: return FORM_TIRED
		_: return FORM_COLD
```

- [ ] **Step 5: Re-pin `tests/unit/test_palette.gd` `test_form_glow_maps_each_band`**

```gdscript
func test_form_glow_maps_each_band() -> void:
	# form ints (DP3): >=2 hot, 0..1 steady, -1 tired, <=-2 cold (display-only mapping).
	assert_eq(Palette.form_glow(3), Palette.FORM_HOT)
	assert_eq(Palette.form_glow(1), Palette.FORM_STEADY)
	assert_eq(Palette.form_glow(0), Palette.FORM_STEADY)
	assert_eq(Palette.form_glow(-1), Palette.FORM_TIRED)
	assert_eq(Palette.form_glow(-2), Palette.FORM_COLD)
```

- [ ] **Step 6: Import + run — verify green** (same two commands; count climbs, `All tests passed`)

- [ ] **Step 7: Commit**

```bash
git add scripts/domain/form_band.gd scripts/domain/form_band.gd.uid tests/unit/test_form_band.gd scripts/data/palette.gd tests/unit/test_palette.gd
git commit -m "feat: FormBand canonical banding; fresh player reads STEADY not TIRED (DP3)"
```

---

### Task 3: PortraitLibrary

**Files:**
- Create: `scripts/ui/portrait_library.gd` (+ `.gd.uid`)
- Test: `tests/unit/test_portrait_library.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

func test_path_maps_bucket_and_band() -> void:
	assert_eq(PortraitLibrary.path(Appearance.Bucket.WHITE, FormBand.Band.STEADY), "res://assets/portraits/white-steady.png")
	assert_eq(PortraitLibrary.path(Appearance.Bucket.BLACK, FormBand.Band.HOT), "res://assets/portraits/black-hot.png")

func test_unknown_inputs_clamp_to_white_steady() -> void:
	assert_eq(PortraitLibrary.path(-1, 99), "res://assets/portraits/white-steady.png")

func test_texture_loads_and_caches_all_16() -> void:
	for bucket in Appearance.all():
		for band in [FormBand.Band.HOT, FormBand.Band.STEADY, FormBand.Band.TIRED, FormBand.Band.COLD]:
			var tex := PortraitLibrary.texture_for(bucket, _form_for(band))
			assert_not_null(tex, PortraitLibrary.path(bucket, band))
			assert_true(tex is Texture2D)
	var a := PortraitLibrary.texture_for(Appearance.Bucket.MIXED, 0)
	var b := PortraitLibrary.texture_for(Appearance.Bucket.MIXED, 1)
	assert_eq(a, b, "same band returns the cached object")

# raw form int that lands in the given band (texture_for takes a raw form, not a band)
func _form_for(band: int) -> int:
	match band:
		FormBand.Band.HOT: return 2
		FormBand.Band.STEADY: return 0
		FormBand.Band.TIRED: return -1
		_: return -2
```

- [ ] **Step 2: Import + run — verify red** (parse error: `PortraitLibrary` not declared)

- [ ] **Step 3: Implement `scripts/ui/portrait_library.gd`**

```gdscript
class_name PortraitLibrary
extends RefCounted

# (appearance bucket, raw form int) -> portrait texture (spec DP5).
# Portraits carry NO data -- flavour only. Unknown inputs clamp to white/steady.
# Lazy load() + cache: 16 small PNGs, loaded at most once each.

static var _cache: Dictionary = {}

static func path(bucket: int, band: int) -> String:
	var b_key := Appearance.to_key(bucket)
	if b_key.is_empty():
		b_key = "white"
	var f_key := FormBand.key(band) if band >= FormBand.Band.COLD and band <= FormBand.Band.HOT else "steady"
	return "res://assets/portraits/%s-%s.png" % [b_key, f_key]

static func texture_for(bucket: int, form: int) -> Texture2D:
	var p := path(bucket, FormBand.of(form))
	if not _cache.has(p):
		_cache[p] = load(p)
	return _cache[p]
```

- [ ] **Step 4: Import + run — verify green**

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/portrait_library.gd scripts/ui/portrait_library.gd.uid tests/unit/test_portrait_library.gd
git commit -m "feat: PortraitLibrary (bucket x form -> cached texture) (DP5)"
```

---

### Task 4: Identity — live hero-swap + real picker thumbnails

**Files:**
- Modify: `scenes/player_creation/identity.gd` (hero texture + swap on pick; drop `_HERO_PORTRAIT` const at line 13)
- Modify: `scenes/player_creation/appearance_picker.gd` (tiles become face thumbnails)
- Test: `tests/unit/test_identity_scene.gd` (append)

- [ ] **Step 1: Write the failing tests** (append to `test_identity_scene.gd`, matching its existing setup helpers)

```gdscript
func test_hero_swaps_on_appearance_pick() -> void:
	var scene := _make_scene()  # use this file's existing scene-construction helper name
	var hero: TextureRect = _find_hero(scene)
	var before := hero.texture
	scene._on_appearance_selected(Appearance.Bucket.BLACK)
	assert_eq(hero.texture, PortraitLibrary.texture_for(Appearance.Bucket.BLACK, 0))
	assert_ne(hero.texture, before, "picking BLACK swaps the hero art")

func test_picker_tiles_show_face_thumbnails() -> void:
	var picker := AppearancePicker.new()
	add_child_autofree(picker)
	for bucket in Appearance.all():
		var btn: Button = picker.button_for(bucket)
		assert_eq(btn.icon, PortraitLibrary.texture_for(bucket, 0), Appearance.to_key(bucket))
```

Note: `_find_hero`/`_make_scene` stand in for whatever accessor the existing test file
uses to build the scene and reach `_hero_portrait` — reuse its existing pattern (it
already asserts on hero panel styling from the PR #96 hi-fi guards). Add a small
`button_for(bucket: int) -> Button` accessor to the picker (returns `_buttons[bucket]`).

- [ ] **Step 2: Import + run — verify red** (assert failures / missing `button_for`)

- [ ] **Step 3: Implement.** In `identity.gd`: delete the `_HERO_PORTRAIT` const; in `_build_hero()` set

```gdscript
	_hero_portrait.texture = PortraitLibrary.texture_for(_draft.appearance, 0)
```

in `_on_appearance_selected(bucket)` add the swap before the re-roll:

```gdscript
func _on_appearance_selected(bucket: int) -> void:
	_draft.appearance = bucket
	_hero_portrait.texture = PortraitLibrary.texture_for(bucket, 0)
	_reroll_name_if_possible()                # name bank slice changed
	_refresh_next_enabled()
```

(also re-apply the texture in the `set_draft` re-hydration path where the picker is
restored via `set_selected_silent`, so Back navigation shows the picked face.)

In `appearance_picker.gd` `_ready()` loop, after the stylebox overrides:

```gdscript
		btn.icon = PortraitLibrary.texture_for(bucket, 0)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
```

and give every state stylebox a content margin so the selection ring stays visible
around the opaque face tile — in `_make_tile_style` add:

```gdscript
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
```

plus the accessor:

```gdscript
func button_for(bucket: int) -> Button:
	return _buttons.get(bucket)
```

- [ ] **Step 4: Import + run — verify green** (all pre-existing Identity guards must stay green: country re-theme, re-roll, Next-gating, Back re-hydration)

- [ ] **Step 5: Commit**

```bash
git add scenes/player_creation/identity.gd scenes/player_creation/appearance_picker.gd tests/unit/test_identity_scene.gd
git commit -m "feat: Identity hero live-swaps on appearance pick; picker tiles show real faces (DP6)"
```

---

### Task 5: Season Hub — portrait by bucket×form + de-emoji'd chip

**Files:**
- Modify: `scenes/season_hub/season_hub.gd` (line 12 const, line 120 portrait, lines 388/498-502 chip)
- Test: `tests/unit/test_season_hub_scene.gd` (append; follow its existing view/scene helpers)

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_player_card_portrait_matches_bucket_and_form() -> void:
	var hub := _make_hub_with_view()  # reuse this file's existing builder; set view.appearance = Appearance.Bucket.INDIAN, view.form = 2
	var tex: TextureRect = hub._root.get_node("CardPanel/PlayerCard/Portrait/PortraitTex")
	assert_eq(tex.texture, PortraitLibrary.texture_for(Appearance.Bucket.INDIAN, 2))

func test_form_chip_is_plain_text_no_emoji() -> void:
	assert_eq(_chip_text(2), "HOT")     # _chip_text wraps hub._form_chip
	assert_eq(_chip_text(0), "STEADY")  # fresh player: STEADY, not TIRED
	assert_eq(_chip_text(-1), "TIRED")
	assert_eq(_chip_text(-2), "COLD")
```

- [ ] **Step 2: Import + run — verify red**

- [ ] **Step 3: Implement.** Replace line 12's `const HERO_CAP := preload(...)` usage: delete the const, and at line ~120:

```gdscript
	_root.get_node("CardPanel/PlayerCard/Portrait/PortraitTex").texture = PortraitLibrary.texture_for(_view.appearance, _view.form)
```

(this line currently runs in the one-time style pass — move it to wherever `_view` is
already bound when styling runs; if the style pass runs before the view exists, set the
texture in the same refresh function that sets `form_chip.text` at line 388.)

Replace `_form_chip` (lines 498-502):

```gdscript
func _form_chip(form: int) -> String:
	return FormBand.label(FormBand.of(form))  # no emoji -- Barlow tofus them (DP7)
```

- [ ] **Step 4: Import + run — verify green**

- [ ] **Step 5: Commit**

```bash
git add scenes/season_hub/season_hub.gd tests/unit/test_season_hub_scene.gd
git commit -m "feat: hub player card wears the bucket x form portrait; form chip de-emoji'd (DP6/DP7)"
```

---

### Task 6: Hall of Fame — real portrait for the hero legend

**Files:**
- Modify: `scenes/hall_of_fame/hall_of_fame.tscn:29-31` (ColorRect → TextureRect)
- Modify: `scenes/hall_of_fame/hall_of_fame.gd:13,54`
- Test: `tests/unit/test_hall_of_fame_scene.gd` (append/adjust; if an existing test pins `_hero_portrait.color`, re-pin it to the texture)

- [ ] **Step 1: Write the failing test**

```gdscript
func test_hero_legend_shows_bucket_portrait() -> void:
	# reuse this file's existing archive/scene fixture; hero entry player has appearance = Appearance.Bucket.MIXED, form 0
	var tex: TextureRect = scene.get_node("Layout/Hero/HeroPortrait")
	assert_eq(tex.texture, PortraitLibrary.texture_for(Appearance.Bucket.MIXED, 0))
```

- [ ] **Step 2: Import + run — verify red**

- [ ] **Step 3: Implement.** In the `.tscn`, change the node:

```
[node name="HeroPortrait" type="TextureRect" parent="Layout/Hero"]
custom_minimum_size = Vector2(120, 120)
expand_mode = 5
stretch_mode = 6
```

(`expand_mode = 5` = FIT_HEIGHT_PROPORTIONAL keeps the 120px row; `stretch_mode = 6` = KEEP_ASPECT_COVERED matches the other portrait frames. If the row centring shifts, eyeball in Task 7 and adjust `size_flags_horizontal`.)

In the `.gd`: line 13 type becomes `TextureRect`; `_render_hero` line 54 becomes:

```gdscript
	_hero_portrait.texture = PortraitLibrary.texture_for(e.player.appearance, e.player.form)
```

- [ ] **Step 4: Import + run — verify green** (watch the HoF visibility guards — `row.size.y > 0` assertions must stay green)

- [ ] **Step 5: Commit**

```bash
git add scenes/hall_of_fame/hall_of_fame.tscn scenes/hall_of_fame/hall_of_fame.gd tests/unit/test_hall_of_fame_scene.gd
git commit -m "feat: Hall of Fame hero wears the real portrait (DP6)"
```

---

### Task 7: Renders, hero-cap retirement, design brief, roadmap

**Files:**
- Create: `tools/preview_portraits.gd` (render harness)
- Create: `docs/design-inbox/portrait-tones-REQUEST.md`
- Maybe delete: `assets/portraits/hero-cap.png` (DP10)
- Modify: `PROJECT_ROADMAP.md`

- [ ] **Step 1: Write `tools/preview_portraits.gd`** — follow the existing harness pattern (`tools/preview_outcome.gd`): a `SceneTree` script that builds a 4×4 `GridContainer` of `TextureRect`s (one per bucket×band via `PortraitLibrary.texture_for`), labels rows/columns, screenshots to `docs/mockups/portraits-in-engine-v1.png`, quits. Also refresh the Identity render via the existing `tools/preview_player_creation_identity.gd` (new picker thumbnails + hero) to `docs/mockups/player-creation-identity-portraits-v1.png`.

- [ ] **Step 2: Run both harnesses + eyeball** (editor closed):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && \
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_portraits.gd && \
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_player_creation_identity.gd
```

Read both PNGs. Check: 16 distinct faces; picker ring visible around tiles; hero matches the picked bucket. (Unit tests can't catch invisibility — this eyeball is the gate.)

- [ ] **Step 3: DP10 — retire `hero-cap.png` if unreferenced**

```bash
grep -rn "hero-cap" --include="*.gd" --include="*.tscn" scenes/ scripts/ tools/ tests/
```

Expected: no hits (Tasks 4+5 removed both consumers). If none: `git rm assets/portraits/hero-cap.png` (the design original survives at `docs/design-drop/portraits/view-three-quarter.png`). If hits remain, leave it and note where.

- [ ] **Step 4: Write `docs/design-inbox/portrait-tones-REQUEST.md`** — per DP9. Contents: what landed (the recovered drop + this rung), the ask (the 9-expression face set in all 4 bucket tones — our keys `white/mixed/indian/black`, lightest→darkest per `appearance_picker.placeholder_tint` — at 2× resolution, transparent + stage-background variants), the drop-in contract (files land as `assets/portraits/<bucket>-<band>.png` for the 4 mapped bands per DP2; the other 5 expressions land under `docs/design-drop/portraits/` for future key-moment art), and the render links (`portraits-grid-v1.png` shows the in-house remap being replaced).

- [ ] **Step 5: Commit**

```bash
git add tools/preview_portraits.gd docs/design-inbox/portrait-tones-REQUEST.md docs/mockups/portraits-in-engine-v1.png docs/mockups/player-creation-identity-portraits-v1.png
git rm --cached assets/portraits/hero-cap.png 2>/dev/null; rm -f assets/portraits/hero-cap.png
git commit -m "feat: portrait render harness + design tones brief; retire hero-cap placeholder (DP9/DP10)"
```

---

### Task 8: Full verification + PR

- [ ] **Step 1: iCloud junk sweep** (`find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*"` — must be empty; clean per CLAUDE.md if not)

- [ ] **Step 2: Full suite from a clean import**

```bash
rm -rf .godot && /Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && \
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: count > 809 (baseline 809/10313), `All tests passed`.

- [ ] **Step 3: Launch the real game** (`/Applications/Godot.app/Contents/MacOS/Godot --path .`) — the playable proof for Nico: creation shows real faces on the picker, the hero swaps live, the hub card wears the picked face.

- [ ] **Step 4: PR + merge** (per the always-commit policy: push branch, `gh pr create`, merge, sync `main`, delete branch). Then update `PROJECT_ROADMAP.md` (item 5 closed; iOS export unblocked; portrait-tones brief awaiting design; Form-mechanic rung queued) and commit on `main`.
