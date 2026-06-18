# Bowling Key Moments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Pace-vs-Spin captain decision cards to the bowling innings — the mirror of the batting Key Moments — so a whole match is a fight, not a half-watched replay.

**Architecture:** A bowling Key Moment is another decision baked into `MatchSession`'s deterministic re-sim (the cheap third door, same as Boost/DRS/batting-KM). A new `BowlingKeyMomentPlan` (exact mirror of `KeyMomentPlan`) carries per-over `(from_over, kind)` overrides; it rides a new optional `BowlingPlan.key_moments` field, fed into `simulate_match_teams`'s existing `player_bowling_plan` slot. The 3 moments fire in the opposition's batting innings and override the team's bowler kind (Pace/Spin) — the only bowling lever with real ball EV (the bowling-balance rung tuned its phase tilt + intent×kind matchup).

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Spec: `docs/superpowers/specs/2026-06-18-bowling-key-moments-design.md`.

**Key gotcha (read before Task 3):** passing a non-null `player_bowling_plan` flips the sim into rotation mode (`match_resolver.gd:190`). In the **live game** the opponent brain already passes `opp_bowling_plan` (rotation already on), so the player's textbook+KM plan rides the already-rotating innings and the watched prefix stays byte-identical. So: **`MatchSession` passes the bowling plan only when `_opp_spec != null`, and bowling moments only compute then.** The `_opp_spec == null` standalone/preview path keeps passing `null` → every existing test/preview is untouched. All bowling-KM tests therefore use a *spec'd* session (mirror the existing `_spec_session` / `_adaptive_spec` helpers).

**Conventions reminder (CLAUDE.md):** tabs in `.gd`; run `--import` once after adding a script; judge **red** by the `Parse Error: Identifier "X" not declared` line (GUT skips the file); judge **green** by the total test count climbing + `All tests passed`; run the whole suite each step:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Quit the Godot editor first. Test scripts under `tests/` do **not** get a `.uid`.

---

### Task 1: `BowlingKeyMomentPlan` — the per-over Pace/Spin override

**Files:**
- Create: `scripts/data/bowling_key_moment_plan.gd`
- Test: `tests/unit/test_bowling_key_moment_plan.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# BowlingKeyMomentPlan — the per-over bowler-kind override policy (spec §3, D3).
# Exact mirror of KeyMomentPlan; kind = BowlingPlan.Kind (PACE/SPIN).

func test_empty_returns_base_kind():
	var p := BowlingKeyMomentPlan.new()
	assert_eq(p.effective_for_over(7, BowlingPlan.Kind.SPIN), BowlingPlan.Kind.SPIN)

func test_override_applies_from_its_over_onward():
	var p := BowlingKeyMomentPlan.new()
	p.overrides.append({"from_over": 7, "kind": BowlingPlan.Kind.SPIN})
	assert_eq(p.effective_for_over(6, BowlingPlan.Kind.PACE), BowlingPlan.Kind.PACE, "before the override = base")
	assert_eq(p.effective_for_over(7, BowlingPlan.Kind.PACE), BowlingPlan.Kind.SPIN, "from the override over")
	assert_eq(p.effective_for_over(12, BowlingPlan.Kind.PACE), BowlingPlan.Kind.SPIN, "still applies later")

func test_latest_wins_on_overlap():
	var p := BowlingKeyMomentPlan.new()
	p.overrides.append({"from_over": 7, "kind": BowlingPlan.Kind.SPIN})
	p.overrides.append({"from_over": 16, "kind": BowlingPlan.Kind.PACE})
	assert_eq(p.effective_for_over(15, BowlingPlan.Kind.PACE), BowlingPlan.Kind.SPIN, "over 15 = the over-7 override")
	assert_eq(p.effective_for_over(18, BowlingPlan.Kind.SPIN), BowlingPlan.Kind.PACE, "over 18 = the latest (over-16) override")
```

- [ ] **Step 2: Run the suite to verify it fails**

Run the full-suite command above.
Expected: `Parse Error: Identifier "BowlingKeyMomentPlan" not declared` (GUT skips the file) — that is RED.

