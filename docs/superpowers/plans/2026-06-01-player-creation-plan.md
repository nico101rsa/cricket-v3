# Player Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the V1 Player Creation flow (2 screens: Identity → Build) + hard-permadeath lifecycle hooks (Manual retire button, Win-out archive path, LegendsArchive write), wired up as a runnable Godot 4 project, and formalise the lifecycle decision as ADR 0012.

**Architecture:** Godot 4.x project, GDScript everywhere. Pure-logic units (classifier, name generator, data shapes) authored first and unit-tested with GUT (Godot Unit Test — Godot's standard testing plugin). Two UI scenes (`identity.tscn`, `build.tscn`) hold a transient `PlayerCreationDraft` resource and emit a finalised `Player` resource on Confirm. A `SaveManager` autoload (autoload = Godot singleton wired in `project.godot`) persists the current `Player` and the `LegendsArchive` to `user://` (Godot's per-user save path) via `ResourceSaver`. A `LifecycleManager` autoload owns the single "end this Career" state transition — Manual retire and Win-out both call it. Downstream scenes that don't yet exist (Starting Team picker, Season hub, Hall of Fame) are stubbed; this plan's job is to make Player Creation work, not to build the rest of the shell.

**Tech Stack:** Godot 4.x · GDScript · `Resource`-based data classes (`.tres` save format) · GUT 9.x for unit tests · git for source control.

**Scope cuts available** (if this lands too big):
- Drop Phase 9 (Win-out dev cheat) — defer until the Match scene exists. Manual retire alone is enough to exercise the archive path.
- Drop Phase 4's `LegendsArchive` persistence — write to an in-memory list only, defer disk persistence to Theme 7 (full save system). Phase 8 (Manual retire) still works, just doesn't survive an app restart.
- Drop placeholder portrait commissioning — use 4 plain skin-tone-gradient `ColorRect`s in the picker. The structure of the picker is what matters; real art comes from Theme 6.

These cuts keep the *flow* runnable end-to-end at lower scope. None of them are necessary for V1; flag if the plan feels heavy and we'll trim.

**Out of scope** (mentioned in the spec, deliberately not built here):
- Hall of Fame screen layout (sibling spec, owed by Theme 5 — this plan only writes the archive; rendering it comes later)
- Auto-drop / non-selection / age-based retirement (Theme 9, post-launch)
- Real Match-end Win-out trigger (no Match scene exists yet — Phase 9 uses a dev cheat button)
- Full Save system covering Career state, Match state, etc. (Theme 7 — this plan ships the minimum needed for Player + LegendsArchive)
- AUS Indigenous appearance bucket (deferred per spec §9)
- Tuned magnitudes — classifier thresholds (6/4/2), name-pool sizes, attribute upgrade cap (Theme 7 balance harness)
- Real name banks — Phase 3 ships **stub banks** of 10 firsts × 10 surnames per (Country, Appearance) combo; full ~30×50 bank authoring is its own deliverable

---

## File Structure

```
project.godot                                    # NEW — Godot project file, version/autoload config
.gitignore                                       # MODIFY — add Godot patterns
addons/gut/                                      # NEW — GUT testing plugin (vendored)
scenes/
  main.tscn / main.gd                            # NEW — entry point; routes based on save state
  player_creation/
    identity.tscn / identity.gd                  # NEW — Screen 1
    build.tscn / build.gd                        # NEW — Screen 2
    appearance_picker.tscn / appearance_picker.gd # NEW — 4-thumbnail subscene
  stubs/
    starting_team_picker_stub.tscn / .gd         # NEW — placeholder ("coming soon")
    season_hub_stub.tscn / .gd                   # NEW — placeholder with Manual retire button + dev win cheat
    hall_of_fame_stub.tscn / .gd                 # NEW — placeholder list of LegendEntry rows + "Begin new Player"
scripts/
  data/
    attributes.gd                                # NEW — Resource: {power, composure, attack, control}
    name_pair.gd                                 # NEW — Resource: {first_name, surname}
    player_creation_draft.gd                     # NEW — Resource: transient draft across the 2 screens
    player.gd                                    # NEW — Resource: persisted Player
    legend_entry.gd                              # NEW — Resource: one row in LegendsArchive
    legends_archive.gd                           # NEW — Resource: list of LegendEntry
  domain/
    country.gd                                   # NEW — enum SA/AUS + helper string keys
    appearance.gd                                # NEW — enum white/mixed/indian/black + helpers
    classifier_label.gd                          # NEW — enum BATTER/WK_BATTER/BOWLER/ALL_ROUNDER + display strings
    classifier.gd                                # NEW — pure static function
    name_generator.gd                            # NEW — bank slicing + RNG sampling
    name_banks.gd                                # NEW — stub bank data (10 firsts × 10 surnames × 8 banks)
    cities.gd                                    # NEW — per-Country city lists (SA: 11, AUS: 10)
  services/
    save_manager.gd                              # NEW — autoload; Player + LegendsArchive persistence
    lifecycle_manager.gd                         # NEW — autoload; single "end Career" transition
tests/
  unit/
    test_attributes.gd                           # NEW
    test_classifier.gd                           # NEW
    test_name_generator.gd                       # NEW
    test_player_creation_draft.gd                # NEW
    test_save_manager.gd                         # NEW
    test_lifecycle_manager.gd                    # NEW
  test_runner.gd                                 # GUT entry helper (optional)
docs/adr/
  0012-player-lifecycle-hard-permadeath.md       # NEW — formalises the spec §2 decision
PROJECT_ROADMAP.md                               # MODIFY — close Player Creation, set next step
```

The split is by **responsibility**, not technical layer: data shapes live with their tests, domain logic lives with its tests, services live with their tests, scenes live with their controllers. The `domain/` and `data/` files are framework-agnostic GDScript and can be exercised headlessly by GUT; the `scenes/` files are the only place Godot's UI machinery enters.

---

## Phase 0 — Godot project bootstrap

Pre-build: no `project.godot` exists. Phase 0 stands up the empty project so every later phase has somewhere to land.

### Task 0.1: Initialise the Godot project

**Files:**
- Create: `project.godot`
- Modify: `.gitignore`

- [ ] **Step 1: Confirm Godot 4.3+ is installed**

Run: `godot --version`
Expected: `4.3.y` or newer (`4.3.stable.official.<commit>` / `4.4.…`). **4.3+ is a hard requirement, not a preference** — earlier 4.x builds return an *untyped* `Array` from `Array[T].duplicate()`, which would throw at runtime against the typed return signatures in `cities.gd` / `name_banks.gd`. If `godot --version` reports 4.0–4.2, stop and upgrade. Install from https://godotengine.org/download.

- [ ] **Step 2: Author `project.godot`**

Create `project.godot` with this content:

```ini
; Cricket Sim — Godot project
; Authored 2026-06-01 by Player Creation plan, Phase 0

config_version=5

[application]

config/name="Cricket Sim"
config/description="Mobile roguelite cricket-career. Reigns × Balatro × management."
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.3", "GL Compatibility")
config/icon="res://icon.svg"

[display]

window/size/viewport_width=390
window/size/viewport_height=844
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[debug]

; The test files preload domain scripts that also declare a global `class_name`
; (e.g. `const Country = preload("country.gd")` where country.gd has `class_name Country`).
; That is an intentional, readable "explicit dependency" style for a learner codebase,
; but it triggers SHADOWED_GLOBAL_IDENTIFIER on every test. Silence just that one warning
; so the test output stays clean — all other warnings remain on.
gdscript/warnings/shadowed_global_identifier=0

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

The viewport `390×844` matches the iPhone 14 frame used in all hi-fi mockups (`docs/mockups/around-the-match-v1.html`). GL Compatibility renderer keeps mobile-ready from day one.

**Note — autoloads are registered later, not here.** `SaveManager` (Phase 4) and `LifecycleManager` (Phase 7) are added to a `[autoload]` block *at the phase their script is created*. Registering them now, before the scripts exist, would make Godot emit an `ERROR: Can't autoload …` on every run from Phase 0 through Phase 6 — confusing, and it would make the "no errors" checks below meaningless. Each phase that lands a service script adds its own autoload line.

- [ ] **Step 3: Add Godot ignores to `.gitignore`**

Append to `.gitignore`:

```
# Godot
.godot/
*.import
*.translation
export.cfg
export_presets.cfg
.tmp/
```

- [ ] **Step 4: Open project in Godot once to generate `.godot/`**

Run: `godot --headless --quit --path .`
Expected: Godot imports the project, generates `.godot/` cache directory, exits cleanly. No errors on stderr.

- [ ] **Step 5: Verify project loads**

Run: `godot --headless --quit --path . 2>&1 | head -30`
Expected: no `ERROR:` lines. Because no autoloads are registered yet (see the note above), there are no "Can't autoload" errors to explain away — a clean load means the project file parsed correctly.

- [ ] **Step 6: Add a placeholder `icon.svg`**

Create `icon.svg` (minimal 32×32 placeholder, can be replaced by Theme 6 art):

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" fill="#007749"/>
  <text x="64" y="80" font-family="sans-serif" font-size="64" fill="#FFB81C" text-anchor="middle" font-weight="900">₸</text>
</svg>
```

- [ ] **Step 7: Commit**

```bash
git add project.godot .gitignore icon.svg
git commit -m "Bootstrap Godot 4 project for Player Creation build"
```

### Task 0.2: Install GUT (Godot Unit Test) plugin

GUT is the standard Godot 4 test framework. We vendor it (copy into the repo) rather than installing via Godot's AssetLib so the test setup is reproducible from a clean clone.

**Files:**
- Create: `addons/gut/` (from upstream release)
- Create: `tests/.gdignore`

- [ ] **Step 1: Download GUT 9.x release**

Run:
```bash
mkdir -p /tmp/gut-install && cd /tmp/gut-install \
  && curl -L -o gut.zip https://github.com/bitwes/Gut/archive/refs/tags/v9.3.1.zip \
  && unzip -q gut.zip
```
Expected: `Gut-9.3.1/` extracted. (If 9.3.1 is no longer the latest tag, pick the newest 9.x — pin the version in the commit message.)

- [ ] **Step 2: Vendor GUT into `addons/`**

Run from project root:
```bash
mkdir -p addons && cp -R /tmp/gut-install/Gut-9.3.1/addons/gut addons/
```
Expected: `addons/gut/plugin.cfg` exists.

- [ ] **Step 3: Enable the plugin**

Add to `project.godot` under a new `[editor_plugins]` section (insert near the end):

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")
```

- [ ] **Step 4: Add `tests/.gdignore`**

Create `tests/.gdignore` (empty file). This tells Godot's import scanner that the `tests/` tree is not exported with builds.

```bash
mkdir -p tests && touch tests/.gdignore
```

- [ ] **Step 5: Smoke-test GUT runs**

Create a tiny throwaway test at `tests/unit/test_smoke.gd`:

```gdscript
extends GutTest

func test_addition_works():
    assert_eq(1 + 1, 2, "math still works")
```

Run:
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
Expected: GUT prints `1 passing` (or equivalent), exits 0.

- [ ] **Step 6: Delete the smoke test**

```bash
rm tests/unit/test_smoke.gd
```

We don't keep `test_smoke.gd` — it served its purpose. Real tests come in Phase 1+.

- [ ] **Step 7: Commit**

```bash
git add addons/ project.godot tests/.gdignore
git commit -m "Vendor GUT 9.3.1 for testing; verify smoke test runs"
```

---

## Phase 1 — Domain primitives

Pure data classes and enums. No behaviour beyond invariants. Each is one `Resource` subclass exposing typed fields. These get exercised heavily by every later phase so we get them right first.

### Task 1.1: `Country` enum

**Files:**
- Create: `scripts/domain/country.gd`
- Test: `tests/unit/test_country.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_country.gd`:

```gdscript
extends GutTest

const Country = preload("res://scripts/domain/country.gd")

func test_enum_values_are_sa_and_aus():
    assert_eq(Country.Code.SA, 0)
    assert_eq(Country.Code.AUS, 1)

func test_to_key_returns_canonical_string():
    assert_eq(Country.to_key(Country.Code.SA), "SA")
    assert_eq(Country.to_key(Country.Code.AUS), "AUS")

func test_display_name_returns_uppercased_full_name():
    assert_eq(Country.display_name(Country.Code.SA), "SOUTH AFRICA")
    assert_eq(Country.display_name(Country.Code.AUS), "AUSTRALIA")
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_country.gd -gexit`
Expected: FAIL with "preload error" / file not found.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/domain/country.gd`:

```gdscript
class_name Country
extends RefCounted

enum Code { SA = 0, AUS = 1 }

static func to_key(c: int) -> String:
    match c:
        Code.SA: return "SA"
        Code.AUS: return "AUS"
        _: return ""

static func display_name(c: int) -> String:
    match c:
        Code.SA: return "SOUTH AFRICA"
        Code.AUS: return "AUSTRALIA"
        _: return ""
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_country.gd -gexit`
Expected: PASS, 3 assertions.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/country.gd tests/unit/test_country.gd
git commit -m "Add Country enum (SA/AUS) with key + display name helpers"
```

### Task 1.2: `Appearance` enum

**Files:**
- Create: `scripts/domain/appearance.gd`
- Test: `tests/unit/test_appearance.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_appearance.gd`:

