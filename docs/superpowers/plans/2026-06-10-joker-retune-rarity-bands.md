# Joker Re-tune to Rarity-Tiered Bands — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tune the 45 joker magnitudes so each non-enabler joker's solo win-delta lands in its rarity band (Common +1–4% · Rare +4–7% · Legendary +7–12% over the 48.1% fair-fight floor), no joker is negative, and enablers stay ~0% solo but clear their floor in-combo.

**Architecture:** This rung is **pure tuning** — the DRS/opponent mechanics it needs already shipped with the fair-fight baseline (PR #32). We change only (a) joker magnitudes in `scripts/data/joker_catalog.gd`, and (b) a handful of named scalar DRS dials in `scripts/data/drs_policy.gd` / `scripts/domain/joker_runtime.gd`. The oracle is the existing `tools/sweep_jokers.gd` (now armed: symmetric opponent, prints both `win_delta` and `margin_delta`). Tuning is **empirical** — change a number, re-sweep, read the band, repeat. No new mechanics (documented fallback in Task 2 if data alone can't tame the DRS RETAIN family).

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Sweep is a headless `-s` script emitting one JSON line.

---

## Context the executor needs (read before starting)

**The bands** (solo win-delta above the **48.1%** no-joker floor; ±~1% tolerance):

| Rarity | Band | Decided |
|---|---|---|
| Common | **+1% to +4%** | DB1 (Nico) |
| Rare | **+4% to +7%** | DB1 |
| Legendary | **+7% to +12%** | DB1, confirmed 2026-06-10 |
| Enablers | **~0% solo** (judge in-combo) | §6 of spec |

**The fresh baseline sweep (2026-06-10)** — every arm's `win_delta` over the 48.1% floor. This is the starting state; numbers below are what we tune *from*. Re-run the sweep yourself at the start of every task — within one run all arms share the scenario so per-joker deltas are isolated, but absolute numbers drift run-to-run by ±~1%.

- **🔴 DRS over-band (Task 2):** The Review Master **+28.4%** (Leg, target 7–12), Snicko **+13.6%** (Rare, target 4–7), The Captain's Call **+9.8%** (Rare, target 4–7).
- **🟠 Non-DRS over-band (Task 3):** Field Restrictions **+5.3%** (Com), Powerplay Punch **+5.2%** (Com), Tight Lines **+4.0%** (Com, top edge), Death-Over Stranglehold **+7.2%** (Rare, just over).
- **🔵 Bug (Task 1):** Carry Your Bat **−2.9%** (Rare) — net-negative.
- **🟢 Already in-band (DO NOT TOUCH):** Choke Hold (L +8.7), Squeeze the Middle (C +3.0), Dot Ball Pressure (R +4.5), Cool Head (C +3.9), Spare Review (C +3.2), Captain's Eye (C +2.8), Boundary Hunter (R +4.8).
- **🟡 Under-band but *tunable* (Task 4):** Slog Over Specialist (R +3.2), Power Surge (R +2.9), Compounding Pressure (R +3.3). These DO fire in the neutral sweep, so magnitude bumps move them.
- **⚪ Under-band & participation-limited (Task 5 — DOCUMENT, do NOT inflate, DB4):** Ride the Wave, Hot Streak, Match-Winner's Vigil (Form consumers); Pace Pack, Spinner's Web, First-Change Specialist, The Strike Bowler, The Trap (bowling-change fires); Wicket Maiden, Bowler's Backing; Rotate the Strike, Pressure Cooker, Dead Bat, Block the Shine, Cordon Killer, Attack the Stumps (condition rarely met in the neutral sweep). They read ~0–1% because they rarely *fire*, not because the magnitude is small. Per DB4 we tune firing-strength only if cheap, and **document the residual** rather than cranking the number.
- **⚫ Enablers (Task 5 — verify in-combo, exempt from solo band):** Defensive Captain, Hot Spot, The Sheet Anchor, Captain's Statement, Building Phase, Pedal to the Metal, Boost Adrenaline (all ~0% solo by design).

**The DRS levers and why they behave as they do** (critical for Task 2):
- A review is auto-attempted on **any** team dismissal (team-wide, fair-fight change). `base_reviews=2`, `base_p=0.4`. **On success the review is RETAINED** (real T20 rule, `joker_runtime.gd:198–208`) — only a *failed* review without a retain-joker decrements the pool. So high-accuracy reviews almost never deplete → **accuracy compounds non-linearly** (Cool Head +0.10 → +3.9%, but Snicko +0.25 → +13.6%).
- Because base retain-on-success drives the **in-band Commons too**, lowering `base_p` globally weakens Cool Head / Spare Review / Captain's Eye as well — use it sparingly. Prefer the per-joker dials.
- Per-joker DRS dials: Snicko's `drs_p_bonus` (`joker_catalog.gd:190`), `JokerRuntime.DRS_MASTER_BONUS` (Review Master, `joker_runtime.gd:34`). The Captain's Call is pure **RETAIN** (`drs_role=RETAIN`, no magnitude — retains on *failure* too = effectively infinite reviews); it has no scalar of its own, so it's the hard case (see Task 2 Step 4 + fallback).

**Project conventions (CLAUDE.md):**
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH).
- **Quit the Godot editor first** (`pgrep -x Godot` must be empty) — two headless instances corrupt `.godot`.
- After editing any `scripts/` file run `--import` once before tests. Chain it: `… --import --path . && … gut_cmdln …`.
- Run the suite: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- GUT `-gtest` does **not** filter — the whole suite runs. Judge **green** by "All tests passed" + total count ≥ **362** (rises with new tests). A missing `class_name` shows as a parse error, not a failing assert.
- Tabs for indentation. Commit `*.gd.uid` for `scripts/`, not for `tests/`.
- Clean iCloud junk before a run if a load error appears: `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot` then re-import.
- Run the sweep: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_jokers.gd` → take the **last line** (JSON), parse with the helper below.

**Sweep parse helper** (paste the output's last line into this):
```bash
tail -1 <sweep-output> | python3 -c "
import sys,json
d=json.loads(sys.stdin.read())
for a in d['arms']:
    wd=a.get('win_delta',0); md=a.get('margin_delta',0)
    print(f'{a[\"name\"][:34]:<35}{wd*100:+6.1f}%  Δm{md:+6.2f}')
