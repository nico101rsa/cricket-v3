# T9 Boost Water-Meter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat 2-presses-per-innings Boost budget with ADR 0005's water-meter (fill-locked magnitude, ball-ticked drain/recharge, ~6 full presses/match), and fix the pre-existing cross-innings press double-fire.

**Architecture:** A new pure `BoostMeter` (per-innings, ball-ticked, no RNG) computes fill; at a press the innings resolver locks `(mult, n)` from fill and feeds the **unchanged** `JokerRuntime.on_boost_press`. `BoostPlan` gains innings-aware `press_pairs` + `for_innings(n)` (DW13 double-fire fix). `MatchSession` gates presses on the log-derived meter; the scene badge becomes a fill-% gauge. Spec: `docs/superpowers/specs/2026-07-04-boost-water-meter-design.md` (DW1–DW13).

**Tech Stack:** Godot 4.6.3 GDScript, GUT 9.6 (`-gdir=res://tests/unit`, whole suite every run, red = parse error, green = count climbing). Tabs. Baseline: **860 tests / 10779 asserts green.**

**Godot invocations (branch has fresh `.godot`? run import first):**
- Import (after any new script): `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- Test: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- NEVER run while the Godot editor is open; ONE Godot process at a time; chain `--import && test` when both needed.

---

### Task 1: `BoostMeter` domain class

**Files:**
- Create: `scripts/domain/boost_meter.gd`
- Test: `tests/unit/test_boost_meter.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

# The ADR 0005 water-meter (spec 2026-07-04 DW1-DW6): fill in [0,1], starts full,
# press locks (mult, n) from fill, drains to 0 over the locked window, then
# recharges at 1/RECHARGE_BALLS per ball. Pure, ball-ticked, no RNG.

func test_starts_full() -> void:
	var m := BoostMeter.new()
	assert_almost_eq(m.fill, 1.0, 0.0001, "meter starts full")
	assert_false(m.draining(), "not draining at start")

func test_full_press_locks_base_params() -> void:
	var m := BoostMeter.new()
	var p := m.try_press(1.15, 6)
	assert_almost_eq(p["mult"], 1.15, 0.0001, "full fill -> full mult (DW2)")
	assert_eq(p["n"], 6, "full fill -> full window")
	assert_true(m.draining(), "press starts the drain")

func test_half_press_locks_scaled_params() -> void:
	var m := BoostMeter.new()
	m.fill = 0.5
	var p := m.try_press(1.15, 6)
	assert_almost_eq(p["mult"], 1.075, 0.0001, "mult = 1 + F*(base-1) (DW2)")
	assert_eq(p["n"], 3, "n = round(F * base_n)")

func test_drain_reaches_zero_exactly_at_window_end() -> void:
	var m := BoostMeter.new()
	m.try_press(1.15, 6)
	for i in range(6):
		m.tick()
	assert_almost_eq(m.fill, 0.0, 0.0001, "empty exactly when the buff ends (DW3)")
	assert_false(m.draining(), "drain over")

func test_press_while_draining_is_ignored() -> void:
	var m := BoostMeter.new()
	m.try_press(1.15, 6)
	assert_eq(m.try_press(1.15, 6), {}, "one boost at a time (DW3)")

func test_press_under_min_fill_is_ignored() -> void:
	var m := BoostMeter.new()
	m.fill = 0.2
	assert_eq(m.try_press(1.15, 6), {}, "sub-25% press blocked (DW5)")

func test_recharge_rate_and_cap() -> void:
	var m := BoostMeter.new()
	m.try_press(1.15, 6)
	for i in range(6):
		m.tick()
	m.tick()
	assert_almost_eq(m.fill, 1.0 / 34.0, 0.0001, "+1/34 per ball (DW4)")
	for i in range(50):
		m.tick()
	assert_almost_eq(m.fill, 1.0, 0.0001, "capped at 1.0")