```gdscript
extends GutTest

const Appearance = preload("res://scripts/domain/appearance.gd")

func test_four_buckets_in_canonical_tone_order():
    assert_eq(Appearance.Bucket.WHITE,  0)
    assert_eq(Appearance.Bucket.MIXED,  1)
    assert_eq(Appearance.Bucket.INDIAN, 2)
    assert_eq(Appearance.Bucket.BLACK,  3)

func test_to_key_returns_canonical_string():
    assert_eq(Appearance.to_key(Appearance.Bucket.WHITE),  "white")
    assert_eq(Appearance.to_key(Appearance.Bucket.MIXED),  "mixed")
    assert_eq(Appearance.to_key(Appearance.Bucket.INDIAN), "indian")
    assert_eq(Appearance.to_key(Appearance.Bucket.BLACK),  "black")

func test_all_buckets_returns_ordered_list():
    var all := Appearance.all()
    assert_eq(all.size(), 4)
    assert_eq(all[0], Appearance.Bucket.WHITE)
    assert_eq(all[3], Appearance.Bucket.BLACK)
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_appearance.gd -gexit`
Expected: FAIL with preload error.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/domain/appearance.gd`:

```gdscript
class_name Appearance
extends RefCounted

# UI position 1..4 → lightest..darkest skin tone. See spec §3.3.
# Internal keys are stable string identifiers; UI shows only portraits, never these strings.
enum Bucket { WHITE = 0, MIXED = 1, INDIAN = 2, BLACK = 3 }

static func to_key(b: int) -> String:
    match b:
        Bucket.WHITE:  return "white"
        Bucket.MIXED:  return "mixed"
        Bucket.INDIAN: return "indian"
        Bucket.BLACK:  return "black"
        _: return ""

static func all() -> Array[int]:
    return [Bucket.WHITE, Bucket.MIXED, Bucket.INDIAN, Bucket.BLACK]
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_appearance.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/appearance.gd tests/unit/test_appearance.gd
git commit -m "Add Appearance enum (white/mixed/indian/black, tone-ordered)"
```

### Task 1.3: `ClassifierLabel` enum

**Files:**
- Create: `scripts/domain/classifier_label.gd`
- Test: `tests/unit/test_classifier_label.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_classifier_label.gd`:

```gdscript
extends GutTest

const ClassifierLabel = preload("res://scripts/domain/classifier_label.gd")

func test_enum_has_four_labels():
    assert_eq(ClassifierLabel.Label.BATTER,       0)
    assert_eq(ClassifierLabel.Label.WK_BATTER,    1)
    assert_eq(ClassifierLabel.Label.BOWLER,       2)
    assert_eq(ClassifierLabel.Label.ALL_ROUNDER,  3)

func test_display_name_uses_caps_spec_strings():
    assert_eq(ClassifierLabel.display_name(ClassifierLabel.Label.BATTER),      "BATTER")
    assert_eq(ClassifierLabel.display_name(ClassifierLabel.Label.WK_BATTER),   "WICKET-KEEPER BATTER")
    assert_eq(ClassifierLabel.display_name(ClassifierLabel.Label.BOWLER),      "BOWLER")
    assert_eq(ClassifierLabel.display_name(ClassifierLabel.Label.ALL_ROUNDER), "ALL-ROUNDER")
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_classifier_label.gd -gexit`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/domain/classifier_label.gd`:

```gdscript
class_name ClassifierLabel
extends RefCounted

# Flavour label only — zero impact on auto-sim. See spec §3.5.
enum Label { BATTER = 0, WK_BATTER = 1, BOWLER = 2, ALL_ROUNDER = 3 }

static func display_name(l: int) -> String:
    match l:
        Label.BATTER:      return "BATTER"
        Label.WK_BATTER:   return "WICKET-KEEPER BATTER"
        Label.BOWLER:      return "BOWLER"
        Label.ALL_ROUNDER: return "ALL-ROUNDER"
        _: return ""
```

- [ ] **Step 4: Run the test, verify it passes**

Run as above. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/classifier_label.gd tests/unit/test_classifier_label.gd
git commit -m "Add ClassifierLabel enum + display names"
```

### Task 1.4: `Attributes` resource (the 4-tuple)

**Files:**
- Create: `scripts/data/attributes.gd`
- Test: `tests/unit/test_attributes.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_attributes.gd`:

```gdscript
extends GutTest

const Attributes = preload("res://scripts/data/attributes.gd")

func test_defaults_are_five_each():
    var a := Attributes.new()
    assert_eq(a.power, 5)
    assert_eq(a.composure, 5)
    assert_eq(a.attack, 5)
    assert_eq(a.control, 5)

func test_sum_returns_total_of_four():
    var a := Attributes.new()
    a.power = 7; a.composure = 6; a.attack = 4; a.control = 3
    assert_eq(a.sum(), 20)

func test_is_valid_creation_distribution_for_balanced_default():
    var a := Attributes.new()
    assert_true(a.is_valid_creation_distribution(), "default 5/5/5/5 sums to 20, all in [1,8]")

func test_is_valid_creation_distribution_rejects_wrong_total():
    var a := Attributes.new()
    a.power = 8; a.composure = 8; a.attack = 8; a.control = 8  # sum = 32
    assert_false(a.is_valid_creation_distribution())

func test_is_valid_creation_distribution_rejects_zero():
    var a := Attributes.new()
    a.power = 0; a.composure = 6; a.attack = 6; a.control = 8  # sum = 20 but power is below min
    assert_false(a.is_valid_creation_distribution())

func test_is_valid_creation_distribution_rejects_over_cap():
    var a := Attributes.new()
    a.power = 9; a.composure = 5; a.attack = 3; a.control = 3  # sum = 20 but power is above max
    assert_false(a.is_valid_creation_distribution())

func test_duplicate_returns_independent_copy():
    var a := Attributes.new()
    a.power = 7
    var b := a.duplicate_typed()
    b.power = 1
    assert_eq(a.power, 7, "original unchanged")
    assert_eq(b.power, 1, "copy mutated independently")
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_attributes.gd -gexit`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/data/attributes.gd`:

```gdscript
class_name Attributes
extends Resource

# 4-attribute distribution used at Creation and during Career.
# Creation constraints: sum == 20, each in [1, 8]. See spec §3.5.

const CREATION_TOTAL := 20
const CREATION_MIN := 1
const CREATION_MAX := 8

@export var power: int = 5
@export var composure: int = 5
@export var attack: int = 5
@export var control: int = 5

func sum() -> int:
    return power + composure + attack + control

func is_valid_creation_distribution() -> bool:
    if sum() != CREATION_TOTAL:
        return false
    for v in [power, composure, attack, control]:
        if v < CREATION_MIN or v > CREATION_MAX:
            return false
    return true

func duplicate_typed() -> Attributes:
    var copy := Attributes.new()
    copy.power = power
    copy.composure = composure
    copy.attack = attack
    copy.control = control
    return copy
```

- [ ] **Step 4: Run the test, verify it passes**

Run as above. Expected: PASS, 7 assertions.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/attributes.gd tests/unit/test_attributes.gd
git commit -m "Add Attributes resource (4-tuple) with creation invariant"
```

### Task 1.5: `NamePair` resource

**Files:**
- Create: `scripts/data/name_pair.gd`
- Test: covered indirectly via `test_name_generator.gd` (Phase 3) — no separate test for a plain struct

- [ ] **Step 1: Write the resource**

Create `scripts/data/name_pair.gd`:

```gdscript
class_name NamePair
extends Resource

@export var first_name: String = ""
@export var surname: String = ""

func display() -> String:
    return "%s %s" % [first_name, surname]

func display_caps() -> String:
    return display().to_upper()
```

- [ ] **Step 2: Commit**

```bash
git add scripts/data/name_pair.gd
git commit -m "Add NamePair resource"
```

### Task 1.6: `PlayerCreationDraft` resource

The transient state object held by Screen 1 + Screen 2 — lives only across the flow, never persists.

**Files:**
- Create: `scripts/data/player_creation_draft.gd`
- Test: `tests/unit/test_player_creation_draft.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_player_creation_draft.gd`:

```gdscript
extends GutTest

const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func test_new_draft_has_unset_picks():
    var d := PlayerCreationDraft.new()
    assert_eq(d.country, -1, "country unset")
    assert_eq(d.city, "")
    assert_eq(d.appearance, -1, "appearance unset")
    assert_null(d.name)
    assert_not_null(d.attributes, "attributes always present (defaults applied)")

func test_identity_complete_requires_all_three_picks_and_a_name():
    var d := PlayerCreationDraft.new()
    assert_false(d.identity_complete())
    d.country = Country.Code.SA
    assert_false(d.identity_complete())
    d.city = "Cape Town"
    assert_false(d.identity_complete())
    d.appearance = Appearance.Bucket.MIXED
    assert_false(d.identity_complete(), "name still missing")
    var np = load("res://scripts/data/name_pair.gd").new()
    np.first_name = "Jonty"; np.surname = "Springer"
    d.name = np
    assert_true(d.identity_complete())

func test_attributes_default_to_balanced_all_rounder():
    var d := PlayerCreationDraft.new()
    assert_eq(d.attributes.power, 5)
    assert_eq(d.attributes.sum(), 20)
    assert_true(d.attributes.is_valid_creation_distribution())
```

- [ ] **Step 2: Run, verify FAIL**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_player_creation_draft.gd -gexit`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/data/player_creation_draft.gd`:

```gdscript
class_name PlayerCreationDraft
extends Resource

# Transient — lives across the 2 Creation screens. Discarded if user backs out.
# See spec §6.1.

@export var country: int = -1          # Country.Code or -1 if unset
@export var city: String = ""          # "" if unset
@export var appearance: int = -1       # Appearance.Bucket or -1 if unset
@export var name: NamePair             # null until first name-roll
@export var attributes: Attributes     # always present; defaults to 5/5/5/5

func _init() -> void:
    attributes = Attributes.new()

func identity_complete() -> bool:
    return country >= 0 \
        and city != "" \
        and appearance >= 0 \
        and name != null
```

- [ ] **Step 4: Run, verify PASS**

Run as above. Expected: PASS, 8 assertions.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/player_creation_draft.gd tests/unit/test_player_creation_draft.gd
git commit -m "Add PlayerCreationDraft resource"
```

### Task 1.7: `Player` resource (persisted)

**Files:**
- Create: `scripts/data/player.gd`

This is a Resource — at this point we don't need behaviour beyond construction and a `from_draft()` factory. We'll add round-trip persistence tests in Phase 4.

- [ ] **Step 1: Write the Player resource**

Create `scripts/data/player.gd`:

```gdscript
class_name Player
extends Resource

# Persisted Player. New fields added by this spec are flagged below.
# Existing fields (form, affinity, tons_balance) are initialised to neutral
# defaults here; their behaviour belongs to other systems.

@export var name: NamePair                       # immutable post-Creation
@export var country: int = Country.Code.SA       # Country.Code
@export var city: String = ""                    # NEW (spec §6.2)
@export var appearance: int = Appearance.Bucket.WHITE  # NEW (spec §6.2)
@export var attributes: Attributes               # mutable via Tons upgrades
@export var starting_attributes: Attributes      # NEW (spec §6.2) — snapshot at creation, immutable
@export var created_at: int = 0                  # NEW — Unix epoch seconds

# Neutral defaults for fields that other systems own.
@export var form: int = 0          # 0 = "Steady" (neutral); enum will land with the Form system
@export var affinity: int = 0
@export var tons_balance: int = 0

static func from_draft(draft: PlayerCreationDraft) -> Player:
    var p := Player.new()
    p.name = draft.name
    p.country = draft.country
    p.city = draft.city
    p.appearance = draft.appearance
    p.attributes = draft.attributes.duplicate_typed()
    p.starting_attributes = draft.attributes.duplicate_typed()
    p.created_at = int(Time.get_unix_time_from_system())
    return p
```

- [ ] **Step 2: Add a smoke test**

Create `tests/unit/test_player.gd`:

```gdscript
extends GutTest

const Player = preload("res://scripts/data/player.gd")
const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func test_from_draft_copies_identity_and_snapshots_attributes():
    var draft := PlayerCreationDraft.new()
    draft.country = Country.Code.AUS
    draft.city = "Melbourne"
    draft.appearance = Appearance.Bucket.INDIAN
    var n := NamePair.new(); n.first_name = "Ricky"; n.surname = "Stumps"
    draft.name = n
    draft.attributes.power = 7
    draft.attributes.composure = 6
    draft.attributes.attack = 4
    draft.attributes.control = 3  # sum = 20

    var p := Player.from_draft(draft)

    assert_eq(p.city, "Melbourne")
    assert_eq(p.country, Country.Code.AUS)
    assert_eq(p.appearance, Appearance.Bucket.INDIAN)
    assert_eq(p.name.surname, "Stumps")
    assert_eq(p.attributes.power, 7)
    assert_eq(p.starting_attributes.power, 7, "starting snapshot matches")
    assert_gt(p.created_at, 0, "created_at populated")

func test_starting_attributes_are_independent_copy():
    var draft := PlayerCreationDraft.new()
    var n := NamePair.new(); n.first_name = "X"; n.surname = "Y"
    draft.name = n
    var p := Player.from_draft(draft)
    p.attributes.power = 8
    assert_eq(p.starting_attributes.power, 5, "starting snapshot unaffected by later mutation")
```