"
```

---

## Task 1: Fix Carry Your Bat (the net-negative bug)

Carry Your Bat (Rare) reads **−2.9%**: in DEFENSIVE it multiplies wicket ×0.85 **and** runs ×0.90, so it survives but scores too slowly to win. Raise the runs mult so it is net-positive, and ease the wicket mult slightly so it isn't a pure block. Target: land in the Rare band (+4–7%).

**Files:**
- Modify: `scripts/data/joker_catalog.gd:58-64` (the two `carry_your_bat` effect rows)
- Test: `tests/unit/test_joker_catalog.gd` (add a magnitude guard)

- [ ] **Step 1: Write a failing magnitude guard test**

Add to `tests/unit/test_joker_catalog.gd`:
```gdscript
func test_carry_your_bat_scores_while_defending() -> void:
	var rows: Array = _group("carry_your_bat")["effects"]
	var wicket_mult := 1.0
	var runs_mult := 1.0
	for e in rows:
		if e.target == JokerEffect.Target.WICKET:
			wicket_mult = e.mult
		else:
			runs_mult = e.mult
	# Must still protect the wicket but NOT suppress scoring (the bug was runs 0.90).
	assert_lt(wicket_mult, 1.0, "Carry Your Bat still lowers wicket risk")
	assert_gte(runs_mult, 1.0, "Carry Your Bat must not suppress scoring (was 0.90 -> net-negative)")
```

- [ ] **Step 2: Run the suite, confirm the new test FAILS**

Run the suite (command above). Expected: the new assert fails (`runs_mult` is currently 0.90 < 1.0). Everything else green.

- [ ] **Step 3: Raise the magnitudes**

In `scripts/data/joker_catalog.gd:58-64`, change the wicket mult `0.85 → 0.90` and the runs mult `0.90 → 1.05`:
```gdscript
		_g("carry_your_bat", "Carry Your Bat", "Rare", [
			JokerEffect.make("carry_your_bat", "Carry Your Bat", "Rare",
				JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.90,
				BallResolver.Intent.DEFENSIVE),
			JokerEffect.make("carry_your_bat", "Carry Your Bat", "Rare",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.05,
				BallResolver.Intent.DEFENSIVE)]),