func test_three_full_presses_fit_a_120_ball_innings() -> void:
	# Full cycle = 6 drain + 34 recharge = 40 balls (DW4): presses at balls 1/41/81.
	var m := BoostMeter.new()
	var full_presses := 0
	for ball in range(1, 121):
		if ball == 1 or ball == 41 or ball == 81:
			var p := m.try_press(1.15, 6)
			if not p.is_empty() and p["n"] == 6:
				full_presses += 1
		m.tick()
	assert_eq(full_presses, 3, "3 full presses per innings -> ~6 per match (DW4)")
```

- [ ] **Step 2: Run the suite — judge red by the parse error**

Run: import + test chained. Expected: `SCRIPT ERROR: Parse Error: Identifier "BoostMeter" not declared` in the GUT log (the file is skipped); rest of suite green at 860.

- [ ] **Step 3: Implement `scripts/domain/boost_meter.gd`**

```gdscript
class_name BoostMeter
extends RefCounted

# ADR 0005 water-meter (spec 2026-07-04-boost-water-meter-design.md DW1-DW6).
# Per-innings, ticked once per BALL (the deterministic re-sim has no wall clock —
# DW/§2). Press locks magnitude+window from current fill (linear); the meter then
# drains to 0 over exactly that window, and recharges at 1/RECHARGE_BALLS after.
# Pure state machine: no RNG, shared by headless careers and the live match.

const RECHARGE_BALLS := 34     # empty -> full; 6 + 34 = 40-ball full cycle (DW4)
const MIN_PRESS_FILL := 0.25   # a near-empty press is a no-op (DW5)

var fill := 1.0                # starts full each innings (DW1)
var drain_left := 0            # balls of drain remaining (> 0 while boost active)
var _drain_per_ball := 0.0

func draining() -> bool:
	return drain_left > 0

# Attempt a press at a ball start. Returns {} when blocked (draining / under min),
# else the locked buff {"mult": float, "n": int} — DW2's linear lock.
func try_press(base_mult: float, base_n: int) -> Dictionary:
	if draining() or fill < MIN_PRESS_FILL:
		return {}
	var n := maxi(1, roundi(fill * base_n))
	var mult := 1.0 + fill * (base_mult - 1.0)
	drain_left = n
	_drain_per_ball = fill / n
	return {"mult": mult, "n": n}

# Advance one ball (call after each ball resolves).
func tick() -> void:
	if drain_left > 0:
		drain_left -= 1
		fill = 0.0 if drain_left == 0 else maxf(0.0, fill - _drain_per_ball)
	else:
		fill = minf(1.0, fill + 1.0 / RECHARGE_BALLS)
```

- [ ] **Step 4: Import + run suite**

Expected: `All tests passed`, count 860 → 868 (+8).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/boost_meter.gd scripts/domain/boost_meter.gd.uid tests/unit/test_boost_meter.gd
git commit -m "feat: T9 task 1 -- BoostMeter water-meter state machine (DW1-DW6)"
```
(Reminder: test scripts generate no `.uid`; domain scripts do.)

---

### Task 2: `BoostPlan.press_pairs` + `for_innings` (DW13 fix, plan side)

**Files:**
- Modify: `scripts/data/boost_plan.gd`
- Test: `tests/unit/test_boost_plan.gd` (append)

- [ ] **Step 1: Append failing tests to `tests/unit/test_boost_plan.gd`**

```gdscript
# DW13 (spec 2026-07-04): innings-aware pairs. A live session's press in innings 1
# must NOT fire in innings 2 (the old flat list double-fired every press).
func test_for_innings_filters_pairs() -> void:
	var p := BoostPlan.new()
	p.press_pairs = [[1, 5], [2, 16]]
	assert_eq(p.for_innings(1).press_overs, [5], "innings 1 keeps only its press")
	assert_eq(p.for_innings(2).press_overs, [16], "innings 2 keeps only its press")
	assert_almost_eq(p.for_innings(1).base_mult, p.base_mult, 0.0001, "params carried")

func test_for_innings_flat_plan_unchanged() -> void:
	# Headless flat plans (BoostPlan.at) intentionally fire in BOTH innings —
	# that's how boost jokers were priced. Empty pairs -> the plan itself.
	var p := BoostPlan.at([1, 10, 16])
	assert_eq(p.for_innings(1), p, "flat plan passes through untouched")
	assert_eq(p.for_innings(2), p, "flat plan passes through untouched")
```

