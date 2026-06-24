# Live Career Advance + Outcome hi-fi — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the live season loop climb the career grid (Club→City→Province→complete) on Continue, persist the career, and re-skin the Outcome screen to the game's design language.

**Architecture:** Pure grid-transition logic lives as static helpers on `CareerResolver` + a read helper on `CareerState` (headless-testable, no sim). `season_hub` boots the *real* career cell with a seed that varies per season; `main` records the season outcome into the career on season-end, persists it, and routes Continue to the next season or the Hall of Fame. The Outcome scene gains a transition banner + next-up chip.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Run tests headless per CLAUDE.md (`--import` once after adding scripts, then the GUT cmdln). Judge red by the parse-error-skip, green by total count climbing + `All tests passed`.

---

## File structure

- `scripts/data/career_state.gd` — **modify**: add `next_climb_tour(level)` read helper.
- `scripts/domain/career_resolver.gd` — **modify**: add `next_live_cell(state)` + `advance_after_live_season(...)` statics.
- `scenes/season_hub/season_hub.gd` — **modify**: `boot()`/`set_play()` drive the real cell + varying seed + persist a fresh career; add `current_cell()`.
- `scenes/main.gd` — **modify**: `_commit_and_return`/`_show_outcome` record+persist the advance, route Continue.
- `scenes/outcome/outcome.gd` — **modify**: transition banner + next-up chip + re-skin; drop emoji (Barlow tofu).
- `tools/preview_outcome.gd` — **create**: render Outcome states to PNGs for Nico's eyeball.
- Tests: `tests/unit/test_career_state.gd`, `tests/unit/test_career_resolver.gd`, `tests/unit/test_season_hub.gd`, `tests/unit/test_outcome_scene.gd` (modify/create as noted).

**Test commands (reuse throughout):**
- Import (after adding/renaming a script): `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- Suite: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- Chain both in one command and wait (never two Godot processes at once).

---

## Task 1: `CareerState.next_climb_tour`

**Files:**
- Modify: `scripts/data/career_state.gd`
- Test: `tests/unit/test_career_state.gd`

- [ ] **Step 1: Write the failing test** (append to `test_career_state.gd`)

```gdscript
func test_next_climb_tour_fresh_is_zero():
	var s := CareerResolver.start_career(0)
	assert_eq(s.next_climb_tour(0), 0, "fresh career: only (0,0) unlocked")

func test_next_climb_tour_advances_after_beat():
	var s := CareerResolver.start_career(0)
	s.mark_beaten(0, 0)   # unlocks (0,1)
	assert_eq(s.next_climb_tour(0), 1, "after beating (0,0): next climb tour is 1")

func test_next_climb_tour_minus_one_when_readiness_cleared():
	var s := CareerResolver.start_career(0)
	for t in range(CareerState.READINESS_TOUR + 1):
		s.mark_beaten(0, t)
	assert_eq(s.next_climb_tour(0), -1, "all climb tours <= READINESS beaten: -1")
```

- [ ] **Step 2: Run suite, verify the new asserts fail** (parse-error red: `next_climb_tour` not declared). Run the suite command. Expected: the new test methods error / fail.

- [ ] **Step 3: Implement** (add to `career_state.gd`, after `playable_cells()`)

```gdscript
# Lowest unlocked-but-unbeaten tour in [0..READINESS_TOUR] at `level` — the live
# "rush" climb walks these in order (live-career-advance spec, DLC3). -1 if none
# remain (the loop then crosses up, or plays the Premier at the top Level).
func next_climb_tour(level: int) -> int:
	for t in range(READINESS_TOUR + 1):
		if status_of(level, t) == CellStatus.UNLOCKED:
			return t
	return -1
