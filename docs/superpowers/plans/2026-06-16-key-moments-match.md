# Key Moments in the Match — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the playable match pause at 2–3 dramatic points (Powerplay Exit, Wicket Crisis, Death Plan) and ask the captain a two-button decision that visibly changes the rest of the match.

**Architecture:** A Key Moment is another decision baked into `MatchSession`'s deterministic re-sim — exactly like Boost/DRS (spec D1). The choice is a per-over batting-Intent override carried by a new pure `KeyMomentPlan` (`scripts/data/`). `IntentPlan` gains one optional hook (`key_moments`) so the override rides the *existing* `player_intent_plan` seam into the sim with **zero new resolver parameters** (spec §3, "extend IntentPlan" route). Overrides only ever apply from a future over, so the watched prefix stays byte-identical. The interactive-match scene reuses the DRS overlay pause/resume pattern with a second overlay (two tap buttons).

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Run the whole suite each step:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Red = `KeyMomentPlan`/`key_moments` parse error; green = total count climbs + `All tests passed`.

---

## File Structure

- **Create** `scripts/data/key_moment_plan.gd` — the pure policy: an array of `(from_over, band)` overrides + `effective_for_over`.
- **Modify** `scripts/data/intent_plan.gd` — add `var key_moments: KeyMomentPlan = null`; `for_over` consults it (byte-identical when null).
- **Modify** `scripts/domain/match_session.gd` — `_km_plan`, `key_moment_offer(cursor)`, `decide_key_moment(from_over, band)`, recompute moments + pass the km-bearing `IntentPlan` in `_resim`.
- **Modify** `scenes/interactive_match/interactive_match.{gd,tscn}` — a second overlay (KM card, title + two buttons) + a trigger-pause flow mirroring DRS.
- **Create** `tests/unit/test_key_moment_plan.gd` — pure `effective_for_over` cases.
- **Modify** `tests/unit/test_match_session.gd` — offer/decide/prefix/determinism cases.
- **Modify** `tests/unit/test_interactive_match_scene.gd` — KM overlay appears + a press changes the event stream.

### Locked design decisions (from spec §2-§4 + recorded defaults)

- **A Key Moment pauses at an OVER BOUNDARY** — the cursor where the next event to show is the first event of over `N` in the player's batting innings. The override applies from over `N` onward. Over `N`'s balls haven't been shown yet ⇒ the watched prefix is byte-identical (D1). This is the clean reconciliation of spec §3/§4 ("from that over") with the hard byte-identical contract.
- ⚡ **Powerplay Exit** — `from_over = 7` (always). Choices: `Anchor → DEFENSIVE` · `Hunt → AGGRESSIVE` (sets the middle phase).
- 🩸 **Wicket Crisis** — let `W` = the over of the **first wicket** (any batter, team wicket) of the player's batting innings with `7 ≤ W ≤ 14`. Then `from_over = W + 1` (you respond from the over *after* the wicket; capped at 14 so the override over ≤ 15 stays in the middle and never collides with Death Plan at 16). Choices: `Settle → DEFENSIVE` · `Counter-attack → AGGRESSIVE`. If no qualifying wicket, the moment doesn't fire.
- 💀 **Death Plan** — `from_over = 16` (always). Choices: `Milk it → BALANCED` · `Go big → AGGRESSIVE` (sets the death phase).
- "Always" moments simply don't fire if the player is all out before that over (no matching cursor) — handled naturally.
- Triggers are recomputed after every re-sim (D7): a PP-Exit call can move the later Wicket-Crisis over; that's correct.

---

## Task 1: `KeyMomentPlan` pure policy

