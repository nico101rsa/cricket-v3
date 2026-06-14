# Career-line balancing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the 9 career lines (3 climb × 3 spend) equally viable and equally paced — completion within ~5 pts of each other and every median time-to-beat in 27–33h — via a soft readiness gate plus a farm-trigger fix, then an iterative oracle tune.

**Architecture:** Two code changes + a measure-tune loop. (1) Raise the next-League unlock from tour 3 to a tunable `READINESS_TOUR` in `CareerState` so the rusher must climb most of each league before crossing. (2) Fix `CareerPolicy`'s `farm` so it crosses on card-maxed-OR-`FARM_MIN_SEASONS`-at-Level (needs a new `seasons_at_level` counter on `CareerState`) so `joker_only`/`balanced` stop softlocking at 0%. Then sweep the two dials (reserve dials only if measurement demands) via `tools/career_search.gd` until the acceptance bar is green.

**Tech Stack:** Godot 4.6.3 / GDScript, GUT 9.6 test framework. Pure domain logic in `scripts/data` + `scripts/domain`; measurement harness in `scripts/harness` + `tools`.

**Spec:** `docs/superpowers/specs/2026-06-14-career-line-balancing-design.md`

---

## Conventions for every task (project CLAUDE.md)

- **Godot binary:** `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH).
- **Quit the Godot editor before any headless run** (two importers deadlock).
- **ONE Godot process at a time.** Always chain import + test in a single command:
  ```sh
  /Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -25
  ```
- **GUT `-gtest` does NOT filter here** — the whole suite runs every time. Judge **RED** by a `SCRIPT ERROR: Parse Error: Identifier "X" not declared` (a not-yet-defined `const`/field shows up this way, GUT skips that file). Judge **GREEN** by the total test count climbing past **556** and `All tests passed`.
- **Indentation is tabs** in `.gd` files.
- **Commit `*.gd.uid` for scripts under `scripts/`**, never for `tests/` (test scripts generate no `.uid`).
- If a run suddenly fails to load GUT, suspect iCloud `" 2"` conflict files: `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot` then re-import.

---

## Task 1: `seasons_at_level` counter on `CareerState`

The farm trigger needs to know how many Seasons have been played at the current Level. Add the field + wire increment/reset before touching the policy.

**Files:**
- Modify: `scripts/data/career_state.gd`
- Modify: `scripts/domain/career_resolver.gd`
- Test: `tests/unit/test_career_resolver.gd`, `tests/unit/test_career_state.gd`

- [ ] **Step 1: Write the failing tests**

In `tests/unit/test_career_state.gd`, add:

```gdscript
func test_fresh_state_seasons_at_level_zero() -> void:
	var s := CareerState.new()
	assert_eq(s.seasons_at_level, 0, "fresh state has lingered zero Seasons")
```

In `tests/unit/test_career_resolver.gd`, replace `test_accept_offer_moves_team_and_resets_affinity` body to also assert the counter resets, and add a counter-increment assertion to `test_play_season_ticks_counter_and_banks_pay`:

```gdscript
func test_accept_offer_moves_team_and_resets_affinity() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	p.affinity = 4
	s.seasons_at_level = 6
	var o := Offer.new()
	o.team_index = 9
	o.level = 1
	CareerResolver.accept_offer(s, p, o)
	assert_eq(s.current_team_index, 9)
	assert_eq(s.current_level(), 1, "Level follows the Team")
	assert_eq(p.affinity, 0, "Affinity resets on accept")
	assert_eq(s.seasons_at_level, 0, "seasons_at_level resets on a cross-up")
```

Add immediately after `test_play_season_ticks_counter_and_banks_pay`:

```gdscript
func test_play_season_increments_seasons_at_level() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	_play(s, p, 0, 7)
	assert_eq(s.seasons_at_level, 1, "one Season played at this Level")
	_play(s, p, 0, 8)
	assert_eq(s.seasons_at_level, 2, "ticks each Season until a cross-up")
```

- [ ] **Step 2: Run to verify RED**

Run the chained import+test command. Expected: parse error / failures referencing `seasons_at_level` (field not declared).

- [ ] **Step 3: Add the field**

In `scripts/data/career_state.gd`, after the `seasons_played` export (line ~22), add:

```gdscript
@export var seasons_at_level: int = 0   # Seasons at the current Level since the last
                                        # cross-up; resets on accept_offer. Feeds the
                                        # farm climb trigger (career-line balancing).
