# City Clubs at Creation (T11) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-city club-name banks + a surfaced 1-of-3 starting-club pick on Identity (spec `docs/superpowers/specs/2026-07-04-city-clubs-design.md`, DCC1–DCC10). Flavour only.

**Architecture:** New pure data class `CityClubs` (21 city banks × 8 names). `CareerResolver.start_career` gains a trailing-optional `city` param that renames the Club level from the bank (empty/unknown city = byte-identical placeholder names, DCC2). `club_slot` rides Draft → Player → `main._push_career_grid`. Identity gains a "YOUR CLUB" 3-tile section (existing seg-button style).

**Tech Stack:** Godot 4.6.3 / GDScript / GUT 9.6. Tabs. Whole-suite runs; red = parse error or failing assert.

**Test command (every step):**
```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
New `scripts/` files need `--import` once (and commit the generated `.gd.uid`); test files get no `.uid`.

---

### Task 1: `CityClubs` banks

**Files:**
- Create: `scripts/data/city_clubs.gd` (+ commit its `.gd.uid` after `--import`)
- Test: `tests/unit/test_city_clubs.gd` (create)

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

# T11 city clubs (spec 2026-07-04 DCC3/DCC9): every creation city has a bank of
# 8 club names; quality rules unit-enforced; unknown city falls back to canon.

func test_every_city_has_a_bank():
	for city in Cities.SA + Cities.AUS:
		assert_true(CityClubs.has_bank(city), "%s has a club bank" % city)
		assert_eq(CityClubs.bank(city).size(), 8, "%s bank has 8 clubs" % city)

func test_bank_quality_rules():
	var placeholders := []
	for lvl_names in CareerResolver.TEAM_NAMES:
		placeholders.append_array(lvl_names)
	for city in Cities.SA + Cities.AUS:
		var seen := {}
		for nm in CityClubs.bank(city):
			assert_false(seen.has(nm), "%s: '%s' unique within the city" % [city, nm])
			seen[nm] = true
			assert_lte(nm.length(), 22, "%s: '%s' fits the hub header (DCC9)" % [city, nm])
			assert_false(nm in placeholders, "%s: '%s' not a TEAM_NAMES placeholder" % [city, nm])

func test_unknown_city_falls_back_to_placeholder_club_bank():
	assert_eq(CityClubs.bank(""), CareerResolver.TEAM_NAMES[0], "empty city -> canon names")
	assert_eq(CityClubs.bank("Atlantis"), CareerResolver.TEAM_NAMES[0], "unknown city -> canon names")
	assert_false(CityClubs.has_bank(""), "no bank claimed for empty")
```

- [ ] **Step 2: Run the suite — red** (parse error: `CityClubs` not declared; that file skipped).

- [ ] **Step 3: Create `scripts/data/city_clubs.gd`**

