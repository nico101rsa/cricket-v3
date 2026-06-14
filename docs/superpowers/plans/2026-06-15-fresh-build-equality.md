# Fresh-build-equality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make fresh-build win% build-equal by gating batting-position promotion on absolute batting competence ("earn your position"), so weak fresh players bat lower and climb the order as they level up.

**Architecture:** One pure-domain formula change in `InningsResolver.player_position` (multiply the share-promotion term by a `competence` factor that ramps 0→1 with absolute batting), plus one new `InningsTuning` dial `pos_ref_batting`. Full-competence builds reproduce the current formula exactly → minimal ledger ripple. Then a measure-tune loop on `build_spectrum_sweep` and a ledger re-check.

**Tech Stack:** Godot 4.6.3 / GDScript / GUT 9.6. Tabs. Run suite headless; judge red by parse-error, green by count climbing past 562.

---

### Task 1: Competence-gated batting position

**Files:**
- Modify: `scripts/data/innings_tuning.gd` (add `pos_ref_batting` dial)
- Modify: `scripts/domain/innings_resolver.gd:8-13` (`player_position`)
- Test: `tests/unit/test_innings_resolver.gd`

- [ ] **Step 1: Write the failing tests** — append to `tests/unit/test_innings_resolver.gd`:

```gdscript
func test_full_competence_reproduces_old_position() -> void:
	# batting 100 >= pos_ref -> competence 1.0 -> pos = round(9 - 8*0.8) = 3 (unchanged)
	var pos := InningsResolver.player_position(_attrs(50.0, 50.0, 12.5, 12.5), itun)
	assert_eq(pos, 3, "full-competence batting-lean keeps the old #3")

func test_fresh_batting_lean_bats_lower_than_maxed_same_share() -> void:
	# Same share 0.8, different absolute batting. Fresh (weak) must bat no higher.
	var fresh := InningsResolver.player_position(_attrs(17.6, 17.6, 4.4, 4.4), itun)
	var maxed := InningsResolver.player_position(_attrs(50.0, 50.0, 12.5, 12.5), itun)
	assert_gt(fresh, maxed, "a fresh weak batting build bats lower than a maxed one of the same shape")

func test_position_monotonic_in_batting_at_fixed_share() -> void:
	# Share fixed at 0.8 (power==composure==4x attack==control); rising batting -> up the order.
	var weak := InningsResolver.player_position(_attrs(8.8, 8.8, 2.2, 2.2), itun)
	var mid := InningsResolver.player_position(_attrs(17.6, 17.6, 4.4, 4.4), itun)
	var strong := InningsResolver.player_position(_attrs(50.0, 50.0, 12.5, 12.5), itun)
	assert_gte(weak, mid, "weaker bats no higher than mid")
	assert_gte(mid, strong, "mid bats no higher than strong")

func test_pos_ref_batting_dial_deepens_sub_ref_build() -> void:
	# Doubling the reference halves competence for a sub-ref build -> bats deeper.
	var low_ref := InningsResolver.player_position(_attrs(17.6, 17.6, 4.4, 4.4), itun)
	var hi_itun := InningsTuning.new()
	hi_itun.pos_ref_batting = itun.pos_ref_batting * 2.0
	var hi_ref := InningsResolver.player_position(_attrs(17.6, 17.6, 4.4, 4.4), hi_itun)
	assert_gt(hi_ref, low_ref, "a higher pos_ref_batting pushes a sub-ref build deeper")
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: the new asserts fail (`pos_ref_batting` not declared on `InningsTuning` → parse error in the test file, or the dial-respecting / lower-position asserts fail). Whole suite still loads.

- [ ] **Step 3: Add the dial** — in `scripts/data/innings_tuning.gd`, just below `pos_span`:

```gdscript
# build -> batting position promotion is gated by absolute batting competence
# (fresh-build-equality 2026-06-15): pos = round(pos_base - pos_span*share*competence),
# competence = clamp(batting / pos_ref_batting, 0, 1). At/above pos_ref the formula
# is the original share-only promotion (strong builds unchanged); below it a weak
# player bats lower and climbs the order as it levels up. Tuned by build_spectrum_sweep.
@export var pos_ref_batting: float = 60.0
```

- [ ] **Step 4: Change the formula** — replace `InningsResolver.player_position` body (lines 8-13):

```gdscript
static func player_position(attrs: Attributes, itun: InningsTuning) -> int:
	var batting := attrs.power + attrs.composure
	var bowling := attrs.attack + attrs.control
	var share := float(batting) / float(batting + bowling)
	var competence := clampf(float(batting) / itun.pos_ref_batting, 0.0, 1.0)
	var pos := roundi(itun.pos_base - itun.pos_span * share * competence)
	return clampi(pos, 1, 9)