```

- [ ] **Step 4: Run suite, verify green** (count climbs, `All tests passed`).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/career_state.gd tests/unit/test_career_state.gd
git commit -m "feat: CareerState.next_climb_tour (rush-climb cell selection)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `CareerResolver.next_live_cell`

**Files:**
- Modify: `scripts/domain/career_resolver.gd`
- Test: `tests/unit/test_career_resolver.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
func test_next_live_cell_fresh():
	var s := CareerResolver.start_career(0)
	assert_eq(CareerResolver.next_live_cell(s), {"level": 0, "tour": 0})

func test_next_live_cell_walks_tours():
	var s := CareerResolver.start_career(0)
	s.mark_beaten(0, 0)
	assert_eq(CareerResolver.next_live_cell(s), {"level": 0, "tour": 1})

func test_next_live_cell_top_level_premier_when_climb_done():
	var s := CareerResolver.start_career(0)
	# Force the player onto the top Level (Province) with climb tours cleared.
	s.current_team_index = CareerState.TEAMS_PER_LEVEL * 2   # first Province team
	for t in range(CareerState.READINESS_TOUR + 1):
		s.cell_status[s.cell_index(2, t)] = CareerState.CellStatus.BEATEN
	assert_eq(CareerResolver.next_live_cell(s),
		{"level": 2, "tour": CareerState.PREMIER_TOUR})
```

- [ ] **Step 2: Run suite, verify the new asserts fail** (`next_live_cell` not declared).

- [ ] **Step 3: Implement** (add to `career_resolver.gd`, near the Offers block)

```gdscript
# The cell the LIVE loop plays next (rush-climb, spec DLC3): the lowest unbeaten
# climb tour at the current Level; if those are exhausted, the Premier (the caller
# crosses up *before* boot at non-top Levels, so current_level has already advanced
# — this returns the Premier only at the top Level, the lone way to complete).
static func next_live_cell(state: CareerState) -> Dictionary:
	var level := state.current_level()
	var t := state.next_climb_tour(level)
	if t >= 0:
		return {"level": level, "tour": t}
	return {"level": level, "tour": CareerState.PREMIER_TOUR}
```

- [ ] **Step 4: Run suite, verify green.**

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/career_resolver.gd tests/unit/test_career_resolver.gd
git commit -m "feat: CareerResolver.next_live_cell (rush-climb cell for the live loop)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `CareerResolver.advance_after_live_season`

**Files:**
- Modify: `scripts/domain/career_resolver.gd`
- Test: `tests/unit/test_career_resolver.gd`

This is the meat: record the outcome, bump counters, auto-cross at a Level boundary, return a descriptor for the Outcome screen.

- [ ] **Step 1: Write the failing tests**

```gdscript
# A SeasonResult stub with just the fields advance_after_live_season reads.
func _season_stub(beat: bool, won_final: bool) -> SeasonResult:
	var sr := SeasonResult.new()
	sr.beat = beat
	sr.won_final = won_final
	return sr

func test_advance_marks_beaten_and_bumps_counters():
	var s := CareerResolver.start_career(0)
	var p := _make_player()   # existing helper in this test file
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var t := CareerResolver.advance_after_live_season(s, p, _season_stub(true, false), 0, 0, rng)
	assert_eq(s.status_of(0, 0), CareerState.CellStatus.BEATEN)
	assert_eq(s.status_of(0, 1), CareerState.CellStatus.UNLOCKED, "next tour unlocked")
	assert_eq(s.seasons_played, 1)
	assert_eq(s.seasons_at_level, 1)
	assert_false(t["promoted"])
	assert_eq(t["next_tour"], 1)

func test_advance_not_beaten_is_grid_noop_same_cell():
	var s := CareerResolver.start_career(0)
	var p := _make_player()
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var t := CareerResolver.advance_after_live_season(s, p, _season_stub(false, false), 0, 0, rng)
	assert_eq(s.status_of(0, 0), CareerState.CellStatus.UNLOCKED, "not beaten: still unlocked")
	assert_eq(s.seasons_played, 1, "counter still bumps")
	assert_eq(t["next_tour"], 0, "replays the same cell")