```gdscript
class_name CityClubs
extends RefCounted

# T11 (spec 2026-07-04 DCC1/DCC3/DCC9): per-city club-name banks — 8 clubs per
# creation city, named for real suburbs/areas. FLAVOUR ONLY: names never enter a
# resolver. Slots 0-2 are the three offered starting clubs (the 3 lowest-★ Club
# slots on the career ladder), so lead each bank with its most recognisable
# suburbs. Unknown/empty city -> the canon placeholder bank (Karoo Kings stays).

const BANKS := {
	# --- South Africa (Cities.SA) ---
	"Cape Town": ["Newlands CC", "Rondebosch Ramblers", "Sea Point Strollers",
		"Khayelitsha XI", "Claremont Crusaders", "Bo-Kaap Braves",
		"Muizenberg Waves", "Woodstock Wanderers"],
	"Johannesburg": ["Soweto Stars", "Sandton Select", "Alexandra Aces",
		"Randburg Rockets", "Parktown Pilgrims", "Braamfontein XI",
		"Yeoville Yorkers", "Melville CC"],
	"Durban": ["Umhlanga Rocks CC", "Berea Breakers", "Morningside CC",
		"Chatsworth Chargers", "Umlazi XI", "Glenwood Griffins",
		"Phoenix Flames", "Bluff CC"],
	"Pretoria": ["Menlo Park CC", "Hatfield Hurricanes", "Sunnyside Swifts",
		"Waterkloof Warriors", "Arcadia Arrows", "Brooklyn CC",
		"Garsfontein XI", "Silverton Stags"],
	"Gqeberha": ["Summerstrand CC", "Walmer Wanderers", "Newton Park XI",
		"Humewood Harriers", "Motherwell Masters", "Kragga Kamma CC",
		"Richmond Hill Royals", "Charlo Chiefs"],
	"East London": ["Nahoon Nomads", "Vincent CC", "Beacon Bay Blasters",
		"Gonubie Gulls", "Quigney Quicks", "Selborne Strikers",
		"Amalinda XI", "Cambridge Colts"],
	"Bloemfontein": ["Westdene Willows", "Langenhoven Lancers", "Universitas XI",
		"Naval Hill Navigators", "Heidedal Hitters", "Fichardt Park Flyers",
		"Bayswater CC", "Brandwag CC"],
	"Pietermaritzburg": ["Scottsville Scorpions", "Oribi Owls", "Northdale Knights",
		"Athlone CC", "Prestbury Pumas", "Wembley Whites",
		"Hilton XI", "Woodlands Weavers"],
	"Centurion": ["Irene Villagers", "Zwartkops Zebras", "Doringkloof Dukes",
		"Rooihuiskraal CC", "Eldoraigne Eagles", "Hennopspark Herons",
		"Lyttelton XI", "Clubview CC"],
	"Paarl": ["Courtrai CC", "Berg River XI", "Fairyland Flamingos",
		"Mbekweni Mambas", "Huguenot CC", "Klein Drakenstein CC",
		"Paarl East XI", "Denneburg Dassies"],
	"Potchefstroom": ["Die Bult XI", "Mooirivier Mallards", "Baillie Park CC",
		"Grimbeek Giants", "Miederpark Millers", "Van der Hoff CC",
		"Ikageng Invincibles", "Potch Dorp Pipers"],
	# --- Australia (Cities.AUS) ---
	"Sydney": ["Manly Seasiders", "Parramatta Pioneers", "Randwick Royals",
		"Balmain Boatmen", "Coogee Crabs", "Penrith Plainsmen",
		"Mosman Mariners", "Bankstown Blues"],
	"Melbourne": ["Fitzroy Foxes", "St Kilda Seagulls", "Carlton Cavaliers",
		"Brunswick Bats", "Richmond Ravens", "Footscray Ferrets",
		"Toorak Toffs", "Coburg CC"],
	"Brisbane": ["Toowong CC", "New Farm Navigators", "Paddington Pelicans",
		"Kangaroo Point XI", "Red Hill Roosters", "Bulimba Barracudas",
		"West End Wombats", "Ascot Anchors"],
	"Perth": ["Fremantle Fishers", "Subiaco Sharks", "Cottesloe Crushers",
		"Scarborough Surfers", "Joondalup Jets", "Leederville Larks",
		"Victoria Park XI", "Midland Mules"],
	"Adelaide": ["Glenelg CC", "Prospect Pacers", "Unley Unicorns",
		"Semaphore Sailors", "Burnside Bouncers", "Henley Beach XI",
		"Mawson Lakes Meteors", "Norwood Nightjars"],
	"Hobart": ["Sandy Bay Skippers", "Battery Point XI", "Glenorchy Gales",
		"Kingston Kestrels", "New Town CC", "Lenah Valley Lynx",
		"Moonah CC", "Bellerive Breakers"],
	"Canberra": ["Manuka CC", "Turner XI", "Dickson Drakes",
		"Belconnen Bullants", "Woden Valley XI", "Gungahlin Gliders",
		"Ainslie Aviators", "Narrabundah CC"],
	"Geelong": ["Barwon Boaters", "Grovedale XI", "Corio Corsairs",
		"Belmont Bluejays", "Highton Hares", "Lara Lorikeets",
		"Torquay Tides", "Ocean Grove Groms"],
	"Newcastle": ["Merewether CC", "Hamilton Hawkers", "Charlestown Cheetahs",
		"Stockton Stingrays", "Wallsend Wallabies", "Kotara Kookaburras",
		"Lambton Lakers", "Adamstown XI"],
	"Darwin": ["Nightcliff Ospreys", "Fannie Bay Frigates", "Parap Pearlers",
		"Stuart Park Stingers", "Casuarina Crocs", "Larrakeyah XI",
		"Palmerston Pythons", "Mindil Beach Marlins"],
}

static func has_bank(city: String) -> bool:
	return BANKS.has(city)

static func bank(city: String) -> Array:
	if BANKS.has(city):
		return BANKS[city]
	return CareerResolver.TEAM_NAMES[0]
```