- [ ] **Step 3: Write minimal implementation**

```gdscript
class_name BowlingKeyMomentPlan
extends RefCounted

# A bowling Key Moment decision = a per-over bowler-kind override (spec D3,
# 2026-06-18-bowling-key-moments-design.md). Exact mirror of KeyMomentPlan: the
# captain's call appends an {from_over, kind} entry; the effective kind for any over is
# the latest override at-or-before it (highest from_over <= over), falling back to the
# base BowlingPlan rotation. Pure + deterministic. Empty overrides => base kind
# unchanged (byte-identical to a no-bowling-Key-Moment match).

var overrides: Array = []  # of {from_over:int, kind:int} ; kind = BowlingPlan.Kind

func effective_for_over(over: int, base_kind: int) -> int:
	var best_from := -1
	var result := base_kind
	for o in overrides:
		var f: int = o["from_over"]
		if f <= over and f > best_from:
			best_from = f
			result = o["kind"]
	return result
```

- [ ] **Step 4: Import + run the suite to verify it passes**

Run the full-suite command above.
Expected: count climbs by 3, `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/bowling_key_moment_plan.gd scripts/data/bowling_key_moment_plan.gd.uid tests/unit/test_bowling_key_moment_plan.gd
git commit -m "feat: BowlingKeyMomentPlan — per-over pace/spin override (mirror of KeyMomentPlan)"
```

---

### Task 2: `BowlingPlan.key_moments` field

**Files:**
- Modify: `scripts/data/bowling_plan.gd` (add field + consult it in `for_over`)
- Test: `tests/unit/test_bowling_plan.gd` (append)

- [ ] **Step 1: Write the failing test (append to `test_bowling_plan.gd`)**

```gdscript
func test_key_moments_override_phase_rotation():
	var plan := BowlingPlan.new()   # textbook: PACE / SPIN / PACE
	assert_eq(plan.for_over(16), BowlingPlan.Kind.PACE, "death = pace by default")
	plan.key_moments = BowlingKeyMomentPlan.new()
	plan.key_moments.overrides.append({"from_over": 16, "kind": BowlingPlan.Kind.SPIN})
	assert_eq(plan.for_over(15), BowlingPlan.Kind.SPIN, "over 15 still the phase default (middle = spin)")
	assert_eq(plan.for_over(16), BowlingPlan.Kind.SPIN, "over 16 now overridden to spin")

func test_null_key_moments_is_plain_rotation():
	var plan := BowlingPlan.new()
	assert_eq(plan.key_moments, null, "key_moments defaults to null")
	assert_eq(plan.for_over(16), BowlingPlan.Kind.PACE, "null => plain phase rotation")
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: `test_key_moments_override_phase_rotation` FAILS (`for_over` ignores `key_moments`) / `key_moments` not a property — RED.

- [ ] **Step 3: Implement — add the field + consult it**

In `scripts/data/bowling_plan.gd`, add after the phase vars (`var death: int = Kind.PACE`):

```gdscript

# Bowling Key Moment overrides (spec 2026-06-18): per-over bowler-kind overrides from
# in-match captain decisions. null => plain phase rotation (byte-identical to every
# pre-Key-Moment caller). Mirror of IntentPlan.key_moments.
var key_moments: BowlingKeyMomentPlan = null
```

Replace the body of `for_over` with a phase-default + override consult:

```gdscript
# 1-based over number -> bowler Kind for that over (Key Moment overrides win).
func for_over(over: int) -> int:
	var base := _phase_kind(over)
	if key_moments != null:
		return key_moments.effective_for_over(over, base)
	return base

# The plain phase kind (no Key Moment overrides applied).
func _phase_kind(over: int) -> int:
	if over <= POWERPLAY_OVERS:
		return powerplay
	if over < DEATH_START_OVER:
		return middle
	return death
```

- [ ] **Step 4: Import + run the suite to verify it passes**

Expected: count climbs by 2, `All tests passed` (existing `test_for_over_maps_phases` still green — phase defaults unchanged).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/bowling_plan.gd scripts/data/bowling_plan.gd.uid tests/unit/test_bowling_plan.gd
git commit -m "feat: BowlingPlan.key_moments — per-over pace/spin override field"
```