- [ ] **Step 2: Run suite — red**

Expected: 2 failures in `test_boost_plan.gd` (`Invalid access to property 'press_pairs'` / method not found surfaces as a script error on that file; suite otherwise green).

- [ ] **Step 3: Implement in `scripts/data/boost_plan.gd`** — add below `base_n`:

```gdscript
# DW13 (spec 2026-07-04): innings-aware presses for live sessions. When non-empty,
# MatchResolver passes for_innings(1|2) to each innings so a press fires ONLY in
# its own innings. Empty (all headless flat plans) -> for_innings returns self,
# byte-identical to the old behaviour.
var press_pairs: Array = []   # [[innings_no, over], ...]

func for_innings(n: int) -> BoostPlan:
	if press_pairs.is_empty():
		return self
	var p := BoostPlan.new()
	p.base_mult = base_mult
	p.base_n = base_n
	for pr in press_pairs:
		if pr[0] == n:
			p.press_overs.append(pr[1])
	return p
```

- [ ] **Step 4: Run suite** — Expected: green, 870 (+2).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/boost_plan.gd tests/unit/test_boost_plan.gd
git commit -m "feat: T9 task 2 -- BoostPlan innings-aware press_pairs + for_innings (DW13)"
```

---

### Task 3: Resolver — meters, fill-locked presses, log fields, double-fire fix

**Files:**
- Modify: `scripts/domain/innings_resolver.gd` (press block ~213–220; log block ~352–361)
- Modify: `scripts/domain/match_resolver.gd` (4 `simulate_innings` call sites ~207–229)
- Test: `tests/unit/test_fair_fight_baseline.gd` (append; existing boost tests must pass UNCHANGED)

- [ ] **Step 1: Append failing tests to `tests/unit/test_fair_fight_baseline.gd`**

(Reuse this file's existing helpers `_attrs()/_team_*/_tuning()/_itun()` — open it first and copy the call shapes of the existing `test_opponent_boost_*` tests for the long `simulate_innings`/`simulate_match` arg lists.)

```gdscript
# --- T9 water-meter (spec 2026-07-04 DW3/DW8/DW13) ---------------------------

# A press at over 3 while the over-1 press is still recharging locks a WEAKER buff
# than a fresh press would: same seed, the partial-fill innings differs from an
# innings whose only press is the (full-fill) over-1 press by less than the
# full double-press innings did pre-rung. Simplest observable: log fills.
func test_log_carries_meter_fill_and_drain() -> void:
	var boost := BoostPlan.at([2])
	var log: Array = []
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	InningsResolver.simulate_innings(<same args as the existing DF4 boost test,
		with boost as boost_plan and log as ball_log>)
	# over-1 balls: full meter, not draining
	assert_almost_eq(log[0]["boost_fill"], 1.0, 0.0001, "starts full")
	assert_false(log[0]["boost_draining"], "no press yet")
	# over-2 first ball: press fires at full -> draining, fill still 1.0 at lock
	var b7: Dictionary = log[6]
	assert_true(b7["boost_pressed"], "press at over 2 start")
	assert_true(b7["boost_draining"], "drain begins on the press ball")
	# over-3 first ball (ball 13): drain (6 balls) is over, meter empty
	assert_almost_eq(log[12]["boost_fill"], 0.0, 0.0001, "empty after the window")
	assert_false(log[12]["boost_draining"], "recharging now")

func test_press_while_draining_is_ignored_by_resolver() -> void:
	# Presses at overs 2 AND 3: over-3 lands mid-drain? No — drain ends at ball 12,
	# over 3 starts at ball 13 with fill 0 < MIN_PRESS_FILL -> ignored (DW5).
	var boost := BoostPlan.at([2, 3])
	var log: Array = []
	<simulate as above>
	assert_false(log[12]["boost_pressed"], "sub-min press is a no-op")