- [ ] **Step 4: `--import` once, run the suite — green (+3 tests).**

- [ ] **Step 5: Commit** (`git add scripts/data/city_clubs.gd scripts/data/city_clubs.gd.uid tests/unit/test_city_clubs.gd`)
`git commit -m "feat: T11 task 1 -- CityClubs per-city club-name banks (DCC3/DCC9)"`

---

### Task 2: `start_career(slot, city)`

**Files:**
- Modify: `scripts/domain/career_resolver.gd` (the `start_career` loop)
- Test: `tests/unit/test_city_clubs.gd` (extend)

- [ ] **Step 1: Failing tests**

```gdscript
func test_start_career_with_city_names_the_club_level():
	var state := CareerResolver.start_career(1, "Pretoria")
	for k in range(CareerState.TEAMS_PER_LEVEL):
		assert_eq(state.teams[k].team_name, CityClubs.bank("Pretoria")[k],
			"Club slot %d named from the Pretoria bank (DCC1)" % k)
	# Higher levels + ladder untouched
	assert_eq(state.teams[CareerState.TEAMS_PER_LEVEL].team_name,
		CareerResolver.TEAM_NAMES[1][0], "City level keeps placeholder names")
	for k in range(CareerState.TEAMS_PER_LEVEL):
		assert_eq(state.teams[k].stars, CareerResolver.STAR_LADDER[k], "ladder unchanged")
	assert_eq(state.current_team_index, 1, "picked slot honoured")

func test_start_career_without_city_is_byte_identical():
	var state := CareerResolver.start_career(0)
	for k in range(CareerState.TEAMS_PER_LEVEL):
		assert_eq(state.teams[k].team_name, CareerResolver.TEAM_NAMES[0][k],
			"no city -> canon placeholder names (DCC2)")
```

- [ ] **Step 2: Suite — red** (param count / name mismatch assert failures).

- [ ] **Step 3: Implement** — in `career_resolver.gd`, change the signature and the name line:

```gdscript
static func start_career(picked_club_slot: int, city: String = "") -> CareerState:
```
and inside the loop replace `t.team_name = TEAM_NAMES[lvl][k]` with:
```gdscript
			# T11 (DCC1/DCC2): the Club level wears the chosen city's club names;
			# no/unknown city keeps the canon placeholder bank byte-for-byte.
			t.team_name = CityClubs.bank(city)[k] if lvl == 0 and CityClubs.has_bank(city) \
				else TEAM_NAMES[lvl][k]
```

- [ ] **Step 4: Suite — green (+2). Existing career tests unchanged (DCC2).**

- [ ] **Step 5: Commit** `git commit -m "feat: T11 task 2 -- start_career city club naming (DCC1/DCC2)"`

---

### Task 3: `club_slot` through Draft → Player