---

### Task 3: `MatchSession` passes the bowling plan (spec'd path) — byte-identical proof

**Files:**
- Modify: `scripts/domain/match_session.gd` (add `_bowl_km_plan`; build + pass the player bowling plan when `_opp_spec != null`)
- Test: `tests/unit/test_match_session.gd` (append)

- [ ] **Step 1: Write the failing test (append to `test_match_session.gd`)**

```gdscript
# -- Bowling Key Moments (spec 2026-06-18) ----------------------------------
# Bowling moments fire in the OPPOSITION batting innings, and need rotation mode on
# (which only the opponent brain activates), so these use a spec'd session: opp bats
# FIRST (force=0) as a full innings, adaptive brain spec, mirror of _spec_session.

func test_empty_bowling_km_is_byte_identical_to_textbook_plan():
	var spec := _adaptive_spec()
	var s := _spec_session(spec)   # force=0, opp index 6, spec'd (rotation on)
	# Rebuild the same match but pass an explicit textbook player bowling plan (no KM).
	# If the session (empty bowling-KM) matches it, an empty plan is byte-identical.
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var rng := RandomNumberGenerator.new(); rng.seed = 20260615
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[6]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	var plans := OpponentBrain.draw_plans(spec.brain_tier, spec.blend, rng)
	var boost := BoostPlan.new()
	var drs := DRSPolicy.new(); drs.review_balls = []
	var l1: Array = []; var l2: Array = []
	MatchResolver.simulate_match_teams(a, team, opp, tour, BallTuning.new(), InningsTuning.new(),
		rng, IntentPlan.new(), BowlingPlan.new(), [], null, null, plans[0], boost, drs,
		null, null, null, 0, plans[1], l1, l2)
	assert_eq(s.result().ball_log_innings1, l1, "empty bowling-KM session == explicit textbook bowling plan (byte-identical)")
```

(`BowlingPlan.new()` == textbook; `IntentPlan.new()` == the session's all-BALANCED base. The session's `_resim` must mirror these exactly.)

- [ ] **Step 2: Run the suite to verify it fails**

Expected: FAIL — the session currently passes `null` for `player_bowling_plan` while the baseline passes `BowlingPlan.new()`; with rotation already on (opp plan non-null) `null`→`textbook()` *should* match, so this may PASS immediately. If it PASSES, that confirms the equivalence — proceed to wire `_bowl_km_plan` (Task 4 needs it) and keep this as a regression guard. If it FAILS, the session isn't passing a textbook-equivalent plan; fix in Step 3.

- [ ] **Step 3: Implement — add `_bowl_km_plan` and pass the plan when spec'd**

In `scripts/domain/match_session.gd`, after `var _km_plan := KeyMomentPlan.new()` add:

```gdscript
var _bowl_km_plan := BowlingKeyMomentPlan.new()   # accumulated bowling overrides (spec 2026-06-18)
var _bowl_km_moments: Array = []                  # computed bowling moments (lever="bowling")
```

In `_resim`, replace the `simulate_match_teams` call's `null` `player_bowling_plan` argument. Currently:

```gdscript
	_result = MatchResolver.simulate_match_teams(
		_attrs, _team, _opp, _tour, _tuning, _itun, rng,
		ip, null, [], null, null, oip,
		boost, drs, null, null, null, _force, obp, log1, log2)
```

Build a player bowling plan above the call (only when rotation is active, i.e. `_opp_spec != null`; else keep null so the standalone path is untouched):

```gdscript
	# Player bowling plan rides the existing player_bowling_plan slot. Only passed when
	# the opponent brain has rotation on (_opp_spec != null) — then textbook+empty-KM ==
	# the null->textbook() path the live game already runs (byte-identical), and a KM
	# override changes only the future. In the standalone path (_opp_spec == null) we keep
	# null so every pre-rung test/preview is byte-identical (spec §5 gotcha).
	var pbp: BowlingPlan = null
	if _opp_spec != null:
		pbp = BowlingPlan.new()
		pbp.key_moments = _bowl_km_plan
```