func test_press_pairs_do_not_double_fire_across_innings() -> void:
	# DW13: a huge innings-1-only press must leave innings 2 with NO press.
	# Flat [1] fires in both innings; pairs [[1,1]] fires only in innings 1.
	# Same seed: innings1 totals identical (same press), innings2 logs differ in
	# boost_pressed (flat pressed, pairs did not).
	var flat := BoostPlan.new()
	flat.press_overs = [1]; flat.base_mult = 2.0; flat.base_n = 120
	var pairs := BoostPlan.new()
	pairs.press_pairs = [[1, 1]]; pairs.base_mult = 2.0; pairs.base_n = 120
	<run MatchResolver.simulate_match twice, same seed, force player_bats_first=1,
	 capture ball_log_1/ball_log_2 for each, boost_plan = flat then pairs>
	assert_eq(<flat innings1 total>, <pairs innings1 total>, "innings 1 identical")
	assert_true(<flat log2 ball 1>["boost_pressed"], "flat plan leaked into innings 2")
	assert_false(<pairs log2 ball 1>["boost_pressed"], "pairs stay in their innings (DW13)")
```

(The `<...>` are for the implementer to fill from the file's own existing call shapes — the arg lists are 20+ positional params and the test file already has them verbatim. Do not guess them; copy from `test_opponent_boost_lifts_opponent_innings` / `test_opponent_boost_reaches_the_match` in the same file.)

- [ ] **Step 2: Run suite — red** (`boost_fill` key missing / `press_pairs` unread → assert failures).

- [ ] **Step 3: Implement**

`scripts/domain/innings_resolver.gd` — at the top of the ball loop's locals (near `runtime`/`opp_runtime` creation at innings start), create the meters:

```gdscript
	var boost_meter := BoostMeter.new()       # DW1: full at innings start
	var opp_boost_meter := BoostMeter.new()   # DF4 symmetry (DW8)
```

Replace the press block (~213–220):

```gdscript
		# C2e/T9 — a Manager Boost press at this over's start locks a fill-scaled
		# buff off the water-meter (spec 2026-07-04 DW2/DW3); the joker pipeline
		# below is unchanged — it just receives the locked params.
		var boost_pressed_now := false
		if boost_plan != null and balls == (over - 1) * 6 and boost_plan.presses_on(over):
			var locked := boost_meter.try_press(boost_plan.base_mult, boost_plan.base_n)
			if not locked.is_empty():
				runtime.on_boost_press(jokers, player_is_batting, intent, locked["mult"], locked["n"], balls + 1)
				boost_pressed_now = true
		# DF4 — the opponent presses its own Boost off its own meter.
		if opp_boost_plan != null and balls == (over - 1) * 6 and opp_boost_plan.presses_on(over):
			var olocked := opp_boost_meter.try_press(opp_boost_plan.base_mult, opp_boost_plan.base_n)
			if not olocked.is_empty():
				opp_runtime.on_boost_press([], opp_is_batting, intent, olocked["mult"], olocked["n"], balls + 1)
```

In the log block (~352), add two keys to the dict (after `"boost_pressed": boost_pressed_now,`):

```gdscript
				"boost_fill": boost_meter.fill, "boost_draining": boost_meter.draining(),
```

After the log block / at the end of each ball iteration (immediately after the log append, BEFORE the end-of-over strike swap), tick both meters:

```gdscript
		boost_meter.tick()
		opp_boost_meter.tick()