**Files:**
- Modify: `scripts/data/player_creation_draft.gd` (after the `appearance` export), `scripts/data/player.gd` (after `appearance`, + `from_draft`)
- Test: `tests/unit/test_city_clubs.gd` (extend)

- [ ] **Step 1: Failing test**

```gdscript
func test_club_slot_rides_draft_to_player():
	var d := PlayerCreationDraft.new()
	d.country = Country.Code.SA
	d.city = "Pretoria"
	d.appearance = 0
	d.name = NamePair.new()
	d.club_slot = 2
	var p := Player.from_draft(d)
	assert_eq(p.club_slot, 2, "club_slot copied at creation")
	assert_eq(Player.new().club_slot, 0, "old saves default to slot 0 (DCC7)")
```

- [ ] **Step 2: Suite — red** (`club_slot` not in draft → parse error, file skipped).

- [ ] **Step 3: Implement** — draft: `@export var club_slot: int = 0   # starting-club pick, 0-2 (T11 DCC6)`; player: `@export var club_slot: int = 0   # starting-club pick at creation (T11 DCC7; old saves = 0)`; in `Player.from_draft` beside `p.city = draft.city`: `p.club_slot = draft.club_slot`.

- [ ] **Step 4: Suite — green (+1).**

- [ ] **Step 5: Commit** `git commit -m "feat: T11 task 3 -- club_slot rides Draft -> Player (DCC7)"`

---

### Task 4: Identity "YOUR CLUB" section

**Files:**
- Modify: `scenes/player_creation/identity.gd`
- Test: `tests/unit/test_identity_scene.gd` (extend)