and use `pbp` in the call:

```gdscript
	_result = MatchResolver.simulate_match_teams(
		_attrs, _team, _opp, _tour, _tuning, _itun, rng,
		ip, pbp, [], null, null, oip,
		boost, drs, null, null, null, _force, obp, log1, log2)
```

- [ ] **Step 4: Import + run the suite to verify it passes**

Expected: count climbs by 1, `All tests passed`. Crucially the existing `test_empty_km_is_byte_identical_to_no_plan` (null-spec path) is still green (that session has `_opp_spec == null` → still passes `null`).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_session.gd scripts/domain/match_session.gd.uid tests/unit/test_match_session.gd
git commit -m "feat: MatchSession feeds an empty bowling-KM plan when rotation is on (byte-identical)"
```

---

### Task 4: The 3 bowling moments — compute, offer, decide

**Files:**
- Modify: `scripts/domain/match_session.gd` (compute bowling moments in the opp innings; offer + decide)
- Test: `tests/unit/test_match_session.gd` (append)

- [ ] **Step 1: Write the failing tests (append to `test_match_session.gd`)**

```gdscript
func _bowl_km_cursor(s: MatchSession, kind_contains: String) -> int:
	for c in range(s.events().size()):
		var o := s.key_moment_offer(c)
		if not o.is_empty() and o.get("lever", "intent") == "bowling" and (kind_contains in o["title"]):
			return c
	return -1

func test_bowling_powerplay_exit_offer_fires():
	var s := _spec_session(_adaptive_spec())   # opp bats first, full innings
	var c := _bowl_km_cursor(s, "Powerplay")
	assert_gt(c, -1, "a bowling Powerplay Exit moment is offered")
	var o := s.key_moment_offer(c)
	assert_eq(o["from_over"], 7, "bowling PP Exit overrides from over 7")
	assert_eq(o["lever"], "bowling", "tagged as a bowling lever")
	assert_eq(o["choices"].size(), 2, "two choices")
	assert_true(o["choices"][0].has("kind"), "bowling choices carry a kind, not a band")

func test_bowling_death_defence_offer_fires():
	var s := _spec_session(_adaptive_spec())
	var c := _bowl_km_cursor(s, "Death")
	assert_gt(c, -1, "a bowling Death Defence moment is offered")
	assert_eq(s.key_moment_offer(c)["from_over"], 16, "Death Defence overrides from over 16")

func test_decide_bowling_key_moment_prefix_byte_identical():
	var s := _spec_session(_adaptive_spec())
	var c := _bowl_km_cursor(s, "Powerplay")
	var o := s.key_moment_offer(c)
	# opp bats innings1 here (force=0), so the bowling innings log is ball_log_innings1
	var before := s.result().ball_log_innings1.duplicate(true)
	s.decide_bowling_key_moment(o["from_over"], BowlingPlan.Kind.SPIN)
	var after := s.result().ball_log_innings1
	for i in range(before.size()):
		if before[i]["over"] < o["from_over"]:
			assert_eq(after[i], before[i], "prefix ball %d unchanged" % i)
		else:
			break

func test_decide_bowling_key_moment_changes_the_future():
	var s := _spec_session(_adaptive_spec())
	var _c := _bowl_km_cursor(s, "Death")
	var base_total := s.result().innings1.total
	# Force the death overs to spin (away from textbook pace) — must move the opp total.
	s.decide_bowling_key_moment(16, BowlingPlan.Kind.SPIN)
	assert_ne(s.result().innings1.total, base_total, "a spin death changed the opposition total")

func test_bowling_offer_clears_after_decision():
	var s := _spec_session(_adaptive_spec())
	var c := _bowl_km_cursor(s, "Powerplay")
	s.decide_bowling_key_moment(7, BowlingPlan.Kind.SPIN)
	assert_true(s.key_moment_offer(c).is_empty(), "a decided bowling moment no longer offers")
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: FAIL — `decide_bowling_key_moment` not defined / no bowling offers found (`_bowl_km_cursor` returns -1) — RED.

