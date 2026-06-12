# Difficulty Sheet v2 + Prize Escalation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land Nico's difficulty-sheet v2 (new d-values + condition tour names + Tour-4 League gate) and the prize-escalation economy that replaces the removed endgame gate, then re-anchor the E3 ladder grid and career metrics.

**Architecture:** Data-table changes in `DifficultyLadder`/`TourSpec` (d-sheet, strength map, brain map), one topology change in `CareerState.mark_beaten`, new pure prize calculators in `Economy` + dials in `EconomyTuning`, paid out in `CareerResolver.play_season`. No ball/innings/match math is touched — zero sim ripple by construction. Spec: `docs/superpowers/specs/2026-06-12-difficulty-sheet-v2-design.md` (DV1–DV12).

**Tech Stack:** Godot 4.6.3 GDScript (tabs), GUT 9.6. Suite currently **499 green**; judge red by parse-error/failed assert, green by count climbing + `All tests passed`.

**Run commands (every task):**
- Import (only after adding new script files — none are added here): `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- Full suite (<1s, always the whole suite — `-gtest` does not filter): `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

---

### Task 1: D-sheet v2 — `DifficultyLadder` names/table/brains + `TourSpec.mean_frac`

**Files:**
- Modify: `scripts/data/difficulty_ladder.gd`
- Modify: `scripts/data/tour_spec.gd:21-23`
- Test: `tests/unit/test_difficulty_ladder.gd`

- [ ] **Step 1: Rewrite the ladder tests to pin v2**

Replace the bodies of the affected tests in `tests/unit/test_difficulty_ladder.gd` (keep `test_tour_spec_mid_anchor_matches_ref_scalar` and `test_ladder_star_field_shape` unchanged):

```gdscript
func test_tour_spec_mean_frac_endpoints() -> void:
	# v2 (spec DV2): same 0.40-1.30 span stretched over d 1-20.
	assert_almost_eq(TourSpec.mean_frac(1.0), 0.4, 0.0001)
	assert_almost_eq(TourSpec.mean_frac(20.0), 1.3, 0.0001)


func test_tour_spec_make_tour_arithmetic() -> void:
	var spec := TourSpec.new()
	spec.d = 20.0
	var tour := spec.make_tour()
	assert_almost_eq(tour.mean, 1.3 * 31.25, 0.001)
	assert_almost_eq(tour.spread, 0.3 * tour.mean, 0.001)


func test_ladder_has_24_cells_with_v2_bands() -> void:
	var cells := DifficultyLadder.all()
	assert_eq(cells.size(), 24)
	# v2 bands (spec DV1): Club 1-10, City 5-15, Province 9-20.
	var lo := [1.0, 5.0, 9.0]
	var hi := [10.0, 15.0, 20.0]
	for lvl in range(3):
		assert_almost_eq(DifficultyLadder.spec_for(lvl, 0).d, lo[lvl], 0.0001)
		assert_almost_eq(DifficultyLadder.spec_for(lvl, 7).d, hi[lvl], 0.0001)


func test_ladder_d_linear_ramp_with_premier_jump() -> void:
	for lvl in range(3):
		# Linear 1-step ramp across tours 1-7 (indices 0-6)...
		for t in range(1, 7):
			assert_almost_eq(
				DifficultyLadder.spec_for(lvl, t).d - DifficultyLadder.spec_for(lvl, t - 1).d,
				1.0, 0.0001)
		# ...then the jump into Premier (spec DV1: +3 / +4 / +5 by Level).
		assert_gte(DifficultyLadder.spec_for(lvl, 7).d - DifficultyLadder.spec_for(lvl, 6).d, 3.0)


func test_ladder_overlap_anchors_are_exact() -> void:
	# Nico's structural anchor (spec DV2): next Level's Tour 1 == this Level's
	# Tour 5 (same d => identical sim).
	for lvl in range(2):
		assert_almost_eq(
			DifficultyLadder.spec_for(lvl + 1, 0).d,
			DifficultyLadder.spec_for(lvl, 4).d, 0.0001)


func test_ladder_brain_progression() -> void:
	# v2 brain map (spec DV3).
	var club_t1 := DifficultyLadder.spec_for(0, 0)
	assert_eq(club_t1.brain_tier, TourSpec.Tier.NAIVE)
	assert_almost_eq(club_t1.blend, 1.0, 0.0001)
	var club_premier := DifficultyLadder.spec_for(0, 7)        # d10
	assert_eq(club_premier.brain_tier, TourSpec.Tier.TEXTBOOK)
	assert_almost_eq(club_premier.blend, 1.0, 0.0001)
	var city_premier := DifficultyLadder.spec_for(1, 7)        # d15
	assert_eq(city_premier.brain_tier, TourSpec.Tier.STATIC_EQ)
	assert_almost_eq(city_premier.blend, 1.0, 0.0001)
	var province_premier := DifficultyLadder.spec_for(2, 7)    # d20
	assert_eq(province_premier.brain_tier, TourSpec.Tier.ADAPTIVE)
	assert_almost_eq(province_premier.blend, 1.0, 0.0001)


func test_ladder_v2_tour_names() -> void:
	# Condition flavours (spec DV1; names-only this rung, DV4).
	assert_eq(DifficultyLadder.TOUR_NAMES, [
		"Flat & Warm", "Spin", "Green Mamba", "Day Mixed",
		"Evening Spin", "Evening Mamba", "Evening Mixed", "Premier",
	])
	assert_eq(DifficultyLadder.spec_for(0, 3).cell_name, "Club Day Mixed")
```

