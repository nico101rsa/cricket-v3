# Fair-Fight Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a no-joker match at even ★3 a genuine even contest (~48–50%) by giving both teams the same base captain tools (boost + DRS), and add a run-margin readout to the sweep.

**Architecture:** The sim models an innings from the Player's single viewpoint (one `JokerRuntime`). We add a **second `JokerRuntime` for the opponent**, constructed with an empty joker list, fed the opponent's perspective — so it fires only the *base* boost + DRS rules (no joker modifiers, no payoffs). The Player's existing paths are untouched; the opponent runtime is purely additive, threaded as off-by-default trailing params so every existing caller stays byte-identical.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Test command (whole suite, <1s):
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
After adding/renaming any script run `--import` once first. Quit the Godot editor before headless runs. Judge **red** by parse-error / failing-assert, **green** by total count climbing + "All tests passed".

---

## Spec reference

`docs/superpowers/specs/2026-06-09-fair-fight-baseline-design.md` (decisions DF1–DF6).

## File structure

- `scripts/data/drs_policy.gd` — `base_reviews` 1 → 2 (DF3).
- `scripts/domain/innings_resolver.gd` — team-wide Player review gate (DF3); opponent runtime: boost press, per-ball `opp_win` multipliers, opponent dismissal review (DF2/DF4/DF5). Two new trailing params.
- `scripts/domain/match_resolver.gd` — thread `opp_boost_plan` / `opp_drs_policy` through `simulate_match` + `simulate_match_teams` to both innings.
- `tools/sweep_jokers.gd` — symmetric opp intent; give the opponent a `DRSPolicy` + `BoostPlan`; add `margin` to `_scenario` + print mean-margin per arm.
- `tests/unit/test_fair_fight_baseline.gd` — new behaviour tests (created in Task 1).

**Note on rebaselining:** the DRS/boost changes add `randf` draws (more reviews attempted), so any test that runs a full match or innings *with a `drs_policy` or `boost_plan` set* and asserts an exact score/outcome will shift. Determinism still holds (same seed → same result). When a task says "rebaseline", run the suite, read each failing assertion's actual value, confirm it's a value-shift (not a structural break), and update the expected value. Tests that pass `null` for boost/DRS are unaffected.

---

### Task 1: Player DRS reviews any team dismissal (DF3)

**Files:**
- Modify: `scripts/domain/innings_resolver.gd:188`
- Test: `tests/unit/test_fair_fight_baseline.gd` (create)

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_fair_fight_baseline.gd`. This test builds an innings where a **non-hero** batter is the first dismissed, with a high-success DRS, and asserts the review can save a teammate (more balls survived than with no DRS). We compare two seeded runs: one with a `drs_policy` (base_p high) and one without — the DRS run must concede fewer total wickets over a fixed innings, proving reviews now fire on teammate dismissals (not only the hero's).

```gdscript
extends GutTest

# Fair-fight baseline (spec 2026-06-09): team-wide DRS, 2 reviews, opponent base
# boost + DRS. resolve_ball owns the RNG draw order; same seed -> same result.

func _tuning() -> BallTuning:
	return BallTuning.new()

func _itun() -> InningsTuning:
	return InningsTuning.new()

func _rng(seed_val: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

# DF3: with a high-success DRS, a derived (non-hero) innings still gets reviews on
# dismissals -> fewer wickets fall than with no DRS. Pre-fix this was hero-only, so
# a null-player innings got ZERO reviews; now any dismissal can be reviewed.
func test_drs_reviews_any_dismissal_not_just_hero() -> void:
	var hi := DRSPolicy.new()
	hi.base_reviews = 50      # effectively unlimited for the test
	hi.base_p = 1.0           # always overturns
	var no_drs := InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(42))
	var with_drs := InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(42), 0, null, null, null,
		0, 0, 0, [], true, null, null, null, hi)
	assert_lt(with_drs.wickets, no_drs.wickets,
		"team-wide DRS should save non-hero batters too")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -20`
Expected: the new test FAILS (`with_drs.wickets` == `no_drs.wickets`, because the review only fired on `s["is_player"]` and this innings has no hero).

- [ ] **Step 3: Drop the `is_player` gate**

In `scripts/domain/innings_resolver.gd`, line ~188, change:

```gdscript
			if player_is_batting and o.wicket and s["is_player"]:
```
to:
```gdscript
			if player_is_batting and o.wicket:
```

- [ ] **Step 4: Run the test to verify it passes**

Run the suite (same command as Step 2). Expected: the new test PASSES.

- [ ] **Step 5: Rebaseline any shifted tests**

Run the full suite. For each *other* failing test, confirm it sets a `drs_policy` and asserts an exact score/outcome that shifted (a value change, not a structural break), and update the expected value. Re-run until "All tests passed".

- [ ] **Step 6: Commit**

```bash
git add scripts/domain/innings_resolver.gd tests/unit/test_fair_fight_baseline.gd
git commit -m "Fair-fight Task 1: Player DRS reviews any team dismissal (DF3)"
```

---

### Task 2: Two DRS reviews per innings (DF3)

**Files:**
- Modify: `scripts/data/drs_policy.gd:10`
- Test: `tests/unit/test_fair_fight_baseline.gd`

- [ ] **Step 1: Write the failing test**

Add to `test_fair_fight_baseline.gd`. With `base_p = 0.0` (every review fails) the pool drains by 1 per dismissal; the default count must now be 2 — assert the policy default.

```gdscript
# DF3: real T20 allows 2 unsuccessful reviews per innings.
func test_default_review_count_is_two() -> void:
	assert_eq(DRSPolicy.new().base_reviews, 2, "base_reviews default should be 2 (T20 rule)")
```

- [ ] **Step 2: Run to verify it fails**

Run the suite. Expected: FAIL (`base_reviews` is still 1).

- [ ] **Step 3: Bump the default**

In `scripts/data/drs_policy.gd`, line 10:
```gdscript
var base_reviews: int = 1
```
to:
```gdscript
var base_reviews: int = 2
```

- [ ] **Step 4: Run to verify it passes**

Run the suite. Expected: the new test PASSES.

- [ ] **Step 5: Rebaseline shifted tests**

Any test that set a `drs_policy` and relied on exactly 1 review will shift (now 2 reviews available). Confirm value-shift and update expected values. Re-run until "All tests passed".

- [ ] **Step 6: Commit**

```bash
git add scripts/data/drs_policy.gd tests/unit/test_fair_fight_baseline.gd
git commit -m "Fair-fight Task 2: DRS base_reviews 1 -> 2 (T20 rule, DF3)"
```

---

### Task 3: Opponent base boost + DRS in `simulate_innings` (DF2/DF4/DF5)

**Files:**
- Modify: `scripts/domain/innings_resolver.gd` (signature + loop body)
- Test: `tests/unit/test_fair_fight_baseline.gd`

- [ ] **Step 1: Write the failing tests**

Add to `test_fair_fight_baseline.gd`. Two behaviours: (a) an opponent batting innings with a runs-boost scores more; (b) opponent base DRS saves opponent wickets. Both use the *new* trailing params `opp_boost_plan` / `opp_drs_policy` (params 23 & 24).

```gdscript
# DF4: the opponent's own boost buffs the opponent's batting innings (more runs).
func test_opponent_boost_lifts_opponent_innings() -> void:
	var boost := BoostPlan.at([1, 10, 16])
	# player_is_batting = false -> this is the opponent's batting innings.
	var base := InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], false)
	var boosted := InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], false, null, null, null, null, null, [], 0, boost, null)
	assert_gt(boosted.total, base.total, "opponent boost should lift the opponent's score")

# DF5: the opponent reviews to survive its own dismissals (base rule, no jokers).
func test_opponent_drs_saves_opponent_wickets() -> void:
	var hi := DRSPolicy.new()
	hi.base_reviews = 50
	hi.base_p = 1.0
	var base := InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], false)
	var saved := InningsResolver.simulate_innings(
		null, 5, 5.0, 5.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], false, null, null, null, null, null, [], 0, null, hi)
	assert_lt(saved.wickets, base.wickets, "opponent DRS should save opponent batters")