- [ ] **Step 3: Run, verify PASS**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_player.gd -gexit`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add scripts/data/player.gd tests/unit/test_player.gd
git commit -m "Add Player resource with from_draft factory and starting-attributes snapshot"
```

### Task 1.8: `Cities` static data

**Files:**
- Create: `scripts/domain/cities.gd`
- Test: `tests/unit/test_cities.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_cities.gd`:

```gdscript
extends GutTest

const Cities = preload("res://scripts/domain/cities.gd")
const Country = preload("res://scripts/domain/country.gd")

func test_sa_has_eleven_cities_per_spec():
    var sa := Cities.for_country(Country.Code.SA)
    assert_eq(sa.size(), 11)
    assert_true(sa.has("Cape Town"))
    assert_true(sa.has("Pietermaritzburg"))

func test_aus_has_ten_cities_per_spec():
    var aus := Cities.for_country(Country.Code.AUS)
    assert_eq(aus.size(), 10)
    assert_true(aus.has("Sydney"))
    assert_true(aus.has("Darwin"))

func test_unknown_country_returns_empty():
    assert_eq(Cities.for_country(-1).size(), 0)
```

- [ ] **Step 2: Run, verify FAIL**

Expected: FAIL.

- [ ] **Step 3: Write the data**

Create `scripts/domain/cities.gd`:

```gdscript
class_name Cities
extends RefCounted

# Per-Country V1 city lists. Flavour-only — no mechanical impact.
# Source: spec §3.2.

const SA: Array[String] = [
    "Cape Town", "Johannesburg", "Durban", "Pretoria", "Gqeberha",
    "East London", "Bloemfontein", "Pietermaritzburg", "Centurion",
    "Paarl", "Potchefstroom",
]

const AUS: Array[String] = [
    "Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide",
    "Hobart", "Canberra", "Geelong", "Newcastle", "Darwin",
]

static func for_country(c: int) -> Array[String]:
    match c:
        Country.Code.SA:  return SA.duplicate()
        Country.Code.AUS: return AUS.duplicate()
        _: return [] as Array[String]
```

- [ ] **Step 4: Run, verify PASS**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/cities.gd tests/unit/test_cities.gd
git commit -m "Add Cities lookup (SA: 11, AUS: 10) for Player Creation dropdown"
```

---

## Phase 2 — Classifier

Pure deterministic function: `Attributes → ClassifierLabel`. Same function powers the live label on Build screen *and* the derived "current label" / "starting label" reads anywhere a Player is displayed. Locking this with thorough tests now means later UI just plugs in.

### Task 2.1: `Classifier.classify(attrs)`

**Files:**
- Create: `scripts/domain/classifier.gd`
- Test: `tests/unit/test_classifier.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_classifier.gd`. The thresholds are spec §3.5:

```gdscript
extends GutTest

const Classifier = preload("res://scripts/domain/classifier.gd")
const ClassifierLabel = preload("res://scripts/domain/classifier_label.gd")
const Attributes = preload("res://scripts/data/attributes.gd")

func _attrs(p: int, comp: int, att: int, ctrl: int) -> Attributes:
    var a := Attributes.new()
    a.power = p; a.composure = comp; a.attack = att; a.control = ctrl
    return a

# --- All-rounder default ---

func test_balanced_default_is_all_rounder():
    var label := Classifier.classify(_attrs(5, 5, 5, 5))
    assert_eq(label, ClassifierLabel.Label.ALL_ROUNDER)

# --- Batter ---

func test_pure_batter_pattern():
    # Power=8, Composure=8, Attack=2, Control=2 — Composure - Power = 0 (< 2), so Batter not WK
    var label := Classifier.classify(_attrs(8, 8, 2, 2))
    assert_eq(label, ClassifierLabel.Label.BATTER)

func test_minimal_batter_pattern_at_thresholds():
    # Power=6, Composure=6, Attack=4, Control=4 — Composure - Power = 0 (< 2), Batter
    var label := Classifier.classify(_attrs(6, 6, 4, 4))
    assert_eq(label, ClassifierLabel.Label.BATTER)

# --- Wicket-keeper Batter (a Batter pattern where Composure leads Power by ≥2) ---

func test_wk_batter_when_composure_leads_power_by_two():
    # Power=6, Composure=8, Attack=2, Control=4 — Comp-Pow = 2, all Batter conds met
    var label := Classifier.classify(_attrs(6, 8, 2, 4))
    assert_eq(label, ClassifierLabel.Label.WK_BATTER)

func test_wk_batter_with_larger_composure_lead():
    var label := Classifier.classify(_attrs(6, 8, 3, 3))
    assert_eq(label, ClassifierLabel.Label.WK_BATTER)

func test_not_wk_batter_when_composure_lead_is_only_one():
    # Power=7, Composure=8, Att=1, Ctrl=4 — Comp-Pow = 1 < 2, falls back to Batter
    var label := Classifier.classify(_attrs(7, 8, 1, 4))
    assert_eq(label, ClassifierLabel.Label.BATTER)

# --- Bowler ---

func test_pure_bowler_pattern():
    # Power=2, Composure=2, Attack=8, Control=8
    var label := Classifier.classify(_attrs(2, 2, 8, 8))
    assert_eq(label, ClassifierLabel.Label.BOWLER)

func test_minimal_bowler_pattern_at_thresholds():
    # Power=4, Composure=4, Attack=6, Control=6
    var label := Classifier.classify(_attrs(4, 4, 6, 6))
    assert_eq(label, ClassifierLabel.Label.BOWLER)

# --- All-rounder fallthrough ---

func test_mixed_high_attack_with_high_composure_is_all_rounder():
    # Power=4, Composure=7, Attack=7, Control=2 — fails Batter (Power<6), fails Bowler (Compos>4)
    var label := Classifier.classify(_attrs(4, 7, 7, 2))
    assert_eq(label, ClassifierLabel.Label.ALL_ROUNDER)

func test_one_dimension_short_of_batter_is_all_rounder():
    # Power=6, Composure=5, Attack=4, Control=5 — Composure<6
    var label := Classifier.classify(_attrs(6, 5, 4, 5))
    assert_eq(label, ClassifierLabel.Label.ALL_ROUNDER)

# --- Determinism ---

func test_classifier_is_pure():
    var a := _attrs(6, 8, 2, 4)
    var l1 := Classifier.classify(a)
    var l2 := Classifier.classify(a)
    assert_eq(l1, l2)
    # And: mutating a after first call does not affect either label.
    a.power = 1
    assert_eq(l1, ClassifierLabel.Label.WK_BATTER)
```

- [ ] **Step 2: Run, verify FAIL**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_classifier.gd -gexit`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/domain/classifier.gd`. The rule order matters — WK Batter is a refinement of Batter, so check WK first:

```gdscript
class_name Classifier
extends RefCounted

# Pure function: maps an Attributes distribution to a flavour label.
# Thresholds are V1 strawman (spec §3.5) — Theme 7 balance harness will tune.

const BATTER_HI := 6       # Power AND Composure must be ≥ this for Batter family
const BOWLER_HI := 6       # Attack AND Control must be ≥ this for Bowler
const BATTER_LO := 4       # Attack AND Control must be ≤ this for Batter family
const BOWLER_LO := 4       # Power AND Composure must be ≤ this for Bowler
const WK_GAP    := 2       # Composure - Power must be ≥ this for WK refinement

static func classify(a: Attributes) -> int:
    var bat_family := a.power >= BATTER_HI \
        and a.composure >= BATTER_HI \
        and a.attack <= BATTER_LO \
        and a.control <= BATTER_LO

    if bat_family and (a.composure - a.power) >= WK_GAP:
        return ClassifierLabel.Label.WK_BATTER
    if bat_family:
        return ClassifierLabel.Label.BATTER

    var bowl_family := a.attack >= BOWLER_HI \
        and a.control >= BOWLER_HI \
        and a.power <= BOWLER_LO \
        and a.composure <= BOWLER_LO
    if bowl_family:
        return ClassifierLabel.Label.BOWLER

    return ClassifierLabel.Label.ALL_ROUNDER
```

- [ ] **Step 4: Run, verify PASS**

Run as above. Expected: PASS, 11 assertions.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/classifier.gd tests/unit/test_classifier.gd
git commit -m "Add Classifier (pure function: Attributes -> ClassifierLabel) with V1 thresholds"
```

---

## Phase 3 — Name generator

8 banks of `(first_names[], surnames[])` indexed by `(Country, Appearance)`. Stub-sized for this plan (10 firsts × 10 surnames per bank). Full ~30×50 bank authoring is its own deliverable; the *shape* of the generator is what we lock here.

### Task 3.1: Stub name banks

**Files:**
- Create: `scripts/domain/name_banks.gd`

The banks are static data. No TDD ceremony — just author and lock the shape via a structural test.

- [ ] **Step 1: Author the stub banks**

Create `scripts/domain/name_banks.gd`. Use spec §3.4 example names (~70% cricketer-surname plays + ~30% equipment puns); fill in the remainder with plausible variants. The exact strings are stub-quality; balance-tuning + a proper authoring pass replace them later.

```gdscript
class_name NameBanks
extends RefCounted

# Stub V1 banks. 8 banks = 4 Appearance × 2 Country.
# Pool size per bank: 10 firsts × 10 surnames = 100 unique combos.
# Surname mix per spec §3.4: ~70% cricketer-surname plays, ~30% equipment puns.
# Full ~30×50 authoring is a separate deliverable.

const _FIRSTS_SA_WHITE: Array[String]  = ["John", "Jonty", "Quinton", "AB", "Faf", "Dale", "Hansie", "Allan", "Shaun", "Graeme"]
const _FIRSTS_SA_MIXED: Array[String]  = ["Vernon", "Wayne", "JP", "Henry", "Garth", "Roger", "Ashwell", "Paul", "Daryll", "Justin"]
const _FIRSTS_SA_INDIAN: Array[String] = ["Hashim", "Imran", "Keshav", "Tabraiz", "Rilee", "Reeza", "Yasir", "Omar", "Sulieman", "Aiden"]
const _FIRSTS_SA_BLACK: Array[String]  = ["Kagiso", "Temba", "Lungi", "Andile", "Aaron", "Makhaya", "Mfuneko", "Loots", "Thami", "Sibonelo"]

const _FIRSTS_AUS_WHITE: Array[String]  = ["Steve", "Ricky", "Glenn", "Pat", "Mitchell", "Travis", "Marnus", "Adam", "Brett", "Cameron"]
const _FIRSTS_AUS_MIXED: Array[String]  = ["Andrew", "Justin", "Damien", "Brad", "Phillip", "Michael", "Stuart", "Tim", "Greg", "Jason"]
const _FIRSTS_AUS_INDIAN: Array[String] = ["Usman", "Fawad", "Gurinder", "Tanveer", "Aman", "Arjun", "Param", "Nishant", "Jaspreet", "Rohan"]
const _FIRSTS_AUS_BLACK: Array[String]  = ["Scott", "Jason", "D'Arcy", "Daniel", "Marcus", "Eddie", "Tyrone", "Will", "Lance", "Nathan"]

# Surnames per bank — same surname pool is reused across (Country, Appearance) variants
# in V1 stub form. Real authoring will diverge them.
const _SURNAMES_GENERIC: Array[String] = [
    # cricketer plays (~7)
    "Springer", "Tendul", "Smithers", "Vilas", "Dhonner", "Kohlrabi", "Amlaa",
    # equipment puns (~3)
    "Bails", "Stumps", "Yorker",
]

static func first_names_for(country: int, appearance: int) -> Array[String]:
    if country == Country.Code.SA:
        match appearance:
            Appearance.Bucket.WHITE:  return _FIRSTS_SA_WHITE.duplicate()
            Appearance.Bucket.MIXED:  return _FIRSTS_SA_MIXED.duplicate()
            Appearance.Bucket.INDIAN: return _FIRSTS_SA_INDIAN.duplicate()
            Appearance.Bucket.BLACK:  return _FIRSTS_SA_BLACK.duplicate()
    elif country == Country.Code.AUS:
        match appearance:
            Appearance.Bucket.WHITE:  return _FIRSTS_AUS_WHITE.duplicate()
            Appearance.Bucket.MIXED:  return _FIRSTS_AUS_MIXED.duplicate()
            Appearance.Bucket.INDIAN: return _FIRSTS_AUS_INDIAN.duplicate()
            Appearance.Bucket.BLACK:  return _FIRSTS_AUS_BLACK.duplicate()
    return [] as Array[String]

static func surnames_for(country: int, appearance: int) -> Array[String]:
    if first_names_for(country, appearance).is_empty():
        return [] as Array[String]
    return _SURNAMES_GENERIC.duplicate()
```

- [ ] **Step 2: Commit**

```bash
git add scripts/domain/name_banks.gd
git commit -m "Add stub NameBanks (10 firsts x 10 surnames per (Country, Appearance) bank)"
```

### Task 3.2: `NameGenerator.generate(country, appearance, rng)`

The generator: seeded RNG → `NamePair`. Seeded so tests are deterministic.

**Files:**
- Create: `scripts/domain/name_generator.gd`
- Test: `tests/unit/test_name_generator.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_name_generator.gd`:

```gdscript
extends GutTest

const NameGenerator = preload("res://scripts/domain/name_generator.gd")
const NameBanks = preload("res://scripts/domain/name_banks.gd")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func _rng(seed: int) -> RandomNumberGenerator:
    var r := RandomNumberGenerator.new()
    r.seed = seed
    return r

func test_generates_a_name_from_the_correct_bank_slice():
    var rng := _rng(42)
    var n := NameGenerator.generate(Country.Code.SA, Appearance.Bucket.MIXED, rng)
    assert_true(NameBanks.first_names_for(Country.Code.SA, Appearance.Bucket.MIXED).has(n.first_name))
    assert_true(NameBanks.surnames_for(Country.Code.SA, Appearance.Bucket.MIXED).has(n.surname))

func test_same_seed_produces_same_name():
    var n1 := NameGenerator.generate(Country.Code.AUS, Appearance.Bucket.BLACK, _rng(7))
    var n2 := NameGenerator.generate(Country.Code.AUS, Appearance.Bucket.BLACK, _rng(7))
    assert_eq(n1.first_name, n2.first_name)
    assert_eq(n1.surname, n2.surname)

func test_different_seeds_likely_produce_different_names():
    # With 100 unique combos and 10 different seeds, near-certain at least two diverge.
    var seen := {}
    for s in range(10):
        var n := NameGenerator.generate(Country.Code.SA, Appearance.Bucket.WHITE, _rng(s))
        seen[n.display()] = true
    assert_gt(seen.size(), 1, "10 different seeds yielded > 1 distinct name")

func test_invalid_country_appearance_returns_null():
    var rng := _rng(1)
    var n := NameGenerator.generate(-1, Appearance.Bucket.WHITE, rng)
    assert_null(n)

func test_all_eight_banks_are_populated():
    var rng := _rng(0)
    for c in [Country.Code.SA, Country.Code.AUS]:
        for a in Appearance.all():
            var n := NameGenerator.generate(c, a, rng)
            assert_not_null(n, "bank (%s, %s) generated a name" % [Country.to_key(c), Appearance.to_key(a)])
            assert_ne(n.first_name, "")
            assert_ne(n.surname, "")
```

- [ ] **Step 2: Run, verify FAIL**

Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/domain/name_generator.gd`:

```gdscript
class_name NameGenerator
extends RefCounted

# Samples uniformly from the (Country, Appearance) bank slice.
# Caller passes the RNG so tests can seed for determinism.
# Returns null for invalid (country, appearance) combos.

static func generate(country: int, appearance: int, rng: RandomNumberGenerator) -> NamePair:
    var firsts := NameBanks.first_names_for(country, appearance)
    var surnames := NameBanks.surnames_for(country, appearance)
    if firsts.is_empty() or surnames.is_empty():
        return null
    var pair := NamePair.new()
    pair.first_name = firsts[rng.randi() % firsts.size()]
    pair.surname = surnames[rng.randi() % surnames.size()]
    return pair
```

- [ ] **Step 4: Run, verify PASS**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/name_generator.gd tests/unit/test_name_generator.gd
git commit -m "Add NameGenerator (seeded RNG samples from bank slice)"
```

---

## Phase 4 — Persistence layer

Minimal viable save. Handles `Player` (current) + `LegendsArchive` (cumulative). Uses Godot's `ResourceSaver`/`ResourceLoader` with `.tres` files in `user://` (Godot's per-user save path — survives app restarts).

### Task 4.1: `LegendEntry` + `LegendsArchive` resources

**Files:**
- Create: `scripts/data/legend_entry.gd`
- Create: `scripts/data/legends_archive.gd`

- [ ] **Step 1: Write the resources**

Create `scripts/data/legend_entry.gd`:

```gdscript
class_name LegendEntry
extends Resource

# One archived Player. See spec §6.3.

const END_REASON_WON := "won"
const END_REASON_RETIRED := "retired"

@export var player: Player                 # full snapshot at archive time
@export var end_reason: String = ""        # "won" or "retired"
@export var ended_at: int = 0              # Unix epoch seconds
@export var seasons_played: int = 0
# career_stats deferred — Career Records spec (ADR 0011) owns the schema
```

Create `scripts/data/legends_archive.gd`:

```gdscript
class_name LegendsArchive
extends Resource

@export var entries: Array[LegendEntry] = []

func append(entry: LegendEntry) -> void:
    entries.append(entry)

func size() -> int:
    return entries.size()
```

- [ ] **Step 2: Commit**

```bash
git add scripts/data/legend_entry.gd scripts/data/legends_archive.gd
git commit -m "Add LegendEntry + LegendsArchive resources"
```

### Task 4.2: `SaveManager` autoload

The autoload that persists everything. This task creates the script **and** registers it as an autoload in `project.godot` (Phase 0 deliberately left the `[autoload]` block out — see its note).

**Files:**
- Create: `scripts/services/save_manager.gd`
- Modify: `project.godot` (add `[autoload]` block)
- Test: `tests/unit/test_save_manager.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_save_manager.gd`:

```gdscript
extends GutTest

const SaveManagerScript = preload("res://scripts/services/save_manager.gd")
const Player = preload("res://scripts/data/player.gd")
const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const LegendsArchive = preload("res://scripts/data/legends_archive.gd")
const LegendEntry = preload("res://scripts/data/legend_entry.gd")

var sm

func before_each() -> void:
    sm = SaveManagerScript.new()
    sm.player_save_path = "user://_test_player.tres"
    sm.legends_save_path = "user://_test_legends.tres"
    sm.clear_player()
    sm.clear_legends()

func after_each() -> void:
    sm.clear_player()
    sm.clear_legends()

func _make_player() -> Player:
    var d := PlayerCreationDraft.new()
    var n := NamePair.new(); n.first_name = "Jonty"; n.surname = "Springer"
    d.name = n
    return Player.from_draft(d)

# --- Player round-trip ---

func test_load_player_returns_null_when_no_save_exists():
    assert_null(sm.load_player())

func test_save_then_load_returns_equivalent_player():
    var p := _make_player()
    p.attributes.power = 7
    sm.save_player(p)
    var loaded := sm.load_player()
    assert_not_null(loaded)
    assert_eq(loaded.name.first_name, "Jonty")
    assert_eq(loaded.attributes.power, 7)

func test_clear_player_removes_save():
    sm.save_player(_make_player())
    assert_true(sm.has_player())
    sm.clear_player()
    assert_false(sm.has_player())

# --- Legends round-trip ---

func test_load_legends_returns_empty_archive_when_none_saved():
    var arc := sm.load_legends()
    assert_not_null(arc)
    assert_eq(arc.size(), 0)

func test_archive_to_legends_appends_and_persists():
    var p := _make_player()
    sm.archive_to_legends(p, LegendEntry.END_REASON_RETIRED, 3)
    var arc := sm.load_legends()
    assert_eq(arc.size(), 1)
    assert_eq(arc.entries[0].end_reason, LegendEntry.END_REASON_RETIRED)
    assert_eq(arc.entries[0].seasons_played, 3)
    assert_eq(arc.entries[0].player.name.first_name, "Jonty")

func test_archive_to_legends_preserves_prior_entries():
    sm.archive_to_legends(_make_player(), LegendEntry.END_REASON_RETIRED, 1)
    sm.archive_to_legends(_make_player(), LegendEntry.END_REASON_WON, 8)
    var arc := sm.load_legends()
    assert_eq(arc.size(), 2)
    assert_eq(arc.entries[1].end_reason, LegendEntry.END_REASON_WON)

# --- Regression guard: archiving a LOADED player must embed inline, not ext-ref ---
# This is the real-app path: end_career() loads the saved Player (which now carries a
# resource_path) and archives it, then deletes the player file. If archive_to_legends
# stored the player by reference, the saved legends.tres would point at the now-deleted
# file and entry.player would come back null. archive_to_legends must deep-duplicate.

func test_archiving_a_loaded_player_then_clearing_it_keeps_the_legend_intact():
    sm.save_player(_make_player())
    var loaded := sm.load_player()        # loaded.resource_path is now the player file
    assert_not_null(loaded)
    sm.archive_to_legends(loaded, LegendEntry.END_REASON_WON, 5)
    sm.clear_player()                     # delete the file the loaded player came from
    # Force a genuine disk read so we can't be fooled by an in-memory cache hit.
    var arc := ResourceLoader.load(sm.legends_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as LegendsArchive
    assert_not_null(arc)
    assert_eq(arc.size(), 1)
    assert_not_null(arc.entries[0].player, "player embedded inline, survived clear_player()")
    assert_eq(arc.entries[0].player.name.first_name, "Jonty")
```

- [ ] **Step 2: Run, verify FAIL**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_save_manager.gd -gexit`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/services/save_manager.gd`:

```gdscript
extends Node

# Autoload — registered in project.godot as `SaveManager` (see Step 4 below).
# Persists current Player and LegendsArchive to user:// via ResourceSaver.
# user:// = Godot's per-user writable save directory (survives app restarts).

@export var player_save_path: String = "user://player.tres"
@export var legends_save_path: String = "user://legends.tres"

# --- Player ---

func has_player() -> bool:
    return FileAccess.file_exists(player_save_path)

func save_player(p: Player) -> void:
    var err := ResourceSaver.save(p, player_save_path)
    if err != OK:
        push_error("SaveManager: failed to save player (err=%d)" % err)

func load_player() -> Player:
    if not has_player():
        return null
    # CACHE_MODE_IGNORE forces a fresh read from disk every time. A save system
    # must return what is ON DISK, not a shared cached instance that some other
    # part of the app might still be mutating. Without this, two load_player()
    # calls could hand back the SAME object (aliasing bug), and a load right
    # after a save could return the in-memory copy instead of the serialized one.
    return ResourceLoader.load(player_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Player

func clear_player() -> void:
    if has_player():
        DirAccess.remove_absolute(ProjectSettings.globalize_path(player_save_path))

# --- Legends ---

func load_legends() -> LegendsArchive:
    if FileAccess.file_exists(legends_save_path):
        var arc := ResourceLoader.load(legends_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as LegendsArchive
        if arc != null:
            return arc
    return LegendsArchive.new()

func archive_to_legends(p: Player, end_reason: String, seasons_played: int) -> void:
    var arc := load_legends()
    var entry := LegendEntry.new()
    # Deep-duplicate so the archived player has NO resource_path. A path-bearing
    # Player (e.g. one returned by load_player()) would be written into legends.tres
    # as an EXTERNAL reference (ext_resource) pointing at user://player.tres — and
    # the caller (end_career) deletes that file immediately after, orphaning the
    # reference. duplicate(true) embeds the whole Player (and its NamePair /
    # Attributes sub-resources) inline instead. See test_archiving_a_loaded_player_…
    entry.player = p.duplicate(true)
    entry.end_reason = end_reason
    entry.ended_at = int(Time.get_unix_time_from_system())
    entry.seasons_played = seasons_played
    arc.append(entry)
    var err := ResourceSaver.save(arc, legends_save_path)
    if err != OK:
        push_error("SaveManager: failed to save legends (err=%d)" % err)

func clear_legends() -> void:
    if FileAccess.file_exists(legends_save_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(legends_save_path))
```

- [ ] **Step 4: Register the autoload in `project.godot`**

Add this block to `project.godot` (place it after the `[application]` block, before `[display]`):

```ini
[autoload]

SaveManager="*res://scripts/services/save_manager.gd"
```

The leading `*` marks the autoload as enabled. `LifecycleManager` joins this block in Phase 7 — don't add it yet (its script doesn't exist until then).

- [ ] **Step 5: Run, verify PASS**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_save_manager.gd -gexit`
Expected: PASS, including `test_archiving_a_loaded_player_then_clearing_it_keeps_the_legend_intact` (the BLOCKER regression guard).

Also confirm the project loads with the new autoload and no errors:
Run: `godot --headless --quit --path . 2>&1 | head -20`
Expected: no `ERROR:` lines (SaveManager now resolves to a real file).

- [ ] **Step 6: Commit**

```bash
git add scripts/services/save_manager.gd tests/unit/test_save_manager.gd project.godot
git commit -m "Add SaveManager autoload: Player + LegendsArchive round-trip, inline-archive, fresh-read loads"
```

---

## Phase 5 — Screen 1: Identity

The first of the two Creation screens. Country toggle, City dropdown, Appearance picker (4 thumbnails), portrait preview, name + re-roll, Next button.

### Task 5.1: Appearance picker subscene

A small reusable subscene for the 4-portrait picker. Splitting it out keeps `identity.tscn` cleaner and lets us test the picker's selection logic without instantiating the whole screen.

**Files:**
- Create: `scenes/player_creation/appearance_picker.tscn`
- Create: `scenes/player_creation/appearance_picker.gd`

- [ ] **Step 1: Write the controller**

Create `scenes/player_creation/appearance_picker.gd`:

```gdscript
class_name AppearancePicker
extends HBoxContainer

# Emits the selected bucket when the user taps a thumbnail.
signal appearance_selected(bucket: int)

var _selected: int = -1
var _buttons: Dictionary = {}  # bucket -> Button

func _ready() -> void:
    add_theme_constant_override("separation", 12)
    for bucket in Appearance.all():
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(64, 80)
        btn.toggle_mode = true
        btn.flat = true
        # Placeholder appearance — a skin-tone gradient. Theme 6 commissions real portrait art.
        btn.modulate = placeholder_tint(bucket)
        btn.pressed.connect(_on_pressed.bind(bucket))
        add_child(btn)
        _buttons[bucket] = btn

func selected_bucket() -> int:
    return _selected