Delete `test_ladder_levels_overlap` (superseded by `test_ladder_overlap_anchors_are_exact`).

- [ ] **Step 2: Run suite — expect FAILS** (old table asserted by new tests): `.../Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

- [ ] **Step 3: Implement v2 tables**

`scripts/data/tour_spec.gd` — replace the `mean_frac` block (keep everything else):

```gdscript
# mean_frac spans 0.40 (d=1) .. 1.30 (d=20), linear (v2 spec DV2 — same span
# as v1, stretched over the d 1-20 sheet; d=20 = the measured-hard anchor).
static func mean_frac(p_d: float) -> float:
	return 0.4 + (p_d - 1.0) * 0.9 / 19.0
```

Also update the `tour_index` comment on line 14 to `# 0..7 (Flat & Warm .. Premier)`.

`scripts/data/difficulty_ladder.gd` — replace `TOUR_NAMES`, `D_SHEET`, `brain_for`, and the header comment:

```gdscript
# The Career grid's difficulty table — v2 (spec
# 2026-06-12-difficulty-sheet-v2-design.md DV1-DV3, superseding the E3 v1
# sheet): Nico's condition-named tours, linear 1-step ramp inside a Level,
# jump into Premier, bands Club 1-10 / City 5-15 / Province 9-20.

const LEVEL_NAMES := ["Club", "City", "Province"]
const TOUR_NAMES := [
	"Flat & Warm", "Spin", "Green Mamba", "Day Mixed",
	"Evening Spin", "Evening Mamba", "Evening Mixed", "Premier",
]

# d per [level][tour_index] — Nico's sheet verbatim (DV1).
const D_SHEET := [
	[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 10.0],
	[5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 15.0],
	[9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 20.0],
]
```

```gdscript
# d -> [tier, blend] — v1 thresholds scaled 19/11 onto the d 1-20 axis (DV3).
# The ADAPTIVE 0.5 band (d 16-18) is currently unoccupied; kept for ramp
# continuity under future sheet edits.
static func brain_for(d: float) -> Array:
	if d <= 3.0:
		return [TourSpec.Tier.NAIVE, 1.0]
	if d <= 6.0:
		return [TourSpec.Tier.TEXTBOOK, 0.5]
	if d <= 10.0:
		return [TourSpec.Tier.TEXTBOOK, 1.0]
	if d <= 13.0:
		return [TourSpec.Tier.STATIC_EQ, 0.5]
	if d <= 15.0:
		return [TourSpec.Tier.STATIC_EQ, 1.0]
	if d <= 18.0:
		return [TourSpec.Tier.ADAPTIVE, 0.5]
	return [TourSpec.Tier.ADAPTIVE, 1.0]
```