```

- [ ] **Step 2: Run to verify they fail**

Run the suite. Expected: parse error / FAIL — `simulate_innings` does not yet accept `opp_boost_plan` / `opp_drs_policy` (the calls pass extra args).

- [ ] **Step 3: Add the two trailing params**

In `scripts/domain/innings_resolver.gd`, extend the `simulate_innings` signature (after `team_bat_offset: int = 0`, line ~106):

```gdscript
		batting_roster: Array = [],
		team_bat_offset: int = 0,
		opp_boost_plan: BoostPlan = null,
		opp_drs_policy: DRSPolicy = null
) -> InningsResult:
```

- [ ] **Step 4: Create + init the opponent runtime**

After the Player `runtime` is created (line ~123–125), add:

```gdscript
	var opp_is_batting := not player_is_batting   # the opponent's perspective
	var opp_runtime := JokerRuntime.new()         # DF2 — opponent base captain tools (no jokers)
	if opp_drs_policy != null:
		opp_runtime.init_reviews([], opp_drs_policy.base_reviews)
```

- [ ] **Step 5: Fire the opponent boost press**

Immediately after the Player boost-press block (line ~176–177), add:

```gdscript
		# DF4 — the opponent presses its own Boost (base buff, no jokers), side-aware.
		if opp_boost_plan != null and balls == (over - 1) * 6 and opp_boost_plan.presses_on(over):
			opp_runtime.on_boost_press([], opp_is_batting, intent, opp_boost_plan.base_mult, opp_boost_plan.base_n, balls + 1)
```

- [ ] **Step 6: Fold the opponent multipliers into resolve_ball**

Change the `win` line + the `resolve_ball` call (lines ~179–182). Add `opp_win` and multiply it in:

```gdscript
		var win := runtime.tick_mults(player_is_batting)  # C2c — active windowed buffs
		var opp_win := opp_runtime.tick_mults(opp_is_batting)  # DF2 — opponent base buffs
		var o := BallResolver.resolve_ball(
			s["power"], s["composure"], bat_attack, bat_control,
			intent, tuning, rng, jm.x * win.x * opp_win.x, jm.y * win.y * opp_win.y)
```

(Because `tick_mults` is side-filtered, `opp_win.x` carries the opponent's wicket buff only when it bowls, `opp_win.y` its runs buff only when it bats — so multiplying both is always correct.)

- [ ] **Step 7: Add the opponent survival review**

After the existing Player DRS block (the `if drs_policy != null:` block ending ~line 193), add:

```gdscript
			# DF5 — opponent base DRS: review to survive its own dismissal (no jokers,
			# no payoffs). Only in the opponent's batting innings.
			if opp_drs_policy != null and (not player_is_batting) and o.wicket:
				if opp_runtime.try_review([], true, intent, opp_drs_policy.base_p, balls + 1, rng):
					o = BallOutcome.new(false, 0)
```

- [ ] **Step 8: Decay the opponent buffs each ball**

After the Player `runtime.on_ball_end(...)` call (line ~209), add:

```gdscript
		opp_runtime.on_ball_end([], opp_is_batting, balls, false)  # DF2 — decay opponent buffs
```

- [ ] **Step 9: Run to verify the new tests pass**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && <suite cmd>`
Expected: `test_opponent_boost_lifts_opponent_innings` and `test_opponent_drs_saves_opponent_wickets` PASS.

- [ ] **Step 10: Rebaseline shifted tests**

The opponent-review block adds `randf` draws only when `opp_drs_policy` is set, and the multipliers only change when `opp_*` params are set — so existing callers (which pass neither) are byte-identical. Confirm the suite is green except for any test that explicitly set the new params; rebaseline those. Re-run until "All tests passed".

- [ ] **Step 11: Commit**

```bash
git add scripts/domain/innings_resolver.gd tests/unit/test_fair_fight_baseline.gd
git commit -m "Fair-fight Task 3: opponent base boost + DRS in simulate_innings (DF2/DF4/DF5)"
```

---

### Task 4: Thread opponent tools through `match_resolver` (DF2)

**Files:**
- Modify: `scripts/domain/match_resolver.gd` (both `simulate_match` and `simulate_match_teams`)
- Test: `tests/unit/test_fair_fight_baseline.gd`

- [ ] **Step 1: Write the failing test**

Add to `test_fair_fight_baseline.gd`. A full match where the opponent has a strong base boost+DRS should make the Player win *less* than with a passive opponent (the opponent is now armed). Uses `simulate_match_teams`' new trailing params.