```

- [ ] **Step 4: Wire increment + reset**

In `scripts/domain/career_resolver.gd`, in `play_season`, beside `state.seasons_played += 1` (line ~185), add:

```gdscript
	state.seasons_played += 1
	state.seasons_at_level += 1
```

In `accept_offer` (line ~99), add the reset:

```gdscript
static func accept_offer(state: CareerState, player: Player, offer: Offer) -> void:
	state.current_team_index = offer.team_index
	state.seasons_at_level = 0
	player.affinity = 0
```

- [ ] **Step 5: Run to verify GREEN**

Run the chained command. Expected: `All tests passed`, count climbed by 2 (558).

- [ ] **Step 6: Commit**

```sh
git add scripts/data/career_state.gd scripts/data/career_state.gd.uid \
  scripts/domain/career_resolver.gd scripts/domain/career_resolver.gd.uid \
  tests/unit/test_career_state.gd tests/unit/test_career_resolver.gd
git commit -m "Career-line balancing: seasons_at_level counter on CareerState"
```

---

## Task 2: Soft readiness gate (`READINESS_TOUR`)

Raise the next-League unlock from tour 3 (Day Mixed) to `READINESS_TOUR` (default 5). Update the existing gate tests in the SAME task so the suite stays green.

**Files:**
- Modify: `scripts/data/career_state.gd`
- Test: `tests/unit/test_career_state.gd`, `tests/unit/test_career_resolver.gd`, `tests/unit/test_save_manager.gd`

- [ ] **Step 1: Write/repoint the failing tests**

In `tests/unit/test_career_state.gd`, **replace** `test_beating_tour4_unlocks_next_league_at_tour1` with the new gate behaviour, and add a top-Level no-crash check:

```gdscript
func test_beating_readiness_tour_unlocks_next_league_at_tour1() -> void:
	# Career-line balancing: the next League opens off READINESS_TOUR (Evening
	# Mamba, index 5), NOT the old gate tour 3 — so the rusher climbs most of
	# the league before crossing.
	var s := CareerState.new()
	s.cell_status = _all_locked()
	s.mark_beaten(0, 5)
	assert_true(s.is_unlocked(0, 6), "next Tour unlocked")
	assert_true(s.is_unlocked(1, 0), "City Flat & Warm unlocked off the readiness tour")
	assert_false(s.is_unlocked(1, 3), "City's own cells beyond Flat & Warm NOT unlocked")

func test_beating_old_gate_tour_no_longer_unlocks_next_league() -> void:
	var s := CareerState.new()
	s.cell_status = _all_locked()
	s.mark_beaten(0, 3)
	assert_true(s.is_unlocked(0, 4), "next Tour still unlocks")
	assert_false(s.is_unlocked(1, 0), "tour 3 (Day Mixed) no longer opens the next League")

func test_readiness_tour_at_top_level_does_not_crash() -> void:
	var s := CareerState.new()
	s.cell_status = _all_locked()
	s.mark_beaten(2, 5)   # no level 3 to unlock — must not crash
	assert_true(s.is_unlocked(2, 6))
```

> Note: `_all_locked()` is the existing helper in this test file that builds a fully-LOCKED `cell_status` array (used by the current gate tests). If the existing test instead inlines the array, mirror that pattern. Check the top of `test_career_state.gd` for the exact setup used by `test_beating_tour4_unlocks_next_league_at_tour1` and copy it.

In `tests/unit/test_career_resolver.gd`, repoint the three offer-setup beats from tour 3 to tour 5 (lines ~68, ~87, ~100 — each `s.mark_beaten(0, 3)` that exists to unlock City):

```gdscript
	s.mark_beaten(0, 5)   # readiness-tour beat unlocks (1,0) — career-line balancing
```

In `tests/unit/test_save_manager.gd`, line ~144, repoint:

```gdscript
	c.mark_beaten(0, 5)   # the readiness gate cell — unlocks (1,0)
```

- [ ] **Step 2: Run to verify RED**

Run the chained command. Expected: the new `test_beating_readiness_tour…` fails (tour 5 does not yet unlock the next League) and/or `test_beating_old_gate…` fails (tour 3 still unlocks it).

- [ ] **Step 3: Implement the gate change**

In `scripts/data/career_state.gd`, replace the `LEAGUE_GATE_TOUR` const (line ~16):

```gdscript
const READINESS_TOUR := 5   # Evening Mamba — the soft readiness gate (career-line
                            # balancing). Beating it unlocks the next League at Tour 1.
                            # Raised from tour 3 (Day Mixed) so the rusher must clear 6
                            # of 8 tours per League before crossing; Premier (7) stays
                            # optional (DP1). Tunable — swept by career_search.gd.