```

- [ ] **Step 4: Run the suite, confirm green (count ≥ 363)**

- [ ] **Step 5: Re-sweep and check the band**

Run the sweep, parse Carry Your Bat. Target **+4% to +7%**. If still under, raise the runs mult toward 1.10; if over, ease toward 1.00. Re-sweep until in band, then update the test's expectation only if you moved a sign (the guard above stays valid for any in-band value).

- [ ] **Step 6: Commit**

```bash
git add scripts/data/joker_catalog.gd scripts/data/joker_catalog.gd.uid tests/unit/test_joker_catalog.gd
git commit -m "Joker re-tune: fix Carry Your Bat net-negative -> Rare band"
```

---

## Task 2: Pull the DRS family into band

The headline. Three over-band DRS jokers, tuned via their **own** dials so the in-band DRS Commons (Cool Head/Spare Review/Captain's Eye) stay put. Order matters: do Snicko + Review Master first (clean scalar dials), then Captain's Call (the hard RETAIN case) last, re-sweeping after each.

**Files:**
- Modify: `scripts/data/joker_catalog.gd:189-196` (Snicko `drs_p_bonus`)
- Modify: `scripts/domain/joker_runtime.gd:34` (`DRS_MASTER_BONUS`)
- Modify (only if needed): `scripts/data/drs_policy.gd:11` (`base_p`)
- Test: `tests/unit/test_drs_policy.gd:6` (rebaseline `base_p` only if changed)

- [ ] **Step 1: Snicko — lower its accuracy bonus**

Snicko (+13.6%, Rare target 4–7) is `_drs("snicko", …, ACCURACY, 0.25)` at `joker_catalog.gd:190`. Drop the bonus `0.25 → 0.12` (because accuracy compounds, a small cut moves it a lot). Re-import + re-sweep. Target Snicko **+4–7%**. Iterate the bonus (range ~0.08–0.16) until in band. No test asserts Snicko's bonus, so no rebaseline.

- [ ] **Step 2: The Review Master — lower DRS_MASTER_BONUS**

Review Master (+28.4%, Leg target 7–12) is `MASTER` = `DRS_MASTER_BONUS` (+0.30 p) **+ retain-on-fail + an extra review** (`joker_runtime.gd:34,174-175,193-195`). Drop `DRS_MASTER_BONUS 0.30 → 0.12`. Re-import + re-sweep. Target **+7–12%**. If still over (the retain + extra-review alone may exceed 12), continue to ~0.06; if it drops below 7, raise back. Iterate until in band. No test asserts this constant.

- [ ] **Step 3: Re-sweep, snapshot the DRS Commons**

Confirm Cool Head / Spare Review / Captain's Eye are still in the Common band (+1–4%) — Steps 1–2 shouldn't have touched them (they use different dials), but verify. If one drifted out, note it for Step 5.

- [ ] **Step 4: The Captain's Call — the RETAIN case**

Captain's Call (+9.8%, Rare target 4–7) is pure **RETAIN** (retains on failure too → effectively infinite reviews). It has no magnitude dial. Try, in order:
  1. **Data first:** lower `DRSPolicy.base_p 0.40 → 0.34` (`drs_policy.gd:11`). This weakens every per-dismissal review for *both* teams (so the floor stays ~fair) and pulls Captain's Call (and any residual DRS) down. Re-import + re-sweep. **Check the floor** (Baseline arm) re-centred near ~48% and that Cool Head/Spare Review/Captain's Eye did NOT fall below +1%.
  2. If Captain's Call is in band and the Commons held → done. Rebaseline `test_drs_policy.gd:6` to the new `base_p` (`assert_almost_eq(p.base_p, 0.34, 0.0001)`).
  3. **If data alone can't square it** (Captain's Call still > +7% before the Commons fall below +1%): apply the spec's DB3 documented fallback — a single bounded mechanic tweak. Change the `RETAIN` role from "never consume" to **"grants +1 review" (like an extra-review, but it does not also retain-on-fail)**: in `joker_runtime.gd`, (a) add `RETAIN` to the `init_reviews` grant condition (`:174`, alongside `EXTRA_REVIEW`/`MASTER`), and (b) remove the `RETAIN` arm from `try_review`'s retain-setting (`:191-192`) so it no longer makes reviews infinite. Re-sweep; target Rare band. **This is a deliberate, AFK-default mechanic change — record it in the spec's decisions log and the roadmap** (note it changed RETAIN semantics). Add a unit test: with only Captain's Call, the review pool is `base_reviews + 1` and depletes normally on failures.

- [ ] **Step 5: Final DRS re-sweep + suite green**

Re-sweep: Review Master in 7–12, Snicko + Captain's Call in 4–7, the three DRS Commons still in 1–4, none negative. Run the full suite — green, count ≥ 363 (Task 1) plus any Step 4.3 test.

- [ ] **Step 6: Commit**

```bash
git add scripts/data/joker_catalog.gd scripts/data/joker_catalog.gd.uid \
        scripts/domain/joker_runtime.gd scripts/domain/joker_runtime.gd.uid \
        scripts/data/drs_policy.gd scripts/data/drs_policy.gd.uid tests/unit/
