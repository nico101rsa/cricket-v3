# Build-Balance Slice 3 — Gap-Fill + Bowling Conservation + Calibration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Player build win ~50% at even ★3 (team-level fairness) and rate equally in net runs (individual fairness), by conserving the team's batting *and* bowling budgets whatever the Player builds, then re-solving `wicket_value`.

**Architecture:** Two continuous budget-conservation mechanisms (spec §8.6). (1) **Batting gap-fill** — `Team.build_xi` tops up/docks the 10 teammates so team batting points always return to the standard **122**, lifting the all-rounder/mid win-rate dip. (2) **Bowling conservation** — `MatchResolver.simulate_match_teams` reduces the non-Player bowling scalar so the team's 20-over bowling total stays at `over_limit·S`, removing the bowler-Player's free 4-over lever. Then calibrate `wicket_value` on the sweep until the rating band flattens. Both live in the real sim path (D4); the scalar `simulate_match` path stays byte-identical.

**Tech Stack:** Godot 4.6.3 / GDScript, GUT 9.6. Pure domain logic in `scripts/domain/`, data in `scripts/data/`. Test-first: red via parse-error/failing-assert, green by the suite count climbing past **347** and `All tests passed`.

---

## Baseline (before this slice, reproduced 2026-06-09)

`tools/build_spectrum_sweep.gd`, 2000 even-★3 matches/build, neutral Intent:

| build | win% | rating | r-bat | r-bowl |
|---|---|---|---|---|
| 8/8/2/2 (batter) | 48.7 | 8.1 | 8.1 | 0.0 |
| 7/7/3/3 | 46.0 | 5.2 | 5.2 | 0.0 |
| 6/6/4/4 | 45.3 | −0.6 | 0.9 | −1.8 |
| 5/5/5/5 (all-r) | 46.1 | −3.0 | −0.1 | −3.0 |
| 4/4/6/6 | 48.8 | −1.5 | −0.2 | −1.2 |
| 3/3/7/7 | 53.4 | 1.1 | −0.1 | 1.3 |
| 2/2/8/8 (bowler) | **59.0** | 5.8 | −0.1 | 6.0 |

The **U-shape** (bowler peak 59, mid dip ~45, batter fair 48.7) and ratings `[−3,+8]` are the two things this slice flattens.

## File structure

- **Modify** `scripts/data/team.gd` — `build_xi` gains batting gap-fill (D11); new private `_apply_batting_gapfill`.
- **Modify** `scripts/domain/match_resolver.gd` — new pure `_conserved_bowling` (D12); `simulate_match_teams` passes conserved attack/control instead of the raw bowling scalar.
- **Modify** `scripts/data/rating_tuning.gd` — `wicket_value` re-solved value (Task 3).
- **Modify** `tests/unit/test_team.gd` — batting-conservation invariant tests.
- **Modify** `tests/unit/test_match_resolver.gd` — bowling-conservation formula tests + re-verify determinism/directional.
- **Update (diagnostics, not code)** `docs/mockups/distribution-viewer-v1.html` or just record the sweep table in spec §9.5.3.

---

### Task 1: Batting budget conservation in `Team.build_xi` (D11)

**Files:**
- Modify: `scripts/data/team.gd:72-75` (`build_xi`) + add `_apply_batting_gapfill`
- Test: `tests/unit/test_team.gd`

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_team.gd`:

```gdscript
func _bat_pts(xi: Array) -> int:
	var t := 0
	for a in xi:
		t += a.power + a.composure
	return t

func test_build_xi_conserves_team_batting_to_122() -> void:
	var itun := InningsTuning.new()
	for cfg in [[8, 8, 2, 2], [5, 5, 5, 5], [2, 2, 8, 8], [7, 6, 4, 3], [3, 3, 7, 7]]:
		var p := Attributes.new()
		p.power = cfg[0]; p.composure = cfg[1]; p.attack = cfg[2]; p.control = cfg[3]
		var ppos := InningsResolver.player_position(p, itun)
		var xi := Team.build_xi(p, ppos)
		assert_eq(_bat_pts(xi), 122, "team batting conserved to 122 for build %s" % str(cfg))

func test_build_xi_leaves_player_attrs_untouched() -> void:
	var p := Attributes.new()
	p.power = 2; p.composure = 2; p.attack = 8; p.control = 8
	var ppos := InningsResolver.player_position(p, InningsTuning.new())
	var xi := Team.build_xi(p, ppos)
	assert_eq(p.power, 2, "Player power untouched by gap-fill")
	assert_eq(p.composure, 2, "Player composure untouched by gap-fill")
	assert_true(xi[ppos - 1] == p, "Player still at their slot, by reference")