```

CAREFUL: the log must record fill AT BALL START POST-PRESS (DW8) — i.e. read `boost_meter.fill` BEFORE `tick()`. The order above does that. Tick unconditionally (meters exist even with null plans; two RefCounted ticks are noise-cheap and keep the code branch-free).

`scripts/domain/match_resolver.gd` — just above the `if player_bats_first:` branch (~206), derive per-innings plans:

```gdscript
	# DW13: innings-aware live presses — a session press fires only in its innings.
	# Flat headless plans (empty press_pairs) pass through unchanged.
	var bp1: BoostPlan = boost_plan.for_innings(1) if boost_plan != null else null
	var bp2: BoostPlan = boost_plan.for_innings(2) if boost_plan != null else null
```

Then in the 4 call sites: the two innings-1 calls pass `bp1` where they passed `boost_plan`, the two innings-2 calls pass `bp2`. (Both branches: `player_bats_first` first call = innings 1.)

- [ ] **Step 4: Run suite** — Expected: green, +3 tests. The existing DF4 boost tests (`test_opponent_boost_lifts_opponent_innings`, `test_opponent_boost_reaches_the_match`) must pass UNCHANGED — their presses are at over 1 (full meter) so the locked params equal the old flat params exactly (DW2). If they fail, the lock math or tick order is wrong — do not touch the tests.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/innings_resolver.gd scripts/domain/match_resolver.gd tests/unit/test_fair_fight_baseline.gd
git commit -m "feat: T9 task 3 -- resolver water-meter: fill-locked presses, log fields, DW13 double-fire fix"
```

---

### Task 4: `MatchSession` — meter-gated presses, gauge read-model

**Files:**
- Modify: `scripts/domain/match_session.gd` (lines 11, 94–96, 140–168)
- Test: `tests/unit/test_match_session.gd` (boost section ~26–61 + line 360)

- [ ] **Step 1: Rewrite the boost tests in `tests/unit/test_match_session.gd`**

Replace `test_can_boost_respects_budget` (and adjust any other test that calls `presses_left`) with:

```gdscript
func test_can_boost_follows_the_meter() -> void:
	var s := _session(3)   # use this file's existing session helper + seed style
	s.decide_boost(1, 2)
	assert_false(s.can_boost(1, 3), "over-3 start: meter empty (drain just ended)")
	assert_true(s.can_boost(1, 5), "over-5 start: recharged past 25% (12/34)")

func test_boost_fill_matches_log() -> void:
	var s := _session(3)
	assert_almost_eq(s.boost_fill(1, 1), 1.0, 0.0001, "fresh innings, full meter")
	s.decide_boost(1, 2)
	assert_almost_eq(s.boost_fill(1, 3), 0.0, 0.0001, "empty right after the window")
	assert_almost_eq(s.boost_fill(1, 5), 12.0 / 34.0, 0.001, "12 recharge balls by over 5")

func test_blocked_press_never_enters_decisions() -> void:
	var s := _session(3)
	s.decide_boost(1, 2)
	s.decide_boost(1, 3)   # blocked (meter empty)
	assert_eq((s.export_decisions()["presses"] as Array).size(), 1, "no-op press not recorded (DW9)")

func test_boost_state_at_cursor() -> void:
	var s := _session(3)
	s.decide_boost(1, 2)
	# find the cursor of the over-2 press ball's event and assert draining there
	var st_start := s.boost_state(0)
	assert_almost_eq(st_start["fill"], 1.0, 0.0001, "gauge full at match start")
```

Keep `test_decide_boost_leaves_prefix_byte_identical` and `test_boost_changes_score` as-is EXCEPT: `test_boost_changes_score` presses overs 2 and 5 — under the meter the over-5 press now fires at partial fill (~0.35) which still shifts the total; the assertions hold. If a press in that test lands `can_boost == false`, move it to a legal over (2 and 7).

- [ ] **Step 2: Run suite — red** (`can_boost` arg-count / missing `boost_fill`).

- [ ] **Step 3: Implement in `scripts/domain/match_session.gd`**

Delete line 11 (`const BOOST_BUDGET := 2`). Replace the `_resim` press-plan build (94–96):

```gdscript
		var boost := BoostPlan.new()
		for p in _presses:
			boost.press_pairs.append([p[0], p[1]])   # innings-aware (DW13)
```