- [ ] **Step 1: Failing tests** (append; match the file's existing boot pattern — it instantiates `scenes/player_creation/identity.tscn` and drives `_on_country_pressed` etc.)

```gdscript
func test_club_pick_tiles_exist_and_follow_city():
	_scene._on_country_pressed(Country.Code.SA)
	_scene._on_city_selected(_city_index(_scene, "Pretoria"))
	await get_tree().process_frame
	var tiles: Array = _scene._club_buttons
	assert_eq(tiles.size(), 3, "3 starting clubs offered (DCC5)")
	for i in range(3):
		assert_eq(tiles[i].text.split("\n")[0], CityClubs.bank("Pretoria")[i],
			"tile %d named from the city bank" % i)
		assert_true(tiles[i].is_visible_in_tree(), "tile visible")
		assert_gt(tiles[i].size.y, 0.0, "tile not collapsed")
	assert_true(tiles[0].button_pressed, "slot 0 preselected (DCC6)")

func test_club_pick_writes_draft_and_survives_advance():
	_scene._on_country_pressed(Country.Code.SA)
	_scene._on_city_selected(_city_index(_scene, "Pretoria"))
	_scene._on_club_pressed(2)
	var captured: Array = []
	_scene.advance_to_build.connect(func(d): captured.append(d))
	_scene._on_appearance_selected(0)
	_scene._on_next_pressed()
	assert_eq(captured.size(), 1, "advanced")
	assert_eq(captured[0].club_slot, 2, "the pick rides the draft (DCC7)")

# OptionButton index for a named city (index 0 is the placeholder row).
func _city_index(scene, city: String) -> int:
	for i in range(scene._city_dropdown.item_count):
		if scene._city_dropdown.get_item_text(i) == city:
			return i
	return -1
```

- [ ] **Step 2: Suite — red** (`_club_buttons` missing → runtime failures in these tests).

- [ ] **Step 3: Implement** in `identity.gd`:

Members: `var _club_buttons: Array = []` and `var _club_box: VBoxContainer`.
In the body build (after `body.add_child(_build_city_pill())`): `body.add_child(_build_club_pick())`.

```gdscript
# T11 (DCC4/DCC5/DCC6): the 1-of-3 starting-club pick — city-bank names for the
# 3 lowest-★ Club slots (1.5/2.0/2.5), seg-button style, slot 0 preselected,
# never gates Next. Hidden until a bankable city is chosen.
func _build_club_pick() -> Control:
	_club_box = VBoxContainer.new()
	_club_box.add_theme_constant_override("separation", 5)
	_club_box.add_child(_lbl("YOUR CLUB", 10, Palette.WHITE_DIM, Fonts.W_LABEL))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var stars := [1.5, 2.0, 2.5]   # STAR_LADDER slots 0-2 (existing ladder, shown not new)
	for i in range(3):
		var b := _seg_button("")
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(_on_club_pressed.bind(i))
		b.set_meta("stars", stars[i])
		row.add_child(b)
		_club_buttons.append(b)
	_club_box.add_child(row)
	_club_box.visible = false
	return _club_box

func _on_club_pressed(i: int) -> void:
	_draft.club_slot = i
	_refresh_club_tiles()

func _refresh_club_tiles() -> void:
	var show := _draft.city != "" and CityClubs.has_bank(_draft.city)
	_club_box.visible = show
	if not show:
		return
	var bank := CityClubs.bank(_draft.city)
	for i in range(3):
		var b: Button = _club_buttons[i]
		b.text = "%s\n%s" % [bank[i], Display.stars_str(b.get_meta("stars"))]
		var on := _draft.club_slot == i
		b.button_pressed = on
		_style_seg(b, on)
```

Wire refreshes: append `_refresh_club_tiles()` at the end of `_on_city_selected`, `_on_country_pressed`, and `set_draft`'s re-hydration path (wherever the city pill re-renders). Check `_style_seg`'s real signature first (`grep -n "_style_seg" scenes/player_creation/identity.gd`) and match it; if it takes the accent, pass `_accent`.

- [ ] **Step 4: Suite — green (+2). Also confirm no existing identity test broke (the section is hidden until a city is picked, so prior renders are unchanged).**

- [ ] **Step 5: Commit** `git commit -m "feat: T11 task 4 -- YOUR CLUB 3-tile pick on Identity (DCC4-DCC6)"`

---

### Task 5: main wiring + design request + renders

**Files:**
- Modify: `scenes/main.gd:37` (`_push_career_grid`)
- Create: `docs/design-inbox/identity-club-pick-REQUEST.md`
- Output: refreshed `docs/mockups/latest/player-creation-identity.png` via `tools/preview_player_creation_identity.gd` (extend it to pick Pretoria + show the club tiles)

- [ ] **Step 1:** In `_push_career_grid`, replace `CareerResolver.start_career(0)` with `CareerResolver.start_career(player.club_slot, player.city)` (a fresh career only — existing careers load from save, DCC7).
- [ ] **Step 2:** Add a `test_city_clubs.gd` guard that the call path compiles with the new signature (already covered by Task 2's tests; run the suite — green, count unchanged from Task 4).
- [ ] **Step 3:** Write `docs/design-inbox/identity-club-pick-REQUEST.md`: what was added (the 3-tile YOUR CLUB section between city and appearance, seg-button style, name + ★ per tile), why (playtest T11), the render path, and the ask (bless or restyle the section; optional richer local club names per city).
- [ ] **Step 4:** Extend `tools/preview_player_creation_identity.gd` to select Pretoria and re-render; LOOK at the PNG (tiles visible, names not clipped, CTA reachable). Fix and re-render if not.
- [ ] **Step 5:** Full suite green → commit all: `git commit -m "feat: T11 task 5 -- career wiring + identity render + design request"`

---

### Task 6: PR + docs

- [ ] Push; PR (spec DCC list + render); merge; `git pull`; re-run suite on merged main.
- [ ] Close T11 in `docs/PLAYTEST-NOTES.md`; roadmap "Next session" → the playtest-fix queue is EMPTY: next = Nico's continued playtest + the iOS export (resolver-signature refactor queued as its stability pass).