- [ ] **Step 4: Run suite — expect PASS, count ≥ 499** (same test count: one deleted, one added)

- [ ] **Step 5: Commit**

```bash
git add scripts/data/difficulty_ladder.gd scripts/data/tour_spec.gd tests/unit/test_difficulty_ladder.gd
git commit -m "Difficulty sheet v2: d-table + condition tour names + mean_frac /19 re-map + brain re-map (DV1-DV3)"
```

---

### Task 2: Tour-4 League gate in `CareerState` (+ PREMIER_TOUR rename)

**Files:**
- Modify: `scripts/data/career_state.gd:15,88-100,104-113`
- Test: `tests/unit/test_career_state.gd`, `tests/unit/test_save_manager.gd:141-153`

- [ ] **Step 1: Rewrite the gate tests**

In `tests/unit/test_career_state.gd`, replace `test_beat_unlocks_up_and_across` with:

```gdscript
func test_beat_unlocks_next_tour_only_off_gate() -> void:
	# v2 (spec DV5): a non-gate beat unlocks the next Tour, NOT the next League.
	var s := _state()
	s.mark_beaten(0, 0)
	assert_eq(s.status_of(0, 0), CareerState.CellStatus.BEATEN, "cell beaten")
	assert_true(s.is_unlocked(0, 1), "next Tour unlocked")
	assert_false(s.is_unlocked(1, 0), "next League stays locked")
	assert_true(s.is_unlocked(0, 0), "beaten cell stays replayable")


func test_beating_tour4_unlocks_next_league_at_tour1() -> void:
	# v2 (spec DV5): Day Mixed (index 3) is the League gate -> (L+1, 0).
	var s := _state()
	s.cell_status[s.cell_index(0, 3)] = CareerState.CellStatus.UNLOCKED
	s.mark_beaten(0, 3)
	assert_true(s.is_unlocked(0, 4), "next Tour unlocked")
	assert_true(s.is_unlocked(1, 0), "City Flat & Warm unlocked")
	assert_false(s.is_unlocked(1, 3), "City's own gate cell NOT directly unlocked")


func test_province_gate_beat_has_no_level_above() -> void:
	var s := _state()
	s.cell_status[s.cell_index(2, 3)] = CareerState.CellStatus.UNLOCKED
	s.mark_beaten(2, 3)   # no level 3 — must not crash
	assert_true(s.is_unlocked(2, 4))
```

In `tests/unit/test_save_manager.gd` `test_career_save_then_load_roundtrips`, change the unlock setup/assert lines:

```gdscript
	c.mark_beaten(0, 3)
```
(replaces `c.mark_beaten(0, 0)`) and

```gdscript
	assert_eq(loaded.status_of(0, 3), CareerState.CellStatus.BEATEN)
	assert_true(loaded.is_unlocked(1, 0), "unlock state survives")
```
(replaces the `status_of(0, 0)` assert; keep all other asserts).

- [ ] **Step 2: Run suite — expect FAIL** (`is_unlocked(1, 0)` true off-gate under old rule)

- [ ] **Step 3: Implement the gate**

`scripts/data/career_state.gd` — rename the constant (line 15) and add the gate const:

```gdscript
const PREMIER_TOUR := 7
const LEAGUE_GATE_TOUR := 3   # Day Mixed — beating it unlocks the next League (v2 DV5)
```

Update `record_outcome`'s reference (`tour == PREMIER_TOUR`) and its comment to say "Premier-Final win -> Level won; Province Premier win -> Career complete". Replace `mark_beaten`:

```gdscript
# Beating (L,T) unlocks (L,T+1); beating the League-gate Tour (Day Mixed,
# index 3) also unlocks the next League at its first tour (L+1, 0) —
# difficulty-sheet v2 (spec DV5), replacing v1's "any beat unlocks across".
func mark_beaten(level: int, tour: int) -> void:
	cell_status[cell_index(level, tour)] = CellStatus.BEATEN
	_unlock(level, tour + 1)
	if tour == LEAGUE_GATE_TOUR:
		_unlock(level + 1, 0)
```

Also update the `is_unlocked` comment block (lines 37-39) "Province Premium" → "Province Premier".

- [ ] **Step 4: Run suite — expect career_state/save_manager green, but `test_career_resolver` FAILS** (its setups assume the old across-unlock — fixed next step, same task since they pin the same rule)

- [ ] **Step 5: Update the resolver tests' unlock setups**

In `tests/unit/test_career_resolver.gd`:
- `test_cross_level_guarantee_on_fresh_beat` line 68: `s.mark_beaten(0, 0)` → `s.mark_beaten(0, 3)` (comment: `# gate beat unlocks (1,0)`)
- `test_down_level_offer_always_present_while_lower_level_unwon` line 87: same change
- `test_no_down_level_offer_once_lower_level_won` line 100: same change
- `test_play_season_beat_updates_grid` lines 215-216: replace

```gdscript
				assert_true(s.is_unlocked(0, 1), "up cell open")
				assert_false(s.is_unlocked(1, 0), "League gate holds — Practise is not the gate cell")
```

- [ ] **Step 6: Run suite — expect PASS, count ≥ 500** (career_state +1 net)

- [ ] **Step 7: Commit**

```bash
git add scripts/data/career_state.gd tests/unit/test_career_state.gd tests/unit/test_save_manager.gd tests/unit/test_career_resolver.gd
git commit -m "Tour-4 League gate: beating Day Mixed unlocks the next League at Tour 1 (DV5); PREMIER_TOUR rename (DV10)"
```

---

### Task 3: Prize objects — `Economy` + `EconomyTuning` dials

**Files:**
- Modify: `scripts/data/economy_tuning.gd` (append to the win-bonus section)
- Modify: `scripts/domain/economy.gd` (below `win_bonus`)
- Test: `tests/unit/test_economy.gd` (below the win_bonus tests)

- [ ] **Step 1: Write the failing prize tests**

Append to `tests/unit/test_economy.gd`:

```gdscript
# --- prize escalation + prize objects (difficulty-sheet v2, DV7-DV9) ---

func test_prize_escalation_defaults() -> void:
	# Per-tour absolute multipliers vs the T1 base (Nico 2026-06-12: T8 = 1.6x).
	assert_eq(_etun.prize_escalation.size(), 8)
	assert_almost_eq(_etun.prize_escalation[0], 1.0, 0.0001)
	assert_almost_eq(_etun.prize_escalation[3], 1.1, 0.0001)
	assert_almost_eq(_etun.prize_escalation[7], 1.6, 0.0001)


func test_match_win_prize_escalates_with_tour() -> void:
	assert_eq(Economy.match_win_prize(0, 0, _etun), 5, "Club T1 = win_bonus base")
	assert_eq(Economy.match_win_prize(0, 7, _etun), 8, "Club Premier 5 x 1.6")
	assert_eq(Economy.match_win_prize(2, 7, _etun), 24, "Province Premier 15 x 1.6")


func test_playoff_and_final_bonuses_escalate() -> void:
	assert_eq(Economy.playoff_win_bonus(0, 0, _etun), 15, "base 15")
	assert_eq(Economy.playoff_win_bonus(1, 4, _etun), 33, "(15+10) x 1.3 = 32.5 -> 33")
	assert_eq(Economy.final_appearance_bonus(0, 0, _etun), 25)
	assert_eq(Economy.grand_final_prize(2, 7, _etun), 224, "(60+80) x 1.6")


func test_premier_super_prize_flat_by_level() -> void:
	# Not escalated (spec DV8): the T8-only trophy payout.
	assert_eq(Economy.premier_super_prize(0, _etun), 250)
	assert_eq(Economy.premier_super_prize(1, _etun), 500)
	assert_eq(Economy.premier_super_prize(2, _etun), 750)


func test_season_prizes_by_finish_position() -> void:
	# Runner-up: reached The Final (semi won) but no grand-final prize.
	assert_eq(Economy.season_prizes(2, false, 0, 0, _etun), 25 + 15)
	# 3rd: won the 3rd-place playoff only.
	assert_eq(Economy.season_prizes(3, false, 0, 0, _etun), 15)
	# 4th or below the playoffs: nothing.
	assert_eq(Economy.season_prizes(4, false, 0, 0, _etun), 0)
	assert_eq(Economy.season_prizes(7, false, 0, 0, _etun), 0)


func test_season_prizes_champion_and_premier_super() -> void:
	# Champion off-Premier: appearance + playoff win + grand final.
	assert_eq(Economy.season_prizes(1, true, 0, 0, _etun), 25 + 15 + 60)
	# Champion at Club Premier: all of it x1.6 (rounded each) + the super prize.
	var expected := int(round(25 * 1.6)) + int(round(15 * 1.6)) \
		+ int(round(60 * 1.6)) + 250
	assert_eq(Economy.season_prizes(1, true, 0, 7, _etun), expected)
```