```gdscript
func _tour() -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = 5; t.spread = 1.5; t.noise = 1
	return t

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	return a

# DF2: arming the opponent with base boost + DRS lowers the Player's win-rate
# (the fight gets fairer). Compare 200 matches with vs without opponent tools.
func test_opponent_tools_lower_player_winrate() -> void:
	var boost := BoostPlan.at([1, 10, 16])
	var drs := DRSPolicy.new()  # base 2 reviews, p=0.4
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	var wins_passive := 0
	var wins_armed := 0
	for i in 200:
		var rp := _rng(1000 + i)
		var mp := MatchResolver.simulate_match_teams(_attrs(), pt, ot, _tour(),
			_tuning(), _itun(), rp)
		if mp.outcome == MatchResult.Outcome.PLAYER_WIN: wins_passive += 1
		var ra := _rng(1000 + i)
		var ma := MatchResolver.simulate_match_teams(_attrs(), pt, ot, _tour(),
			_tuning(), _itun(), ra, null, null, [], null, null, null, null, null, null, boost, drs)
		if ma.outcome == MatchResult.Outcome.PLAYER_WIN: wins_armed += 1
	assert_lt(wins_armed, wins_passive, "arming the opponent should lower the Player win-rate")
```

(Note the `simulate_match_teams` trailing args: after `opp_field_plan` come the new `opp_boost_plan`, `opp_drs_policy` — added in Step 3.)

- [ ] **Step 2: Run to verify it fails**

Run the suite. Expected: parse error / FAIL — `simulate_match_teams` doesn't accept the two new args yet.

- [ ] **Step 3: Add params to `simulate_match` and pass to both innings**

In `scripts/domain/match_resolver.gd`, extend `simulate_match`'s signature (after `opp_bat_offset: int = 0`, line ~149):

```gdscript
		player_bat_offset: int = 0,
		opp_bat_offset: int = 0,
		opp_boost_plan: BoostPlan = null,
		opp_drs_policy: DRSPolicy = null
) -> MatchResult:
```

Then pass `opp_boost_plan, opp_drs_policy` as the final two args to **both** `InningsResolver.simulate_innings(...)` calls (the `player_bats_first` branch and the `else` branch — lines ~178–187 and ~190–198). Each call currently ends with `..., player_roster/opp_roster, *_bat_offset)`; append `, opp_boost_plan, opp_drs_policy)`.

- [ ] **Step 4: Add params to `simulate_match_teams` and forward them**

In `simulate_match_teams`, extend the signature (after `opp_field_plan: FieldPlan = null`, line ~87):

```gdscript
		opp_field_plan: FieldPlan = null,
		opp_boost_plan: BoostPlan = null,
		opp_drs_policy: DRSPolicy = null
) -> MatchResult:
```

Then in its `return simulate_match(...)` call (line ~112–119), append the two new args after `opp_bat_offset` (`opp_bat - ref3`):

```gdscript
		player_roster, opp_roster, player_bat - ref3, opp_bat - ref3,
		opp_boost_plan, opp_drs_policy)
```

- [ ] **Step 5: Run to verify it passes**

Run: `--import` then the suite. Expected: `test_opponent_tools_lower_player_winrate` PASSES.

- [ ] **Step 6: Rebaseline shifted tests**

Existing callers pass neither new arg → byte-identical. Rebaseline only tests that set them. Re-run until "All tests passed".

- [ ] **Step 7: Commit**

```bash
git add scripts/domain/match_resolver.gd tests/unit/test_fair_fight_baseline.gd
git commit -m "Fair-fight Task 4: thread opponent boost+DRS through match_resolver (DF2)"
```

---

### Task 5: Sweep — symmetric opponent + margin readout, verify ~48–50% (DF1/DF6)

**Files:**
- Modify: `tools/sweep_jokers.gd`
- (No unit test — this is the diagnostic oracle; verification is the printed baseline.)

- [ ] **Step 1: Make the opponent symmetric + armed**

In `tools/sweep_jokers.gd`, `_scenario` (line ~183–194): change `_opp_intent_plan()` to the Player's `_intent_plan()`, and give the opponent its own `BoostPlan` + `DRSPolicy`. Add two helpers and pass them as the new trailing args:

```gdscript
# DF1/DF4/DF5 — the opponent runs the same base game-plan (symmetric intent) and
# holds the same base captain tools (boost + DRS), minus jokers, so the no-joker
# baseline is a fair fight.
func _opp_boost_plan() -> BoostPlan:
	return BoostPlan.at([1, 10, 16])

func _opp_drs_policy() -> DRSPolicy:
	return DRSPolicy.new()
```