Replace the whole Boost section (140–168):

```gdscript
# -- Boost: ADR 0005 water-meter (spec 2026-07-04 DW9) ------------------------

# Is innings_no (1/2) the Player's batting innings?
func player_bats_this(innings_no: int) -> bool:
	return (innings_no == 1) == _result.player_bats_first

func _innings_log(innings_no: int) -> Array:
	return _result.ball_log_innings1 if innings_no == 1 else _result.ball_log_innings2

# First log row of a 1-based over in an innings, or {}.
func _over_start_row(innings_no: int, over: int) -> Dictionary:
	for b in _innings_log(innings_no):
		if b["over"] == over:
			return b
	return {}

# The meter fill at an over's start (what a press there would lock from).
func boost_fill(innings_no: int, over: int) -> float:
	var row := _over_start_row(innings_no, over)
	return row.get("boost_fill", 0.0)

# Can the player press at this over's start? Mirrors BoostMeter's own gate off
# the logged meter state, so the UI and the sim can never disagree (DW9).
func can_boost(innings_no: int, over: int) -> bool:
	for p in _presses:
		if p[0] == innings_no and p[1] == over:
			return false
	var row := _over_start_row(innings_no, over)
	if row.is_empty() or row["boost_draining"]:
		return false
	return row["boost_fill"] >= BoostMeter.MIN_PRESS_FILL

# Gauge state at a playback cursor: meter fill + draining at the last ball the
# cursor event covers (ball events -> that ball; over events -> the over's last ball).
func boost_state(cursor: int) -> Dictionary:
	var last := {"fill": 1.0, "draining": false}
	for i in range(mini(cursor, _events.size() - 1) + 1):
		var e: Dictionary = _events[i]
		if not e.has("over") or e.get("innings", -1) == -1:
			continue
		var log := _innings_log(e["innings"])
		for b in log:
			if b["over"] != e["over"]:
				continue
			if e["type"] == "ball" and b.get("ball_in_over", -1) != e.get("ball", -2):
				continue
			last = {"fill": b["boost_fill"], "draining": b["boost_draining"]}
	return last

# Add a Boost press at 1-based within-innings over in innings_no, re-sim.
func decide_boost(innings_no: int, over: int) -> void:
	if not can_boost(innings_no, over):
		return
	_presses.append([innings_no, over])
	_resim()

# Back-compat helper: boost innings 1.
func decide_boost_over(over: int) -> void:
	decide_boost(1, over)
```

NOTE: `boost_state` as written is O(cursor × log) — if the suite feels slow, hoist to a single log walk; correctness first. `presses_left` is deleted; grep for stray callers (`grep -rn "presses_left" scripts scenes tests tools`) and update them (Task 5 handles the scene).

- [ ] **Step 4: Run suite** — Expected: green, count ≈ 875 (+3 net: −1 replaced, +4 new). Fix any straggler `can_boost(1)`-arity callers the grep finds.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_session.gd tests/unit/test_match_session.gd
git commit -m "feat: T9 task 4 -- MatchSession meter-gated presses + gauge read-model"
```

---

### Task 5: Scene — the gauge button

**Files:**
- Modify: `scenes/interactive_match/interactive_match.gd` (badge creation ~277–281; `_on_boost` ~474; `_update_boost_button` ~484)
- Test: whichever scene test asserts the boost button (`grep -n "boost" tests/unit/test_interactive_match*.gd`) — update/add badge assertions
- Verify: re-render `tools/preview_interactive_match.gd` + EYEBALL (unit tests can't catch invisibility — project rule)

- [ ] **Step 1: Update the scene**

Badge creation (~277): `_lbl("100%", 9, ...)` instead of `("0", 12, ...)`; `custom_minimum_size = Vector2(30, 22)`; `position = Vector2(36, -4)`.

Replace `_on_boost` / `_update_boost_button` and delete the `_boost_active_over/_boost_active_innings` members (lines 29–30) — draining state now comes from the session:

```gdscript
func _on_boost() -> void:
	var inn := _innings_at_cursor()
	var next_over := mini(_over_at_cursor() + 1, 20)
	if not _session.can_boost(inn, next_over):
		return
	_session.decide_boost(inn, next_over)
	_event_count = _session.events().size()
	_render()

