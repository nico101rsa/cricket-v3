# DRS Team-Wide Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the bowling side's DRS claim review fire on every over for the Player slot (not just hero-bowled overs), then re-measure everything that baseline fed: fair-fight floor, 45 joker deltas, ₸ prices.

**Architecture:** One-line gate removal in `InningsResolver.simulate_innings`'s claim-review branch (spec DD1), guarded by a new directional GUT test (DD6). The rest of the rung is oracle re-runs: probe (acceptance), joker sweep (new floor + deltas), price interpolation (DE4 rule), build/economy verification (no re-tune unless out of band).

**Tech Stack:** Godot 4.6.3 headless + GUT 9.6. Spec: `docs/superpowers/specs/2026-06-10-drs-teamwide-fix-design.md`.

**Conventions (all tasks):** tabs in `.gd`; ONE Godot process at a time (chain `--import && test` where scripts were added; sweeps sequentially); quit the editor first (`pgrep -x Godot`); clean iCloud `" 2"` files if GUT fails to load; suite green = count > 396 + `All tests passed`.

---

### Task 1: The fix, test-first (DD1 + DD6)

**Files:**
- Modify: `tests/unit/test_fair_fight_baseline.gd` (append test)
- Modify: `scripts/domain/innings_resolver.gd` (claim branch, ~line 212 + block comment ~197–201)

- [ ] **Step 1: Write the failing test** — append to `tests/unit/test_fair_fight_baseline.gd` (tabs):

```gdscript
# DRS team-wide fix (spec 2026-06-10, DD6): the PLAYER slot's claim review must
# fire on ALL overs, even with ZERO hero-bowled overs. Opponent batting innings
# (player_is_batting=false), player_bowler_overs=0, claim-everything Player DRS
# -> more opponent wickets than the no-DRS base. Pre-fix the player_bowling gate
# made this structurally impossible (0 hero overs -> 0 claims).
func test_player_claim_review_is_team_wide() -> void:
	var hi := DRSPolicy.new()
	hi.base_reviews = 50
	hi.base_p = 1.0
	var base := InningsResolver.simulate_innings(
		null, 12, 2.0, 2.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], false)
	var claimed := InningsResolver.simulate_innings(
		null, 12, 2.0, 2.0, _tuning(), _itun(), _rng(7), 0, null, null, null,
		0, 0, 0, [], false, null, null, null, hi)
	assert_gt(claimed.wickets, base.wickets,
		"Player claim-review should take opponent wickets on non-hero overs")
```