```

Update `mark_beaten` (line ~95) to fire off the readiness tour:

```gdscript
func mark_beaten(level: int, tour: int) -> void:
	cell_status[cell_index(level, tour)] = CellStatus.BEATEN
	_unlock(level, tour + 1)
	if tour == READINESS_TOUR:
		_unlock(level + 1, 0)
```

Grep for any other `LEAGUE_GATE_TOUR` references and update them (`grep -rn LEAGUE_GATE_TOUR scripts tools`). The roadmap/spec note none remain beyond `mark_beaten`, but verify.

- [ ] **Step 4: Run to verify GREEN**

Run the chained command. Expected: `All tests passed`, count climbed (Task-1 + new gate tests; ~560).

- [ ] **Step 5: Commit**

```sh
git add scripts/data/career_state.gd scripts/data/career_state.gd.uid \
  tests/unit/test_career_state.gd tests/unit/test_career_resolver.gd tests/unit/test_save_manager.gd
git commit -m "Career-line balancing: soft readiness gate (next League opens off tour 5)"
```

---

## Task 3: Farm-trigger fix (`FARM_MIN_SEASONS`)

`farm` must cross on card-maxed OR `seasons_at_level >= FARM_MIN_SEASONS` so non-training spends no longer softlock at 0%.

**Files:**
- Modify: `scripts/harness/career_policy.gd`
- Test: `tests/unit/test_career_policy.gd`

- [ ] **Step 1: Write the failing tests**

In `tests/unit/test_career_policy.gd`, add (adapt the `Player`/`CareerState` construction to the helpers already in this file — check how existing `_wants_to_cross`/`choose_offer` tests build their `state` and `player`):

```gdscript
func test_farm_crosses_after_min_seasons_even_unmaxed() -> void:
	var s := CareerState.new()
	var p := _fresh_player()   # card well below the cap
	s.seasons_at_level = CareerPolicy.FARM_MIN_SEASONS
	assert_true(CareerPolicy._wants_to_cross("farm", s, p),
		"farm crosses once it has lingered FARM_MIN_SEASONS, even unmaxed")

func test_farm_holds_before_min_seasons_when_unmaxed() -> void:
	var s := CareerState.new()
	var p := _fresh_player()
	s.seasons_at_level = CareerPolicy.FARM_MIN_SEASONS - 1
	assert_false(CareerPolicy._wants_to_cross("farm", s, p),
		"farm holds while under the linger cap and unmaxed")

func test_farm_crosses_immediately_when_maxed() -> void:
	var s := CareerState.new()
	var p := _maxed_player()   # all four attrs at ShopResolver.ATTR_CAP
	s.seasons_at_level = 0
	assert_true(CareerPolicy._wants_to_cross("farm", s, p),
		"a maxed card crosses without waiting for the linger cap")
```

> If `_fresh_player()` / `_maxed_player()` helpers don't exist in this test file, add them: a fresh `Player` with `Attributes` at 11 each, and one at `ShopResolver.ATTR_CAP` each. Mirror `tools/career_search.gd::_fresh_player()` for the fresh build.

- [ ] **Step 2: Run to verify RED**

Run the chained command. Expected: parse error referencing `FARM_MIN_SEASONS` (const not declared).

- [ ] **Step 3: Implement the trigger**

In `scripts/harness/career_policy.gd`, add the const near `KINDS` (line ~13):

```gdscript
const FARM_MIN_SEASONS := 8   # farm crosses after this many Seasons at a Level even if
                              # the card never maxes (joker_only/balanced never train) —
                              # fixes the 0% softlock. Tunable — swept by career_search.gd.
```

Replace the `"farm"` branch in `_wants_to_cross` (line ~50):

```gdscript
		"farm":
			# Over-invest before moving on: cross once the card maxes OR after
			# lingering FARM_MIN_SEASONS at this Level (the no-softlock fallback,
			# since joker_only/balanced never fully train).
			return _card_maxed(player) or state.seasons_at_level >= FARM_MIN_SEASONS