- [ ] **Step 3: Implement — compute bowling moments + offer + decide**

In `scripts/domain/match_session.gd`:

Add a helper for the opposition batting log (mirror of `_player_batting_log`):

```gdscript
# The opposition's batting-innings raw ball-log (the innings where the Player bowls).
func _opp_batting_log() -> Array:
	return _result.ball_log_innings2 if _result.player_bats_first else _result.ball_log_innings1

# Over of the first opposition wicket falling in overs 7..14, else -1 (New Batsman source).
# Capped at 14 so the override over (wicket+1) stays <= 15, never colliding with Death (16).
func _first_opp_middle_wicket_over() -> int:
	for b in _opp_batting_log():
		if b["wicket"] and b["over"] >= 7 and b["over"] <= 14:
			return b["over"]
	return -1
```

Extend `_compute_km_moments` — at the end of the existing function, after the batting moments, add the bowling moments (computed only when rotation is on, i.e. `_opp_spec != null`). First, tag the existing batting `_add_moment` entries with a lever. Change `_add_moment` to accept and store a lever, defaulting to "intent":

```gdscript
func _add_moment(player_innings: int, title: String, prompt: String, from_over: int, choices: Array, lever: String = "intent") -> void:
	var c := _cursor_for_over(player_innings, from_over)
	if c == -1:
		return  # the innings never reached this over (e.g. all out) — moment doesn't fire
	_km_moments.append({"title": title, "prompt": prompt, "from_over": from_over,
		"cursor": c, "choices": choices, "lever": lever})
```

Then append the bowling block at the end of `_compute_km_moments`:

```gdscript
	# Bowling moments fire in the opposition's batting innings and override the team's
	# bowler kind (Pace/Spin). Only when rotation is on (_opp_spec != null) — see Task 3.
	if _opp_spec != null:
		var obi := 2 if _result.player_bats_first else 1
		_add_moment(obi, "🎯 Powerplay Exit", "Powerplay's done — how do you bowl the middle?", 7,
			[{"label": "Spin", "kind": BowlingPlan.Kind.SPIN},
			 {"label": "Pace", "kind": BowlingPlan.Kind.PACE}], "bowling")
		var owo := _first_opp_middle_wicket_over()
		if owo != -1:
			_add_moment(obi, "🔥 New Batsman In", "A new batter's in — how do you attack?", owo + 1,
				[{"label": "Pace", "kind": BowlingPlan.Kind.PACE},
				 {"label": "Spin", "kind": BowlingPlan.Kind.SPIN}], "bowling")
		_add_moment(obi, "💀 Death Defence", "Last five overs — how do you defend?", 16,
			[{"label": "Pace", "kind": BowlingPlan.Kind.PACE},
			 {"label": "Spin", "kind": BowlingPlan.Kind.SPIN}], "bowling")
```

Make `_km_decided` lever-aware (it currently only checks `_km_plan`). Replace it:

```gdscript
func _km_decided(from_over: int, lever: String = "intent") -> bool:
	var plan: Variant = _bowl_km_plan if lever == "bowling" else _km_plan
	for o in plan.overrides:
		if o["from_over"] == from_over:
			return true
	return false
```

Update `key_moment_offer` to pass the lever into `_km_decided` and surface it:

```gdscript
func key_moment_offer(cursor: int) -> Dictionary:
	for m in _km_moments:
		var lever: String = m.get("lever", "intent")
		if m["cursor"] == cursor and not _km_decided(m["from_over"], lever):
			return {"title": m["title"], "prompt": m["prompt"],
				"from_over": m["from_over"], "choices": m["choices"], "lever": lever}
	return {}
```

Add the bowling decide (mirror of `decide_key_moment`):

```gdscript
# Commit a bowling Key Moment: override bowler kind to `kind` from `from_over` onward, re-sim.
func decide_bowling_key_moment(from_over: int, kind: int) -> void:
	if _km_decided(from_over, "bowling"):
		return
	_bowl_km_plan.overrides.append({"from_over": from_over, "kind": kind})
	_resim()
```