(Arg positions mirror `test_opponent_claim_review_takes_player_wickets` but with `player_is_batting=false` and the policy in the **`drs_policy`** slot — 4 args after `player_is_batting`, vs the opponent test's `opp_drs_policy` 9 args after.)

- [ ] **Step 2: Run, verify RED** (no `--import` needed — no new script files):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -15
```

Expected: 1 failing assert (`claimed.wickets` == `base.wickets`, the gate blocks every claim), total tests 397.

- [ ] **Step 3: The fix** — in `scripts/domain/innings_resolver.gd` claim branch, change:

```gdscript
		if (not player_is_batting) and player_bowling and drs_policy != null:
```

to

```gdscript
		if (not player_is_batting) and drs_policy != null:
```

and update the block comment above (lines ~197–201): replace the sentence describing the hero-only claim with: `Both claim reviews are TEAM-WIDE on every over (Nico's ruling 2026-06-10: the hero is just part of the team) — the Player's runtime carries the team's jokers, the opponent's is base-only.`

- [ ] **Step 4: Run suite, verify GREEN**: same command. Expected: **397 passing, `All tests passed`**. If any seed-pinned two-sided-DRS test shifted, inspect — a pure baseline-value update is mechanical (update + note in commit); a *directional* failure means a real break (stop, debug with superpowers:systematic-debugging).

- [ ] **Step 5: Commit**

```sh
git add tests/unit/test_fair_fight_baseline.gd scripts/domain/innings_resolver.gd
git commit -m "DRS claim review is team-wide for the Player slot (drop the player_bowling gate) - Nico's ruling, spec DD1/DD6"
```

### Task 2: Probe acceptance (DD4)

**Files:** none modified (oracle run; results land in spec §10 at Task 6).

- [ ] **Step 1: Run the probe** (~2–4 min, N=4000 × 5 arms):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/probe_side_asymmetry.gd
```

- [ ] **Step 2: Check against the E1 "before" table** (E1 spec §10.1). PASS = `DRS both only` reads ~49/49 (each side within ~1.5pts of the `all null` row's 50.2/48.8), and `full textbook config` loses its skew (was 44.0/55.1 → expect ~49/49 too). Record the full after-table for spec §10. FAIL = asymmetry persists → stop, debug (the gate was not the whole mechanism).

### Task 3: Joker re-sweep — new floor + 45 deltas (DD5, DD9)

**Files:** none modified yet (JSON output captured for Tasks 4/6).

- [ ] **Step 1: Run the joker oracle** (both profiles in one run, ~60–80s; save output):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_jokers.gd > /tmp/sweep_jokers_post_drs.txt 2>&1; tail -5 /tmp/sweep_jokers_post_drs.txt
```

- [ ] **Step 2: Record the new fair-fight floor** — the `Baseline (no jokers)` arm win-rate (was **48.1%**; expect ~49–50%). This is the new joker-tuning floor.

- [ ] **Step 3: Band check (DD9)** — for each of the 45 jokers compute fresh delta = arm win% − baseline win%; compare to rarity bands (Common +1–4 / Rare +4–7 / Legendary +7–12, realized basis: conditionals = in-condition × fire-rate, enablers judged in-combo). Expect DRS/Reviewer jokers (Cool Head, Spare Review, Captain's Eye, Captain's Call, Review Master, Snicko) to move most — claim-side effects now fire on 20 overs, not 0–4. List any joker > ~1.5pts outside band (N=2000) → magnitude nudge per the rung-2 method (catalog `mult`/`drs_p_bonus`/grant dials only, re-run affected arm to confirm); borderline reads → findings, not chased.

- [ ] **Step 4: If any magnitude changed:** update `scripts/data/joker_catalog.gd`, re-run the sweep once for fresh final deltas, run the GUT suite (green ≥ 397), commit:

```sh
git add scripts/data/joker_catalog.gd
git commit -m "Joker band re-tune against the post-DRS-fix floor (DD9): <which dials>"
```

### Task 4: Price refresh (DD5, 7c-D rule DE4)

**Files:**
- Modify: `scripts/data/joker_catalog.gd` (`PRICES`)
- Modify: `docs/joker-pool-v1.md` (₸ column + any delta notes)
- Modify: viewer DATA only if it embeds deltas/prices (check `docs/mockups/economy-v1.html` + `distribution-viewer-v1.html` for a joker-price table; skip if not embedded)

- [ ] **Step 1: Recompute all 45 prices** from the Task 3 final deltas with the DE4 rule:

```
frac  = clamp((realized_delta − band_delta_lo) / (band_delta_hi − band_delta_lo), 0, 1)
price = round5(price_lo + frac × (price_hi − price_lo))
```

Delta bands: Common 1–4 / Rare 4–7 / Legendary 7–12. Price bands: Common ₸30–50 / Rare ₸90–120 / Legendary ₸220–250. Conditionals use realized (in-condition × fire-rate, fire-rates printed by the sweep); enablers price at band floor.

- [ ] **Step 2: Update `PRICES`** in `scripts/data/joker_catalog.gd` (every changed entry), mirror the ₸ column in `docs/joker-pool-v1.md`.

- [ ] **Step 3: Suite green** (a price test may pin values — update only if the test asserts specific ₸ numbers, mechanically):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```sh
git add scripts/data/joker_catalog.gd docs/joker-pool-v1.md
git commit -m "Joker prices refreshed from post-DRS-fix realized deltas (DE4 interpolation)"
```

### Task 5: Build-balance + economy verification (DD7, DD8 — verify, don't re-tune)

**Files:** none expected.

- [ ] **Step 1: Build sweep** (sequential, ONE Godot at a time):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/build_spectrum_sweep.gd > /tmp/build_sweep_post_drs.txt 2>&1; grep -i "win" /tmp/build_sweep_post_drs.txt | head -20
```

PASS = win-rate spread across builds ≤ ~3pts (was 2.0). FAIL → record finding, flag balance re-open in roadmap (do NOT re-tune in this rung).

- [ ] **Step 2: Economy sweep**:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_economy.gd > /tmp/econ_sweep_post_drs.txt 2>&1; grep -i "pay\|income\|₸" /tmp/econ_sweep_post_drs.txt | head -20
```

PASS = build pay spread ≤ ~₸2 (was ₸0.2). FAIL → record finding, flag (no re-tune).

### Task 6: Findings, roadmap, PR

**Files:**
- Modify: `docs/superpowers/specs/2026-06-10-drs-teamwide-fix-design.md` (§10)
- Modify: `PROJECT_ROADMAP.md` (status + Last closed + Next session handoff)

- [ ] **Step 1: Write spec §10** — probe after-table (vs the E1 before-table) · new fair-fight floor · the joker deltas that moved (esp. the 6 DRS jokers) + any DD9 nudges · the price changes table (old → new) · DD7/DD8 verification reads · anything surprising.

- [ ] **Step 2: Update `PROJECT_ROADMAP.md`** — Current status line (floor + test count), "Last closed" entry for this rung, rewrite "Next session" handoff (next rung = bowling-balance, design seed in E1 spec §10.3; the known-dirty-baseline warning paragraph is now RESOLVED — remove it).

- [ ] **Step 3: Commit docs, push, PR, merge** (verification-before-completion: suite green first):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -3
git add docs/superpowers/specs/2026-06-10-drs-teamwide-fix-design.md PROJECT_ROADMAP.md docs/superpowers/plans/2026-06-10-drs-teamwide-fix.md
git commit -m "DRS team-wide fix findings + roadmap close-out"
git push -u origin drs-teamwide-fix
gh pr create --title "DRS team-wide fix: claim reviews on every over, both sides + baseline/joker/price re-measurement" --body "..."
gh pr merge --merge --delete-branch
git checkout main && git pull
```