```

- [ ] **Step 4: Run to verify GREEN**

Run the chained command. Expected: `All tests passed`, count climbed by 3 (~563).

- [ ] **Step 5: Commit**

```sh
git add scripts/harness/career_policy.gd scripts/harness/career_policy.gd.uid \
  tests/unit/test_career_policy.gd
git commit -m "Career-line balancing: farm crosses on maxed-OR-FARM_MIN_SEASONS (no 0% softlock)"
```

---

## Task 4: Update CONTEXT.md canon

The readiness gate is a shipped game rule — the design source of truth must reflect it.

**Files:**
- Modify: `CONTEXT.md`

- [ ] **Step 1: Find the gate canon**

```sh
grep -n -i "Tour 4\|Day Mixed\|League gate\|gate tour\|unlocks the next League" CONTEXT.md
```

- [ ] **Step 2: Update the prose**

Change the "beating Tour 4 / Day Mixed unlocks the next League" canon to: **the next League unlocks by beating the readiness tour (Evening Mamba, the 6th of 8); the Premier (8th) stays an optional trophy chase.** Keep it brief and match surrounding style. (If the converged `READINESS_TOUR` ends up ≠ 5 after Task 6, re-touch this line — note that inline.)

- [ ] **Step 3: Commit**

```sh
git add CONTEXT.md
git commit -m "CONTEXT: next-League unlock now the readiness tour (Evening Mamba), not Day Mixed"
```

---

## Task 5: Baseline oracle run (measure the defaults)

Now measure the 9 arms with the new gate (tour 5) + farm fix (8) at defaults — the starting point for the tune.

**Files:** none (measurement only).

- [ ] **Step 1: Launch the full 9-arm oracle detached**

(>10-min run — must be detached per CLAUDE.md; the watcher greps the LOG, never pgrep.)

```sh
cd "/Users/nicomcdonald/Documents/Playground/Cricket v2"
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && \
nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s tools/career_search.gd > /tmp/cb_baseline.log 2>&1 &
```

- [ ] **Step 2: Watch for completion**

Poll the log for the final `DATA ` line (or Godot exiting):

```sh
grep -c "^DATA " /tmp/cb_baseline.log    # 1 == done
tail -20 /tmp/cb_baseline.log
```

- [ ] **Step 3: Record the 9-arm table**

Copy the per-arm lines (`arm <climb> x <spend>: …`) into the spec §10 as "Iteration 0 (defaults: READINESS_TOUR=5, FARM_MIN_SEASONS=8)". Compute completion max−min and note which arms are out of the 27–33h band.

- [ ] **Step 4: Commit the baseline record**

```sh
git add docs/superpowers/specs/2026-06-14-career-line-balancing-design.md
git commit -m "Career-line balancing: spec §10 iteration-0 baseline (gate=5, farm=8)"
```

---

## Task 6: Measure-tune loop (converge to the acceptance bar)

Iterate the two structural dials (reserve dials only if needed) until §2 is green: completion max−min ≤ 5 pts AND every median time-to-beat ∈ [27,33]h.

**Files:**
- Modify: `scripts/data/career_state.gd` (`READINESS_TOUR`), `scripts/harness/career_policy.gd` (`FARM_MIN_SEASONS`), and only-if-needed `scripts/data/economy_tuning.gd` / `scripts/data/difficulty_ladder.gd`.

- [ ] **Step 1: Read the latest table and decide the next move**

Decision rules (simplest mechanic first):
- **`rush` median time below 27h** → raise `READINESS_TOUR` (5 → 6). Re-run.
- **`rush`/`trophy` above 33h or completion too low** → lower `READINESS_TOUR` (5 → 4) or check difficulty.
- **`farm` off-pace / under-completes** → adjust `FARM_MIN_SEASONS` (6–12).
- **Completion spread > 5 pts and the gate alone won't close it** (trophy/farm climb more but don't finish faster) → reach for a reserve dial: raise the super-prize / prize-escalation sizes in `EconomyTuning` so the extra climbing buys a faster Province finish; or make the Province-Premier final more strength-sensitive. **If `EconomyTuning` is touched, note in §10 that the joker/build/pay/env ledger is unaffected (prize dials are off the ball path) — no ledger re-run owed.**

- [ ] **Step 2: Apply ONE dial change, re-run the oracle**

Edit the single chosen dial. Then the detached run (fresh log name per iteration, e.g. `/tmp/cb_iter2.log`):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && \
nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s tools/career_search.gd > /tmp/cb_iterN.log 2>&1 &
```