func test_advance_auto_crosses_when_readiness_beaten():
	var s := CareerResolver.start_career(0)
	var p := _make_player()
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	# Pre-clear tours 0..READINESS-1 so this season's beat is the readiness tour.
	for t0 in range(CareerState.READINESS_TOUR):
		s.mark_beaten(0, t0)
	var t := CareerResolver.advance_after_live_season(
		s, p, _season_stub(true, false), 0, CareerState.READINESS_TOUR, rng)
	assert_eq(s.current_level(), 1, "auto-crossed up to City")
	assert_true(t["promoted"])
	assert_eq(t["to_level"], 1)
	assert_eq(s.seasons_at_level, 0, "cross resets seasons_at_level")
	assert_eq(p.affinity, 0, "cross resets affinity")

func test_advance_completes_on_province_premier_win():
	var s := CareerResolver.start_career(0)
	var p := _make_player()
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	s.current_team_index = CareerState.TEAMS_PER_LEVEL * 2   # Province
	s.cell_status[s.cell_index(2, CareerState.PREMIER_TOUR)] = CareerState.CellStatus.UNLOCKED
	var t := CareerResolver.advance_after_live_season(
		s, p, _season_stub(true, true), 2, CareerState.PREMIER_TOUR, rng)
	assert_true(s.complete)
	assert_true(t["complete"])
```

(If `_make_player()` does not already exist in `test_career_resolver.gd`, add a tiny helper that returns a `Player` with `attributes`, `affinity = 0` — copy the pattern from an existing career-resolver test in that file.)

- [ ] **Step 2: Run suite, verify the new asserts fail** (`advance_after_live_season` not declared).

- [ ] **Step 3: Implement** (add to `career_resolver.gd`, after `next_live_cell`)

```gdscript
# End-of-Season grid transition for the LIVE loop (spec 2026-06-24, DLC4). Mirrors
# play_season's tail: record the outcome, bump the Season counters, and auto-cross
# up at a Level boundary (rush model — no Offers UI; accept the cross-up offer the
# headless resolver would generate). Returns a descriptor the Outcome screen reads.
# Pure: mutates only `state` + `player`, runs no sim.
static func advance_after_live_season(
		state: CareerState, player: Player, result: SeasonResult,
		level: int, tour: int, rng: RandomNumberGenerator) -> Dictionary:
	var from_level := level
	state.record_outcome(level, tour, result.beat, result.won_final)
	state.seasons_played += 1
	state.seasons_at_level += 1
	var promoted := false
	if not state.complete:
		var cur := state.current_level()
		var up := cur + 1
		if state.next_climb_tour(cur) == -1 and up < CareerState.LEVELS \
				and state.any_unlocked_at(up):
			for o in generate_offers(state, result.beat, rng):
				if o.level == up:
					accept_offer(state, player, o)
					promoted = true
					break
	var nxt := next_live_cell(state)
	return {
		"beat": result.beat,
		"promoted": promoted,
		"from_level": from_level,
		"tour": tour,
		"to_level": state.current_level(),
		"complete": state.complete,
		"next_level": nxt["level"],
		"next_tour": nxt["tour"],
	}
```

- [ ] **Step 4: Run suite, verify green.**

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/career_resolver.gd tests/unit/test_career_resolver.gd
git commit -m "feat: CareerResolver.advance_after_live_season (record+auto-cross the live climb)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `season_hub` boots the real cell + persists the career

**Files:**
- Modify: `scenes/season_hub/season_hub.gd`
- Test: `tests/unit/test_season_hub.gd` (the boot/resume tests)

- [ ] **Step 1: Write the failing test** (append; mirror the existing boot test's save fixtures — it already sets up a Player save)

```gdscript
func test_boot_persists_a_fresh_career():
	# Arrange: a Player save but NO career save (fresh).
	SaveManager.clear_career()
	SaveManager.clear_live_season()
	SaveManager.save_player(_make_saved_player())   # existing helper in this file
	var hub = _make_hub()                            # existing helper that instances the scene
	hub.boot()
	assert_true(SaveManager.has_career(), "fresh career is persisted on boot")
	# Cleanup
	SaveManager.clear_career(); SaveManager.clear_player(); SaveManager.clear_live_season()