- [ ] **Step 2: Run suite — expect FAIL** (`prize_escalation` / `match_win_prize` not declared — parse-level red counts)

- [ ] **Step 3: Implement dials + calculators**

Append to `scripts/data/economy_tuning.gd` (after the win-bonus section):

```gdscript
# Prize escalation + prize objects (difficulty-sheet v2, spec DV7/DV8 — the
# incentive replacing the removed endgame gate). Escalation = per-tour ABSOLUTE
# multipliers vs the Tour-1 base (Nico 2026-06-12: not compounding, T8 = 1.6x);
# scales the four match-prize objects only — game fee + performance pay are
# untouched, so build-pay equality is untouched.
@export var prize_escalation: Array[float] = [1.0, 1.1, 1.1, 1.1, 1.3, 1.4, 1.5, 1.6]
@export var playoff_win_base: float = 15.0        # winning a semi / the 3rd-place playoff
@export var playoff_win_level_step: float = 10.0
@export var final_appearance_base: float = 25.0   # playing The Final
@export var final_appearance_level_step: float = 15.0
@export var grand_final_base: float = 60.0        # winning The Final
@export var grand_final_level_step: float = 40.0
@export var premier_super_base: float = 250.0     # Premier (T8) Grand Final trophy payout,
@export var premier_super_level_step: float = 250.0   # NOT escalated (DV8)
```

Append to `scripts/domain/economy.gd` (after `win_bonus`):

```gdscript
# --- Prize escalation + prize objects (difficulty-sheet v2, spec DV7-DV9) ----
# Escalation scales the match-prize objects only (Nico's ruling) — never the
# game fee or performance pay. All are team outcomes: build-independent.

static func match_win_prize(level: int, tour: int, tuning: EconomyTuning) -> int:
	return int(round(win_bonus(level, tuning) * tuning.prize_escalation[tour]))


static func playoff_win_bonus(level: int, tour: int, tuning: EconomyTuning) -> int:
	return int(round((tuning.playoff_win_base + tuning.playoff_win_level_step * level)
		* tuning.prize_escalation[tour]))


static func final_appearance_bonus(level: int, tour: int, tuning: EconomyTuning) -> int:
	return int(round((tuning.final_appearance_base + tuning.final_appearance_level_step * level)
		* tuning.prize_escalation[tour]))


static func grand_final_prize(level: int, tour: int, tuning: EconomyTuning) -> int:
	return int(round((tuning.grand_final_base + tuning.grand_final_level_step * level)
		* tuning.prize_escalation[tour]))


# Flat by Level, not escalated (DV8): only payable at T8, so escalation would
# just fold into the dial.
static func premier_super_prize(level: int, tuning: EconomyTuning) -> int:
	return int(round(tuning.premier_super_base + tuning.premier_super_level_step * level))


# The Season-level payout from a final table position (DV9). final_pos is
# 1..8 (0 = unknown -> nothing). Positions 1-2 played The Final (a semi win);
# position 3 won the 3rd-place playoff.
static func season_prizes(final_pos: int, won_final: bool, level: int, tour: int,
		tuning: EconomyTuning) -> int:
	var total := 0
	if final_pos >= 1 and final_pos <= 2:
		total += final_appearance_bonus(level, tour, tuning)
		total += playoff_win_bonus(level, tour, tuning)
	elif final_pos == 3:
		total += playoff_win_bonus(level, tour, tuning)
	if won_final:
		total += grand_final_prize(level, tour, tuning)
		if tour == CareerState.PREMIER_TOUR:
			total += premier_super_prize(level, tuning)
	return total
```