git commit -m "Joker re-tune: DRS family (Review Master/Snicko/Captain's Call) into rarity bands"
```

---

## Task 3: Pull over-band non-DRS jokers down

Four jokers acting above their tier. All pure magnitude edits; two have catalog asserts to rebaseline.

**Files:**
- Modify: `scripts/data/joker_catalog.gd` — Powerplay Punch (`:37-40`), Field Restrictions (`:216-219`), Tight Lines (`:70-73`), Death-Over Stranglehold (`:20-22` and `:49-52`)
- Test: `tests/unit/test_joker_catalog.gd:26` (death_over) + `:47` (field_restrictions)

- [ ] **Step 1: Edit the four magnitudes (starting points)**

- Powerplay Punch (Com +5.2 → target 1–4): runs mult `1.10 → 1.06`.
- Field Restrictions (Com +5.3 → target 1–4): runs mult `1.12 → 1.07`.
- Tight Lines (Com +4.0, top edge → keep low-mid): runs mult `0.90 → 0.93` (less run suppression = weaker).
- Death-Over Stranglehold (Rare +7.2, just over → target 4–7): runs mult `0.80 → 0.83`. **Note:** this magnitude appears TWICE — `slice_v1()` (`:20-22`) AND `implemented_groups()` (`:49-52`). Change **both** to keep them consistent.

- [ ] **Step 2: Rebaseline the catalog asserts**

In `tests/unit/test_joker_catalog.gd`: line 26 `assert_almost_eq(j.mult, 0.80 …)` → `0.83`; line 47 `assert_almost_eq(e.mult, 1.12 …)` → `1.07`. (Powerplay Punch and Tight Lines have no magnitude asserts.)

- [ ] **Step 3: Re-import, run suite green, re-sweep**

Confirm all four now sit in band (Commons 1–4, Death-Over 4–7). Iterate any that overshot/undershot. Green suite.

- [ ] **Step 4: Commit**

```bash
git add scripts/data/joker_catalog.gd scripts/data/joker_catalog.gd.uid tests/unit/test_joker_catalog.gd
git commit -m "Joker re-tune: over-band Commons + Death-Over into rarity bands"
```

---

## Task 4: Nudge tunable under-band jokers up

Three Rares that *do* fire in the neutral sweep but read below their band. Magnitude bumps will move them (unlike the participation-limited tail in Task 5).

**Files:**
- Modify: `scripts/data/joker_catalog.gd` — Slog Over Specialist (`:65-68`), Power Surge (`:173-174` → `BOOST_AMPLIFY_MULT`), Compounding Pressure (`:175-176` → `BOOST_COMPOUND_BONUS`)
- Modify (boost dials): `scripts/domain/joker_runtime.gd:16,22` if Power Surge / Compounding need it
- Test: none assert these magnitudes

- [ ] **Step 1: Slog Over Specialist (R +3.2 → 4–7)**

Death-overs aggressive runs mult `1.25 → 1.35` (`joker_catalog.gd:67`). Re-import + re-sweep. Iterate toward band.

- [ ] **Step 2: Power Surge (R +2.9) & Compounding Pressure (R +3.3)**

Both are boost-role jokers driven by constants in `joker_runtime.gd`: Power Surge = `BOOST_AMPLIFY_MULT` (1.20, `:16`); Compounding Pressure = `BOOST_COMPOUND_BONUS` (1.25, `:22`). Bump each ~+0.05 (`1.20→1.25`, `1.25→1.30`) only if Step-1 re-sweep still shows them under +4. Re-sweep, iterate. **Don't** push the Boost-stack arm absurd — recheck it in Task 5.

- [ ] **Step 3: Re-import, suite green, re-sweep — confirm the three in 4–7**

- [ ] **Step 4: Commit**

```bash
git add scripts/data/joker_catalog.gd scripts/data/joker_catalog.gd.uid \
        scripts/domain/joker_runtime.gd scripts/domain/joker_runtime.gd.uid