(Optional faster signal while triangulating: `CAREER_QUICK=1` for N=10, or `N=30`; confirm the final accepted config at full N=60.)

- [ ] **Step 3: Record the iteration in spec §10**

Append the iteration's dials + 9-arm table + the max−min and band check. Keep the running history so the convergence path is legible.

- [ ] **Step 4: Repeat Steps 1–3 until GREEN at N=60**

Acceptance: completion max−min ≤ 5 pts AND all 9 medians ∈ [27,33]h.

- [ ] **Step 5: Run the full unit suite once more (regression)**

Confirm the dial edits didn't break a literal-pinned test:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && \
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -15
```

Expected: `All tests passed`. (If `READINESS_TOUR`/`FARM_MIN_SEASONS` moved off the defaults, update the Task-3 linger tests only if they hard-coded a value — they reference the const, so they should still pass.)

- [ ] **Step 6: Commit the converged config**

```sh
git add scripts/data/career_state.gd scripts/data/career_state.gd.uid \
  scripts/harness/career_policy.gd scripts/harness/career_policy.gd.uid \
  docs/superpowers/specs/2026-06-14-career-line-balancing-design.md
# include economy_tuning.gd / difficulty_ladder.gd (+ .uid) only if a reserve dial moved
git commit -m "Career-line balancing: converged dials (gate=<X>, farm=<Y>) — all 9 arms green"
```

---

## Task 7: Findings + viz + roadmap

Make the result legible and hand off.

**Files:**
- Modify: `docs/superpowers/specs/2026-06-14-career-line-balancing-design.md` (§10 final), `docs/mockups/career-search-v1.html` (refresh DATA), `PROJECT_ROADMAP.md`, `CONTEXT.md` (only if the converged gate ≠ tour 5).

- [ ] **Step 1: Finalise spec §10**

Write the headline: the converged `READINESS_TOUR` / `FARM_MIN_SEASONS` (+ any reserve dial), the final 9-arm completion+time table proving §2 green (state the bar explicitly: completion max−min and the band), the iteration path summary, and the "ledger untouched (no ball/innings/joker/economy math)" confirmation.

- [ ] **Step 2: Refresh the viz**

Update the `DATA` block in `docs/mockups/career-search-v1.html` with the final N=60 arms so the 9-arm comparison reflects the balanced grid. (Open it in a browser to eyeball — Nico learns by seeing.)

- [ ] **Step 3: Update CONTEXT.md if the gate moved**

If the converged `READINESS_TOUR` ≠ 5, re-touch the Task-4 canon line to the actual tour name/index.

- [ ] **Step 4: Update PROJECT_ROADMAP.md**

Move career-line balancing into the done chain; refresh the "Next session" handoff (state, next step, seams). Note the rung GREEN and the converged dials.

- [ ] **Step 5: Commit + open the PR**

```sh
git add -A
git commit -m "Career-line balancing: findings, viz refresh, roadmap handoff"
git push -u origin career-line-balancing
gh pr create --title "Career-line balancing: soft readiness gate + farm fix" \
  --body "All 9 career lines within 5pts completion + 27-33h band. Spec/plan dated 2026-06-14."
```

Then merge the PR, sync local `main`, delete the branch (per the global commit policy).

---

## Self-review notes

- **Spec coverage:** §4 gate → Task 2; §5 farm + counter → Tasks 1 & 3; §6 dials/loop → Tasks 5 & 6; §7 tests → Tasks 1–3; §2 acceptance → Task 6; CONTEXT canon (CB-6) → Task 4; §10 findings → Task 7. All covered.
- **Type consistency:** `seasons_at_level` (int field on `CareerState`), `READINESS_TOUR` (const on `CareerState`), `FARM_MIN_SEASONS` (const on `CareerPolicy`), `_wants_to_cross(kind, state, player)` signature unchanged — names match across tasks.
- **Test helpers:** Tasks 1 & 3 reference existing test helpers (`_all_locked`, `_player`, `_play`, `_fresh_player`, `_maxed_player`); each step notes "verify/add if absent" so the engineer confirms against the actual file rather than assuming.
- **Ordering:** the counter (Task 1) lands before the farm trigger (Task 3) that consumes it; the gate change (Task 2) updates its own broken tests in-task so the suite never stays red across a commit.
