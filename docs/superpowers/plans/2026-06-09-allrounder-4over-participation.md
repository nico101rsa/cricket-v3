# All-Rounder 4-Over Participation + Exact Conservation — Implementation Plan (Part 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the all-rounder bowl its full 4 overs (authenticity), let batting-ish builds bowl *somewhat*, and keep win-rate flat (win ≈ loss across builds) by upgrading bowling conservation to be *exact* (fractional) instead of integer-rounded.

**Architecture:** Three coupled changes, all validated by a spike (2026-06-09): (1) re-shape the build→overs curve so 5/5 hits the 4-over cap and 8/8 stays at 0; (2) make `_conserved_bowling` return an **exact float** (not a rounded int) and widen the bowling-stat params down the `simulate_match → simulate_innings → resolve_ball` chain to `float`, so a *weak* part-time bowler's overs are compensated exactly (the integer rounding under-compensated and dragged the team below par); (3) re-tune `bowl_concentration_k` 1.0→0.5 (exact conservation is tighter, so the old penalty over-corrects strong bowlers). Implements Part 1 of spec `2026-06-09-allrounder-viability-and-team-construction-design.md`. Parts 2 (Tons synergy bonus) and 3 (team construction) are recorded decisions, NOT built here.

**Tech Stack:** Godot 4.6.3 / GDScript, GUT 9.6. Test-first: red via parse-error/failing-assert, green by the suite count climbing/holding and `All tests passed`. Quit the Godot editor before headless runs (`pgrep -x Godot`).

---

## Spike-validated target (the numbers this plan reproduces)

With `gain=13, base=-2.6` (overs: 8/8→0, 7/7→1, 6/6→3, 5/5→4, 4/4+→4), exact float conservation, and `bowl_concentration_k=0.5`, the build-spectrum sweep reads:

```
build:  8/8  7/7  6/6  5/5  4/4  3/3  2/2
win%:  48.7 46.9 48.2 48.0 48.9 48.4 48.6   ← spread 2.0 (flatter than Slice-3's 4.1)
```