Update the existing `decide_key_moment` guard to pass its lever explicitly (it checks batting):

```gdscript
func decide_key_moment(from_over: int, band: int) -> void:
	if _km_decided(from_over, "intent"):
		return
	_km_plan.overrides.append({"from_over": from_over, "band": band})
	_resim()
```

- [ ] **Step 4: Import + run the suite to verify it passes**

Expected: count climbs by 5, `All tests passed`. Existing batting-KM tests still green (they now read `lever == "intent"` by default).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_session.gd scripts/domain/match_session.gd.uid tests/unit/test_match_session.gd
git commit -m "feat: 3 bowling Key Moments — Powerplay Exit / New Batsman In / Death Defence"
```

---

### Task 5: Wire the bowling moments into the interactive scene

**Files:**
- Modify: `scenes/interactive_match/interactive_match.gd` (`km_press` routes by lever)
- Test: `tests/unit/test_interactive_match_scene.gd` (append; confirm the file name first with `ls tests/unit | grep interactive`)

**Note:** the scene already scans `key_moment_offer` and shows `_show_km_overlay` for ANY moment (batting or bowling), because both live in `_km_moments`. Only `km_press` needs to route by lever (batting → `decide_key_moment(band)`, bowling → `decide_bowling_key_moment(kind)`).

- [ ] **Step 1: Write the failing test**

First find the scene test file: `ls tests/unit | grep -i interactive`. Append to it (use its existing harness/helpers for instancing the scene + a session). Pattern:

```gdscript
func test_bowling_km_overlay_decides_via_kind():
	# Build a spec'd session (opp bats first, full innings) so a bowling moment exists.
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	var career := CareerResolver.start_career(0)
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[6]
	var tour := DifficultyLadder.spec_for(career.current_level(), 0).make_tour()
	var spec := TourSpec.new(); spec.brain_tier = TourSpec.Tier.ADAPTIVE; spec.blend = 1.0
	var session := MatchSession.start(a, team, opp, tour, 20260615, 0, null, null, spec)
	# Find the cursor of the bowling Death Defence moment.
	var target := -1
	for c in range(session.events().size()):
		var o := session.key_moment_offer(c)
		if not o.is_empty() and o.get("lever", "") == "bowling" and "Death" in o["title"]:
			target = c; break
	assert_gt(target, -1, "a bowling moment exists to drive the overlay")
	var scene = preload("res://scenes/interactive_match/interactive_match.tscn").instantiate()
	add_child_autoqfree(scene)
	scene.set_session(session)
	scene.boot()
	scene.seek_to(target)
	assert_true(scene.km_overlay_visible(), "the bowling KM overlay is showing")
	scene.km_press(1)   # pick Spin (option B for Death Defence)
	assert_false(scene.km_overlay_visible(), "overlay closes after the pick")
```

(Adapt instancing/teardown to the existing scene-test helpers — match how the batting-KM scene test does it.)

- [ ] **Step 2: Run the suite to verify it fails**

Expected: FAIL — `km_press` reads `_pending_km["choices"][i]["band"]`, but a bowling choice has no `band` key → error / no decision — RED.

- [ ] **Step 3: Implement — route `km_press` by lever**

In `scenes/interactive_match/interactive_match.gd`, replace `km_press`:

```gdscript
# Player picked option index i (0/1) on the current Key Moment card.
func km_press(i: int) -> void:
	$KMOverlay.visible = false
	if not _pending_km.is_empty():
		var lever: String = _pending_km.get("lever", "intent")
		if lever == "bowling":
			var kind: int = _pending_km["choices"][i]["kind"]
			_session.decide_bowling_key_moment(_pending_km["from_over"], kind)
		else:
			var band: int = _pending_km["choices"][i]["band"]
			_session.decide_key_moment(_pending_km["from_over"], band)
		_event_count = _session.events().size()
	_pending_km = {}
	_render()
	if _resume_after_km and _cursor < _event_count:
		_resume_after_km = false
		play()