```

- [ ] **Step 2: Run the suite, verify the new tests fail**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>/dev/null | grep -E "Passing|fail|Tests "`
Expected: `test_build_xi_conserves_team_batting_to_122` FAILS — current `build_xi` does no top-up, so for non-batter builds the total is < 122 (e.g. 2/2/8/8 → 116). (Quit the Godot editor first; run `pgrep -x Godot`.)

- [ ] **Step 3: Implement the gap-fill in `build_xi`**

Replace `build_xi` in `scripts/data/team.gd` and add the helper:

```gdscript
# The Player's team order: the standard XI with the archetype at the Player's
# 1-based batting position `ppos` replaced by the Player, then the 10 teammates
# topped up / docked so the team's batting points return to the standard 122 —
# build-adaptive gap-fill (Slice 3, D11). ppos is 1..9 (< 11), safe.
static func build_xi(player_attrs: Attributes, ppos: int) -> Array:
	var xi := standard_xi()
	var displaced: Attributes = xi[ppos - 1]
	var deficit := (displaced.power + displaced.composure) - (player_attrs.power + player_attrs.composure)
	xi[ppos - 1] = player_attrs
	_apply_batting_gapfill(xi, ppos, deficit)
	return xi

# Spread `deficit` batting points across the 10 non-Player slots so the team
# batting total lands back on 122. Walks the order TAIL -> TOP (deepen the lineup,
# leaving the strong top-order batters intact until the deficit is large),
# alternating composure then power per sweep. Floors each stat at 1. The Player
# slot (index ppos-1) is never touched. The tail-first distribution is a
# calibration lever (spec §8.6 D14).
static func _apply_batting_gapfill(xi: Array, ppos: int, deficit: int) -> void:
	if deficit == 0:
		return
	var step := 1 if deficit > 0 else -1
	var remaining := absi(deficit)
	var slots: Array[int] = []
	for i in range(10, -1, -1):   # 10 -> 0, tail to top
		if i != ppos - 1:
			slots.append(i)
	var idx := 0
	while remaining > 0:
		var slot: int = slots[idx % slots.size()]
		var a: Attributes = xi[slot]
		if (idx / slots.size()) % 2 == 1:   # sweep 0 = composure, sweep 1 = power, ...
			a.power = maxi(1, a.power + step)
		else:
			a.composure = maxi(1, a.composure + step)
		remaining -= 1
		idx += 1
```

*(Note: `standard_xi()` returns 11 fresh `Attributes` (each `archetype_*()` is fresh), so mutating teammate slots is safe — no shared state. `player_attrs` is a shared reference but lives only at `ppos-1`, which the loop skips.)*

- [ ] **Step 4: Run the suite, verify green**

Run the import+test command from Step 2.
Expected: the two new tests PASS; **total climbs to ~349**; `All tests passed`. Existing `test_build_xi_places_player_at_position` + `test_teams_player_innings_uses_real_batting_card` still pass (top-order BATTERs untouched for small deficits → flat top order preserved).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/team.gd scripts/data/team.gd.uid tests/unit/test_team.gd
git commit -m "Slice 3 Task 1: batting budget conservation (gap-fill to 122) in build_xi"
```

---

### Task 2: Bowling budget conservation in `simulate_match_teams` (D12)

**Files:**
- Modify: `scripts/domain/match_resolver.gd` (add `_conserved_bowling`; edit `simulate_match_teams` lines 78-90)
- Test: `tests/unit/test_match_resolver.gd`

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_match_resolver.gd`:

```gdscript
# --- Slice 3: bowling budget conservation (D12) -------------------------------

func test_conserved_bowling_no_overs_returns_scalar() -> void:
	assert_eq(MatchResolver._conserved_bowling(5, 0, 8, 20), 5, "n=0 -> unchanged team scalar")

func test_conserved_bowling_neutral_player_unchanged() -> void:
	# All-rounder bowls 2 overs at attack 5 == team scalar -> teammates unchanged.
	assert_eq(MatchResolver._conserved_bowling(5, 2, 5, 20), 5, "player at team par -> no change")

func test_conserved_bowling_strong_bowler_weakens_teammates() -> void:
	# 4 overs at attack 8 -> the other 16 bowl weaker so the team total holds at ~100.
	var c := MatchResolver._conserved_bowling(5, 4, 8, 20)
	assert_eq(c, 4, "round((20*5 - 4*8)/16) = round(4.25) = 4")
	assert_almost_eq(4 * 8 + 16 * c, 100, 8, "team total bowling ≈ over_limit*scalar (within rounding)")

func test_conserved_bowling_floored_at_1() -> void:
	assert_eq(MatchResolver._conserved_bowling(1, 4, 8, 20), 1, "result floored at 1")
```