# Programmatically reflect a selection WITHOUT emitting appearance_selected.
# Used when re-hydrating the screen from an existing draft (Back navigation) —
# we want the visual ring restored but must NOT trigger a name re-roll.
func set_selected_silent(bucket: int) -> void:
    _selected = bucket
    for b in _buttons.keys():
        (_buttons[b] as Button).button_pressed = (b == bucket)

# Enable/disable the whole picker (spec §4: Appearance is disabled until Country is picked).
func set_enabled(enabled: bool) -> void:
    for b in _buttons.keys():
        (_buttons[b] as Button).disabled = not enabled

func _on_pressed(bucket: int) -> void:
    _selected = bucket
    for b in _buttons.keys():
        (_buttons[b] as Button).button_pressed = (b == bucket)
    appearance_selected.emit(bucket)

# Static so callers (the portrait preview on Identity, the recap on Build) can
# get the same placeholder tint without holding a picker instance.
# Placeholder until Theme 6 art lands.
static func placeholder_tint(bucket: int) -> Color:
    match bucket:
        Appearance.Bucket.WHITE:  return Color(0.95, 0.86, 0.76)
        Appearance.Bucket.MIXED:  return Color(0.78, 0.62, 0.48)
        Appearance.Bucket.INDIAN: return Color(0.62, 0.45, 0.33)
        Appearance.Bucket.BLACK:  return Color(0.36, 0.24, 0.18)
        _: return Color.WHITE
```

- [ ] **Step 2: Build the scene file**

Create `scenes/player_creation/appearance_picker.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/player_creation/appearance_picker.gd" id="1"]

[node name="AppearancePicker" type="HBoxContainer"]
script = ExtResource("1")
```

- [ ] **Step 3: Add a smoke test**

Create `tests/unit/test_appearance_picker.gd`:

```gdscript
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
```

- [ ] **Step 4: Run, verify PASS**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_appearance_picker.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scenes/player_creation/appearance_picker.tscn scenes/player_creation/appearance_picker.gd tests/unit/test_appearance_picker.gd
git commit -m "Add AppearancePicker subscene (4 placeholder thumbnails, selection signal)"
```

### Task 5.2: Identity scene structure

**Files:**
- Create: `scenes/player_creation/identity.tscn`
- Create: `scenes/player_creation/identity.gd`

- [ ] **Step 1: Write the controller**

Create `scenes/player_creation/identity.gd`:

```gdscript
extends Control

# Player Creation — Screen 1: Identity.
# Owns the in-progress PlayerCreationDraft, hands it to Build on Next.

signal advance_to_build(draft: PlayerCreationDraft)

@onready var _country_sa_btn: Button = $Layout/CountryRow/SaBtn
@onready var _country_aus_btn: Button = $Layout/CountryRow/AusBtn
@onready var _city_dropdown: OptionButton = $Layout/CityRow/CityDropdown
@onready var _portrait_preview: ColorRect = $Layout/PortraitPreview
@onready var _appearance_picker: AppearancePicker = $Layout/AppearancePicker
@onready var _name_label: Label = $Layout/NameRow/NameLabel
@onready var _reroll_btn: Button = $Layout/NameRow/RerollBtn
@onready var _next_btn: Button = $Layout/NextBtn

var _draft: PlayerCreationDraft
var _rng: RandomNumberGenerator

# Called by the router when navigating BACK from Build, so the screen re-hydrates
# from the in-progress draft instead of starting blank (spec §4: Back preserves picks).
# Must be called before the node enters the tree, or it refreshes immediately if already ready.
func set_draft(draft: PlayerCreationDraft) -> void:
    _draft = draft
    if is_node_ready():
        _refresh_all()

func _ready() -> void:
    if _draft == null:
        _draft = PlayerCreationDraft.new()  # fresh cold-start; set_draft() not used
    _rng = RandomNumberGenerator.new()
    _rng.randomize()
    _wire_signals()
    _refresh_all()  # doubles as hydration — paints whatever the draft currently holds

func _wire_signals() -> void:
    _country_sa_btn.pressed.connect(_on_country_pressed.bind(Country.Code.SA))
    _country_aus_btn.pressed.connect(_on_country_pressed.bind(Country.Code.AUS))
    _city_dropdown.item_selected.connect(_on_city_selected)
    _appearance_picker.appearance_selected.connect(_on_appearance_selected)
    _reroll_btn.pressed.connect(_on_reroll_pressed)
    _next_btn.pressed.connect(_on_next_pressed)

func _on_country_pressed(c: int) -> void:
    if _draft.country == c:
        return
    _draft.country = c
    _draft.city = ""                          # spec §4 Screen 1: City resets on Country change
    _reroll_name_if_possible()                # name bank slice changed
    _refresh_country_buttons()
    _refresh_city_dropdown()
    _refresh_appearance_picker()              # picker enables now that a Country exists
    _refresh_portrait_preview()
    _refresh_next_enabled()

func _on_city_selected(idx: int) -> void:
    if idx <= 0:
        _draft.city = ""
    else:
        _draft.city = _city_dropdown.get_item_text(idx)
    _refresh_next_enabled()

func _on_appearance_selected(bucket: int) -> void:
    _draft.appearance = bucket
    _reroll_name_if_possible()                # name bank slice changed
    _refresh_portrait_preview()
    _refresh_next_enabled()

func _on_reroll_pressed() -> void:
    _reroll_name_if_possible()

func _on_next_pressed() -> void:
    if _draft.identity_complete():
        advance_to_build.emit(_draft)

# --- Helpers ---

func _reroll_name_if_possible() -> void:
    if _draft.country < 0 or _draft.appearance < 0:
        _draft.name = null
    else:
        _draft.name = NameGenerator.generate(_draft.country, _draft.appearance, _rng)
    _refresh_name_label()

func _refresh_all() -> void:
    _refresh_country_buttons()
    _refresh_city_dropdown()
    _refresh_appearance_picker()
    _refresh_portrait_preview()
    _refresh_name_label()
    _refresh_next_enabled()

func _refresh_country_buttons() -> void:
    _country_sa_btn.button_pressed = (_draft.country == Country.Code.SA)
    _country_aus_btn.button_pressed = (_draft.country == Country.Code.AUS)

func _refresh_city_dropdown() -> void:
    _city_dropdown.clear()
    _city_dropdown.add_item("— Select a city —", 0)
    _city_dropdown.set_item_disabled(0, true)
    _city_dropdown.disabled = (_draft.country < 0)
    if _draft.country >= 0:
        var city_list := Cities.for_country(_draft.country)
        for c in city_list:
            _city_dropdown.add_item(c)
        # Honour a city already on the draft (hydration on Back); else show placeholder.
        # Cities sit at dropdown index 1..N because the placeholder occupies index 0.
        var idx := city_list.find(_draft.city)
        _city_dropdown.select(idx + 1 if idx >= 0 else 0)

func _refresh_appearance_picker() -> void:
    # Spec §4: Appearance is disabled until a Country is picked.
    _appearance_picker.set_enabled(_draft.country >= 0)
    # Restore the selection ring on hydration without re-rolling the name.
    if _draft.appearance >= 0:
        _appearance_picker.set_selected_silent(_draft.appearance)

func _refresh_portrait_preview() -> void:
    # Placeholder — same tint logic as the picker. Replaced by Theme 6 art.
    if _draft.appearance < 0:
        _portrait_preview.color = Color(0.2, 0.2, 0.2)
    else:
        _portrait_preview.color = AppearancePicker.placeholder_tint(_draft.appearance)

func _refresh_name_label() -> void:
    if _draft.name == null:
        _name_label.text = "—"
        _reroll_btn.disabled = true
    else:
        _name_label.text = _draft.name.display_caps()
        _reroll_btn.disabled = false

func _refresh_next_enabled() -> void:
    _next_btn.disabled = not _draft.identity_complete()
```

- [ ] **Step 2: Build the scene file**