func test_current_cell_is_fresh_zero():
	SaveManager.clear_career(); SaveManager.clear_live_season()
	SaveManager.save_player(_make_saved_player())
	var hub = _make_hub()
	hub.boot()
	assert_eq(hub.current_cell(), Vector2i(0, 0))
	SaveManager.clear_career(); SaveManager.clear_player(); SaveManager.clear_live_season()
```

(If helpers `_make_hub()`/`_make_saved_player()` are named differently in the file, reuse the existing ones — read the top of `test_season_hub.gd` first.)

- [ ] **Step 2: Run suite, verify fail** (`current_cell` not declared / career not persisted).

- [ ] **Step 3: Implement** — replace `boot()` and `set_play()` and add `current_cell()`.

Replace `boot()` body (currently `season_hub.gd:132-151`) with:

```gdscript
func boot() -> void:
	if _view != null or _play != null:
		return
	if not SaveManager.has_player():
		return
	var player := SaveManager.load_player()
	var fresh := not SaveManager.has_career()
	var career: CareerState = SaveManager.load_career() if not fresh \
		else CareerResolver.start_career(0)
	if fresh:
		SaveManager.save_career(career)   # the live career is now durable
	# Cross-session resume (spec 2026-06-23): replay the saved decisions instead of
	# starting fresh. The saved season is already at next_live_cell(career).
	if SaveManager.has_live_season():
		var play := SeasonPlay.from_state(SaveManager.load_live_season(), player, career)
		set_play(player, career, play)
		return
	# Fresh season at the career's next cell, seed varying per Season so re-attempts
	# and later cells differ (spec DLC6). seasons_played==0 keeps the first-game seed.
	var cell := CareerResolver.next_live_cell(career)
	var spec := DifficultyLadder.spec_for(cell["level"], cell["tour"])
	var team: Team = career.teams[career.current_team_index]
	var play := SeasonPlay.start(
		player.attributes, team, career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(),
		BOOT_SEED + career.seasons_played, spec)
	set_play(player, career, play)
```

Add two members near the other vars (top of file, by `_play`):

```gdscript
var _cell_level: int = 0
var _cell_tour: int = 0
```

Replace `set_play()` body (`season_hub.gd:159-166`) with:

```gdscript
func set_play(player: Player, career: CareerState, play: SeasonPlay) -> void:
	_player = player; _career = career; _play = play
	# The career cell this Season is being played at — stable during a Season (the
	# grid only advances at Season end), so deriving it here matches what boot used.
	var cell := CareerResolver.next_live_cell(career)
	_cell_level = cell["level"]; _cell_tour = cell["tour"]
	var team: Team = career.teams[career.current_team_index]
	play.enable_pay(player, EconomyTuning.new(), team.stars, _cell_level, _cell_tour)
	set_view(SeasonViewBuilder.build(player, career, play.live_season(), play.played_count()))
```

Add the accessor (near `live_play()`):

```gdscript
func current_cell() -> Vector2i:
	return Vector2i(_cell_level, _cell_tour)
```

- [ ] **Step 4: Import + run suite, verify green** (no script added, but run `--import` if Godot complains; otherwise just the suite). The existing resume integration test MUST stay green.

- [ ] **Step 5: Commit**

```bash
git add scenes/season_hub/season_hub.gd tests/unit/test_season_hub.gd
git commit -m "feat: season hub boots the real career cell + persists a fresh career

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: `main` records the advance on season-end + routes Continue