- [ ] **Step 2: Run the suite, verify the new tests fail**

Run the import+test command from Task 1 Step 2.
Expected: the four new tests FAIL with `Parse Error: ... _conserved_bowling ... not declared` style errors (GUT logs the parse error and skips the file) — the function does not exist yet.

- [ ] **Step 3: Implement `_conserved_bowling` and wire it in**

Add to `scripts/domain/match_resolver.gd` (e.g. just above `simulate_match_teams`):

```gdscript
# Bowling budget conservation (Slice 3, D12). When the Player bowls `n` of the
# innings' `overs` at their own `player_stat` (attack or control), the other
# (overs - n) bowlers bowl at this conserved value so the team's total bowling
# (n*player_stat + (overs-n)*result) ≈ overs*team_scalar — identical to a team
# with no Player bowling, and to the opponent. Floors at 1. Pure. Spec §8.6 D12.
static func _conserved_bowling(team_scalar: int, n: int, player_stat: int, overs: int) -> int:
	if n <= 0 or n >= overs:
		return team_scalar
	return maxi(1, roundi((float(overs) * team_scalar - n * player_stat) / float(overs - n)))
```

Then in `simulate_match_teams`, after the four strength draws (lines 69-72) and before the `simulate_match` call, compute the conserved bowling and use it. Replace the `simulate_match(...)` call's bowling args (currently `player_bat, player_bowl, player_bowl,`):

```gdscript
	# Bowling budget conservation (Slice 3, D12): the Player bowls a 0-4 over quota
	# at their own attack/control; the other overs are scaled down so the team's
	# total bowling stays at over_limit*player_bowl — removing the free bowling
	# lever a bowler-build otherwise got. No new RNG draws -> determinism preserved.
	var n_overs := InningsResolver.player_overs(player_attrs, itun)
	var cons_attack := _conserved_bowling(player_bowl, n_overs, player_attrs.attack, itun.over_limit)
	var cons_control := _conserved_bowling(player_bowl, n_overs, player_attrs.control, itun.over_limit)

	return simulate_match(
		player_attrs,
		player_bat, cons_attack, cons_control,
		opp_bat, opp_bowl, opp_bowl,
		player_bats_first, tuning, itun, rng,
		player_intent_plan, player_bowling_plan, jokers, field_plan,
		player_bowl_intent_plan, opp_intent_plan, boost_plan, drs_policy, opp_field_plan,
		player_roster, opp_roster, player_bat - ref3, opp_bat - ref3)
```

*(Leave `simulate_match` itself untouched — the scalar path stays byte-identical, so every joker test / direct `simulate_match` caller is unaffected.)*

- [ ] **Step 4: Run the suite, verify green**

Run the import+test command.
Expected: the four new tests PASS; total climbs to ~353; `All tests passed`. **Re-verify the existing** `test_teams_determinism`, `test_teams_determinism_with_roster`, `test_teams_directional_strong_beats_weak`, `test_teams_even_roughly_balanced` all still PASS (conservation adds no RNG and scales with `S`, so determinism + 5★>0.5★ hold; the even-balance test uses a 5/5/5/5 Player whose conserved value rounds back to 5 → unaffected).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_resolver.gd scripts/domain/match_resolver.gd.uid tests/unit/test_match_resolver.gd
git commit -m "Slice 3 Task 2: bowling budget conservation in simulate_match_teams"
```

---

### Task 3: Calibrate `wicket_value` + confirm both bars flat (D13/D14)

This task is **sweep-driven calibration**, not pure TDD: the oracle is `tools/build_spectrum_sweep.gd`, and the success criteria are the two flatness bars. Unit-test invariants are already locked (Tasks 1-2).

- [ ] **Step 1: Re-run the sweep with both mechanisms live**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/build_spectrum_sweep.gd 2>/dev/null | grep -E "build|/"`
Expected (qualitative): the win% **U flattens markedly** — the bowler peak drops from 59 toward ~50 (D12 removed its free lever) and the mid/all-rounder dip lifts from ~45 toward ~50 (D11 restored team batting). Record the table.