Create `scenes/player_creation/identity.tscn`. Hand-author this `.tscn` (Godot's scene format is text-based; this works):

```ini
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/player_creation/identity.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/player_creation/appearance_picker.tscn" id="2"]

[node name="Identity" type="Control"]
anchors_preset = 15
script = ExtResource("1")

[node name="Layout" type="VBoxContainer" parent="."]
anchors_preset = 15
offset_left = 16.0
offset_top = 32.0
offset_right = -16.0
offset_bottom = -32.0

[node name="Header" type="Label" parent="Layout"]
text = "1 / 2 · IDENTITY"

[node name="CountryRow" type="HBoxContainer" parent="Layout"]

[node name="SaBtn" type="Button" parent="Layout/CountryRow"]
text = "🇿🇦 SOUTH AFRICA"
toggle_mode = true

[node name="AusBtn" type="Button" parent="Layout/CountryRow"]
text = "🇦🇺 AUSTRALIA"
toggle_mode = true

[node name="CityRow" type="HBoxContainer" parent="Layout"]

[node name="CityLabel" type="Label" parent="Layout/CityRow"]
text = "CITY"

[node name="CityDropdown" type="OptionButton" parent="Layout/CityRow"]

[node name="PortraitPreview" type="ColorRect" parent="Layout"]
custom_minimum_size = Vector2(180, 220)
color = Color(0.2, 0.2, 0.2, 1)

[node name="AppearancePicker" parent="Layout" instance=ExtResource("2")]

[node name="NameRow" type="HBoxContainer" parent="Layout"]

[node name="NameLabel" type="Label" parent="Layout/NameRow"]
text = "—"

[node name="RerollBtn" type="Button" parent="Layout/NameRow"]
text = "🔄"
disabled = true

[node name="NextBtn" type="Button" parent="Layout"]
text = "NEXT ▶"
disabled = true
```

- [ ] **Step 3: Smoke test the scene instantiates**

Create `tests/unit/test_identity_scene.gd`:

```gdscript
extends GutTest

const IdentityScene = preload("res://scenes/player_creation/identity.tscn")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

var identity

func before_each() -> void:
    identity = IdentityScene.instantiate()
    add_child_autofree(identity)
    await get_tree().process_frame

func test_loads_with_next_disabled_and_no_picks():
    assert_true(identity._next_btn.disabled)
    assert_eq(identity._draft.country, -1)

func test_picking_country_sa_resets_city_and_re_rolls_name_when_appearance_is_set():
    identity._draft.appearance = Appearance.Bucket.MIXED
    identity._on_country_pressed(Country.Code.SA)
    assert_eq(identity._draft.country, Country.Code.SA)
    assert_eq(identity._draft.city, "")
    assert_not_null(identity._draft.name, "name re-rolled because Country + Appearance now both set")

func test_picking_all_three_enables_next():
    identity._on_country_pressed(Country.Code.SA)
    identity._on_appearance_selected(Appearance.Bucket.WHITE)
    # Simulate the OptionButton selecting "Cape Town" (item index 1)
    identity._city_dropdown.select(1)
    identity._on_city_selected(1)
    assert_false(identity._next_btn.disabled)

func test_changing_country_resets_city_pick():
    identity._on_country_pressed(Country.Code.SA)
    identity._on_appearance_selected(Appearance.Bucket.WHITE)
    identity._city_dropdown.select(1)
    identity._on_city_selected(1)
    assert_ne(identity._draft.city, "")
    identity._on_country_pressed(Country.Code.AUS)
    assert_eq(identity._draft.city, "", "city resets on country change")
    assert_true(identity._next_btn.disabled)

func test_appearance_picker_disabled_until_country_picked():
    # Fresh screen, no Country yet → picker disabled (spec §4).
    for child in identity._appearance_picker.get_children():
        assert_true((child as Button).disabled, "picker disabled before Country")
    identity._on_country_pressed(Country.Code.SA)
    for child in identity._appearance_picker.get_children():
        assert_false((child as Button).disabled, "picker enabled after Country")

func test_set_draft_hydrates_ui_and_preserves_name():
    # Simulate returning from Build with a fully-populated draft (Back navigation).
    var d := PlayerCreationDraft.new()
    d.country = Country.Code.AUS
    d.city = "Sydney"
    d.appearance = Appearance.Bucket.BLACK
    var n = load("res://scripts/data/name_pair.gd").new()
    n.first_name = "Pat"; n.surname = "Stumps"
    d.name = n

    var fresh = IdentityScene.instantiate()
    fresh.set_draft(d)                       # before tree entry
    add_child_autofree(fresh)
    await get_tree().process_frame

    assert_true(fresh._country_aus_btn.button_pressed, "AUS toggle restored")
    assert_eq(fresh._appearance_picker.selected_bucket(), Appearance.Bucket.BLACK, "appearance ring restored")
    assert_eq(fresh._city_dropdown.get_item_text(fresh._city_dropdown.get_selected()), "Sydney", "city restored")
    assert_eq(fresh._name_label.text, "PAT STUMPS", "name preserved, NOT re-rolled")
    assert_false(fresh._next_btn.disabled, "all picks present → Next enabled")
```

This needs `PlayerCreationDraft` available in the test — add it to the preload block at the top of the file:

```gdscript
const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
```

- [ ] **Step 4: Run, verify PASS**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_identity_scene.gd -gexit`
Expected: PASS (all six tests, including the picker-disable and Back-hydration guards).

- [ ] **Step 5: Eyeball the scene in the editor**

Run: `godot --path . scenes/player_creation/identity.tscn`
Expected: window opens, screen renders with toggle pillows, city dropdown disabled, 4 grey-to-brown picker rectangles, "NEXT ▶" disabled. Toggle SA, pick a city, tap a thumbnail → name appears and NEXT enables. Close the window.

If the layout is rough — fine, that's expected. Visual polish lands when claude.ai's hi-fi mockup (`docs/mockups/player-creation-v1.html`) translates into the production scene styling. The plan's job here is functional correctness.

- [ ] **Step 6: Commit**

```bash
git add scenes/player_creation/identity.tscn scenes/player_creation/identity.gd tests/unit/test_identity_scene.gd
git commit -m "Add Identity scene (Screen 1): country/city/appearance/name + re-roll"
```

---

## Phase 6 — Screen 2: Build

Attribute sliders + points counter + live classifier + Confirm.

### Task 6.1: Build scene

**Files:**
- Create: `scenes/player_creation/build.tscn`
- Create: `scenes/player_creation/build.gd`

- [ ] **Step 1: Write the controller**

Create `scenes/player_creation/build.gd`:

```gdscript
extends Control

# Player Creation — Screen 2: Build.
# Receives a PlayerCreationDraft from Identity, lets the user spend 20 points
# across 4 attributes, then confirms → persists Player + emits confirmed signal.

# back_pressed carries the draft so the router can re-hydrate Identity with the
# user's picks intact (spec §4: Back preserves picks).
signal back_pressed(draft: PlayerCreationDraft)
signal confirmed(player: Player)

@onready var _recap_portrait: ColorRect = $Layout/RecapRow/RecapPortrait
@onready var _recap_label: Label = $Layout/RecapRow/RecapLabel
@onready var _power_slider: HSlider = $Layout/Sliders/PowerRow/PowerSlider
@onready var _power_readout: Label = $Layout/Sliders/PowerRow/PowerReadout
@onready var _composure_slider: HSlider = $Layout/Sliders/ComposureRow/ComposureSlider
@onready var _composure_readout: Label = $Layout/Sliders/ComposureRow/ComposureReadout
@onready var _attack_slider: HSlider = $Layout/Sliders/AttackRow/AttackSlider
@onready var _attack_readout: Label = $Layout/Sliders/AttackRow/AttackReadout
@onready var _control_slider: HSlider = $Layout/Sliders/ControlRow/ControlSlider
@onready var _control_readout: Label = $Layout/Sliders/ControlRow/ControlReadout
@onready var _points_label: Label = $Layout/PointsCounter
@onready var _classifier_label: Label = $Layout/ClassifierLabel
@onready var _back_btn: Button = $Layout/Footer/BackBtn
@onready var _confirm_btn: Button = $Layout/Footer/ConfirmBtn

var _draft: PlayerCreationDraft

func set_draft(draft: PlayerCreationDraft) -> void:
    _draft = draft
    if is_node_ready():
        _push_draft_to_ui()

func _ready() -> void:
    for s in [_power_slider, _composure_slider, _attack_slider, _control_slider]:
        s.min_value = Attributes.CREATION_MIN
        s.max_value = Attributes.CREATION_MAX
        s.step = 1
        s.value = 5
        s.value_changed.connect(_on_slider_changed)
    _back_btn.pressed.connect(func(): back_pressed.emit(_draft))
    _confirm_btn.pressed.connect(_on_confirm_pressed)
    if _draft == null:
        _draft = PlayerCreationDraft.new()
    _push_draft_to_ui()

func _on_slider_changed(_v: float) -> void:
    _draft.attributes.power     = int(_power_slider.value)
    _draft.attributes.composure = int(_composure_slider.value)
    _draft.attributes.attack    = int(_attack_slider.value)
    _draft.attributes.control   = int(_control_slider.value)
    _refresh_readouts()

func _push_draft_to_ui() -> void:
    # set_value_no_signal: writing a slider value normally emits value_changed,
    # which fires _on_slider_changed mid-update and reads the OTHER (not-yet-pushed)
    # sliders back into the draft — corrupting it. Pushing silently then refreshing
    # once is correct and re-entrancy-safe (matters when Back returns a non-default draft).
    _power_slider.set_value_no_signal(_draft.attributes.power)
    _composure_slider.set_value_no_signal(_draft.attributes.composure)
    _attack_slider.set_value_no_signal(_draft.attributes.attack)
    _control_slider.set_value_no_signal(_draft.attributes.control)
    _refresh_recap()
    _refresh_readouts()

func _refresh_recap() -> void:
    # Spec §4 Screen 2: small identity recap confirming who was built on Screen 1.
    if _draft.appearance >= 0:
        _recap_portrait.color = AppearancePicker.placeholder_tint(_draft.appearance)
    else:
        _recap_portrait.color = Color(0.2, 0.2, 0.2)
    var name_text := _draft.name.display_caps() if _draft.name != null else "—"
    var country_key := Country.to_key(_draft.country) if _draft.country >= 0 else ""
    _recap_label.text = "%s · %s · %s" % [name_text, _draft.city, country_key]

func _refresh_readouts() -> void:
    _power_readout.text     = str(_draft.attributes.power)
    _composure_readout.text = str(_draft.attributes.composure)
    _attack_readout.text    = str(_draft.attributes.attack)
    _control_readout.text   = str(_draft.attributes.control)

    var remaining := Attributes.CREATION_TOTAL - _draft.attributes.sum()
    _points_label.text = "POINTS REMAINING: %d / %d" % [remaining, Attributes.CREATION_TOTAL]
    _points_label.modulate = Color.WHITE if remaining == 0 else Color(1, 0.3, 0.3)

    var label := Classifier.classify(_draft.attributes)
    _classifier_label.text = "YOUR PLAYER IS A: %s" % ClassifierLabel.display_name(label)

    _confirm_btn.disabled = not _draft.attributes.is_valid_creation_distribution()

func _on_confirm_pressed() -> void:
    if not _draft.attributes.is_valid_creation_distribution():
        return
    var player := Player.from_draft(_draft)
    SaveManager.save_player(player)
    confirmed.emit(player)
```

- [ ] **Step 2: Build the scene file**

Create `scenes/player_creation/build.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/player_creation/build.gd" id="1"]

[node name="Build" type="Control"]
anchors_preset = 15
script = ExtResource("1")

[node name="Layout" type="VBoxContainer" parent="."]
anchors_preset = 15
offset_left = 16.0
offset_top = 32.0
offset_right = -16.0
offset_bottom = -32.0

[node name="Header" type="Label" parent="Layout"]
text = "2 / 2 · BUILD"

[node name="RecapRow" type="HBoxContainer" parent="Layout"]

[node name="RecapPortrait" type="ColorRect" parent="Layout/RecapRow"]
custom_minimum_size = Vector2(28, 34)
color = Color(0.2, 0.2, 0.2, 1)

[node name="RecapLabel" type="Label" parent="Layout/RecapRow"]
text = "—"

[node name="PointsCounter" type="Label" parent="Layout"]
text = "POINTS REMAINING: 0 / 20"

[node name="Sliders" type="VBoxContainer" parent="Layout"]

[node name="PowerRow" type="HBoxContainer" parent="Layout/Sliders"]

[node name="PowerLabel" type="Label" parent="Layout/Sliders/PowerRow"]
text = "POWER"

[node name="PowerSlider" type="HSlider" parent="Layout/Sliders/PowerRow"]
size_flags_horizontal = 3
min_value = 1.0
max_value = 8.0
step = 1.0
value = 5.0

[node name="PowerReadout" type="Label" parent="Layout/Sliders/PowerRow"]
text = "5"

[node name="ComposureRow" type="HBoxContainer" parent="Layout/Sliders"]

[node name="ComposureLabel" type="Label" parent="Layout/Sliders/ComposureRow"]
text = "COMPOSURE"

[node name="ComposureSlider" type="HSlider" parent="Layout/Sliders/ComposureRow"]
size_flags_horizontal = 3
min_value = 1.0
max_value = 8.0
step = 1.0
value = 5.0

[node name="ComposureReadout" type="Label" parent="Layout/Sliders/ComposureRow"]
text = "5"

[node name="AttackRow" type="HBoxContainer" parent="Layout/Sliders"]

[node name="AttackLabel" type="Label" parent="Layout/Sliders/AttackRow"]
text = "ATTACK"

[node name="AttackSlider" type="HSlider" parent="Layout/Sliders/AttackRow"]
size_flags_horizontal = 3
min_value = 1.0
max_value = 8.0
step = 1.0
value = 5.0

[node name="AttackReadout" type="Label" parent="Layout/Sliders/AttackRow"]
text = "5"

[node name="ControlRow" type="HBoxContainer" parent="Layout/Sliders"]

[node name="ControlLabel" type="Label" parent="Layout/Sliders/ControlRow"]
text = "CONTROL"

[node name="ControlSlider" type="HSlider" parent="Layout/Sliders/ControlRow"]
size_flags_horizontal = 3
min_value = 1.0
max_value = 8.0
step = 1.0
value = 5.0

[node name="ControlReadout" type="Label" parent="Layout/Sliders/ControlRow"]
text = "5"

[node name="ClassifierLabel" type="Label" parent="Layout"]
text = "YOUR PLAYER IS A: ALL-ROUNDER"

[node name="Footer" type="HBoxContainer" parent="Layout"]

[node name="BackBtn" type="Button" parent="Layout/Footer"]
text = "← BACK"

[node name="ConfirmBtn" type="Button" parent="Layout/Footer"]
text = "BEGIN CAREER ▶"
```

- [ ] **Step 3: Smoke-test the scene**

Create `tests/unit/test_build_scene.gd`:

```gdscript
extends GutTest

const BuildScene = preload("res://scenes/player_creation/build.tscn")
const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func _draft() -> PlayerCreationDraft:
    var d := PlayerCreationDraft.new()
    d.country = Country.Code.SA
    d.city = "Cape Town"
    d.appearance = Appearance.Bucket.WHITE
    var n := NamePair.new(); n.first_name = "Jonty"; n.surname = "Springer"
    d.name = n
    return d

func test_default_attributes_confirm_enabled_label_all_rounder():
    var build = BuildScene.instantiate()
    build.set_draft(_draft())
    add_child_autofree(build)
    await get_tree().process_frame
    assert_eq(build._draft.attributes.sum(), 20)
    assert_false(build._confirm_btn.disabled)
    assert_string_contains(build._classifier_label.text, "ALL-ROUNDER")

func test_dragging_sliders_above_20_disables_confirm():
    var build = BuildScene.instantiate()
    build.set_draft(_draft())
    add_child_autofree(build)
    await get_tree().process_frame
    build._power_slider.value = 8
    # Simulate the signal manually (gut may not fire it synchronously)
    build._on_slider_changed(8.0)
    assert_ne(build._draft.attributes.sum(), 20)
    assert_true(build._confirm_btn.disabled)
    assert_string_contains(build._points_label.text, "REMAINING")

func test_confirm_persists_player_and_emits_signal():
    SaveManager.player_save_path = "user://_test_build_player.tres"
    SaveManager.clear_player()
    var build = BuildScene.instantiate()
    build.set_draft(_draft())
    add_child_autofree(build)
    await get_tree().process_frame
    watch_signals(build)
    build._on_confirm_pressed()
    assert_signal_emitted(build, "confirmed")
    assert_true(SaveManager.has_player())
    SaveManager.clear_player()

func test_recap_shows_identity_from_draft():
    var build = BuildScene.instantiate()
    build.set_draft(_draft())
    add_child_autofree(build)
    await get_tree().process_frame
    assert_string_contains(build._recap_label.text, "JONTY SPRINGER")
    assert_string_contains(build._recap_label.text, "Cape Town")
    assert_string_contains(build._recap_label.text, "SA")

func test_back_emits_the_same_draft_for_rehydration():
    var build = BuildScene.instantiate()
    var d := _draft()
    build.set_draft(d)
    add_child_autofree(build)
    await get_tree().process_frame
    watch_signals(build)
    build._back_btn.pressed.emit()
    assert_signal_emitted_with_parameters(build, "back_pressed", [d])
```

- [ ] **Step 4: Run, verify PASS**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_build_scene.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Eyeball the scene**

Run: `godot --path . scenes/player_creation/build.tscn`
Expected: window opens, 4 sliders all at 5, classifier label says "ALL-ROUNDER", Confirm button enabled. Drag Power to 8 + Composure to 8 → label changes to "BATTER" or "WICKET-KEEPER BATTER" depending on Attack/Control. Drag everything to 8 → points-remaining goes negative-red and Confirm disables. Close.

- [ ] **Step 6: Commit**

```bash
git add scenes/player_creation/build.tscn scenes/player_creation/build.gd tests/unit/test_build_scene.gd
git commit -m "Add Build scene (Screen 2): 4 sliders, live classifier, Confirm persists Player"
```

---

## Phase 7 — Main scene routing + downstream stubs

The `Main` scene is the entry point. On launch, it checks `SaveManager` and routes:
- Existing Player → Season hub stub
- No Player → Identity → Build → Starting Team picker stub

**Task order matters here.** `LifecycleManager` (7.1) lands *before* the stubs (7.2) because the Season hub stub calls `LifecycleManager.manual_retire()` — that reference won't parse unless the autoload is already registered, so committing the stubs first would leave a broken tree.

### Task 7.1: `LifecycleManager` autoload skeleton

Single owner of the "end this Career" transition. Phase 8 + 9 add the real tests; here we land the script and register the autoload so the Season hub stub (7.2) compiles.

**Files:**
- Create: `scripts/services/lifecycle_manager.gd`
- Modify: `project.godot` (add `LifecycleManager` to the `[autoload]` block)

- [ ] **Step 1: Author the skeleton**

Create `scripts/services/lifecycle_manager.gd`:

```gdscript
extends Node

# Autoload — single owner of the "end this Career" state transition.
# Manual retire + Win-out both route through end_career() so future auto-drop
# (Theme 9, post-launch) is a third trigger pointing at the same transition.
# See spec §2 + ADR 0012.

signal career_ended(end_reason: String)

# Seasons-played counter. Real Career-state code will own this; for V1 we
# just hand 1 to archive_to_legends as a placeholder.
const _PLACEHOLDER_SEASONS := 1

func manual_retire() -> void:
    end_career(LegendEntry.END_REASON_RETIRED)

func win_out() -> void:
    end_career(LegendEntry.END_REASON_WON)

func end_career(reason: String) -> void:
    var p := SaveManager.load_player()
    if p == null:
        push_warning("LifecycleManager.end_career called with no Player loaded")
        return
    SaveManager.archive_to_legends(p, reason, _PLACEHOLDER_SEASONS)
    SaveManager.clear_player()
    career_ended.emit(reason)
```

- [ ] **Step 2: Register the autoload in `project.godot`**

Add `LifecycleManager` to the existing `[autoload]` block (`SaveManager` was added in Phase 4):

```ini
[autoload]

SaveManager="*res://scripts/services/save_manager.gd"
LifecycleManager="*res://scripts/services/lifecycle_manager.gd"
```

- [ ] **Step 3: Verify the project loads with both autoloads resolved**

Run: `godot --headless --quit --path . 2>&1 | head -30`
Expected: no `ERROR:` lines. Both autoloads now point at real files.

- [ ] **Step 4: Commit**

```bash
git add scripts/services/lifecycle_manager.gd project.godot
git commit -m "Add LifecycleManager autoload skeleton (manual_retire + win_out → end_career)"
```

### Task 7.2: Stub downstream scenes

Three placeholder scenes so the routing has somewhere to go. Each is a single `Label` + a single `Button` that returns control.

**Files:**
- Create: `scenes/stubs/starting_team_picker_stub.tscn` + `.gd`
- Create: `scenes/stubs/season_hub_stub.tscn` + `.gd`
- Create: `scenes/stubs/hall_of_fame_stub.tscn` + `.gd`

- [ ] **Step 1: Author the Starting Team picker stub**

Create `scenes/stubs/starting_team_picker_stub.gd`:

```gdscript
extends Control

# Placeholder. Real Starting Team picker lives in around-the-match-v1.html mockup
# and is part of Theme 5's broader Season hub work — not in scope here.

signal proceed_to_season()

func _ready() -> void:
    $Layout/ContinueBtn.pressed.connect(func(): proceed_to_season.emit())
```

Create `scenes/stubs/starting_team_picker_stub.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/stubs/starting_team_picker_stub.gd" id="1"]

[node name="StartingTeamPickerStub" type="Control"]
anchors_preset = 15
script = ExtResource("1")

[node name="Layout" type="VBoxContainer" parent="."]
anchors_preset = 15
offset_left = 16.0
offset_top = 32.0
offset_right = -16.0
offset_bottom = -32.0

[node name="Title" type="Label" parent="Layout"]
text = "STARTING TEAM PICKER\n(stub — real version is Theme 5+)"

[node name="ContinueBtn" type="Button" parent="Layout"]
text = "ENTER FIRST SEASON ▶"
```

- [ ] **Step 2: Author the Season hub stub**

The Season hub stub carries two affordances: a **Manual retire** button (used in Phase 8) and a **dev "Simulate win"** button (used in Phase 9). Both call into `LifecycleManager`.

Create `scenes/stubs/season_hub_stub.gd`:

```gdscript
extends Control

# Placeholder. The real Season hub is the Theme 5 hi-fi spec
# (docs/mockups/around-the-match-v1.html §1). This stub exists so the
# Manual-retire button has a home + so the dev win-out cheat has a trigger.

func _ready() -> void:
    $Layout/RetireBtn.pressed.connect(_on_retire_pressed)
    $Layout/DevWinBtn.pressed.connect(_on_dev_win_pressed)
    _refresh_player_display()

func _refresh_player_display() -> void:
    var p := SaveManager.load_player()
    if p == null:
        $Layout/PlayerLabel.text = "(no player)"
    else:
        $Layout/PlayerLabel.text = "%s · %s · %s" % [
            p.name.display_caps(),
            p.city,
            Country.to_key(p.country),
        ]

func _on_retire_pressed() -> void:
    var dialog := ConfirmationDialog.new()
    dialog.dialog_text = "End this Player's career? They will be archived to the Hall of Fame."
    dialog.title = "Retire Player"
    dialog.confirmed.connect(func(): LifecycleManager.manual_retire())
    add_child(dialog)
    dialog.popup_centered()

func _on_dev_win_pressed() -> void:
    # Dev-only — wired here until the real Match scene exists to trigger it.
    LifecycleManager.win_out()
```

Create `scenes/stubs/season_hub_stub.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/stubs/season_hub_stub.gd" id="1"]

[node name="SeasonHubStub" type="Control"]
anchors_preset = 15
script = ExtResource("1")

[node name="Layout" type="VBoxContainer" parent="."]
anchors_preset = 15
offset_left = 16.0
offset_top = 32.0
offset_right = -16.0
offset_bottom = -32.0

[node name="Title" type="Label" parent="Layout"]
text = "SEASON HUB (stub)"

[node name="PlayerLabel" type="Label" parent="Layout"]
text = "(no player)"

[node name="RetireBtn" type="Button" parent="Layout"]
text = "End this Player's career"

[node name="DevWinBtn" type="Button" parent="Layout"]
text = "[DEV] Simulate winning the final"
```

- [ ] **Step 3: Author the Hall of Fame stub**

The stub just lists archived Legends and links back to a new Creation.

Create `scenes/stubs/hall_of_fame_stub.gd`:

```gdscript
extends Control

# Placeholder. Real Hall of Fame is a sibling spec, owed by Theme 5.
# This stub renders the LegendsArchive as plain text rows + a "Begin new Player" button.

signal begin_new_player()

func _ready() -> void:
    $Layout/BeginBtn.pressed.connect(func(): begin_new_player.emit())
    _render_legends()

func _render_legends() -> void:
    var arc: LegendsArchive = SaveManager.load_legends()
    var list_label: Label = $Layout/LegendsList
    var lines: Array[String] = []
    for entry in arc.entries:
        var arc_text := "%s · %s · %s · %d seasons" % [
            entry.player.name.display_caps(),
            entry.player.city,
            entry.end_reason.to_upper(),
            entry.seasons_played,
        ]
        lines.append(arc_text)
    if lines.is_empty():
        list_label.text = "(no Legends yet)"
    else:
        list_label.text = "\n".join(lines)
```

Create `scenes/stubs/hall_of_fame_stub.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/stubs/hall_of_fame_stub.gd" id="1"]

[node name="HallOfFameStub" type="Control"]
anchors_preset = 15
script = ExtResource("1")

[node name="Layout" type="VBoxContainer" parent="."]
anchors_preset = 15
offset_left = 16.0
offset_top = 32.0
offset_right = -16.0
offset_bottom = -32.0

[node name="Title" type="Label" parent="Layout"]
text = "HALL OF FAME (stub)"

[node name="LegendsList" type="Label" parent="Layout"]
text = "(no Legends yet)"

[node name="BeginBtn" type="Button" parent="Layout"]
text = "BEGIN NEW PLAYER ▶"
```

- [ ] **Step 4: Commit**

```bash
git add scenes/stubs/
git commit -m "Add stub scenes: Starting Team picker, Season hub, Hall of Fame"
```

### Task 7.3: Main scene routing

**Files:**
- Create: `scenes/main.tscn`
- Create: `scenes/main.gd`

- [ ] **Step 1: Write the router**

Create `scenes/main.gd`:

```gdscript
extends Node

# Entry point. Picks the right scene based on save state, then drives transitions.

const IDENTITY := preload("res://scenes/player_creation/identity.tscn")
const BUILD := preload("res://scenes/player_creation/build.tscn")
const STARTING_TEAM := preload("res://scenes/stubs/starting_team_picker_stub.tscn")
const SEASON_HUB := preload("res://scenes/stubs/season_hub_stub.tscn")
const HALL_OF_FAME := preload("res://scenes/stubs/hall_of_fame_stub.tscn")

@onready var _slot: Control = $Slot

func _ready() -> void:
    LifecycleManager.career_ended.connect(_on_career_ended)
    if SaveManager.has_player():
        _push(SEASON_HUB.instantiate())
    else:
        _start_creation()

# draft is null on a fresh cold start / new Player, or the in-progress draft when
# the user taps Back from Build (spec §4: Back preserves picks). Passing it into
# Identity.set_draft re-hydrates the screen instead of starting blank.
func _start_creation(draft: PlayerCreationDraft = null) -> void:
    var identity := IDENTITY.instantiate()
    if draft != null:
        identity.set_draft(draft)
    identity.advance_to_build.connect(_on_identity_advance)
    _push(identity)

func _on_identity_advance(draft: PlayerCreationDraft) -> void:
    var build := BUILD.instantiate()
    build.set_draft(draft)
    build.back_pressed.connect(_start_creation)   # back_pressed emits the draft → _start_creation(draft)
    build.confirmed.connect(_on_build_confirmed)
    _push(build)

func _on_build_confirmed(_player: Player) -> void:
    var picker := STARTING_TEAM.instantiate()
    picker.proceed_to_season.connect(func(): _push(SEASON_HUB.instantiate()))
    _push(picker)

func _on_career_ended(_reason: String) -> void:
    var hof := HALL_OF_FAME.instantiate()
    # Wrap in a 0-arg lambda: begin_new_player emits no args, and connecting it
    # straight to _start_creation(draft = null) would lean on GDScript filling the
    # default from an arg-less signal. The lambda makes the arity unambiguous —
    # a fresh creation, no draft to re-hydrate.
    hof.begin_new_player.connect(func(): _start_creation())
    _push(hof)

func _push(scene: Control) -> void:
    for c in _slot.get_children():
        c.queue_free()
    _slot.add_child(scene)
```

- [ ] **Step 2: Build the scene file**

Create `scenes/main.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")

[node name="Slot" type="Control" parent="."]
anchors_preset = 15
```

- [ ] **Step 3: Smoke-run the full cold-start flow**

Make sure no test save exists from a prior run:
```bash
rm -f ~/.local/share/godot/app_userdata/Cricket\ Sim/player.tres 2>/dev/null
rm -f ~/Library/Application\ Support/Godot/app_userdata/Cricket\ Sim/player.tres 2>/dev/null
```
(macOS: second path. Linux: first. Win: `%APPDATA%\Godot\app_userdata\Cricket Sim\player.tres`.)

Run: `godot --path .`
Expected sequence in the running app:
1. Identity screen appears (no save → cold start).
2. Pick SA → pick Cape Town → tap a portrait → "NEXT" enables → tap NEXT.
3. Build screen appears with sliders at 5/5/5/5 and classifier "ALL-ROUNDER".
4. Tap "BEGIN CAREER" → Starting Team picker stub appears.
5. Tap "ENTER FIRST SEASON" → Season hub stub appears showing the Player's identity line.
6. Close the window.
7. Re-run `godot --path .`.
8. The app skips Creation and lands directly on the Season hub stub (save resumed).

If step 8 works, the routing is correct.

- [ ] **Step 4: Smoke-test the router instantiates**

Create `tests/unit/test_main_router.gd`:

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const Country = preload("res://scripts/domain/country.gd")
const Appearance = preload("res://scripts/domain/appearance.gd")

func before_each() -> void:
    SaveManager.player_save_path = "user://_test_main_player.tres"
    SaveManager.legends_save_path = "user://_test_main_legends.tres"
    SaveManager.clear_player()
    SaveManager.clear_legends()

func after_each() -> void:
    SaveManager.clear_player()
    SaveManager.clear_legends()

func test_router_instantiates_without_error():
    var main = MainScene.instantiate()
    add_child_autofree(main)
    await get_tree().process_frame
    assert_eq(main._slot.get_child_count(), 1, "one child mounted")
    # No save → first child is Identity
    var first = main._slot.get_child(0)
    assert_true(first.has_signal("advance_to_build"), "first scene is Identity (has advance_to_build signal)")

func test_back_from_build_returns_to_identity_with_picks_preserved():
    var main = MainScene.instantiate()
    add_child_autofree(main)
    await get_tree().process_frame

    # Drive Identity to a complete draft, then advance to Build.
    var identity = main._slot.get_child(0)
    identity._on_country_pressed(Country.Code.SA)
    identity._on_appearance_selected(Appearance.Bucket.WHITE)
    identity._city_dropdown.select(1)          # first real city (index 0 is the placeholder)
    identity._on_city_selected(1)
    var draft = identity._draft
    identity.advance_to_build.emit(draft)
    await get_tree().process_frame

    var build = main._slot.get_child(0)
    assert_true(build.has_method("set_draft"), "advanced to Build")

    # Tap Back → router should mount a fresh Identity hydrated from the same draft.
    build.back_pressed.emit(draft)
    await get_tree().process_frame

    var back_identity = main._slot.get_child(0)
    assert_true(back_identity.has_signal("advance_to_build"), "returned to Identity")
    assert_eq(back_identity._draft.city, draft.city, "city pick preserved across Back")
    assert_false(back_identity._next_btn.disabled, "hydrated Identity has Next enabled")
```

- [ ] **Step 5: Run, verify PASS**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_main_router.gd -gexit`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add scenes/main.tscn scenes/main.gd tests/unit/test_main_router.gd
git commit -m "Add Main router (cold-start → Creation → Starting Team stub → Season hub stub)"
```

---

## Phase 8 — Manual retire

The Manual-retire button is already wired on the Season hub stub from Phase 7. Phase 8 tests that the whole transition lands.

### Task 8.1: LifecycleManager Manual-retire tests

**Files:**
- Test: `tests/unit/test_lifecycle_manager.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_lifecycle_manager.gd`:

```gdscript
extends GutTest

const PlayerCreationDraft = preload("res://scripts/data/player_creation_draft.gd")
const NamePair = preload("res://scripts/data/name_pair.gd")
const LegendEntry = preload("res://scripts/data/legend_entry.gd")

func before_each() -> void:
    SaveManager.player_save_path = "user://_test_lc_player.tres"
    SaveManager.legends_save_path = "user://_test_lc_legends.tres"
    SaveManager.clear_player()
    SaveManager.clear_legends()

func after_each() -> void:
    SaveManager.clear_player()
    SaveManager.clear_legends()

func _seeded_player() -> void:
    var d := PlayerCreationDraft.new()
    var n := NamePair.new(); n.first_name = "Jonty"; n.surname = "Springer"
    d.name = n
    SaveManager.save_player(Player.from_draft(d))

func test_manual_retire_clears_player_and_archives_with_retired_reason():
    _seeded_player()
    watch_signals(LifecycleManager)
    LifecycleManager.manual_retire()
    assert_false(SaveManager.has_player(), "Player cleared")
    var arc := SaveManager.load_legends()
    assert_eq(arc.size(), 1)
    assert_eq(arc.entries[0].end_reason, LegendEntry.END_REASON_RETIRED)
    assert_signal_emitted_with_parameters(LifecycleManager, "career_ended", [LegendEntry.END_REASON_RETIRED])

func test_manual_retire_with_no_player_is_a_no_op_warning():
    # No player loaded; should not crash, should not archive.
    LifecycleManager.manual_retire()
    var arc := SaveManager.load_legends()
    assert_eq(arc.size(), 0)
```

- [ ] **Step 2: Run, verify PASS**

The implementation already lives at `scripts/services/lifecycle_manager.gd` from Phase 7.2 — these tests should pass straight away. If they don't, fix the LifecycleManager and re-run.

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_lifecycle_manager.gd -gexit`
Expected: PASS.

- [ ] **Step 3: Manual end-to-end smoke**

Run: `godot --path .`
1. Go through Creation as in Phase 7.3.
2. On the Season hub stub, tap "End this Player's career" → confirm in the dialog.
3. The Hall of Fame stub appears, showing one row: `JONTY SPRINGER · Cape Town · RETIRED · 1 seasons`.
4. Tap "BEGIN NEW PLAYER" → returns to Identity screen.

- [ ] **Step 4: Commit**

```bash
git add tests/unit/test_lifecycle_manager.gd
git commit -m "Test LifecycleManager.manual_retire archives Player and clears save"
```

---

## Phase 9 — Win-out archival hook + dev cheat

The dev "Simulate winning the final" button on the Season hub stub already wires `LifecycleManager.win_out()` from Phase 7. Phase 9 tests it and confirms the second end-state path archives correctly.

### Task 9.1: Win-out tests

**Files:**
- Modify: `tests/unit/test_lifecycle_manager.gd`

- [ ] **Step 1: Add the failing test**

Append to `tests/unit/test_lifecycle_manager.gd`:

```gdscript
func test_win_out_clears_player_and_archives_with_won_reason():
    _seeded_player()
    watch_signals(LifecycleManager)
    LifecycleManager.win_out()
    assert_false(SaveManager.has_player())
    var arc := SaveManager.load_legends()
    assert_eq(arc.size(), 1)
    assert_eq(arc.entries[0].end_reason, LegendEntry.END_REASON_WON)
    assert_signal_emitted_with_parameters(LifecycleManager, "career_ended", [LegendEntry.END_REASON_WON])
```

- [ ] **Step 2: Run, verify PASS**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_lifecycle_manager.gd -gexit`
Expected: PASS, all 3 tests.

- [ ] **Step 3: Manual smoke for the win-out path**

Run: `godot --path .`
1. If a save exists, retire it first. Roll a new Player through Creation.
2. On the Season hub stub, tap "[DEV] Simulate winning the final".
3. The Hall of Fame stub appears, showing the Player with `WON · 1 seasons`.

- [ ] **Step 4: Commit**

```bash
git add tests/unit/test_lifecycle_manager.gd
git commit -m "Test LifecycleManager.win_out archives Player with 'won' reason"
```

---

## Phase 10 — ADR 0012 + roadmap update

The spec §2 already has the rationale; this phase formalises it as an ADR and closes the open loop in `PROJECT_ROADMAP.md`.

### Task 10.1: Write ADR 0012

**Files:**
- Create: `docs/adr/0012-player-lifecycle-hard-permadeath.md`

- [ ] **Step 1: Author the ADR**

Create `docs/adr/0012-player-lifecycle-hard-permadeath.md`. Match the prose style of `0010-around-the-match-navigation-shell.md` (intro paragraph + numbered locked decision + Considered alternatives + Decided date + reference back to the spec):

```markdown
# Player lifecycle — hard permadeath

V1 Player lifecycle has **two end-states** and **no other ways out**: the Player either **wins the Province's Premium tour Final** (Win-out) or the human **manually retires them** via a corner button on the Season hub. Both archive the Player to the **LegendsArchive** and trigger a new Player Creation. There is no auto-drop, no non-selection, no age-based retirement, no team-release path. Hard permadeath, two triggers, single archive transition.

Reasons:

1. **Seasons-played becomes a real cost.** Permadeath gives the Hall of Fame meaning. The "now beat that" replay loop hooks off finite Player-lives, not just numerical scores — every Legend on the wall represents a specific Career that cannot be retried.
2. **Auto-drop balance is hard before the baseline loop is playtested.** Layering an unproven failure mode on an unproven success loop is bad sequencing. We need to know what "good Career" feels like before we can decide what "your Career ends here" should look like.
3. **Architecturally cheap to add later.** An auto-drop trigger added post-launch is the same state transition as Manual retire, just counter-triggered instead of button-triggered. The `LifecycleManager.end_career(reason)` signature already takes a reason — adding a third trigger is one new caller, zero rewrite cost.
4. **Form-anchored, not Team-anchored.** If/when Theme 9 ships auto-drop, the trigger anchors on **Player form** (low runs over last K innings, lost Key Moments, etc.), **not Team result**. A good Player on a bad Team shouldn't be punished for the Team's losses. This is recorded here so the future implementer doesn't have to re-discover the principle.

The Manual-retire button is the cheap escape-hatch for *"I'm stuck and want to roll a new Player"* — it covers the player-experience case that auto-drop would otherwise need to solve, without requiring any failure detection or balance work.

Decided 2026-06-01 alongside the Player Creation spec at `docs/superpowers/specs/2026-06-01-player-creation-design.md` §2, formalised at implementation-plan time.

## Considered alternatives

- **Auto-drop on Team relegation.** The Player is dropped when their Team finishes bottom of the table. Rejected — punishes the Player for the Team's mistakes, conflates the Team-management layer with the Player-life layer. Holds for Theme 9 *only* if anchored on Player form, not Team result.
- **Age-based retirement.** Player retires after N Seasons regardless of form. Rejected for V1 because the Career-length feel hasn't been playtested; a hard age cap might make Careers too short or too long before we know which. Holds for Theme 9.
- **No permadeath; Players persist across Careers.** Rejected — would gut the Hall of Fame's meaning and remove the "finite life" frame the game's identity rests on. Anti to the spec's core thesis.
- **Soft retire — Player keeps playing but loses upgrades.** Rejected — too mechanically novel to add at V1; the simple binary (alive / archived) reads cleaner.
```

- [ ] **Step 2: Commit**

```bash
git add docs/adr/0012-player-lifecycle-hard-permadeath.md
git commit -m "ADR 0012: Player lifecycle — hard permadeath (Win-out + Manual retire)"
```

### Task 10.2: Update `PROJECT_ROADMAP.md`

- [ ] **Step 1: Patch the roadmap**

Edit `PROJECT_ROADMAP.md` and:
1. Update "Last closed" to mention Player Creation built.
2. Update "Next theme" to point at Hall of Fame screen (sibling spec) **or** Theme 7 (Tech foundation: balance harness), depending on priority — leave as "decision point" rather than picking now.
3. In the Decisions log, add a row for 2026-06-XX (today's date when executing) noting ADR 0012 written + Player Creation built.
4. In Reference docs, change the line `0012 Player lifecycle hard-permadeath — owed at plan time` to remove the `— owed at plan time` suffix.

Use Edit to make each change rather than a full rewrite — the file is large and other sections shouldn't drift.

- [ ] **Step 2: Commit**

```bash
git add PROJECT_ROADMAP.md
git commit -m "Roadmap: close Player Creation build; ADR 0012 written"
```

---

## Phase 11 — Full test sweep + final smoke

Belt-and-braces verification before claiming done.

### Task 11.1: Run the full test suite

- [ ] **Step 1: Run all tests**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: every test passes. Count is approximately 60+ assertions across these files (test counts in parens):
- `test_country.gd` (3)
- `test_appearance.gd` (3)
- `test_classifier_label.gd` (2)
- `test_attributes.gd` (7)
- `test_player_creation_draft.gd` (3)
- `test_player.gd` (2)
- `test_cities.gd` (3)
- `test_classifier.gd` (11)
- `test_name_generator.gd` (5)
- `test_save_manager.gd` (7 — includes the loaded-player inline-archive regression guard)
- `test_appearance_picker.gd` (4 — includes silent-select + enable/disable)
- `test_identity_scene.gd` (6 — includes picker-disable + Back-hydration)
- `test_build_scene.gd` (5 — includes recap + back-carries-draft)
- `test_main_router.gd` (2 — includes Back-preserves-picks integration)
- `test_lifecycle_manager.gd` (3)

If anything fails: fix that test/file, re-run the full sweep, do not move on.

### Task 11.2: Full manual end-to-end

- [ ] **Step 1: Wipe save state**

```bash
rm -rf ~/Library/Application\ Support/Godot/app_userdata/Cricket\ Sim 2>/dev/null
rm -rf ~/.local/share/godot/app_userdata/Cricket\ Sim 2>/dev/null
```

- [ ] **Step 2: Cold-start run**

Run: `godot --path .`
Walk through the full happy path:
1. Identity → SA → Cape Town → tap a portrait → re-roll the name a couple of times → NEXT.
2. Build → tap "← BACK" → confirm Identity returns with SA, Cape Town, the portrait, and the **same name** still selected (spec §4: Back preserves picks) → NEXT again.
3. Build → set Power=8 Composure=8 Attack=2 Control=2 → classifier shows "BATTER" → confirm the recap row at the top shows the name · city · SA → BEGIN CAREER.
4. Starting Team picker stub → ENTER FIRST SEASON.
5. Season hub stub → tap "End this Player's career" → confirm.
6. Hall of Fame stub → see your Legend → BEGIN NEW PLAYER.
7. Identity → AUS → Sydney → tap a portrait → NEXT.
8. Build → make a wildly unbalanced shape (all 8s) → see Confirm disabled, points-remaining red. Pull back to 20 total → Confirm enables → BEGIN CAREER.
9. Starting Team picker → Season hub → tap "[DEV] Simulate winning the final".
10. Hall of Fame stub → two rows now, second one shows "WON".
11. Close the window.
12. Re-run `godot --path .` → cold-start, no current Player (last one archived) → Identity screen appears.

If any step misbehaves, fix the underlying issue and re-walk from step 1.

- [ ] **Step 3: Commit any fixes**

If steps above required fixes, commit each as a focused change:
```bash
git add <files>
git commit -m "Fix: <what broke>"
```

If no fixes were needed, no commit.

---

## Done. Hand-off

Player Creation V1 is built. The Player object persists, the LegendsArchive accumulates, Manual retire works, Win-out works (via dev cheat), and ADR 0012 is on the record.

**What's NOT done (deliberately):**

- Hall of Fame screen real layout — separate spec, owed by Theme 5.
- Starting Team picker real implementation — Theme 5 broader Season-hub work.
- Season hub real implementation — Theme 5 broader Season-hub work.
- Match scene that fires real Win-out triggers — Theme 7 onwards.
- Real name banks (~30 × 50 per bank, ~12,000 unique combos) — separate authoring deliverable.
- Real portrait art (8 sets — 4 Appearance × 2 Country) — Theme 6.
- Hi-fi visual styling matching `docs/mockups/player-creation-v1.html` (when it exists from claude.ai) — separate styling pass.
- Tuned classifier thresholds, attribute upgrade cap — Theme 7 balance harness.
- Auto-drop / non-selection / age-based retirement — Theme 9 (post-launch).

These are all out of scope per the spec's §2 and §10 lists, and reflected in PROJECT_ROADMAP.md after Task 10.2.