**Files:**
- Modify: `scenes/main.gd`

No new unit test — this is scene orchestration glue exercised by the manual sanity run + the (already-green) headless logic tests. Keep changes minimal.

- [ ] **Step 1: Implement** — replace `_commit_and_return` (`main.gd:89-104`) with:

```gdscript
func _commit_and_return(play: SeasonPlay, session: MatchSession, career: CareerState) -> void:
	play.commit_player_result(session.result(), session.export_decisions())
	var player: Player = play.pay_player()
	if player == null:
		player = SaveManager.load_player()
	if player != null:
		SaveManager.save_player(player)
	# The career cell this Season was played at (the grid hasn't advanced yet).
	var cell := CareerResolver.next_live_cell(career)
	if play.season_done():
		# Record the outcome into the career grid (rush-climb advance), persist it,
		# clear the finished live season, and show the Outcome screen.
		var rng := RandomNumberGenerator.new()
		rng.seed = play.seed() + 7   # distinct from strength/AI/playoff seeds
		var transition := CareerResolver.advance_after_live_season(
			career, player, play.season_result(), cell["level"], cell["tour"], rng)
		SaveManager.save_career(career)
		SaveManager.clear_live_season()
		if player != null:
			SaveManager.save_player(player)   # affinity reset on a cross-up
		_show_outcome(play, career, transition)
	else:
		SaveManager.save_live_season(play.to_state(cell["level"], cell["tour"]))
		_show_live_hub(play, career)
```

Replace `_show_outcome` (`main.gd:108-112`) with:

```gdscript
# The end-of-season Outcome (finish + ₸ banked + the career transition). Continue
# starts the next Season at the new cell, or — when the Career is complete (won the
# Province Premier) — routes through the Hall of Fame.
func _show_outcome(play: SeasonPlay, career: CareerState, transition: Dictionary) -> void:
	var screen := OUTCOME.instantiate()
	if transition.get("complete", false):
		screen.continue_pressed.connect(func(): LifecycleManager.win_out())
	else:
		screen.continue_pressed.connect(_push_hub)
	_push(screen)
	screen.set_outcome(play.season_result(), play.pay_so_far(), play.season_wins(),
		career, transition)
```

- [ ] **Step 2: Import + run suite, verify still green** (no logic test here; confirm nothing regressed).

- [ ] **Step 3: Commit**

```bash
git add scenes/main.gd
git commit -m "feat: main records the live season into the career + routes Continue/win-out

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Outcome screen — transition banner, next-up chip, re-skin (no emoji)

**Files:**
- Modify: `scenes/outcome/outcome.gd`
- Test: `tests/unit/test_outcome_scene.gd` (create if absent)

- [ ] **Step 1: Write the failing scene test**

```gdscript
extends GutTest

const OUTCOME := preload("res://scenes/outcome/outcome.tscn")

func _result(pos: int) -> SeasonResult:
	var sr := SeasonResult.new()
	sr.player_final_position = pos
	sr.beat = pos <= 3
	sr.won_final = pos == 1
	return sr

func _show(result: SeasonResult, transition: Dictionary) -> Control:
	var s := OUTCOME.instantiate()
	add_child_autofree(s)
	s.set_outcome(result, 60, 4, null, transition)
	return s

func test_promoted_banner_visible_and_named():
	var s := _show(_result(1), {"promoted": true, "to_level": 1, "complete": false,
		"next_level": 1, "next_tour": 0, "beat": true, "from_level": 0, "tour": 5})
	var banner: Label = s.get_node("%Banner")
	assert_true(banner.is_visible_in_tree())
	assert_gt(banner.size.y, 0.0)
	assert_string_contains(banner.text, "CITY")

func test_complete_routes_to_hall_of_fame_chip():
	var s := _show(_result(1), {"promoted": false, "to_level": 2, "complete": true,
		"next_level": 2, "next_tour": 7, "beat": true, "from_level": 2, "tour": 7})
	var nextup: Label = s.get_node("%NextUp")
	assert_string_contains(nextup.text, "HALL OF FAME")