In the `simulate_match_teams(...)` call, replace `_opp_intent_plan()` with `_intent_plan()` and append the opponent tools:

```gdscript
	var m := MatchResolver.simulate_match_teams(a, pt, ot, _tour, _tuning, _itun, rng, _intent_plan(), _bowling_plan(), config, _field_plan(), _bowl_intent_plan(), _intent_plan(), _boost_plan(), _drs_policy(), _opp_field_plan(), _opp_boost_plan(), _opp_drs_policy())
```

- [ ] **Step 2: Add the margin readout (DM2)**

In `_scenario`, after computing `player_runs` / `won`, compute the run margin and return it:

```gdscript
	var p_inn := m.innings1 if not m.innings1.player_line().is_empty() else m.innings2
	var o_inn := m.innings2 if p_inn == m.innings1 else m.innings1
	var margin := p_inn.total - o_inn.total
	return {"player_runs": player_runs, "won": won, "margin": margin}
```

In the arms loop (after `win_rate` is computed, ~line 89), add a mean-margin per arm:

```gdscript
		var margins := Sweep.values_of(arm["records"], "margin")
		var margin_sum := 0.0
		for mg in margins:
			margin_sum += mg
		var mean_margin := margin_sum / margins.size()
```

Add to the `arms_json.append({...})` dict: `"mean_margin": mean_margin,` and `"margin_delta": mean_margin - baseline_margin,` (capture `baseline_margin` at `ai == 0`, mirroring `baseline_win`).

- [ ] **Step 3: Run the sweep and read the baseline**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_jokers.gd 2>&1 | tail -3`
Read the first arm ("Baseline (no jokers)") `win_rate` and `mean_margin`.
**Expected (DF6):** baseline win-rate ≈ **0.48–0.52** and mean_margin ≈ 0 (within ~±5 runs). If it is materially higher (e.g. >0.55), the opponent tooling is not fully wired — re-check Tasks 3–4.

- [ ] **Step 4: Commit**

```bash
git add tools/sweep_jokers.gd
git commit -m "Fair-fight Task 5: symmetric+armed opponent in sweep + margin readout (DF1/DF6)"
```

---

### Task 6: Verify, document, PR

**Files:**
- Modify: `PROJECT_ROADMAP.md`

- [ ] **Step 1: Full green suite**

Run the whole suite. Expected: "All tests passed", count ≥ 356 + the new tests. Record the number.

- [ ] **Step 2: Confirm determinism**

Re-run the suite once more; the determinism tests must still pass (same seed → same result).

- [ ] **Step 3: Update the roadmap**

In `PROJECT_ROADMAP.md`, move "fair-fight baseline" to done in the status/history, record the measured baseline win-rate, and refresh the **Next session** handoff to point at **rung 2 (the joker re-tune)** — note its spec is already written (`2026-06-09-joker-retune-rarity-bands-design.md`) and now runs against the honest baseline.

- [ ] **Step 4: Commit + push + PR**

```bash
git add PROJECT_ROADMAP.md
git commit -m "Roadmap: fair-fight baseline done; rung 2 = joker re-tune"
git push -u origin joker-retune-rarity-bands
gh pr create --title "Fair-fight baseline: symmetric opponent captain tools" --body "..."
```

Then merge the PR, sync local `main`, delete the branch (per commit policy).

---

## Self-review

- **Spec coverage:** DF1 (symmetric intent → Task 5) · DF2 (opponent runtime → Tasks 3–4) · DF3 (team-wide + 2 reviews → Tasks 1–2) · DF4 (opponent boost → Tasks 3, 5) · DF5 (opponent survive DRS; claim deferred → Task 3) · DF6 (~48–50% baseline → Task 5 Step 3). Margin readout (DM2) → Task 5 Step 2. All covered.
- **Placeholders:** none — every code step shows the code. (The PR `--body "..."` is filled at execution from the task summary.)
- **Type consistency:** `opp_boost_plan: BoostPlan` / `opp_drs_policy: DRSPolicy` used identically across `simulate_innings`, `simulate_match`, `simulate_match_teams`; `BoostPlan.at`, `DRSPolicy.new`, `JokerRuntime` methods (`init_reviews`, `on_boost_press`, `tick_mults`, `try_review`, `on_ball_end`) match their definitions; `BallOutcome.new(bool, int)` matches existing usage.