- [ ] **Step 4: Run suite — expect PASS, count ≥ 506**

- [ ] **Step 5: Commit**

```bash
git add scripts/data/economy_tuning.gd scripts/domain/economy.gd tests/unit/test_economy.gd
git commit -m "Prize escalation economy: per-tour multipliers + playoff/final/grand-final objects + Premier super prize (DV7-DV9)"
```

---

### Task 4: Pay the prizes in `CareerResolver.play_season`

**Files:**
- Modify: `scripts/domain/career_resolver.gd:132-141`
- Test: `tests/unit/test_career_resolver.gd:167-186`

- [ ] **Step 1: Update the reconciliation test to the v2 pay formula**

In `test_play_season_pay_reconciles_with_match_pay`, replace the expected-pay loop body and add the season-prize line (the rest of the test stands; it plays tour 0 so escalation is 1.0 but `season_prizes` can still pay on a playoff finish):

```gdscript
	for m in played:
		expected += Economy.match_pay(m, stars_at_play, etun)["total"]
		if m.outcome == MatchResult.Outcome.PLAYER_WIN:
			wins += 1
			expected += Economy.match_win_prize(0, 0, etun)
	expected += Economy.season_prizes(
		season.player_final_position, season.won_final, 0, 0, etun)
	assert_eq(out["pay"], expected, "pay = match pay + win prizes + season prizes")
	assert_eq(out["wins"], wins, "wins reported")
```

- [ ] **Step 2: Run suite — PASS or FAIL depends on seed 13's finish.** If it passes (seed finished 4th+ at tour 0, where `match_win_prize == win_bonus`), the test is still the right pin — proceed; the implementation step below is then guarded by it for any future prize-paying regression. To force a red first, temporarily assert `Economy.season_prizes(2, false, 0, 0, etun) == 0` is NOT used — skip theatrics: accept this test as a characterization pin and rely on Task 3's red for TDD discipline.

- [ ] **Step 3: Implement the payout**

In `scripts/domain/career_resolver.gd` `play_season`, replace the pay loop (lines 133-139):

```gdscript
	var pay := 0
	var wins := 0
	for m in _player_matches(season):
		pay += Economy.match_pay(m, stars_at_play, etun)["total"]
		if m.outcome == MatchResult.Outcome.PLAYER_WIN:
			wins += 1
			pay += Economy.match_win_prize(level, tour_index, etun)
	# Season-level prizes (difficulty-sheet v2 DV9): reached/won The Final,
	# 3rd-place playoff, Premier super prize.
	pay += Economy.season_prizes(
		season.player_final_position, season.won_final, level, tour_index, etun)
	player.tons_balance += pay
```

Update the function's doc comment "(DC9 + DC10)" → "(DC9 + DC10 + v2 prizes DV7-DV9)".