```

- [ ] **Step 4: Import + run the suite to verify it passes**

Expected: count climbs by 1, `All tests passed`. Existing batting-KM scene test still green.

- [ ] **Step 5: Commit**

```bash
git add scenes/interactive_match/interactive_match.gd tests/unit/test_interactive_match_scene.gd
git commit -m "feat: interactive scene routes bowling Key Moments via decide_bowling_key_moment"
```

---

### Task 6: D6 measurement (real trade-off) + screenshot deliverable

**Files:**
- Modify: `tools/sweep_interactive_levers.gd` (add a bowling-KM arm) — inspect its existing arm structure first
- Create: `docs/mockups/bowling-key-moment-built-v1.png` (screenshot proof)

This task is an **oracle measurement + deliverable, not a unit gate** — no red/green TDD loop.

- [ ] **Step 1: Read the sweep tool** — `tools/sweep_interactive_levers.gd`. Note how it builds a `MatchSession` for the weak Club team vs the 7 fixtures and how it decomposes the batting levers (base / +km_aggr / −km_def). Mirror that for a bowling arm.

- [ ] **Step 2: Add a bowling-KM arm** — for each fixture, after building the session, drive the bowling moments two ways: a "bowl-spin-everywhere" arm (`decide_bowling_key_moment(7, SPIN)`, `(16, SPIN)`) and a "bowl-pace-everywhere" arm (`PACE`), recording each arm's win-rate. Keep `ILB_QUICK=1` smoke support (small N) for a fast check.

- [ ] **Step 3: Run the smoke arm**

```bash
ILB_QUICK=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_interactive_levers.gd
```
Confirm it runs and prints per-arm win-rates. (Full N=400 ~6.5 min is optional; the smoke proves wiring.)

- [ ] **Step 4: Record the finding** — note in the spec §10 (add one) or the roadmap: the win-lift of bowling Spin vs Pace, and whether either is strictly-best. Phase-correct bowling *can* be the textbook answer (as phase-correct batting is) — the question is whether the adaptive opponent's intent makes the best kind *shift* by fixture. If one band dominates flatly, flag it for Nico as a feel call (not a blocker).

- [ ] **Step 5: Capture the screenshot** — launch the real game and photograph a bowling moment paused (mirror how `key-moment-built-v1.png` was produced — check `tools/preview_key_moment.gd`; a bowling analog may be worth a tiny `tools/preview_bowling_key_moment.gd`, or seed the demo save and screenshot the live bowling innings). Save to `docs/mockups/bowling-key-moment-built-v1.png`.

- [ ] **Step 6: Commit**

```bash
git add tools/sweep_interactive_levers.gd docs/mockups/bowling-key-moment-built-v1.png docs/superpowers/specs/2026-06-18-bowling-key-moments-design.md
git commit -m "test+docs: bowling-KM lever measurement + screenshot deliverable"
```

---

## Self-Review

- **Spec coverage:** §2 lever → Tasks 1–4. §3 D1–D9 → D1/D3/D4 Tasks 1–3, D5/D7 Task 4, D8 Tasks 4–5, D9 (batting untouched) verified by existing tests staying green, D6 Task 6. §4 three archetypes → Task 4. §5 architecture → Tasks 1–5. §6 testing → tests in every task + Task 6 oracle. §7 scope: Field Set / Star-on-49 / opp bowling-KM / swipe all deferred (not in any task). §8 deliverable → Task 6 screenshot + launch. ✓ No gaps.
- **Placeholder scan:** every code step has full GDScript; the two adapt-to-existing-harness notes (scene test instancing in Task 5, sweep arm in Task 6) point at concrete reference files. No TBD/TODO.
- **Type consistency:** `BowlingKeyMomentPlan.effective_for_over(over, base_kind)`, `overrides` of `{from_over, kind}`, `BowlingPlan.key_moments`, `BowlingPlan.Kind.PACE/SPIN`, `decide_bowling_key_moment(from_over, kind)`, moment dict `lever`/`choices[].kind`, `_km_decided(from_over, lever)` consistent across Tasks 1–5. ✓