func _update_boost_button() -> void:
	var st := _session.boost_state(_cursor)
	if st["draining"]:
		_boost_btn.disabled = true
		_boost_badge.text = "ON"
		return
	var inn := _innings_at_cursor()
	var next_over := mini(_over_at_cursor() + 1, 20)
	_boost_btn.disabled = not _session.can_boost(inn, next_over)
	_boost_badge.text = "%d%%" % roundi(st["fill"] * 100.0)
```

- [ ] **Step 2: Update/extend the scene test** — assert the badge text matches `\d+%|ON` at boot (was a press count). Run suite → green.

- [ ] **Step 3: Re-render + eyeball**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/preview_interactive_match.gd
```
Check `docs/mockups/in-match-hifi-built-autosim.png` (and siblings): badge reads "100%" and doesn't clip. Then launch the real game once (`--path .`) and press BOOST mid-innings: badge → "ON" → percent climbing after the window. Fix any clipping (min-size/position) before committing.

- [ ] **Step 4: Commit**

```bash
git add scenes/interactive_match/interactive_match.gd tests/unit/<scene test> docs/mockups/*.png
git commit -m "feat: T9 task 5 -- BOOST button is the water-meter gauge (fill % / ON)"
```

---

### Task 6: Balance gate + spec Results

**Files:**
- Modify: `tools/sweep_interactive_levers.gd` (~181–183)
- Modify: `docs/superpowers/specs/2026-07-04-boost-water-meter-design.md` §9

- [ ] **Step 1: Update the Boost arm** (old 16+18 schedule dies — over 18 would sit at 18% fill, blocked; the meter-optimal ceiling is 3 full presses):

```gdscript
	if arm.get("boost", false):
		s.decide_boost(inn, 1)
		s.decide_boost(inn, 8)
		s.decide_boost(inn, 16)
```

- [ ] **Step 2: Run the floor sweep** (same harness as the T8 gate):

```bash
nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_form_balance.gd > /tmp/t9_floor.log 2>&1 &
```
Watch by grepping the LOG (never pgrep). Gate: every build 48–49% win-rate (fair-fight band). The floor carries no boost plan — a shift here means Task 3 broke something unrelated; STOP and debug, don't tune.

- [ ] **Step 3: Run the lever sweep** (`ILB_QUICK=1` first for a smoke, then full):

```bash
nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_interactive_levers.gd > /tmp/t9_levers.log 2>&1 &
```
Gate (DW12): Boost arm delta in **+2..+8 win-pts** (was +1.5, N=4200/arm ±0.7pp). Outside → tune `BoostPlan.base_mult` first, `BoostMeter.RECHARGE_BALLS` second, re-run. If the final number sits above ~+6, note boost-joker re-pricing as a flagged follow-up in the spec (§6 rule), don't do it here.

- [ ] **Step 4: Fill spec §9** with both tables (build → win% for the floor; arm → delta for levers, with N and ± band per the provenance rule), commit:

```bash
git add docs/superpowers/specs/2026-07-04-boost-water-meter-design.md tools/sweep_interactive_levers.gd
git commit -m "docs: T9 balance gate results -- floor + boost lever under the water-meter"
```

---

### Task 7: Finish — full suite, PR, roadmap

- [ ] Full suite green; `git push -u origin playtest-t9-boost-water-meter`; `gh pr create` (title "T9: Boost water-meter (ADR 0005)"), body summarising DW1–DW13 + gate numbers, merge, sync main, delete branch.
- [ ] Close the T9 item in `docs/PLAYTEST-NOTES.md` (✅ DONE line, like T8's).
- [ ] Update `PROJECT_ROADMAP.md` Next session block (T9 done → next = T10 scorecard moments).