**Files:**
- Create: `scripts/data/key_moment_plan.gd`
- Test: `tests/unit/test_key_moment_plan.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# KeyMomentPlan — the per-over batting-Intent override policy (spec §3, D3).

func test_empty_returns_base_band():
	var p := KeyMomentPlan.new()
	assert_eq(p.effective_for_over(7, BallResolver.Intent.BALANCED), BallResolver.Intent.BALANCED)

func test_override_applies_from_its_over_onward():
	var p := KeyMomentPlan.new()
	p.overrides.append({"from_over": 7, "band": BallResolver.Intent.AGGRESSIVE})
	assert_eq(p.effective_for_over(6, BallResolver.Intent.BALANCED), BallResolver.Intent.BALANCED, "before the override = base")
	assert_eq(p.effective_for_over(7, BallResolver.Intent.BALANCED), BallResolver.Intent.AGGRESSIVE, "from the override over")
	assert_eq(p.effective_for_over(12, BallResolver.Intent.BALANCED), BallResolver.Intent.AGGRESSIVE, "still applies later")

func test_latest_wins_on_overlap():
	var p := KeyMomentPlan.new()
	p.overrides.append({"from_over": 7, "band": BallResolver.Intent.AGGRESSIVE})
	p.overrides.append({"from_over": 12, "band": BallResolver.Intent.DEFENSIVE})
	assert_eq(p.effective_for_over(11, BallResolver.Intent.BALANCED), BallResolver.Intent.AGGRESSIVE, "over 11 = the over-7 override")
	assert_eq(p.effective_for_over(14, BallResolver.Intent.BALANCED), BallResolver.Intent.DEFENSIVE, "over 14 = the latest (over-12) override")
```

- [ ] **Step 2: Run the suite — expect a parse error (`KeyMomentPlan ... not declared`).**

- [ ] **Step 3: Create the implementation**

```gdscript
class_name KeyMomentPlan
extends RefCounted

# A Key Moment decision = a per-over batting-Intent override (spec D3). The captain's
# call appends an {from_over, band} entry; the effective Intent for any over is the
# latest override at-or-before it (highest from_over <= over), falling back to the
# base band. Pure + deterministic — fed into IntentPlan, which is fed into the sim.
# Empty overrides => returns the base band unchanged (byte-identical).

var overrides: Array = []  # of {from_over:int, band:int} ; band = BallResolver.Intent

func effective_for_over(over: int, base_band: int) -> int:
	var best_from := -1
	var result := base_band
	for o in overrides:
		var f: int = o["from_over"]
		if f <= over and f > best_from:
			best_from = f
			result = o["band"]
	return result
```

- [ ] **Step 4: Run the suite — expect green, count +3.**

- [ ] **Step 5: Commit** `git add scripts/data/key_moment_plan.gd* tests/unit/test_key_moment_plan.gd && git commit`

---

## Task 2: `IntentPlan.key_moments` hook

**Files:**
- Modify: `scripts/data/intent_plan.gd`
- Test: `tests/unit/test_intent_plan.gd`

- [ ] **Step 1: Write the failing test (append to the existing file)**

```gdscript
func test_key_moments_override_for_over():
	var km := KeyMomentPlan.new()
	km.overrides.append({"from_over": 7, "band": BallResolver.Intent.AGGRESSIVE})
	var plan := IntentPlan.new()  # all phases BALANCED
	plan.key_moments = km
	assert_eq(plan.for_over(6), BallResolver.Intent.BALANCED, "powerplay unaffected")
	assert_eq(plan.for_over(7), BallResolver.Intent.AGGRESSIVE, "override drives the middle")

func test_null_key_moments_is_phase_band():
	var plan := IntentPlan.new()
	plan.middle = BallResolver.Intent.DEFENSIVE
	assert_eq(plan.for_over(10), BallResolver.Intent.DEFENSIVE, "no km => plain phase band")
```

- [ ] **Step 2: Run the suite — expect the two new asserts to fail (`key_moments` not a property).**

- [ ] **Step 3: Edit `intent_plan.gd`.** Add the field after the state-rule fields:

```gdscript
# Key Moment overrides (spec 2026-06-16): per-over Intent overrides from in-match
# decisions. null => plain phase bands (byte-identical to every pre-KM caller).
var key_moments: KeyMomentPlan = null
```

Replace `for_over` with a base-band helper + km consultation:

```gdscript
# 1-based over number -> Intent band for that over (Key Moment overrides win).
func for_over(over: int) -> int:
	var base := _phase_band(over)
	if key_moments != null:
		return key_moments.effective_for_over(over, base)
	return base

func _phase_band(over: int) -> int:
	match IntentPlan.phase_of(over):
		0:
			return powerplay
		1:
			return middle
		_:
			return death
```

- [ ] **Step 4: Run the suite — expect green, count +2, and NO existing test regressed** (`for_state` still calls `for_over`, which is byte-identical when `key_moments == null`).

- [ ] **Step 5: Commit** `git add scripts/data/intent_plan.gd* tests/unit/test_intent_plan.gd && git commit`

---

## Task 3: `MatchSession` — offer, decide, resim threading

**Files:**
- Modify: `scripts/domain/match_session.gd`
- Test: `tests/unit/test_match_session.gd`

- [ ] **Step 1: Write the failing tests (append to the existing file)**

```gdscript
# -- Key Moments (spec 2026-06-16) ------------------------------------------

func _km_cursor(s: MatchSession, kind_contains: String) -> int:
	# walk the event stream, return the cursor where this KM offer fires
	for c in range(s.events().size()):
		var o := s.key_moment_offer(c)
		if not o.is_empty() and (kind_contains in o["title"]):
			return c
	return -1

func test_powerplay_exit_offer_fires():
	var s := _session()
	var c := _km_cursor(s, "Powerplay")
	assert_gt(c, -1, "a Powerplay Exit moment is offered")
	var o := s.key_moment_offer(c)
	assert_eq(o["from_over"], 7, "PP Exit overrides from over 7")
	assert_eq(o["choices"].size(), 2, "two choices")

func test_death_plan_offer_fires():
	var s := _session()
	var c := _km_cursor(s, "Death")
	assert_gt(c, -1, "a Death Plan moment is offered")
	assert_eq(s.key_moment_offer(c)["from_over"], 16, "Death Plan overrides from over 16")

func test_decide_key_moment_prefix_byte_identical():
	var s := _session()
	var c := _km_cursor(s, "Powerplay")
	var o := s.key_moment_offer(c)
	var before := s.result().ball_log_innings1.duplicate(true)
	s.decide_key_moment(o["from_over"], BallResolver.Intent.AGGRESSIVE)
	var after := s.result().ball_log_innings1
	for i in range(before.size()):
		if before[i]["over"] < o["from_over"]:
			assert_eq(after[i], before[i], "prefix ball %d unchanged" % i)
		else:
			break

func test_decide_key_moment_changes_the_future():
	var s := _session()
	var c := _km_cursor(s, "Powerplay")
	var base_total := s.result().innings1.total
	s.decide_key_moment(7, BallResolver.Intent.AGGRESSIVE)
	assert_ne(s.result().innings1.total, base_total, "an Aggressive middle changed the batting total")

func test_offer_clears_after_decision():
	var s := _session()
	var c := _km_cursor(s, "Powerplay")
	s.decide_key_moment(7, BallResolver.Intent.DEFENSIVE)
	assert_true(s.key_moment_offer(c).is_empty(), "a decided moment no longer offers")

func test_empty_km_is_byte_identical_to_no_plan():
	# a fresh session (no decisions) must match a same-seed baseline ball-log
	var s := _session()
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var rng := RandomNumberGenerator.new(); rng.seed = 20260615
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[0]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	var l1: Array = []; var l2: Array = []
	MatchResolver.simulate_match_teams(a, team, opp, tour, BallTuning.new(), InningsTuning.new(),
		rng, null, null, [], null, null, null, BoostPlan.new(), DRSPolicy.new(),
		null, null, null, 1, null, l1, l2)
	assert_eq(s.result().ball_log_innings1, l1, "no-decision KM session == plain baseline (byte-identical)")
```

- [ ] **Step 2: Run the suite — expect parse errors / failures (`key_moment_offer` etc. not declared).**

- [ ] **Step 3: Edit `match_session.gd`.** Add a member near the other policy members:

```gdscript
var _km_plan := KeyMomentPlan.new()   # accumulated Key Moment overrides (spec 2026-06-16)
var _km_moments: Array = []           # computed {kind, title, prompt, from_over, cursor, choices}
```

In `_resim`, pass a km-bearing `IntentPlan` as `player_intent_plan` (replace the first `null` after `rng`) and recompute the moments at the end:

```gdscript
	var ip := IntentPlan.new()         # all-BALANCED base; carries the KM overrides
	ip.key_moments = _km_plan
	...
	_result = MatchResolver.simulate_match_teams(
		_attrs, _team, _opp, _tour, _tuning, _itun, rng,
		ip, null, [], null, null, null,
		boost, drs, null, null, null, _force, null, log1, log2)
	_result.ball_log_innings1 = log1
	_result.ball_log_innings2 = log2
	_events = MatchViewBuilder.build_events(_result, _player)
	_compute_km_moments()
```

Add the Key Moment block at the end of the file:

```gdscript
# -- Key Moments (spec 2026-06-16) ------------------------------------------

# The player's batting-innings raw ball-log (triggers read the ball-log, not the
# player-centric event stream — a teammate's wicket lives in an over summary; D7).
func _player_batting_log() -> Array:
	return _result.ball_log_innings1 if _result.player_bats_first else _result.ball_log_innings2

# Over of the first team wicket falling in overs 7..14, else -1 (Wicket Crisis source).
func _first_middle_wicket_over() -> int:
	for b in _player_batting_log():
		if b["wicket"] and b["over"] >= 7 and b["over"] <= 14:
			return b["over"]
	return -1

# Cursor (event index) of the first event of `over` in the player's batting innings,
# or -1 if the innings never reaches it (all out earlier). The pause fires BEFORE
# this event shows, so overs < `over` are byte-identical.
func _cursor_for_over(player_innings: int, over: int) -> int:
	for i in range(_events.size()):
		var e: Dictionary = _events[i]
		if e.get("innings", -1) == player_innings and e.has("over") and e["over"] == over:
			return i
	return -1

func _add_moment(player_innings: int, title: String, prompt: String, from_over: int, choices: Array) -> void:
	var c := _cursor_for_over(player_innings, from_over)
	if c == -1:
		return  # the innings never reached this over (e.g. all out) — moment doesn't fire
	_km_moments.append({"title": title, "prompt": prompt, "from_over": from_over,
		"cursor": c, "choices": choices})

func _compute_km_moments() -> void:
	_km_moments = []
	var pbi := 1 if _result.player_bats_first else 2
	_add_moment(pbi, "⚡ Powerplay Exit", "How do you play the middle overs?", 7,
		[{"label": "Anchor", "band": BallResolver.Intent.DEFENSIVE},
		 {"label": "Hunt", "band": BallResolver.Intent.AGGRESSIVE}])
	var wo := _first_middle_wicket_over()
	if wo != -1:
		_add_moment(pbi, "🩸 Wicket Crisis", "A wicket's down — how do you respond?", wo + 1,
			[{"label": "Settle", "band": BallResolver.Intent.DEFENSIVE},
			 {"label": "Counter-attack", "band": BallResolver.Intent.AGGRESSIVE}])
	_add_moment(pbi, "💀 Death Plan", "Last five overs — what's the play?", 16,
		[{"label": "Milk it", "band": BallResolver.Intent.BALANCED},
		 {"label": "Go big", "band": BallResolver.Intent.AGGRESSIVE}])

func _km_decided(from_over: int) -> bool:
	for o in _km_plan.overrides:
		if o["from_over"] == from_over:
			return true
	return false

# Given the playback cursor (index of the event about to be shown), return the Key
# Moment to pause on — {title, prompt, from_over, choices:[{label,band}]} — or {}.
func key_moment_offer(cursor: int) -> Dictionary:
	for m in _km_moments:
		if m["cursor"] == cursor and not _km_decided(m["from_over"]):
			return {"title": m["title"], "prompt": m["prompt"],
				"from_over": m["from_over"], "choices": m["choices"]}
	return {}

# Commit a Key Moment: override batting Intent to `band` from `from_over` onward, re-sim.
func decide_key_moment(from_over: int, band: int) -> void:
	if _km_decided(from_over):
		return
	_km_plan.overrides.append({"from_over": from_over, "band": band})
	_resim()
```