- [ ] **Step 4: Run suite — expect PASS, count ≥ 506**

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/career_resolver.gd tests/unit/test_career_resolver.gd
git commit -m "Career pay: match-win prize escalates by tour + season prizes paid from final position (DV9)"
```

---

### Task 5: Re-anchor — E3 ladder sweep + career preview, viz + canon docs

**Files:**
- Run: `tools/sweep_difficulty_ladder.gd` (full N=200), `tools/career_preview.gd` (full N=100)
- Modify: `docs/mockups/difficulty-ladder-v1.html` (DATA block + captions), `docs/mockups/career-loop-v1.html` (DATA block + captions), `CONTEXT.md` (canon lines 27/30/44/117/147), `docs/difficulty-sheet-v2.md` (mark built), spec §10 findings
- No test changes.

- [ ] **Step 1: Run the E3 ladder sweep** (ONE Godot process at a time; ~3-20 min):

```bash
nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_difficulty_ladder.gd > /tmp/e3_v2_sweep.log 2>&1 &
```

Watch by grepping the LOG (never pgrep): `grep -c "DATA = " /tmp/e3_v2_sweep.log` until 1.

- [ ] **Step 2: Run the career preview** (after the sweep exits — never overlapping):

```bash
nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/career_preview.gd > /tmp/career_v2_preview.log 2>&1 &
```

Same log-grep watch for its final DATA line.

- [ ] **Step 3: Acceptance checks (spec DV12)** against the sweep output: d monotone in beat-rate within each Level (within noise), Premier clearly harder than T7 at every Level, City T1 ≈ Club T5 beat-rate (same-d identical sims), Province Premier in the ~10-20% band, careers still complete in the preview (no softlock), bank trajectory shows the prize income. Any breach → stop and re-tune the brain table or prize dials, re-run, and record the change in spec §10.

- [ ] **Step 4: Refresh both viz DATA blocks** with the new JSON lines + update captions that name tours ("Practise"/"Premium" → v2 names) and the unlock rule.

- [ ] **Step 5: Update canon docs**: CONTEXT.md — Career entry (line ~27: unlock = next Tour; Day Mixed gate opens the next Level; Premier naming), Tour entry (line ~30: the 8 condition names), Win-a-Level entries (~44/117: "Premier", trophy payout now = the prize objects + super prize), Difficulty-topology resolution (~147: v2 bands + pointer to `docs/difficulty-sheet-v2.md`). Mark `docs/difficulty-sheet-v2.md` header "Not yet built" → built by this rung. Fill spec §10 findings (measured grid, career metrics, prize readout).

- [ ] **Step 6: Run suite one last time — expect PASS ≥ 506; commit**

```bash
git add docs/ CONTEXT.md
git commit -m "Difficulty sheet v2 re-anchor: measured beat-grid + career metrics with prizes; viz + CONTEXT canon refreshed"
```

---

### Task 6: PR + merge + roadmap

- [ ] Push branch, open PR, merge to `main`, sync local, delete branch.
- [ ] Update `PROJECT_ROADMAP.md`: status line + Last closed + decisions log + Next session handoff (→ E4, now unblocked).
- [ ] Final commit + push on `main` via the PR.

## Self-review notes

- Spec coverage: DV1-DV3 → Task 1 · DV5/DV10 → Task 2 · DV6 → no code change (covered by updated resolver tests) · DV7-DV9 → Tasks 3-4 · DV4 → no code (names only, Task 1) · DV11/DV12 → Task 5 · close-out → Task 6.
- Type consistency: `match_win_prize(level, tour, etun)`, `season_prizes(final_pos, won_final, level, tour, etun)` used identically in Tasks 3 and 4; `PREMIER_TOUR` introduced Task 2, referenced Task 3 (Task ordering matters: Task 3's `season_prizes` references `CareerState.PREMIER_TOUR` — Task 2 must land first; order is enforced by the plan sequence).
- Round-half check: GDScript `round(32.5)` = 33 (half away from zero) — pinned in `test_playoff_and_final_bonuses_escalate`.