```

- [ ] **Step 5: Run the suite to verify green**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit | tail -5`
Expected: `All tests passed`, count climbed (566+). The four pre-existing `player_position` tests stay green (their builds are full-competence at `pos_ref_batting=60`).

- [ ] **Step 6: Commit**

```bash
git add scripts/data/innings_tuning.gd scripts/data/innings_tuning.gd.uid scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid tests/unit/test_innings_resolver.gd
git commit -m "Fresh-build-equality: competence-gated batting position + pos_ref_batting dial"
```

---

### Task 2: Tune `pos_ref_batting` to flatten fresh win%

**Files:** Modify: `scripts/data/innings_tuning.gd` (final `pos_ref_batting` value)

- [ ] **Step 1: Baseline measure** — run the sweep at all three totals with the strawman dial:

```bash
for S in 44 125 200; do echo "=== SUM=$S ==="; SUM=$S /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/build_spectrum_sweep.gd 2>/dev/null; done
```

Record the win% spread (max−min across the 7 builds) per total.

- [ ] **Step 2: Tune** — if SUM=44 spread > ~4 pts, adjust `pos_ref_batting` and re-run:
  - Raising `pos_ref_batting` → more compression at fresh (weak builds bat lower) → flatter fresh, but watch SUM=125/200 staying flat AND keeping the all-rounder (batting 62.5) at/near full competence so its archetype position (and the existing `test_even_build_bats_middle` #5 assertion) holds. If a value > 62.5 is needed, update that test in this task.
  - Lowering it → less compression. Iterate until all three totals are ≤ ~4 pts.

- [ ] **Step 3: Re-run the unit suite** (the tuned value must keep Task-1 + existing position tests green; update `test_even_build_bats_middle` only if the tuned `pos_ref_batting > 62.5` genuinely moves the all-rounder).

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit | tail -3
```

- [ ] **Step 4: Commit the tuned dial**

```bash
git add scripts/data/innings_tuning.gd tests/unit/test_innings_resolver.gd
git commit -m "Fresh-build-equality: tune pos_ref_batting to flatten fresh win%"
```

---

### Task 3: Ledger re-check + re-peg

**Files:** possibly Modify economy/joker tuning dials if drift is found (record in §10).

- [ ] **Step 1: env probe** — `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/probe_scoring_env.gd 2>/dev/null` — expect ~155 / RR ~8.2 / ~6.2 wkts (byte-identical if null-player). Record.
- [ ] **Step 2: build spread at maxed** — already captured in Task 2 SUM=125; confirm ≤ ~2.
- [ ] **Step 3: joker floor + bands** — `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_jokers.gd 2>/dev/null | tail -60` — confirm floor ~45.5 and no joker blows its rarity band; if a band breaks, note it (price re-interpolation is a follow-up, flag don't silently absorb).
- [ ] **Step 4: economy pay** — `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_economy.gd 2>/dev/null | tail -40` — confirm pay spread stays ~₸0.3–0.6; if it drifts, re-peg one dial (e.g. `runs_rate`) and note it.
- [ ] **Step 5: fresh pay equality (A3)** — check whether `build_spectrum_sweep SUM=44` (already has a `rating` column proxy) shows build-equal individual output; note any fresh pay-spread as a finding (separate-rung if real).
- [ ] **Step 6: Commit any re-peg** — `git commit -am "Fresh-build-equality: ledger re-peg (<dial> <old>-><new>)"` (skip if no drift).

---

### Task 4: Findings, roadmap, PR

- [ ] **Step 1: Fill spec §10** — tuned `pos_ref_batting`, before/after win% spreads at SUM 44/125/200, ledger deltas, fresh pay-equality result. Commit.
- [ ] **Step 2: Before/after viz** (optional, if spread story is worth seeing) — `docs/mockups/fresh-build-equality-v1.html` mirroring the project's sweep-viewer pattern.
- [ ] **Step 3: Update `PROJECT_ROADMAP.md`** — Current status + Decisions log + the "Next session" handoff (this bug closed; next direction = presentation).
- [ ] **Step 4: Push + PR + merge + sync main + delete branch** (per commit policy).

---

## Self-Review notes

- **Spec coverage:** D1 (formula+dial) = Task 1; D2/D3 (overs/gap-fill untouched) = no task by design; A1 (tune) = Task 2; A2 (ledger) = Task 3; A3 (fresh pay) = Task 3 Step 5; §10 = Task 4.
- **Type consistency:** dial name `pos_ref_batting` used identically across InningsTuning, the formula, and all tests.
- **Regression safety:** the four existing `player_position` tests use full-competence builds at `pos_ref_batting=60`, so they stay green; the only one at risk under aggressive tuning is `test_even_build_bats_middle` (all-rounder batting 62.5) — Task 2 Step 2/3 calls this out explicitly.