func test_no_emoji_in_banner():
	# Barlow tofus emoji — the banner must stay text-only.
	var s := _show(_result(1), {"promoted": false, "to_level": 2, "complete": true,
		"next_level": 2, "next_tour": 7, "beat": true, "from_level": 2, "tour": 7})
	var banner: Label = s.get_node("%Banner")
	for ch in "🏆🏏↑▶":
		assert_false(banner.text.contains(ch), "no emoji glyphs (Barlow tofu)")
```

(Use unique-name access `%Banner`/`%NextUp` — set `unique_name_in_owner`/`name` on those nodes in code so the test can find them. `assert_string_contains`/`assert_gt` are GUT built-ins.)

- [ ] **Step 2: Run suite, verify fail** (new nodes/params absent).

- [ ] **Step 3: Implement** — update `outcome.gd`. Change the signature and insert the banner + next-up; drop emoji from `_headline`.

Signature + new pieces (insert the banner between Headline and StatsPanel, next-up after the panel; full method shown for the new bits):

```gdscript
func set_outcome(result: SeasonResult, pay: int, wins: int,
		_career: CareerState = null, transition: Dictionary = {}) -> void:
	var pos := result.player_final_position
	var made_playoffs := pos <= 4
	var games := 7 + (2 if made_playoffs else 0)
	# ... (existing bg / center / col / kicker / head construction unchanged) ...

	# Transition banner — the new central line (cleared / promoted / champion / retry).
	var b := _banner_for(transition)
	var banner := Label.new()
	banner.name = "Banner"
	banner.unique_name_in_owner = true
	banner.text = b["text"]
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_color", b["color"])
	banner.add_theme_font_size_override("font_size", 15)
	Fonts.weigh(banner, Fonts.W_BOLD)
	col.add_child(banner)

	# ... (existing StatsPanel rows unchanged) ...

	# Next-up chip — where Continue takes you.
	var nextup := Label.new()
	nextup.name = "NextUp"
	nextup.unique_name_in_owner = true
	nextup.text = _next_up_text(transition)
	nextup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nextup.add_theme_color_override("font_color", Palette.WHITE_DIM)
	nextup.add_theme_font_size_override("font_size", 11)
	Fonts.weigh(nextup, Fonts.W_MEDIUM)
	col.add_child(nextup)

	# ... (existing Continue CTA, but text from _cta_text(transition)) ...
```

Add helpers + de-emoji `_headline`:

```gdscript
func _banner_for(t: Dictionary) -> Dictionary:
	if t.get("complete", false):
		return {"text": "PROVINCE CHAMPIONS · CAREER COMPLETE", "color": Palette.GOLD}
	if t.get("promoted", false):
		return {"text": "PROMOTED TO %s" % _level_word(t.get("to_level", 0)).to_upper(),
			"color": Palette.GOLD}
	if t.get("beat", false):
		return {"text": "%s · TOUR %d CLEARED" %
			[_level_word(t.get("from_level", 0)).to_upper(), int(t.get("tour", 0)) + 1],
			"color": Palette.WHITE}
	return {"text": "MISSED OUT · ANOTHER GO", "color": Palette.WHITE_DIM}

func _next_up_text(t: Dictionary) -> String:
	if t.get("complete", false):
		return "NEXT: HALL OF FAME"
	return "NEXT: %s · TOUR %d" % [
		_level_word(t.get("next_level", 0)).to_upper(), int(t.get("next_tour", 0)) + 1]

func _cta_text(t: Dictionary) -> String:
	return "ENTER THE HALL OF FAME  >" if t.get("complete", false) else "CONTINUE  >"

func _level_word(level: int) -> String:
	return ["Club", "City", "Province"][clampi(level, 0, 2)]
