# Bowling Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un-solve the static strategy layer — phase-dependent pace/spin tilt + intent×kind matchup wicket term + wicket-cost tuning — so textbook P/S/P emerges and no constant plan dominates (spec `docs/superpowers/specs/2026-06-11-bowling-balance-design.md`, BB1–BB10).

**Architecture:** Three additive, off-by-default-compatible changes: `IntentPlan.phase_of()` (BB2) → matchup term inside `resolve_ball` via trailing `bowler_kind := -1` + `BallTuning` tables (BB3) → per-kind phase bonus applied at the innings resolver's profile lookup via `InningsTuning` dials (BB1). Then a tuning loop judged by the E1 self-play oracle (BB5/BB6) and the full ripple re-verification (BB7). Scalar/no-rotation paths stay byte-identical (BB9).

**Tech Stack:** Godot 4.6.3 GDScript (tabs), GUT 9.6. Test command:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Judge red by parse-error/failing assert, green by total count climbing past **397** + `All tests passed`. **One Godot process at a time; `pgrep -x Godot` first; clean iCloud `" 2"` junk before runs.**

---

### Task 1: `IntentPlan.phase_of()` (BB2)

**Files:**
- Modify: `scripts/data/intent_plan.gd`
- Test: `tests/unit/test_bowling_balance.gd` (new — all this rung's tests live here)

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_bowling_balance.gd`:

```gdscript
extends GutTest

# Bowling-balance rung (spec 2026-06-11-bowling-balance-design.md).

func test_phase_of_maps_boundaries() -> void:
	assert_eq(IntentPlan.phase_of(1), 0, "over 1 -> powerplay")
	assert_eq(IntentPlan.phase_of(6), 0, "over 6 -> powerplay (boundary)")
	assert_eq(IntentPlan.phase_of(7), 1, "over 7 -> middle (boundary)")
	assert_eq(IntentPlan.phase_of(15), 1, "over 15 -> middle (boundary)")
	assert_eq(IntentPlan.phase_of(16), 2, "over 16 -> death (boundary)")
	assert_eq(IntentPlan.phase_of(20), 2, "over 20 -> death")

func test_for_over_unchanged_by_refactor() -> void:
	var t := IntentPlan.textbook()
	assert_eq(t.for_over(6), BallResolver.Intent.AGGRESSIVE, "textbook over 6 aggressive")
	assert_eq(t.for_over(7), BallResolver.Intent.BALANCED, "textbook over 7 balanced")
	assert_eq(t.for_over(16), BallResolver.Intent.AGGRESSIVE, "textbook over 16 aggressive")
```

- [ ] **Step 2: Run suite, verify red**

Run the test command above. Expected: SCRIPT ERROR / failing assert on `phase_of` (member not found), rest green.

- [ ] **Step 3: Implement**

In `scripts/data/intent_plan.gd`, add below the constants and refactor `for_over`:

```gdscript
# Phase index for a 1-based over: 0 = Powerplay, 1 = middle, 2 = death.
# Single source of truth for phase boundaries (BB2).
static func phase_of(over: int) -> int:
	if over <= POWERPLAY_OVERS:
		return 0
	if over < DEATH_START_OVER:
		return 1
	return 2

# 1-based over number -> Intent band for that over.
func for_over(over: int) -> int:
	match IntentPlan.phase_of(over):
		0:
			return powerplay
		1:
			return middle
		_:
			return death
```

(Replace the existing `for_over` body.)

- [ ] **Step 4: `--import` once (new test script), run suite, verify green**

```sh
pgrep -x Godot || true   # must be empty — quit the editor first
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && \
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: count climbs to **399**, `All tests passed`.

- [ ] **Step 5: Commit**

```sh
git add scripts/data/intent_plan.gd tests/unit/test_bowling_balance.gd
git commit -m "IntentPlan.phase_of: single source of truth for phase boundaries (BB2)"
```

(No `.uid` for test scripts; `intent_plan.gd.uid` already tracked.)

---

### Task 2: matchup term inside the ball atom (BB3)

**Files:**
- Modify: `scripts/data/ball_tuning.gd`, `scripts/domain/ball_resolver.gd`
- Test: `tests/unit/test_bowling_balance.gd`

- [ ] **Step 1: Write the failing tests** (append to `test_bowling_balance.gd`)

```gdscript
func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

# bowler_kind = -1 must ignore the matchup tables entirely (BB9).
func test_resolve_ball_kind_default_is_byte_identical() -> void:
	var t := BallTuning.new()
	t.matchup_w_spin = [5.0, 5.0, 5.0]  # poison: would near-guarantee wickets if read
	t.matchup_w_pace = [5.0, 5.0, 5.0]
	for seed_value in range(1, 200):
		var a := BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value))
		var b := BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value), 1.0, 1.0, -1)
		assert_eq(a.wicket, b.wicket, "wicket identical (seed %d)" % seed_value)
		assert_eq(a.runs, b.runs, "runs identical (seed %d)" % seed_value)

# Slogging spin out-dies slogging pace at equal stats (default strawman table).
func test_aggressive_vs_spin_out_dies_aggressive_vs_pace() -> void:
	var t := BallTuning.new()
	var pace_w := 0
	var spin_w := 0
	for seed_value in range(1, 4001):
		if BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value), 1.0, 1.0, BowlingPlan.Kind.PACE).wicket:
			pace_w += 1
		if BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.AGGRESSIVE, t, _rng(seed_value), 1.0, 1.0, BowlingPlan.Kind.SPIN).wicket:
			spin_w += 1
	assert_gt(spin_w, pace_w, "AGG-vs-spin (%d) takes more wickets than AGG-vs-pace (%d)" % [spin_w, pace_w])

# The term reads the table by intent: zero entries = no shift.
func test_matchup_zero_entries_do_not_shift() -> void:
	var t := BallTuning.new()
	for seed_value in range(1, 200):
		var a := BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.BALANCED, t, _rng(seed_value), 1.0, 1.0, -1)
		var b := BallResolver.resolve_ball(5, 5, 5.0, 5.0, BallResolver.Intent.BALANCED, t, _rng(seed_value), 1.0, 1.0, BowlingPlan.Kind.SPIN)
		assert_eq(a.wicket, b.wicket, "BAL-vs-spin default 0.0 -> identical (seed %d)" % seed_value)
		assert_eq(a.runs, b.runs, "runs identical (seed %d)" % seed_value)
```

(Default strawman: only `matchup_w_spin[AGG]` is non-zero, so BAL-vs-spin must be a no-op. Expected separation in the directional test: p≈6.2% vs ≈8.2% over 4000 paired seeds — far beyond noise.)

- [ ] **Step 2: Run suite, verify red** (missing `matchup_w_*` members / unknown 10th arg)

- [ ] **Step 3: Implement**

`scripts/data/ball_tuning.gd` — append:

```gdscript
# --- Intent x bowler-kind matchup (BB3): added to the wicket logit when the
# bowler's kind is known. Indexed by BallResolver.Intent [DEF, BAL, AGG].
# Strawman: only slogging spin is extra-risky (stumped / holed out to the deep).
@export var matchup_w_pace: Array[float] = [0.0, 0.0, 0.0]
@export var matchup_w_spin: Array[float] = [0.0, 0.0, 0.30]
```

`scripts/domain/ball_resolver.gd` — extend the signature and stage 1:

```gdscript
static func resolve_ball(
		bat_power: int,
		bat_composure: int,
		bowl_attack: float,
		bowl_control: float,
		intent: Intent,
		tuning: BallTuning,
		rng: RandomNumberGenerator,
		wicket_mult: float = 1.0,
		runs_mult: float = 1.0,
		bowler_kind: int = -1
) -> BallOutcome:
	# Stage 1 — wicket roll (Composure vs Attack), in log-odds; jokers scale p_wicket.
	# bowler_kind (BowlingPlan.Kind, -1 = unknown) adds the intent x kind matchup
	# term (BB3) — e.g. slogging spin carries extra wicket risk.
	var matchup := 0.0
	if bowler_kind == BowlingPlan.Kind.PACE:
		matchup = tuning.matchup_w_pace[intent]
	elif bowler_kind == BowlingPlan.Kind.SPIN:
		matchup = tuning.matchup_w_spin[intent]
	var logit_w := tuning.base_w + tuning.k_w * (bowl_attack - bat_composure) + tuning.intent_w[intent] + matchup
```

(Rest of the function unchanged.)

- [ ] **Step 4: Run suite, verify green** — count **402**, `All tests passed`.

- [ ] **Step 5: Commit**

```sh
git add scripts/data/ball_tuning.gd scripts/domain/ball_resolver.gd tests/unit/test_bowling_balance.gd
git commit -m "Intent x bowler-kind matchup term in resolve_ball (BB3): slogging spin is extra-risky; -1 kind = byte-identical"
```

---

### Task 3: per-kind phase bonus at the profile lookup (BB1, BB4)

**Files:**
- Modify: `scripts/data/innings_tuning.gd`, `scripts/domain/innings_resolver.gd`
- Test: `tests/unit/test_bowling_balance.gd`

- [ ] **Step 1: Write the failing tests** (append)

```gdscript
var _bt := BallTuning.new()
var _it := InningsTuning.new()

# Helper-level: the phase bonus lands on both stats, floored at 1.0.
func test_phased_profile_applies_kind_phase_bonus() -> void:
	var atk := BowlingAttack.new(5, 5)  # pace (7,3) / spin (3,7)
	var it := InningsTuning.new()
	it.pace_phase_bonus = [0.7, -0.7, 0.7]
	it.spin_phase_bonus = [-0.7, 0.7, -0.7]
	var pp_pace := InningsResolver.phased_profile(atk, BowlingPlan.Kind.PACE, 3, it)
	assert_almost_eq(pp_pace.x, 7.7, 0.001, "pace PP attack 7 + 0.7")
	assert_almost_eq(pp_pace.y, 3.7, 0.001, "pace PP control 3 + 0.7")
	var mid_pace := InningsResolver.phased_profile(atk, BowlingPlan.Kind.PACE, 10, it)
	assert_almost_eq(mid_pace.x, 6.3, 0.001, "pace middle attack 7 - 0.7")
	var mid_spin := InningsResolver.phased_profile(atk, BowlingPlan.Kind.SPIN, 10, it)
	assert_almost_eq(mid_spin.y, 7.7, 0.001, "spin middle control 7 + 0.7")
	it.spin_phase_bonus = [-9.0, 0.0, 0.0]
	var floored := InningsResolver.phased_profile(atk, BowlingPlan.Kind.SPIN, 1, it)
	assert_almost_eq(floored.x, 1.0, 0.001, "floored at 1.0")

# Player-bowled overs carry no kind (BB4): -1 if player bowling, else bowler_type.
func test_ball_kind_player_override() -> void:
	assert_eq(InningsResolver.ball_kind(true, BowlingPlan.Kind.SPIN), -1, "player bowling -> -1")
	assert_eq(InningsResolver.ball_kind(false, BowlingPlan.Kind.SPIN), BowlingPlan.Kind.SPIN, "team over -> plan kind")
	assert_eq(InningsResolver.ball_kind(false, -1), -1, "no rotation -> -1")

# Scalar path (no bowling plan) must not read the new dials at all (BB9).
func test_scalar_innings_ignores_phase_dials() -> void:
	var poisoned := InningsTuning.new()
	poisoned.pace_phase_bonus = [9.0, 9.0, 9.0]
	poisoned.spin_phase_bonus = [-9.0, -9.0, -9.0]
	for seed_value in range(1, 30):
		var a := InningsResolver.simulate_innings(null, 5, 5, 5, _bt, _it, _rng(seed_value))
		var b := InningsResolver.simulate_innings(null, 5, 5, 5, _bt, poisoned, _rng(seed_value))
		assert_eq(a.total, b.total, "scalar total identical (seed %d)" % seed_value)
		assert_eq(a.wickets, b.wickets, "scalar wickets identical (seed %d)" % seed_value)

# Directional (the real-benchmark shape, defaults on): pace out-wickets spin in
# a pure-Powerplay innings (over_limit = 6).
func test_pace_takes_more_powerplay_wickets_than_spin() -> void:
	var it := InningsTuning.new()
	it.over_limit = 6
	var atk := BowlingAttack.new(5, 5)
	var pace_w := 0
	var spin_w := 0
	for seed_value in range(1, 61):
		pace_w += InningsResolver.simulate_innings(null, 5, 5, 5, _bt, it, _rng(seed_value), 0, null, atk, BowlingPlan.pace_only()).wickets
		spin_w += InningsResolver.simulate_innings(null, 5, 5, 5, _bt, it, _rng(seed_value), 0, null, atk, BowlingPlan.spin_only()).wickets
	assert_gt(pace_w, spin_w, "PP: pace wickets (%d) > spin wickets (%d)" % [pace_w, spin_w])

# Directional: a spin middle (textbook P/S/P) concedes less than all-pace.
func test_spin_middle_concedes_less_than_pace_middle() -> void:
	var atk := BowlingAttack.new(5, 5)
	var psp := 0
	var ppp := 0
	for seed_value in range(1, 61):
		psp += InningsResolver.simulate_innings(null, 5, 5, 5, _bt, _it, _rng(seed_value), 0, null, atk, BowlingPlan.textbook()).total
		ppp += InningsResolver.simulate_innings(null, 5, 5, 5, _bt, _it, _rng(seed_value), 0, null, atk, BowlingPlan.pace_only()).total
	assert_lt(psp, ppp, "P/S/P conceded (%d) < P/P/P conceded (%d)" % [psp, ppp])
```

- [ ] **Step 2: Run suite, verify red** (missing `phased_profile`/`ball_kind`/dials)

- [ ] **Step 3: Implement**

`scripts/data/innings_tuning.gd` — append:

```gdscript
# Per-kind phase effectiveness bonus (BB1), added to BOTH attack and control at
# the profile lookup, indexed by IntentPlan.phase_of [PP, middle, death].
# Mirrored signs keep the per-phase sum across kinds ~zero. Real-T20 shape:
# pace owns the Powerplay + death, spin owns the middle (E1 spec §10.3).
@export var pace_phase_bonus: Array[float] = [0.7, -0.7, 0.7]
@export var spin_phase_bonus: Array[float] = [-0.7, 0.7, -0.7]
```

`scripts/domain/innings_resolver.gd` — two new statics above `_build_batters`:

```gdscript
# The over's effective bowling profile: kind profile + that kind's phase bonus
# on both stats (BB1), floored at 1.0. Pure; unit-tested directly.
static func phased_profile(attack: BowlingAttack, kind: int, over: int, itun: InningsTuning) -> Vector2:
	var prof := attack.profile(kind)
	var ph := IntentPlan.phase_of(over)
	var bonus: float = itun.pace_phase_bonus[ph] if kind == BowlingPlan.Kind.PACE else itun.spin_phase_bonus[ph]
	return Vector2(maxf(1.0, prof.x + bonus), maxf(1.0, prof.y + bonus))

# The bowler kind resolve_ball sees: the Player's bowling kind is deferred
# (player-as-bowler D4), so Player-bowled overs carry no kind (BB4).
static func ball_kind(player_bowling: bool, bowler_type: int) -> int:
	return -1 if player_bowling else bowler_type
```

In `simulate_innings`, replace this block (currently right after the intent/Form lines):

```gdscript
		var bat_attack := opp_attack
		var bat_control := opp_control
		if bowling_attack != null and bowling_plan != null:
			var prof := bowling_attack.profile(bowling_plan.for_over(over))
			bat_attack = prof.x
			bat_control = prof.y
```

with (hoists `bowler_type` so the profile site can use it):

```gdscript
		var bat_attack := opp_attack
		var bat_control := opp_control
		var bowler_type := -1  # current over's BowlingPlan.Kind (C2d/BB3); -1 = no rotation
		if bowling_plan != null:
			bowler_type = bowling_plan.for_over(over)
		if bowling_attack != null and bowling_plan != null:
			var prof := phased_profile(bowling_attack, bowler_type, over, itun)
			bat_attack = prof.x
			bat_control = prof.y
```

Then DELETE the now-duplicate later block:

```gdscript
		var bowler_type := -1  # current over's BowlingPlan.Kind (C2d); -1 = no rotation
		if bowling_plan != null:
			bowler_type = bowling_plan.for_over(over)
```

Finally, extend the `resolve_ball` call with the kind (BB4):

```gdscript
			var o := BallResolver.resolve_ball(
				s["power"], s["composure"], bat_attack, bat_control,
				intent, tuning, rng, jm.x * win.x * opp_win.x, jm.y * win.y * opp_win.y,
				ball_kind(player_bowling, bowler_type))
```

- [ ] **Step 4: Run suite — judge fallout honestly**

Expected: the 6 new tests pass (count **408**). Pre-existing rotation-path tests may shift (defaults changed where a bowling plan is active): determinism/null-regression tests must still pass untouched; any *threshold* test that fails gets inspected — adjust only if the failure is the mechanic working as specced (record which in the commit message). Byte-identity (scalar) tests must NOT need touching — if one fails, the wiring is wrong (BB9).

- [ ] **Step 5: Commit**

```sh
git add scripts/data/innings_tuning.gd scripts/domain/innings_resolver.gd tests/unit/test_bowling_balance.gd
git commit -m "Phase-dependent pace/spin bonus at the profile lookup (BB1) + kind into resolve_ball, -1 on Player overs (BB4)"
```

---

### Task 4: tuning loop vs the E1 oracle (BB5, BB6)

**Files:**
- Modify (as the loop dictates): `scripts/data/innings_tuning.gd`, `scripts/data/ball_tuning.gd`, `scripts/data/team.gd`
- Test: `tests/unit/test_bowling_balance.gd` (archetype tests, only if the BB5 tail lever is adopted)
- Oracle: `tools/sweep_policy_selfplay.gd` (read-only)

- [ ] **Step 1: Smoke the oracle**

```sh
E1_QUICK=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_policy_selfplay.gd
```

(~2 min.) Read: per-iter best-response labels + gains, final A/B policies, equilibrium flag, gap arms.

- [ ] **Step 2: Evaluate against §6 acceptance (quick-mode = directional only)**

1. No constant-kind (S/S/S or P/P/P) stable equilibrium, both sides.
2. Textbook vs all-AGG (read `A/A/A·P/S/P` and nearby rows in the iter-0 landscape vs the textbook incumbent): within ±5 pts of even.
3. Iter-0 best-response gain over textbook ≤ 8 pts.
4. Best-found vs naive ≥ ~+15 over mirror (gap arms).

- [ ] **Step 3: If all-AGG still dominates → BB5 lever 1, tail steepening (Nico's call)**

First the failing tests (append to `test_bowling_balance.gd`):

```gdscript
# BB5 lever 1 — archetype sharpening conserves the 20-point build equality.
func test_archetypes_remain_20_point_builds() -> void:
	for a in [Team.archetype_batter(), Team.archetype_bowler(), Team.archetype_allrounder()]:
		assert_eq(a.power + a.composure + a.attack + a.control, 20, "every archetype is exactly 20 points")

func test_sharpened_tail_is_steeper() -> void:
	var bat := Team.archetype_batter()
	var bowl := Team.archetype_bowler()
	assert_eq(bat.power, 9, "sharpened batter power 9")
	assert_eq(bowl.power, 1, "sharpened bowler power 1")
	assert_eq(bowl.attack, 9, "sharpened bowler attack 9")
```

Then in `scripts/data/team.gd`:

```gdscript
static func archetype_batter() -> Attributes:
	var a := Attributes.new()
	a.power = 9; a.composure = 9; a.attack = 1; a.control = 1
	return a

static func archetype_bowler() -> Attributes:
	var a := Attributes.new()
	a.power = 1; a.composure = 1; a.attack = 9; a.control = 9
	return a
```

Run the full suite — any `test_team.gd` assertions on 8/2 stats or the 122/98 split get updated to the new sharpened values (126/94; mechanically justified, note in commit). Re-smoke the oracle.

- [ ] **Step 4: If STILL dominant → BB5 lever 2, `intent_w[AGGRESSIVE]`**

Raise `intent_w[2]` in `scripts/data/ball_tuning.gd` in +0.1 steps (0.60 → max ~0.90), re-running the smoke each step. Prefer the smallest move that passes §6. (Also available if criterion 2 over-shoots the other way — all-AGG collapsing 20+ pts *below* textbook — in which case back off the matchup/tilt magnitudes instead of intent_w.)

- [ ] **Step 5: Dial polish**

If criteria are near-misses, adjust `pace_phase_bonus`/`spin_phase_bonus` (±0.2 steps) and `matchup_w_spin[AGG]` (±0.1) — smallest total deviation from strawman that passes. Keep mirrored signs (scoring-environment-neutral).

- [ ] **Step 6: Full oracle run (final acceptance)**

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_policy_selfplay.gd
```

(~15 min — run backgrounded, nothing else Godot meanwhile.) All §6 criteria on full-N numbers. Save the DATA block → update `docs/mockups/policy-selfplay-v1.html` DATA.

- [ ] **Step 7: Full test suite green, then commit**

```sh
git add -A scripts/ tests/ docs/mockups/policy-selfplay-v1.html
git commit -m "Bowling-balance tuning: <final dials> pass E1-oracle acceptance (no constant-kind equilibrium, textbook competitive)"
```

---

### Task 5: ripple re-verification (BB7)

**Files:**
- Oracles (read-only): `tools/sweep_jokers.gd`, `tools/build_spectrum_sweep.gd`, `tools/sweep_economy.gd`, `tools/probe_side_asymmetry.gd`
- Modify if bands/prices move: `scripts/data/joker_catalog.gd` (magnitudes/`PRICES`), `docs/joker-pool-v1.md`, viewer DATA blocks (`docs/mockups/economy-v1.html` + joker viewer)

Run each sweep SEQUENTIALLY (one Godot process at a time):

- [ ] **Step 1: New fair-fight floor** — `sweep_jokers.gd` no-joker arm; record the number (replaces 48.9%; honesty, not a target).
- [ ] **Step 2: 45 joker bands** — both profiles vs the new floor. Bands per `docs/joker-pool-v1.md`. Blown bands: dial-only re-tunes (magnitudes in `joker_catalog.gd`), DRS-rung precedent — no mechanic changes here.
- [ ] **Step 3: Prices** — DE4 interpolation (economy spec `2026-06-10-tons-economy-7cD-design.md`) on the fresh realized deltas for any joker whose delta moved bands-relevantly; mirror pool doc + viewer DATA.
- [ ] **Step 4: Build spread** — `build_spectrum_sweep.gd`: win-rate spread across builds ≤ ~3 pts.
- [ ] **Step 5: Pay spread** — `sweep_economy.gd`: ≤ ₸1 across builds, fee share ~50%.
- [ ] **Step 6: DRS symmetry regression** — `probe_side_asymmetry.gd`: DRS-both mirror still ~49/49.
- [ ] **Step 7: Commit** per artefact group (floor+bands, prices, verifications), descriptive messages.

If Step 4 or 5 FAILS its bar: the tail lever (if adopted) is the likely cause — first try gap-fill-respecting fixes (it self-adapts), then reduce sharpening to batter-only or revert lever 1 and lean on `intent_w` (note the trade in §10 findings).

---

### Task 6: close-out (docs, PR, merge)

- [ ] **Step 1: Spec §10 findings** — fill in: final dials, oracle headline (equilibrium status, textbook standing, all-AGG gap, skill gap), new floor, bands moved/re-priced, build/pay spreads, BB5 levers adopted or not and why.
- [ ] **Step 2: Roadmap** — update Current status / Last closed / Next session handoff (next rung: E2 conditional policy per the approved queue).
- [ ] **Step 3: Full suite green; clean `git status`.**
- [ ] **Step 4: PR + merge**

```sh
git push && gh pr create --title "Bowling balance: phase-dependent pace/spin tilt + intent x kind matchup + wicket-cost re-price" --body "<summary per template>" && gh pr merge --merge --delete-branch
```

Then sync local `main`.

---

## Self-review notes

- Spec coverage: BB1→T3, BB2→T1, BB3→T2, BB4→T3 (`ball_kind`), BB5→T4 S3/S4, BB6→T4 S2/S6, BB7→T5, BB8 (no task — deferred), BB9→T2 S1 + T3 tests, BB10→dials in tuning resources throughout. ✓
- Counts after T1/T2/T3: 399/402/408 (+2/+3/+6); T4 may add +2 (archetype tests). Thresholds in directional tests checked against the logistic math (separations ≫ noise). ✓
- `phased_profile` returns `Vector2` (floats) — bowling params downstream are floats since PR #31. ✓