- [ ] **Step 4: Run the suite — expect green, count +7, and the existing Boost/DRS prefix tests still green** (the empty-km determinism test guards the `null → ip` swap).

- [ ] **Step 5: Commit** `git add scripts/domain/match_session.gd* tests/unit/test_match_session.gd && git commit`

---

## Task 4: interactive_match scene — the KM card overlay + trigger pause

**Files:**
- Modify: `scenes/interactive_match/interactive_match.tscn`
- Modify: `scenes/interactive_match/interactive_match.gd`
- Test: `tests/unit/test_interactive_match_scene.gd`

- [ ] **Step 1: Write the failing scene tests (append to the existing file)**

```gdscript
func _km_cursor(s: MatchSession, kind: String) -> int:
	for c in range(s.events().size()):
		var o := s.key_moment_offer(c)
		if not o.is_empty() and (kind in o["title"]):
			return c
	return -1

func test_km_overlay_appears_at_a_trigger():
	var s := _make_session()
	var c := _km_cursor(s, "Powerplay")
	assert_gt(c, -1, "a Powerplay Exit moment exists")
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(c)
	assert_true(_scene.km_overlay_visible(), "KM card shown at the trigger")

func test_km_choice_changes_event_stream():
	var s := _make_session()
	var c := _km_cursor(s, "Powerplay")
	var before := s.result().innings1.total
	_scene.set_session(s, "Karoo Kings", "Opponent")
	_scene.boot()
	_scene.seek_to(c)
	_scene.km_press(1)   # the second option (Hunt = AGGRESSIVE)
	assert_false(_scene.km_overlay_visible(), "overlay hides after a choice")
	assert_ne(s.result().innings1.total, before, "the choice re-simulated the match")
```

- [ ] **Step 2: Run the suite — expect failures (`km_overlay_visible` / `km_press` not declared).**

- [ ] **Step 3a: Edit `interactive_match.tscn`** — add a second overlay after the DRS `Overlay` node block (top-level child of the scene root, sibling of `Overlay`):

```
[node name="KMOverlay" type="Panel" parent="."]
visible = false
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -150.0
offset_top = -90.0
offset_right = 150.0
offset_bottom = 90.0

[node name="KMBox" type="VBoxContainer" parent="KMOverlay"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 12.0
offset_top = 12.0
offset_right = -12.0
offset_bottom = -12.0

[node name="KMTitle" type="Label" parent="KMOverlay/KMBox"]
layout_mode = 2
autowrap_mode = 3
text = "Key Moment"

[node name="KMPrompt" type="Label" parent="KMOverlay/KMBox"]
layout_mode = 2
autowrap_mode = 3
text = ""

[node name="KMOptA" type="Button" parent="KMOverlay/KMBox"]
layout_mode = 2
text = "Option A"

[node name="KMOptB" type="Button" parent="KMOverlay/KMBox"]
layout_mode = 2
text = "Option B"
```

- [ ] **Step 3b: Edit `interactive_match.gd`.** Add state near the other overlay state:

```gdscript
var _pending_km := {}              # the KM offer currently shown
var _resume_after_km := false      # was autoplay running when the KM card popped?
```

In `_ready`, wire the two KM buttons + hide the overlay:

```gdscript
	$KMOverlay/KMBox/KMOptA.pressed.connect(func(): km_press(0))
	$KMOverlay/KMBox/KMOptB.pressed.connect(func(): km_press(1))
	$KMOverlay.visible = false
```

In `step(delta)`, check the KM offer first, then the review offer (a strategic over-boundary call precedes a ball-level review). Replace the offer block:

```gdscript
	if delta > 0:
		var km := _session.key_moment_offer(_cursor)
		if not km.is_empty():
			_pending_km = km
			_resume_after_km = _playing
			_show_km_overlay(km)
			pause()
			return
		var offer := _session.review_offer(_cursor)
		if not offer.is_empty():
			_pending_review = offer
			_resume_after_review = _playing
			_show_overlay(offer)
			pause()
			return
	if _cursor >= _event_count:
		pause()
```

In `seek_to`, also surface a KM offer (used by tests + manual scrubbing):

```gdscript
	var km := _session.key_moment_offer(_cursor)
	if not km.is_empty():
		_pending_km = km
		_show_km_overlay(km)
		return
	var offer := _session.review_offer(_cursor)
	if not offer.is_empty():
		_pending_review = offer
		_show_overlay(offer)
```

Add the KM overlay helpers (near `_show_overlay`):

```gdscript
func km_overlay_visible() -> bool:
	return $KMOverlay.visible

func _show_km_overlay(km: Dictionary) -> void:
	$KMOverlay/KMBox/KMTitle.text = km["title"]
	$KMOverlay/KMBox/KMPrompt.text = km["prompt"]
	$KMOverlay/KMBox/KMOptA.text = km["choices"][0]["label"]
	$KMOverlay/KMBox/KMOptB.text = km["choices"][1]["label"]
	$KMOverlay.visible = true

# Player picked option index i (0/1) on the current KM card.
func km_press(i: int) -> void:
	$KMOverlay.visible = false
	if not _pending_km.is_empty():
		var band: int = _pending_km["choices"][i]["band"]
		_session.decide_key_moment(_pending_km["from_over"], band)
		_event_count = _session.events().size()
	_pending_km = {}
	_render()
	if _resume_after_km and _cursor < _event_count:
		_resume_after_km = false
		play()
```

- [ ] **Step 4: Run the suite — expect green, count +2.** (`--import` first — a new scene node was added.)

- [ ] **Step 5: Commit** `git add scenes/interactive_match/* tests/unit/test_interactive_match_scene.gd && git commit`

---

## Task 5: Eyeball + launch the playable game (spec §7 — LAUNCH, don't screenshot)

**Files:** none (verification + deliverable)

- [ ] **Step 1: Confirm the full suite is green** (count = baseline 619 + 14 ≈ 633).

- [ ] **Step 2: Seed the demo save**
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/seed_demo_save.gd`

- [ ] **Step 3: Launch the real app** (editor must be quit first — never two Godot instances)
`/Applications/Godot.app/Contents/MacOS/Godot --path .`

- [ ] **Step 4: Tell Nico exactly what to do/feel** — from the hub, tap your green PLAY fixture, press Play, and watch for the match to PAUSE at the Powerplay Exit (over 7), at a Wicket Crisis if a wicket falls in the middle, and at the Death Plan (over 16). Pick a side on each two-button card and feel the rest of the innings change. Does the pause land? Does the choice visibly move the score?

---

## Self-Review

- **Spec coverage:** D1 byte-identical re-sim ✓ (Task 3 prefix + determinism tests); D2 maps to Intent ✓ (Tasks 1-2); D3 per-over override `KeyMomentPlan` ✓ (Task 1); D4 three archetypes ✓ (Task 3 `_compute_km_moments`); D5 two tap buttons + overlay reuse ✓ (Task 4); D6 Boost/DRS untouched ✓ (separate code paths); D7 triggers from the ball-log, recomputed each resim ✓ (Task 3). §6 testing 1-5 all mapped. §7 launch ✓ (Task 5).
- **Placeholder scan:** none — every code step is concrete.
- **Type consistency:** `effective_for_over(over, base_band)`, `key_moments`, `key_moment_offer(cursor)`, `decide_key_moment(from_over, band)`, `km_press(i)`, `km_overlay_visible()` used identically across tasks/tests.
- **Open default recorded:** Wicket Crisis window capped to overs 7-14 (override 8-15) to avoid the Death-Plan collision at 16 — a refinement of spec §9; note in roadmap findings.
```