All builds land win ≈ loss (anchored to the batter's dead-even ~48.7), and the all-rounder bowls its full 4 overs.

## File structure

- **Modify** `scripts/data/innings_tuning.gd` — `bowl_overs_gain` 8→13, `bowl_overs_base` -2.5→-2.6, `bowl_concentration_k` 1.0→0.5.
- **Modify** `scripts/domain/ball_resolver.gd` — `resolve_ball` `bowl_attack`/`bowl_control` `int`→`float`.
- **Modify** `scripts/domain/innings_resolver.gd` — `simulate_innings` `opp_attack`/`opp_control` `int`→`float`.
- **Modify** `scripts/domain/match_resolver.gd` — `_conserved_bowling` returns `float`; `simulate_match` `player_team_attack`/`player_team_control`/`opp_attack`/`opp_control` `int`→`float`; round before `BowlingAttack.new` (rotation path).
- **Modify** `scripts/data/rating_tuning.gd` — re-derive par from the new 5/5 output if it shifted (Task 3).
- **Modify** `tests/unit/test_innings_resolver.gd` — update the 5/5→overs assertion + monotonic test.
- **Modify** `tests/unit/test_match_resolver.gd` — update `_conserved_bowling` tests to float + add the exact-conservation identity test.
- **Update (diagnostics)** spec §9 calibrated baseline.

---

### Task 1: Re-shape the bowling-overs curve

**Files:**
- Modify: `scripts/data/innings_tuning.gd:21-22`
- Test: `tests/unit/test_innings_resolver.gd:46-58`

- [ ] **Step 1: Update the failing tests to the new target shape**

In `tests/unit/test_innings_resolver.gd`, replace `test_even_build_bowls_part_time` (line 46-48) and the monotonic test's mid expectation:

```gdscript
func test_even_build_bowls_full_quota() -> void:
	var itun := InningsTuning.new()
	assert_eq(InningsResolver.player_overs(_attrs(5, 5, 5, 5), itun), 4, "all-rounder bowls the full 4-over quota (authenticity)")

func test_batting_ish_build_bowls_somewhat() -> void:
	var itun := InningsTuning.new()
	assert_eq(InningsResolver.player_overs(_attrs(7, 7, 3, 3), itun), 1, "a 7/7 bowls somewhat (~1 over), not zero (DA5)")
```

Then update `test_overs_monotonic_in_bowling_share` (line 54+) so its mid/bowler comparison uses `<=` (the all-rounder now ties the bowler at the 4 cap). Read lines 54-58 first; change any strict `mid < bowler` to `mid <= bowler` and keep `batter < mid`:

```gdscript
func test_overs_monotonic_in_bowling_share() -> void:
	var itun := InningsTuning.new()
	var batter := InningsResolver.player_overs(_attrs(8, 8, 2, 2), itun)
	var mid := InningsResolver.player_overs(_attrs(5, 5, 5, 5), itun)
	var bowler := InningsResolver.player_overs(_attrs(2, 2, 8, 8), itun)
	assert_lt(batter, mid, "more bowling share -> more overs (batter < all-rounder)")
	assert_lte(mid, bowler, "all-rounder up to the cap, bowler at the cap")
```

- [ ] **Step 2: Run the suite, verify these tests fail**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>/dev/null | grep -E "Failing|even_build|batting_ish"`
Expected: `test_even_build_bowls_full_quota` FAILS (current curve gives 5/5 → 2, not 4); `test_batting_ish_build_bowls_somewhat` FAILS (current gives 7/7 → 0).

- [ ] **Step 3: Re-shape the curve**

In `scripts/data/innings_tuning.gd`:

```gdscript
@export var bowl_overs_gain: float = 13.0
@export var bowl_overs_base: float = -2.6
```

(Gives overs 0,1,3,4,4,4,4 for builds 8/8…2/2 — spike-validated. `player_overs` itself is unchanged: `clamp(round(gain*share + base), 0, max)`.)

- [ ] **Step 4: Run the suite, verify green**

Run the import+test command. Expected: the two new tests PASS; `test_pure_batter_bowls_no_overs` (8/8→0) and `test_pure_bowler_bowls_full_quota` (2/2→4) still PASS; total holds at 353; `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/innings_tuning.gd scripts/data/innings_tuning.gd.uid tests/unit/test_innings_resolver.gd
git commit -m "Part 1 Task 1: all-rounder bowls full 4 overs (overs curve gain=13/base=-2.6)"
```

---

### Task 2: Exact (float) bowling conservation

**Files:**
- Modify: `scripts/domain/ball_resolver.gd:30-31`
- Modify: `scripts/domain/innings_resolver.gd:86-87` (`simulate_innings` `opp_attack`/`opp_control`)
- Modify: `scripts/domain/match_resolver.gd` (`_conserved_bowling` + `simulate_match` bowling params + `BowlingAttack.new` rounding)
- Test: `tests/unit/test_match_resolver.gd:291-305`

- [ ] **Step 1: Update + add the failing conservation tests**

In `tests/unit/test_match_resolver.gd`, replace the four `_conserved_bowling` tests (lines 291-305) with float versions + an exactness identity:

```gdscript
func test_conserved_bowling_no_overs_returns_scalar() -> void:
	assert_almost_eq(MatchResolver._conserved_bowling(5, 0, 8, 20), 5.0, 0.0001, "n=0 -> unchanged team scalar")

func test_conserved_bowling_neutral_player_unchanged() -> void:
	assert_almost_eq(MatchResolver._conserved_bowling(5, 2, 5, 20), 5.0, 0.0001, "player at team par -> no change")

func test_conserved_bowling_is_exact_not_rounded() -> void:
	# Strong bowler: 4 overs at attack 8, no concentration penalty -> exact 4.25, NOT rounded to 4.
	assert_almost_eq(MatchResolver._conserved_bowling(5, 4, 8, 20), 4.25, 0.0001, "(20*5 - 4*8)/16 = 4.25 exactly")

func test_conserved_bowling_weak_player_compensated_above_scalar() -> void:
	# Weak part-timer: 1 over at attack 3 -> teammates bowl ABOVE 5 to hold the total. This is
	# the case the old integer round() under-compensated (dragging the team below par).
	var c := MatchResolver._conserved_bowling(5, 1, 3, 20)
	assert_gt(c, 5.0, "a weak player's overs are compensated by stronger teammates (> scalar)")

func test_conserved_bowling_identity_holds_exactly() -> void:
	# The whole point: total team bowling = over_limit * scalar, for any n/player_stat (k=0).
	for case in [[5, 1, 3], [5, 4, 8], [6, 2, 4], [4, 3, 7]]:
		var s: int = case[0]; var n: int = case[1]; var stat: int = case[2]
		var c := MatchResolver._conserved_bowling(s, n, stat, 20)
		assert_almost_eq(n * stat + (20 - n) * c, float(20 * s), 0.0001,
			"team total bowling == over_limit*scalar for n=%d stat=%d" % [n, stat])

func test_conserved_bowling_floored_at_1() -> void:
	assert_almost_eq(MatchResolver._conserved_bowling(1, 4, 8, 20), 1.0, 0.0001, "result floored at 1.0")
```

- [ ] **Step 2: Run the suite, verify failure**

Run the import+test command. Expected: `test_conserved_bowling_is_exact_not_rounded` FAILS (current returns int 4, not 4.25); `test_conserved_bowling_identity_holds_exactly` FAILS (integer rounding breaks the identity).

- [ ] **Step 3: Make `_conserved_bowling` return an exact float**

In `scripts/domain/match_resolver.gd`, replace `_conserved_bowling` (lines 56-61):

```gdscript
static func _conserved_bowling(team_scalar: float, n: int, player_stat: int, overs: int,
		concentration_k: float = 0.0) -> float:
	if n <= 0 or n >= overs:
		return team_scalar
	var penalty := concentration_k * n * maxf(0.0, player_stat - team_scalar)
	return maxf(1.0, (overs * team_scalar - n * player_stat - penalty) / float(overs - n))
```

- [ ] **Step 4: Widen the bowling-stat params to float down the call chain**

The exact float must survive into `resolve_ball`. Widen these param types (int callers coerce to float automatically, so every existing scalar-path caller/test is byte-identical):

`scripts/domain/ball_resolver.gd` (lines 30-31):
```gdscript
		bowl_attack: float,
		bowl_control: float,
```

`scripts/domain/innings_resolver.gd` `simulate_innings` (lines 86-87):
```gdscript
		opp_attack: float,
		opp_control: float,
```

`scripts/domain/match_resolver.gd` `simulate_match` (lines 125-129) — widen the team bowling params:
```gdscript
		player_team_attack: float,
		player_team_control: float,
		opp_batting: int,
		opp_attack: float,
		opp_control: float,
```

Still in `simulate_match`, the rotation path constructs `BowlingAttack` from these (now float) values — round to int there so `BowlingAttack` (integer pace/spin profiles) is unaffected. Replace lines 166-167:
```gdscript
		opp_bowl = BowlingAttack.new(roundi(opp_attack), roundi(opp_control))
		player_bowl = BowlingAttack.new(roundi(player_team_attack), roundi(player_team_control))
```

*(Rationale: rotation is opt-in and not used in the balance sweep; exact conservation matters in the constant-scalar path, which the sweep uses. The player's own `p_bowl_attack`/`p_bowl_control` stay int — the player bowls at their real integer stat.)*

- [ ] **Step 5: Pass the float conserved value from `simulate_match_teams`**

No code change needed — `cons_attack`/`cons_control` (lines 106-107) already come from `_conserved_bowling` (now float) and are passed into `simulate_match`'s now-float params. Confirm the `:=` inference picked up float (it will).

- [ ] **Step 6: Run the suite, verify green + determinism + scalar path intact**

Run the import+test command. Expected: all six conservation tests PASS; the existing `test_teams_determinism`, `test_teams_directional_strong_beats_weak`, `test_teams_even_roughly_balanced`, and all scalar-path joker/`simulate_match` tests still PASS (int args coerce → byte-identical); total holds at 353+1 (the new identity test) = ~354; `All tests passed`.

- [ ] **Step 7: Commit**

```bash
git add scripts/domain/ball_resolver.gd scripts/domain/ball_resolver.gd.uid scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid scripts/domain/match_resolver.gd scripts/domain/match_resolver.gd.uid tests/unit/test_match_resolver.gd
git commit -m "Part 1 Task 2: exact (float) bowling conservation — compensates weak part-timers precisely"
```

---

### Task 3: Re-tune `concentration_k` + calibrate to flat win ≈ loss

Sweep-driven calibration (oracle = `tools/build_spectrum_sweep.gd`). Spike-validated values below; re-confirm them.

- [ ] **Step 1: Set `bowl_concentration_k` 1.0 → 0.5**

In `scripts/data/innings_tuning.gd`:
```gdscript
@export var bowl_concentration_k: float = 0.5
```
*(Exact conservation is tighter than the old integer version, so the strong-bowler penalty that was 1.0 now over-corrects — 0.5 re-balances it.)*

- [ ] **Step 2: Re-sweep and confirm flat**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/build_spectrum_sweep.gd 2>/dev/null | grep -E "build|/"`
Expected: win% ≈ `48.7 46.9 48.2 48.0 48.9 48.4 48.6` (spread ~2.0), all builds win ≈ loss. If any build is outside ~±2% of the batter's ~48.7, nudge `bowl_concentration_k` (±0.1) and/or the gap-fill distribution and re-sweep.

- [ ] **Step 3: Re-derive the rating par lines if the 5/5 output shifted**

The all-rounder now bowls 4 overs (was 2), so its bowling line changed — re-derive par so the average player still rates ~0. Read the 5/5 row's SR and econ from the sweep table (columns `SR` and `econ`). If they differ from the current `sr_par=107.4` / `rr_par=9.0` by more than ~1, update `scripts/data/rating_tuning.gd` to the new SR/econ and re-check that pure-batter ≈ pure-bowler rating still roughly holds (adjust `wicket_value` if needed — it is currently 2.0). The rating staying a "smile" (specialists above the all-rounder) is expected and fine — Part 2 (the Tons bonus) is the parity fix, not this. If the par lines moved, update `tests/unit/test_rating_tuning.gd`'s `test_defaults` to match.

- [ ] **Step 4: Record the calibrated baseline in the spec**

Append a `## 10. Part 1 calibrated baseline (2026-06-09)` block to `docs/superpowers/specs/2026-06-09-allrounder-viability-and-team-construction-design.md` with the final overs curve, `bowl_concentration_k`, any rating-dial changes, and the final win% table. Confirm: all builds win ≈ loss within ±~2%; all-rounder bowls 4.

- [ ] **Step 5: Run the full suite + commit**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>/dev/null | grep -E "Tests |Passing|All tests"
git add scripts/data/innings_tuning.gd scripts/data/innings_tuning.gd.uid scripts/data/rating_tuning.gd scripts/data/rating_tuning.gd.uid tests/unit/test_rating_tuning.gd docs/superpowers/specs/2026-06-09-allrounder-viability-and-team-construction-design.md
git commit -m "Part 1 Task 3: re-tune concentration_k=0.5 + calibrate to flat win≈loss (spread ~2.0)"
```

---

### Task 4: Verify, PR, merge, roadmap

- [ ] **Step 1:** Clean iCloud `" 2"` files + stray `tools/_tmp_*` uids: `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete; rm -rf .godot`; `--import` once.
- [ ] **Step 2:** Full suite green, count ~354. Confirm `All tests passed`.
- [ ] **Step 3:** Push branch `allrounder-viability`; open PR → `main` with a plain-English body (all-rounder bowls 4 now; exact conservation; final win% table). Merge; sync local `main`; delete branch.
- [ ] **Step 4:** Update `PROJECT_ROADMAP.md` — note Part 1 done (all-rounder authentic + balance re-flattened), Part 2 (Tons synergy bonus) still queued for the Career/meta rung, Part 3 decided (uniform offset). Refresh the Session Handoff.

---

## Self-review

- **Spec coverage:** §3.2 overs curve → Task 1. §3.3 conservation rounding fix (the "floor/ceil mix" the spec described — realised here as exact float, which is the cleaner equivalent and was spike-validated) → Task 2. §3.3 re-flatten target (win ≈ loss) + `concentration_k` lever → Task 3. DA5 (7/7 bowls somewhat) → Task 1's `test_batting_ish_build_bowls_somewhat`. Parts 2 & 3 explicitly out of scope (recorded decisions). ✓
- **Note on the spec's "floor/ceil" wording:** §3.3 proposed a per-over floor/ceil *integer* mix; the spike showed widening to **float** achieves the same exact conservation with far less surface (no per-over scheduling). Same outcome (team total held exactly); Task 4 Step 4 records this realisation in the spec.
- **Placeholders:** none — all values (gain=13, base=-2.6, k=0.5, the win% row) are spike-measured, not guessed. Task 3 Step 3 par-line re-derivation is a measured read, not a placeholder.
- **Type consistency:** `_conserved_bowling(...) -> float`; `bowl_attack/bowl_control: float` in `resolve_ball`; `opp_attack/opp_control: float` in `simulate_innings`; `player_team_attack/control + opp_attack/control: float` in `simulate_match`; `BowlingAttack.new` gets `roundi(...)`. Consistent across tasks.