```

In `_headline`, replace the emoji line:

```gdscript
	match pos:
		1: return "CHAMPIONS"
		2: return "RUNNERS-UP"
		3: return "3RD PLACE"
		4: return "SEMI-FINAL EXIT"
		_: return "MISSED THE PLAYOFFS"
```

And set the CTA text via `cta.text = _cta_text(transition)` (replacing the literal `"CONTINUE  ▶"`).

- [ ] **Step 4: Import + run suite, verify green.**

- [ ] **Step 5: Commit**

```bash
git add scenes/outcome/outcome.gd tests/unit/test_outcome_scene.gd
git commit -m "feat: Outcome screen transition banner + next-up + de-emoji (Barlow)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Render the Outcome states for Nico + roadmap

**Files:**
- Create: `tools/preview_outcome.gd`
- Modify: `PROJECT_ROADMAP.md`

- [ ] **Step 1: Write the preview tool** (copy the window/render pattern from an existing `tools/preview_*.gd`; read one first). It should instance the Outcome scene with four transitions — cleared / promoted / champion / missed — and `get_viewport().get_texture().get_image().save_png(...)` each to `docs/mockups/`. Use a 390×844 window (the project's phone frame).

```gdscript
extends SceneTree
# Headless-ish render of the Outcome screen states for eyeballing. Run:
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_outcome.gd
const OUTCOME := preload("res://scenes/outcome/outcome.tscn")

func _init() -> void:
	# (mirror the exact pattern of tools/preview_live_season_finish.gd — window size,
	#  await frames, save_png — that tool already renders the low-fi outcome.)
	pass
```

(Read `tools/preview_live_season_finish.gd` and follow it exactly — it already renders the Outcome screen; just feed the four transition dictionaries and save four PNGs `docs/mockups/outcome-{cleared,promoted,champion,missed}-v1.png`.)

- [ ] **Step 2: Import + run the preview**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . \
  && /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_outcome.gd
```

Expected: four PNGs written under `docs/mockups/`.

- [ ] **Step 3: Eyeball** the PNGs (Read each). Confirm: banner reads correctly per state, no tofu boxes (emoji), gold on promotion/champion, layout not clipped.

- [ ] **Step 4: Commit the renders + tool**

```bash
git add tools/preview_outcome.gd tools/preview_outcome.gd.uid docs/mockups/outcome-*-v1.png
git commit -m "test: Outcome screen state renders (cleared/promoted/champion/missed)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 5: Full suite + final verification**, then update the roadmap's history + Next-session block (done at PR time, not here).

---

## Self-review notes

- **Spec coverage:** DLC1–DLC10 all land — climb model (Tasks 2/3), beat=top3 (Task 3 uses `result.beat`), cell rule (Tasks 1/2), auto-cross (Task 3), Premier optional/required (Task 2 returns Premier only at top Level + Task 3 completes on won_final), career persisted + varying seed (Task 4), complete→HoF (Task 5), Outcome re-skin no-brief (Task 6), pure statics (Tasks 2/3), not-beaten replays (Task 3 `test_advance_not_beaten_is_grid_noop_same_cell`).
- **Determinism:** the boot seed only varies *between* Seasons via `seasons_played`; within a Season the saved seed drives resume (unchanged) — the existing resume test guards it (Task 4 Step 4).
- **Emoji:** Task 6 actively removes emoji (Barlow tofu) and tests for their absence.
- **Type consistency:** `advance_after_live_season` returns the dict keys the Outcome screen reads (`complete`/`promoted`/`to_level`/`from_level`/`tour`/`next_level`/`next_tour`/`beat`); `current_cell()` returns `Vector2i` consumed by `to_state(int,int)` via `.x/.y` — note `main` uses the `next_live_cell` dict (`cell["level"]/cell["tour"]`), not the hub's `Vector2i`, since the hub is freed by then. Consistent within each file.