git commit -m "Joker re-tune: lift under-band Rares (Slog Over, Power Surge, Compounding) into band"
```

---

## Task 5: Verify enablers in-combo + document the participation-limited tail

No magnitude inflation here (DB4) — this task confirms the exempt jokers behave and writes down the honest residual for the jokers a neutral sweep under-fires.

**Files:**
- Modify: `docs/superpowers/specs/2026-06-09-joker-retune-rarity-bands-design.md` (append a "Findings / residuals" section)

- [ ] **Step 1: Re-sweep, read the stack + combo arms**

Confirm the combinatorial arms clear their floor (they should, post-tune): Batting stack, Field-defensive stack, Bowling-intent stack, Boost-stack, Reviewer stack, Form-window stack, Wicket-Hunter stack, Form-source combo. Record their post-tune deltas. **Reviewer stack should have dropped substantially** from +43.6% after Task 2 — sanity-check it's no longer an auto-win.

- [ ] **Step 2: Confirm enablers are ~0% solo, positive in-combo**

Defensive Captain, Hot Spot, the 3 Form sources, Pedal, Adrenaline: ~0% solo (expected) AND the relevant stack arm (Form-source combo, Boost-stack) clears its floor. If an enabler reads materially negative, investigate; otherwise document as expected.

- [ ] **Step 3: Document the participation-limited residuals**

Append to the spec a short table: each under-band participation-limited joker (Ride the Wave, Hot Streak, Match-Winner's Vigil, Pace Pack, Spinner's Web, First-Change Specialist, The Strike Bowler, The Trap, Wicket Maiden, Bowler's Backing, Rotate the Strike, Pressure Cooker, Dead Bat, Block the Shine, Cordon Killer, Attack the Stumps), its solo delta, and a one-line reason it under-fires in the neutral sweep (e.g. "fires only on a 2nd Form event within 6 balls — rare at a 5/5/5/5 build"). State explicitly: magnitude left at firing-strength per DB4, residual is a fire-rate artefact, in-combo value covered by the stack arms. **If Task 4 left any of the genuinely-tunable three still under-band, note that too.**

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-06-09-joker-retune-rarity-bands-design.md
git commit -m "Joker re-tune: verify enablers in-combo + document participation-limited residuals"
```

---

## Task 6: Final sweep, docs, roadmap handoff

**Files:**
- Modify: `docs/joker-pool-v1.md` (tuned magnitudes — single source of truth)
- Modify: `docs/mockups/distribution-viewer-v1.html` (`DATA` const = final sweep)
- Modify: `PROJECT_ROADMAP.md` (status + Session Handoff)

- [ ] **Step 1: Run the final full sweep and save the JSON**

Run `tools/sweep_jokers.gd`, keep the last line. This is the artefact for the viewer.

- [ ] **Step 2: Update `docs/joker-pool-v1.md` magnitudes**

For every joker whose magnitude changed (Tasks 1–4), update its number in the pool doc so it matches the catalog. This is the human-readable source of truth.

- [ ] **Step 3: Update the viewer `DATA`**

Replace the `DATA` const in `docs/mockups/distribution-viewer-v1.html` with the Step-1 JSON so the overlaid-histogram viewer reflects the tuned pool.

- [ ] **Step 4: Final verification — full suite green**

Run the suite. Confirm "All tests passed", count ≥ 363. Confirm the sweep: every non-enabler joker in band (±~1%) or documented as participation-limited; none negative; enablers ~0% solo.

- [ ] **Step 5: Update `PROJECT_ROADMAP.md`**

Move the rung to done in Current status; write the Session Handoff (state, next step, seams). Next theme after this = **7c layer D (₸ economy)** per the roadmap's 7c decomposition.

- [ ] **Step 6: Commit, push, PR, merge**

```bash
git add docs/joker-pool-v1.md docs/mockups/distribution-viewer-v1.html PROJECT_ROADMAP.md
git commit -m "Joker re-tune: final sweep, docs + viewer, roadmap handoff -> 7c-D economy"
git push -u origin joker-retune-rarity-bands
```
Then open + merge the PR (per the commit policy), sync `main`, delete the branch.

---

## Self-review notes

- **Spec coverage:** §2 bands (all tasks) · §5.1 mechanics — already shipped (fair-fight), not re-done here ✓ · §5.2 re-tune (Tasks 1–4) · §6 enablers (Task 5) · §7 verification (Tasks across + Task 6) · DB1 bands (context) · DB3 fallback (Task 2.4) · DB4 no-inflation (Task 5). ✓
- **Empirical caveat:** the magnitude *starting points* are estimates; the binding instruction is "re-sweep, land in band, iterate." The sweep is the oracle, not the numbers in this plan.
- **Branch:** work on `joker-retune-rarity-bands` (the spec branch name) off current `main`.
- **Determinism/rebaseline:** only Task 2.3's `base_p` change and Task 3's two catalog asserts touch existing test values; the fair-fight tests force `base_p` locally so they're robust. Run the full suite after every task.