- [ ] **Step 2: Read win-rate flatness; if any build is outside ~50±3, adjust and re-sweep**

Levers, in order of preference:
- **Bowler/high-build still > ~53:** conservation under-correcting — the rounding of `_conserved_bowling` to int can leave a small residual; acceptable within ±3. If larger, the bowling cap interaction or `bowl_overs_*` curve is the next lever (do **not** lift the 4-over cap — spec §4.5).
- **All-rounder/mid still < ~47:** batting gap-fill under-correcting (tail-first distribution is gentle/low-leverage). Switch `_apply_batting_gapfill` to walk **top -> tail** (range `0..11`) to give the top-up more run-leverage, or split it (half top, half tail). Re-run `test_build_xi_conserves_team_batting_to_122` after any change (the 122 invariant must still hold) + re-sweep.
- Record which lever moved and the resulting table.

- [ ] **Step 3: Solve `wicket_value` for rating flatness**

With teams conserved, read each build's `rating` / `r-bat` / `r-bowl` columns. A batter's rating is all `r-bat`; a bowler's is all `r-bowl`, and `r-bowl` scales linearly with `wicket_value` via `W * wicket_value`. Pick `wicket_value` so the **pure-bowler mean rating ≈ pure-batter mean rating** and the whole band tightens. Procedure: try the current 10, then adjust up/down, editing `scripts/data/rating_tuning.gd:12` and re-running the sweep. Because conservation collapsed the bowler's free wickets, the value may need to **rise** above 10 to lift bowler/all-rounder ratings toward the batter's. Land the band within a ~±5 net-runs spread.

```gdscript
# scripts/data/rating_tuning.gd line 12 — set to the solved value:
@export var wicket_value: float = <SOLVED>  # solved Slice 3 (2026-06-09) against conserved teams
```

- [ ] **Step 4: Final sweep + record the calibrated baseline**

Run the sweep once more. Add a `### 9.5.3 Slice 3 calibrated baseline` block to `docs/superpowers/specs/2026-06-08-build-balance-rating-and-team-design.md` with the final table, the win% spread, the rating spread, the chosen `wicket_value`, and which distribution lever was used. Confirm both bars: win% ~50±~3 across all 7 builds; rating band tight.

- [ ] **Step 5: Eyeball + commit**

Optionally refresh `docs/mockups/distribution-viewer-v1.html`'s `DATA` const (~line 53) with the new per-build distribution for a visual. Then:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>/dev/null | grep -E "Tests |Passing|All tests"
git add scripts/data/rating_tuning.gd scripts/data/rating_tuning.gd.uid docs/superpowers/specs/2026-06-08-build-balance-rating-and-team-design.md docs/mockups/distribution-viewer-v1.html
git commit -m "Slice 3 Task 3: re-solve wicket_value + calibrate to flat win-rate & rating"
```

---

### Task 4: Verify, PR, merge, roadmap

- [ ] **Step 1:** Clean iCloud `" 2"` conflict files + stray `tools/_tmp_*` uids: `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete; rm -rf .godot`; then `--import` once.
- [ ] **Step 2:** Full suite green, count > 347 (expect ~353). Confirm `All tests passed`.
- [ ] **Step 3:** Push branch; open PR `build-balance-slice3-gapfill` -> `main` with a plain-English body (what flattened, the final sweep table, `wicket_value` found). Merge; sync local `main`; delete branch.
- [ ] **Step 4:** Update `PROJECT_ROADMAP.md` — move Slice 3 to done, refresh the Session Handoff (next = joker re-tune against the flat baseline, or Career multi-Season loop — Nico's call).

---

## Self-review

- **Spec coverage:** §4.3 gap-fill → Task 1 (D11, conserve batting to 122). §4.4 bowling-uses-roster / §8.6 D12 → Task 2 (conserve bowling to over_limit·S). §3.5/§4.5/§5 calibration + wicket_value → Task 3 (D13/D14). Both success bars (win% flat, rating flat) → Task 3 Steps 2-4. ✓
- **Placeholders:** Task 3 carries deliberate `<SOLVED>` / `<...>` because the calibrated values are *outputs* of the sweep — every step says exactly which file/line to edit and how to read the oracle. No hidden TODOs.
- **Type consistency:** `_apply_batting_gapfill(xi, ppos, deficit)` and `_conserved_bowling(team_scalar, n, player_stat, overs) -> int` are used exactly as defined. `InningsResolver.player_position` / `player_overs` / `itun.over_limit` match the real signatures read from source.
