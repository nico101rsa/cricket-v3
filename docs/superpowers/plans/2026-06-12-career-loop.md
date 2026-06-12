# Career Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The headless multi-Season Career loop — grid navigation, ₸ income, star mutation, Offers, persistence — per spec `docs/superpowers/specs/2026-06-12-career-loop-design.md` (DC1–DC16).

**Architecture:** Pure data (`CareerState`, `Offer`) + static domain logic (`CareerResolver`) on top of the untouched `SeasonResolver`/`DifficultyLadder`/`Economy` seams; persistence via `SaveManager`; an eyeball oracle (`tools/career_preview.gd` → `docs/mockups/career-loop-v1.html`). **Zero sim-math changes, zero oracle ripple (DC3).**

**Tech Stack:** Godot 4.6.3 GDScript (tabs!), GUT 9.6. Suite currently **464 green**.

**House rules (project CLAUDE.md):**
- Run tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- After ADDING any script under `scripts/` or `tools/`: run `--import` once first:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- RED = `SCRIPT ERROR: Parse Error: Identifier "X" not declared` (GUT skips that file); GREEN = total count climbs + `All tests passed`. `-gtest` does NOT filter — always run the whole suite.
- ONE Godot process at a time; quit the editor first.
- Commit `*.gd.uid` for `scripts/` + `tools/` files; test files do NOT generate `.uid`.
- zsh: gate commits on grepping `All tests passed`, not `$?` of a pipeline.

---

### Task 1: `Economy.win_bonus` + dials (DC10)

**Files:**
- Modify: `scripts/data/economy_tuning.gd` (append dials)
- Modify: `scripts/domain/economy.gd` (append function)
- Test: `tests/unit/test_economy.gd` (append tests)

- [ ] **Step 1: Write the failing tests** — append to `tests/unit/test_economy.gd`:

```gdscript
# --- win_bonus (career-loop rung, DC10) ---

func test_win_bonus_scales_with_level() -> void:
	assert_eq(Economy.win_bonus(0, _etun), 5, "Club win bonus")
	assert_eq(Economy.win_bonus(1, _etun), 10, "City win bonus")
	assert_eq(Economy.win_bonus(2, _etun), 15, "Province win bonus")

func test_win_bonus_follows_dials() -> void:
	var t := EconomyTuning.new()
	t.win_bonus_base = 8.0
	t.win_bonus_level_step = 2.0
	assert_eq(Economy.win_bonus(2, t), 12, "8 + 2x2")
```

(`_etun` already exists in this test file as a default `EconomyTuning`.)

- [ ] **Step 2: Run suite, verify RED** — expect failing assertions / parse error on `win_bonus` (a missing *method* fails the test with "Invalid call", not a parse error — either is RED). Count stays 464 + new failures.

- [ ] **Step 3: Implement** — append to `scripts/data/economy_tuning.gd`:

```gdscript
# Team winning bonus (career-loop rung DC10, ideas cluster 2): ₸ per Player-team
# win, scaling with Level. Deliberately small next to ~₸66 match pay so
# build-pay equality is untouched (team wins are build-independent).
@export var win_bonus_base: float = 5.0
@export var win_bonus_level_step: float = 5.0
```

Append to `scripts/domain/economy.gd`:

```gdscript
# ₸ bonus per Player-team WIN (league or playoff), scaling with Level —
# career-loop rung DC10. match_pay is deliberately untouched.
static func win_bonus(level: int, tuning: EconomyTuning) -> int:
	return int(round(tuning.win_bonus_base + tuning.win_bonus_level_step * level))
```

- [ ] **Step 4: Run suite, verify GREEN** (count climbs past 464, `All tests passed`).
- [ ] **Step 5: Commit** — `git add scripts/data/economy_tuning.gd scripts/domain/economy.gd tests/unit/test_economy.gd && git commit -m "Career loop: Economy.win_bonus per-win team bonus scaling with Level (DC10)"`

---

### Task 2: `CareerState` + `Offer` data classes (DC4/DC6, §3.1–3.2)

**Files:**
- Create: `scripts/data/career_state.gd`
- Create: `scripts/data/offer.gd`
- Test: `tests/unit/test_career_state.gd` (new)

- [ ] **Step 1: Write the failing tests** — create `tests/unit/test_career_state.gd`:

```gdscript
extends GutTest

# CareerState grid topology + transitions (spec 2026-06-12-career-loop-design.md
# DC4, §3.1). States here are built by hand; start_career() is CareerResolver's
# (Task 3).

func _state() -> CareerState:
	var s := CareerState.new()
	var stars := [1.5, 2.0, 2.5, 3.0, 3.0, 3.5, 4.0, 4.5]
	for lvl in range(3):
		for k in range(8):
			var t := Team.new()
			t.team_name = "L%d-T%d" % [lvl, k]
			t.stars = stars[k]
			s.teams.append(t)
	var status: Array[int] = []
	for i in range(24):
		status.append(CareerState.CellStatus.LOCKED)
	status[0] = CareerState.CellStatus.UNLOCKED
	s.cell_status = status
	return s

func test_fresh_state_only_club_practise_unlocked() -> void:
	var s := _state()
	assert_true(s.is_unlocked(0, 0), "Club Practise open")
	assert_false(s.is_unlocked(0, 1), "next Tour locked")
	assert_false(s.is_unlocked(1, 0), "City locked")
	assert_eq(s.playable_cells(), [0], "one playable cell")

func test_beat_unlocks_up_and_across() -> void:
	var s := _state()
	s.mark_beaten(0, 0)
	assert_eq(s.status_of(0, 0), CareerState.CellStatus.BEATEN, "cell beaten")
	assert_true(s.is_unlocked(0, 1), "up unlocked")
	assert_true(s.is_unlocked(1, 0), "across unlocked")
	assert_true(s.is_unlocked(0, 0), "beaten cell stays replayable")

func test_beat_at_edges_clamps() -> void:
	var s := _state()
	s.cell_status[s.cell_index(2, 7)] = CareerState.CellStatus.UNLOCKED
	s.mark_beaten(2, 7)   # no level 3 / tour 8 to unlock — must not crash
	assert_eq(s.status_of(2, 7), CareerState.CellStatus.BEATEN)

func test_province_premium_gate_needs_both_lower_premium_wins() -> void:
	var s := _state()
	s.cell_status[s.cell_index(2, 7)] = CareerState.CellStatus.UNLOCKED
	assert_false(s.is_unlocked(2, 7), "gated while no Premium won")
	s.level_won[0] = true
	assert_false(s.is_unlocked(2, 7), "gated while City Premium unwon")
	s.level_won[1] = true
	assert_true(s.is_unlocked(2, 7), "open once Club + City won")

func test_record_outcome_beat_and_level_win() -> void:
	var s := _state()
	s.record_outcome(0, 0, true, false)
	assert_eq(s.status_of(0, 0), CareerState.CellStatus.BEATEN, "beat recorded")
	s.cell_status[s.cell_index(0, 7)] = CareerState.CellStatus.UNLOCKED
	s.record_outcome(0, 7, true, true)
	assert_true(s.level_won[0], "Premium Final win = Level won")
	assert_false(s.complete, "Club win does not complete the Career")

func test_record_outcome_province_premium_win_completes() -> void:
	var s := _state()
	s.level_won = [true, true, false]
	s.cell_status[s.cell_index(2, 7)] = CareerState.CellStatus.UNLOCKED
	s.record_outcome(2, 7, true, true)
	assert_true(s.level_won[2])
	assert_true(s.complete, "Province Premium win completes the Career")

func test_record_outcome_loss_changes_nothing() -> void:
	var s := _state()
	s.record_outcome(0, 0, false, false)
	assert_eq(s.status_of(0, 0), CareerState.CellStatus.UNLOCKED, "still just unlocked")
	assert_false(s.level_won[0])

func test_current_level_and_rosters() -> void:
	var s := _state()
	s.current_team_index = 10
	assert_eq(s.current_level(), 1, "team 10 is a City team")
	assert_eq(s.roster_of(1).size(), 8)
	var opps := s.opponents_of_current()
	assert_eq(opps.size(), 7, "7 opponents")
	for t in opps:
		assert_ne(t, s.teams[10], "current team not its own opponent")

func test_lowest_star_club_indices() -> void:
	var s := _state()
	assert_eq(s.lowest_star_club_indices(), [0, 1, 2], "the 3 lowest-star Club slots")

func test_any_unlocked_at() -> void:
	var s := _state()
	assert_true(s.any_unlocked_at(0))
	assert_false(s.any_unlocked_at(1))

func test_offer_is_pure_data() -> void:
	var o := Offer.new()
	o.team_index = 9
	o.level = 1
	o.stars = 3.5
	assert_eq(o.team_index, 9)
	assert_eq(o.level, 1)
	assert_eq(o.stars, 3.5)
```

- [ ] **Step 2: Run suite, verify RED** — expect `Parse Error: Identifier "CareerState" not declared` (GUT logs + skips the file; count stays put).

- [ ] **Step 3: Implement** — create `scripts/data/career_state.gd`:

```gdscript
class_name CareerState
extends Resource

# The persistent Career-grid state (career-loop rung, spec
# 2026-06-12-career-loop-design.md §3.1): 24 Teams (8 per Level, level-major),
# 24 cell statuses (level*8 + tour), Level wins, the Seasons-played counter.
# Pure data + read helpers + transitions on its OWN fields (mark_beaten,
# record_outcome); cross-object orchestration lives in CareerResolver.

enum CellStatus { LOCKED, UNLOCKED, BEATEN }

const LEVELS := 3
const TOURS := 8
const TEAMS_PER_LEVEL := 8
const PREMIUM_TOUR := 7

@export var teams: Array[Team] = []
@export var current_team_index: int = 0
@export var cell_status: Array[int] = []
@export var level_won: Array[bool] = [false, false, false]
@export var seasons_played: int = 0
@export var complete: bool = false

func current_level() -> int:
	return floori(current_team_index / float(TEAMS_PER_LEVEL))

func cell_index(level: int, tour: int) -> int:
	return level * TOURS + tour

func status_of(level: int, tour: int) -> int:
	return cell_status[cell_index(level, tour)]

# Unlocked-and-playable. Encapsulates the ordered endgame gate (DC4):
# Province Premium needs both lower Premium tours WON, not just adjacency.
func is_unlocked(level: int, tour: int) -> bool:
	if status_of(level, tour) == CellStatus.LOCKED:
		return false
	if level == 2 and tour == PREMIUM_TOUR:
		return level_won[0] and level_won[1]
	return true

func playable_cells() -> Array:
	var lvl := current_level()
	var out: Array = []
	for t in range(TOURS):
		if is_unlocked(lvl, t):
			out.append(t)
	return out

func roster_of(level: int) -> Array:
	var out: Array = []
	for i in range(level * TEAMS_PER_LEVEL, (level + 1) * TEAMS_PER_LEVEL):
		out.append(teams[i])
	return out

func opponents_of_current() -> Array:
	var lvl := current_level()
	var out: Array = []
	for i in range(lvl * TEAMS_PER_LEVEL, (lvl + 1) * TEAMS_PER_LEVEL):
		if i != current_team_index:
			out.append(teams[i])
	return out

# The 3 lowest-★ Club slots — the legal starting picks (DC7). Ties break by slot.
func lowest_star_club_indices() -> Array:
	var arr: Array = []
	for i in range(TEAMS_PER_LEVEL):
		arr.append(i)
	arr.sort_custom(func(a, b):
		if is_equal_approx(teams[a].stars, teams[b].stars):
			return a < b
		return teams[a].stars < teams[b].stars)
	return arr.slice(0, 3)

func any_unlocked_at(level: int) -> bool:
	for t in range(TOURS):
		if status_of(level, t) != CellStatus.LOCKED:
			return true
	return false

# Beating (L,T) unlocks (L,T+1) and (L+1,T) — CONTEXT.md "above and across".
func mark_beaten(level: int, tour: int) -> void:
	cell_status[cell_index(level, tour)] = CellStatus.BEATEN
	_unlock(level, tour + 1)
	_unlock(level + 1, tour)

func _unlock(level: int, tour: int) -> void:
	if level >= LEVELS or tour >= TOURS:
		return
	var i := cell_index(level, tour)
	if cell_status[i] == CellStatus.LOCKED:
		cell_status[i] = CellStatus.UNLOCKED

# The full end-of-Season grid transition (unit-testable without forcing a sim
# outcome): beat -> mark+unlock; Premium-Final win -> Level won; Province
# Premium win -> Career complete.
func record_outcome(level: int, tour: int, beat: bool, won_final: bool) -> void:
	if beat:
		mark_beaten(level, tour)
	if tour == PREMIUM_TOUR and won_final:
		level_won[level] = true
		if level == LEVELS - 1:
			complete = true
```

Create `scripts/data/offer.gd`:

```gdscript
class_name Offer
extends RefCounted

# One end-of-Season recruitment proposal (career-loop spec §3.2). Pure data;
# stars is a snapshot taken AFTER the rollover mutation (DC8) so the Offer
# shows the ★ the Team will actually have next Season.

var team_index: int = 0
var level: int = 0
var stars: float = 0.0
```

- [ ] **Step 4: Run `--import` once** (new scripts), then the suite. GREEN, count climbs.
- [ ] **Step 5: Commit** — `git add scripts/data/career_state.gd scripts/data/career_state.gd.uid scripts/data/offer.gd scripts/data/offer.gd.uid tests/unit/test_career_state.gd && git commit -m "Career loop: CareerState grid (24 cells, endgame gate, record_outcome) + Offer data (DC4/DC16 spec)"`

---

### Task 3: `CareerResolver.start_career` (DC6/DC7)

**Files:**
- Create: `scripts/domain/career_resolver.gd`
- Test: `tests/unit/test_career_resolver.gd` (new)

- [ ] **Step 1: Write the failing tests** — create `tests/unit/test_career_resolver.gd`:

```gdscript
extends GutTest

# CareerResolver — the multi-Season loop (spec 2026-06-12-career-loop-design.md).

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func test_start_career_builds_24_teams_with_star_ladder() -> void:
	var s := CareerResolver.start_career(0)
	assert_eq(s.teams.size(), 24, "8 teams x 3 Levels")
	var names := {}
	for lvl in range(3):
		var star_sum := 0.0
		for t in s.roster_of(lvl):
			star_sum += t.stars
			assert_false(t.team_name.is_empty(), "every team named")
			assert_false(names.has(t.team_name), "names distinct: %s" % t.team_name)
			names[t.team_name] = true
		assert_almost_eq(star_sum / 8.0, 3.0, 0.001, "Level %d star mean 3.0" % lvl)

func test_start_career_grid_and_counters_fresh() -> void:
	var s := CareerResolver.start_career(1)
	assert_eq(s.current_team_index, 1, "picked team")
	assert_eq(s.current_level(), 0, "starts at Club")
	assert_eq(s.playable_cells(), [0], "only Club Practise open")
	assert_eq(s.seasons_played, 0)
	assert_false(s.complete)

func test_start_career_rejects_non_underdog_pick() -> void:
	var s := CareerResolver.start_career(7)   # the 4.5★ franchise — not a legal pick
	assert_true(s.current_team_index in s.lowest_star_club_indices(),
		"invalid pick falls back to a lowest-3 slot")
```

- [ ] **Step 2: Run suite, verify RED** — `Identifier "CareerResolver" not declared`.

- [ ] **Step 3: Implement** — create `scripts/domain/career_resolver.gd`:

```gdscript
class_name CareerResolver
extends RefCounted

# Drives the multi-Season Career loop on top of SeasonResolver (spec
# 2026-06-12-career-loop-design.md, DC1-DC16). Static, no member state.
# Deterministic given rng; per-Season draw order is fixed:
# league+playoffs -> star mutation x24 -> offer draws.

const STAR_LADDER := [1.5, 2.0, 2.5, 3.0, 3.0, 3.5, 4.0, 4.5]   # mean 3.0 (DC6)
const OFFER_COUNT := 3
const CROSS_OFFER_P := 0.5   # P(next-Level offer) when unlocked but not a fresh beat (DC11)

# Strawman SA-flavoured placeholder names (DC6); the Country master-data axis
# replaces these in a later data rung. "Karoo Kings" is canon-cited (CONTEXT.md).
const TEAM_NAMES := [
	["Karoo Kings", "Dusty Plains", "Riverside Rovers", "Old Mill XI",
	 "Salt Pan Strikers", "Bushveld Bears", "Harbour Town", "Granite Hill"],
	["Metro Mavericks", "Dockside Dynamos", "Uptown Titans", "Foundry Falcons",
	 "Skyline Sixers", "Old Quarter CC", "Park Lane Panthers", "Terminal Tigers"],
	["Highveld Hawks", "Coastal Chargers", "Garden Route Giants", "Drakensberg Drifters",
	 "Platteland Pumas", "Winelands Warriors", "Escarpment Eagles", "Lowveld Lions"],
]

# Build a fresh Career: 24 Teams on the star ladder, only Club Practise
# unlocked, the Player on one of the 3 lowest-star Club teams (DC7).
# Deterministic — no rng.
static func start_career(picked_club_slot: int) -> CareerState:
	var state := CareerState.new()
	for lvl in range(CareerState.LEVELS):
		for k in range(CareerState.TEAMS_PER_LEVEL):
			var t := Team.new()
			t.team_name = TEAM_NAMES[lvl][k]
			t.stars = STAR_LADDER[k]
			state.teams.append(t)
	var status: Array[int] = []
	for i in range(CareerState.LEVELS * CareerState.TOURS):
		status.append(CareerState.CellStatus.LOCKED)
	status[0] = CareerState.CellStatus.UNLOCKED
	state.cell_status = status
	if not picked_club_slot in state.lowest_star_club_indices():
		push_error("start_career: pick %d is not a lowest-3 Club slot" % picked_club_slot)
		picked_club_slot = state.lowest_star_club_indices()[0]
	state.current_team_index = picked_club_slot
	return state
```

- [ ] **Step 4: Run `--import`, then the suite. GREEN.**
- [ ] **Step 5: Commit** — `git add scripts/domain/career_resolver.gd scripts/domain/career_resolver.gd.uid tests/unit/test_career_resolver.gd && git commit -m "Career loop: start_career — 24-team rosters on the star ladder, underdog pick validated (DC6/DC7)"`

---

### Task 4: Offers + accept/stay (DC11/DC16, §3.3)

**Files:**
- Modify: `scripts/domain/career_resolver.gd` (append)
- Test: `tests/unit/test_career_resolver.gd` (append)

- [ ] **Step 1: Write the failing tests** — append to `tests/unit/test_career_resolver.gd`:

```gdscript
# --- Offers (DC11/DC16) ---

func _player() -> Player:
	var p := Player.new()
	var a := Attributes.new()
	a.power = 35.0; a.composure = 30.0; a.attack = 30.0; a.control = 30.0
	p.attributes = a
	return p

func test_offers_are_distinct_and_exclude_current_team() -> void:
	var s := CareerResolver.start_career(0)
	var offers := CareerResolver.generate_offers(s, false, _rng(11))
	assert_lte(offers.size(), 3, "at most 3")
	assert_gt(offers.size(), 0, "some offers")
	var seen := {}
	for o in offers:
		assert_ne(o.team_index, s.current_team_index, "never the current team")
		assert_false(seen.has(o.team_index), "distinct teams")
		seen[o.team_index] = true
		assert_eq(o.stars, s.teams[o.team_index].stars, "stars snapshot matches")

func test_cross_level_guarantee_on_fresh_beat() -> void:
	var s := CareerResolver.start_career(0)
	s.mark_beaten(0, 0)   # unlocks (1,0)
	for seed_value in [1, 2, 3, 4, 5]:
		var offers := CareerResolver.generate_offers(s, true, _rng(seed_value))
		var has_city := false
		for o in offers:
			if o.level == 1:
				has_city = true
		assert_true(has_city, "fresh beat + unlocked City => City offer (seed %d)" % seed_value)

func test_no_cross_level_offer_while_higher_level_locked() -> void:
	var s := CareerResolver.start_career(0)
	var offers := CareerResolver.generate_offers(s, true, _rng(3))
	for o in offers:
		assert_eq(o.level, 0, "no City teams while City is locked")

func test_down_level_offer_always_present_while_lower_level_unwon() -> void:
	var s := CareerResolver.start_career(0)
	s.mark_beaten(0, 0)
	s.current_team_index = 9   # moved to City; Club unwon
	for seed_value in [1, 2, 3, 4, 5]:
		var offers := CareerResolver.generate_offers(s, false, _rng(seed_value))
		var has_club := false
		for o in offers:
			if o.level == 0:
				has_club = true
		assert_true(has_club, "DC16: Club offer present while Club unwon (seed %d)" % seed_value)

func test_no_down_level_offer_once_lower_level_won() -> void:
	var s := CareerResolver.start_career(0)
	s.mark_beaten(0, 0)
	s.current_team_index = 9
	s.level_won[0] = true
	var offers := CareerResolver.generate_offers(s, false, _rng(2))
	for o in offers:
		assert_ne(o.level, 0, "no Club offers once Club is won")

func test_no_offers_once_complete() -> void:
	var s := CareerResolver.start_career(0)
	s.complete = true
	assert_eq(CareerResolver.generate_offers(s, true, _rng(1)).size(), 0)

func test_accept_offer_moves_team_and_resets_affinity() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	p.affinity = 4
	var o := Offer.new()
	o.team_index = 9
	o.level = 1
	CareerResolver.accept_offer(s, p, o)
	assert_eq(s.current_team_index, 9)
	assert_eq(s.current_level(), 1, "Level follows the Team")
	assert_eq(p.affinity, 0, "Affinity resets on accept")

func test_stay_increments_affinity() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	CareerResolver.stay(s, p)
	CareerResolver.stay(s, p)
	assert_eq(p.affinity, 2)
```

- [ ] **Step 2: Run suite, verify RED** (missing-method failures on `generate_offers`).

- [ ] **Step 3: Implement** — append to `scripts/domain/career_resolver.gd`:

```gdscript
# --- Offers (DC11 + DC16) -----------------------------------------------------

# End-of-Season offer set: [cross-up slot] + [down slot, DC16] + same-Level
# fill, max OFFER_COUNT, all distinct, never the current Team. Staying is
# always available to the caller — it is not an Offer row.
static func generate_offers(state: CareerState, just_beat: bool, rng: RandomNumberGenerator) -> Array:
	if state.complete:
		return []
	var level := state.current_level()
	var offers: Array = []
	var taken: Array = [state.current_team_index]

	# Cross-up: guaranteed on a fresh beat with the higher Level reachable,
	# else a CROSS_OFFER_P coin (DC11).
	var up := level + 1
	if up < CareerState.LEVELS and state.any_unlocked_at(up):
		if just_beat or rng.randf() < CROSS_OFFER_P:
			_append_offer(state, up, taken, offers, rng)

	# Down: ALWAYS one Team from the highest unwon lower Level (DC16 —
	# anti-softlock: the endgame gate needs every Level's Premium won).
	for down in range(level - 1, -1, -1):
		if not state.level_won[down]:
			_append_offer(state, down, taken, offers, rng)
			break

	while offers.size() < OFFER_COUNT:
		if not _append_offer(state, level, taken, offers, rng):
			break
	return offers

# Draw one random not-yet-taken Team at `level` into offers. False if exhausted.
static func _append_offer(state: CareerState, level: int, taken: Array, offers: Array, rng: RandomNumberGenerator) -> bool:
	var pool: Array = []
	for i in range(level * CareerState.TEAMS_PER_LEVEL, (level + 1) * CareerState.TEAMS_PER_LEVEL):
		if not i in taken:
			pool.append(i)
	if pool.is_empty():
		return false
	var idx: int = pool[rng.randi_range(0, pool.size() - 1)]
	taken.append(idx)
	var o := Offer.new()
	o.team_index = idx
	o.level = level
	o.stars = state.teams[idx].stars
	offers.append(o)
	return true

static func accept_offer(state: CareerState, player: Player, offer: Offer) -> void:
	state.current_team_index = offer.team_index
	player.affinity = 0

static func stay(_state: CareerState, player: Player) -> void:
	player.affinity += 1
```

- [ ] **Step 4: Run suite. GREEN.**
- [ ] **Step 5: Commit** — `git add scripts/domain/career_resolver.gd tests/unit/test_career_resolver.gd && git commit -m "Career loop: end-of-Season Offers (cross-up guarantee, DC16 down-offer anti-softlock) + accept/stay affinity semantics"`

---

### Task 5: `play_season` (DC5/DC8/DC9/DC13, §3.3)

**Files:**
- Modify: `scripts/domain/career_resolver.gd` (append)
- Test: `tests/unit/test_career_resolver.gd` (append)

- [ ] **Step 1: Write the failing tests** — append to `tests/unit/test_career_resolver.gd`:

```gdscript
# --- play_season (DC5/DC8/DC9/DC13) ---

func _play(s: CareerState, p: Player, tour: int, seed_value: int) -> Dictionary:
	return CareerResolver.play_season(
		s, p, tour, BallTuning.new(), InningsTuning.new(), EconomyTuning.new(),
		_rng(seed_value))

func test_play_season_deterministic() -> void:
	var s1 := CareerResolver.start_career(0)
	var s2 := CareerResolver.start_career(0)
	var p1 := _player()
	var p2 := _player()
	var o1 := _play(s1, p1, 0, 99)
	var o2 := _play(s2, p2, 0, 99)
	assert_eq(o1["pay"], o2["pay"], "pay deterministic")
	assert_eq(o1["wins"], o2["wins"], "wins deterministic")
	assert_eq(o1["season"].player_final_position, o2["season"].player_final_position)
	assert_eq(o1["offers"].size(), o2["offers"].size())
	for k in range(o1["offers"].size()):
		assert_eq(o1["offers"][k].team_index, o2["offers"][k].team_index, "offer %d same" % k)

func test_play_season_ticks_counter_and_banks_pay() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	var out := _play(s, p, 0, 7)
	assert_eq(s.seasons_played, 1, "Seasons played ticks win or lose")
	assert_eq(p.tons_balance, out["pay"], "pay banked")
	assert_gt(out["pay"], 0, "a Season always pays something (game fees)")

func test_play_season_pay_reconciles_with_match_pay() -> void:
	var s := CareerResolver.start_career(0)
	var p := _player()
	var etun := EconomyTuning.new()
	var stars_at_play: float = s.teams[s.current_team_index].stars
	var out := _play(s, p, 0, 13)
	var season: SeasonResult = out["season"]
	var expected := 0
	var wins := 0
	var played: Array = season.league.player_matches.duplicate()
	for m in [season.semi1, season.semi2, season.final_match, season.third_place]:
		if not m.innings1.player_line().is_empty() or not m.innings2.player_line().is_empty():
			played.append(m)
	for m in played:
		expected += Economy.match_pay(m, stars_at_play, etun)["total"]
		if m.outcome == MatchResult.Outcome.PLAYER_WIN:
			wins += 1
			expected += Economy.win_bonus(0, etun)
	assert_eq(out["pay"], expected, "pay = sum match_pay + win bonuses (stars at play time)")
	assert_eq(out["wins"], wins, "wins reported")

func test_play_season_mutates_stars_at_rollover() -> void:
	var s := CareerResolver.start_career(0)
	var before: Array = []
	for t in s.teams:
		before.append(t.stars)
	var _out := _play(s, _player(), 0, 21)
	var changed := 0
	for k in range(24):
		assert_between(s.teams[k].stars, 0.5, 5.0, "stars clamped")
		if not is_equal_approx(s.teams[k].stars, before[k]):
			changed += 1
	assert_gt(changed, 0, "ADR 0009 mutation fired across the rosters")

func test_play_season_beat_updates_grid() -> void:
	# A strong player on the 2.5★ pick at Club Practise (d=1.0) beats the
	# Season often; find a seed that beats and assert the grid moved.
	var found := false
	for seed_value in range(50):
		var s := CareerResolver.start_career(2)
		var p := _player()
		p.attributes.power = 50.0
		p.attributes.composure = 50.0
		var out := _play(s, p, 0, seed_value)
		if out["season"].beat:
			assert_eq(s.status_of(0, 0), CareerState.CellStatus.BEATEN)
			assert_true(s.is_unlocked(0, 1), "up cell open")
			assert_true(s.is_unlocked(1, 0), "across cell open")
			found = true
			break
	assert_true(found, "a beating seed exists within 50 at Club Practise")

func test_play_season_locked_cell_is_rejected() -> void:
	var s := CareerResolver.start_career(0)
	var out := CareerResolver.play_season(
		s, _player(), 5, BallTuning.new(), InningsTuning.new(), EconomyTuning.new(), _rng(1))
	assert_true(out.is_empty(), "locked cell returns empty")
	assert_eq(s.seasons_played, 0, "nothing ticked")
```

- [ ] **Step 2: Run suite, verify RED** (missing `play_season`).

- [ ] **Step 3: Implement** — append to `scripts/domain/career_resolver.gd`:

```gdscript
# --- The Season turn (DC5/DC8/DC9/DC13) ----------------------------------------

# Play one Season at (current Level, tour_index): simulate via SeasonResolver
# with the cell's DifficultyLadder spec (tour distribution + opponent brain,
# DC13), bank ₸ (DC9 + DC10), update the grid, tick Seasons-played, mutate all
# 24 Teams (DC8), then generate Offers. Returns
# {season, pay, wins, offers}; {} if the cell is locked.
static func play_season(
		state: CareerState, player: Player, tour_index: int,
		tuning: BallTuning, itun: InningsTuning, etun: EconomyTuning,
		rng: RandomNumberGenerator,
		intent_plan: IntentPlan = null, bowling_plan: BowlingPlan = null
) -> Dictionary:
	var level := state.current_level()
	if not state.is_unlocked(level, tour_index):
		push_error("play_season: cell (%d,%d) is locked" % [level, tour_index])
		return {}
	var spec := DifficultyLadder.spec_for(level, tour_index)
	var team: Team = state.teams[state.current_team_index]
	var stars_at_play := team.stars   # pay uses the ★ the Season was played at (DC8)
	var season := SeasonResolver.simulate_season(
		player.attributes, team, state.opponents_of_current(), spec.make_tour(),
		tuning, itun, rng, intent_plan, bowling_plan, spec)

	var pay := 0
	var wins := 0
	for m in _player_matches(season):
		pay += Economy.match_pay(m, stars_at_play, etun)["total"]
		if m.outcome == MatchResult.Outcome.PLAYER_WIN:
			wins += 1
			pay += Economy.win_bonus(level, etun)
	player.tons_balance += pay

	state.record_outcome(level, tour_index, season.beat, season.won_final)
	state.seasons_played += 1

	for t in state.teams:
		t.mutate_stars(rng)

	return {
		"season": season,
		"pay": pay,
		"wins": wins,
		"offers": generate_offers(state, season.beat, rng),
	}

# Every match the Player actually played: the 7 league fixtures + any knockout
# whose scorecard carries the Player (statted matches only — derived knockouts
# between other teams have no player_line).
static func _player_matches(season: SeasonResult) -> Array:
	var out: Array = season.league.player_matches.duplicate()
	for m in [season.semi1, season.semi2, season.final_match, season.third_place]:
		if not m.innings1.player_line().is_empty() or not m.innings2.player_line().is_empty():
			out.append(m)
	return out
```

- [ ] **Step 4: Run suite. GREEN.** (The beat-seed scan test runs ≤50 Seasons — the suite stays seconds-fast; if it's slow, lower the scan to 20.)
- [ ] **Step 5: Commit** — `git add scripts/domain/career_resolver.gd tests/unit/test_career_resolver.gd && git commit -m "Career loop: play_season — DifficultyLadder cell sim, pay+win-bonus banking, grid update, star mutation rollover (DC5/DC8/DC9/DC13)"`

---

### Task 6: Persistence + lifecycle (DC14)

**Files:**
- Modify: `scripts/services/save_manager.gd`
- Modify: `scripts/services/lifecycle_manager.gd`
- Test: `tests/unit/test_save_manager.gd` (append), `tests/unit/test_lifecycle_manager.gd` (modify hooks + append)

- [ ] **Step 1: Write the failing tests.** Append to `tests/unit/test_save_manager.gd` (and add `sm.career_save_path = "user://_test_career.tres"` + `sm.clear_career()` to its `before_each`/`after_each`):

```gdscript
# --- Career round-trip (career-loop DC14) ---

func test_load_career_returns_null_when_no_save_exists():
	assert_null(sm.load_career())

func test_career_save_then_load_roundtrips():
	var c := CareerResolver.start_career(0)
	c.seasons_played = 5
	c.mark_beaten(0, 0)
	c.teams[3].stars = 4.0
	sm.save_career(c)
	var loaded := sm.load_career()
	assert_eq(loaded.seasons_played, 5)
	assert_eq(loaded.current_team_index, 0)
	assert_eq(loaded.status_of(0, 0), CareerState.CellStatus.BEATEN)
	assert_true(loaded.is_unlocked(1, 0), "unlock state survives")
	assert_eq(loaded.teams.size(), 24)
	assert_eq(loaded.teams[3].stars, 4.0)
	assert_eq(loaded.teams[0].team_name, c.teams[0].team_name)

func test_clear_career_removes_save():
	sm.save_career(CareerResolver.start_career(0))
	assert_true(sm.has_career())
	sm.clear_career()
	assert_false(sm.has_career())
	assert_null(sm.load_career())
```

Modify `tests/unit/test_lifecycle_manager.gd` — add to `before_each`: `SaveManager.career_save_path = "user://_test_lc_career.tres"` and `SaveManager.clear_career()`; add `SaveManager.clear_career()` to `after_each`. Append:

```gdscript
func test_end_career_archives_real_seasons_played_and_clears_career():
	_seeded_player()
	var c := CareerResolver.start_career(0)
	c.seasons_played = 7
	SaveManager.save_career(c)
	LifecycleManager.manual_retire()
	var arc := SaveManager.load_legends()
	assert_eq(arc.entries[0].seasons_played, 7, "real counter archived")
	assert_false(SaveManager.has_career(), "career save cleared")

func test_end_career_without_career_save_defaults_to_one_season():
	_seeded_player()
	LifecycleManager.manual_retire()
	var arc := SaveManager.load_legends()
	assert_eq(arc.entries[0].seasons_played, 1, "back-compat default")
```

- [ ] **Step 2: Run suite, verify RED** (missing `load_career` etc.).

- [ ] **Step 3: Implement.** In `scripts/services/save_manager.gd`, add below the existing path exports:

```gdscript
@export var career_save_path: String = "user://career.tres"
```

and append a Career section (mirror of the Player one — CACHE_MODE_IGNORE for the same fresh-read reason):

```gdscript
# --- Career (career-loop rung DC14) ---

func has_career() -> bool:
	return FileAccess.file_exists(career_save_path)

func save_career(c: CareerState) -> void:
	var err := ResourceSaver.save(c, career_save_path)
	if err != OK:
		push_error("SaveManager: failed to save career (err=%d)" % err)

func load_career() -> CareerState:
	if not has_career():
		return null
	return ResourceLoader.load(career_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as CareerState

func clear_career() -> void:
	if has_career():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(career_save_path))
```

In `scripts/services/lifecycle_manager.gd`: delete the `_PLACEHOLDER_SEASONS` const (and its comment) and replace `end_career` with:

```gdscript
func end_career(reason: String) -> void:
	var p := SaveManager.load_player()
	if p == null:
		push_warning("LifecycleManager.end_career called with no Player loaded")
		return
	# Real Seasons-played from the Career save (career-loop DC14); a Career-less
	# save (pre-rung or test fixture) archives the old placeholder 1.
	var seasons := 1
	var c := SaveManager.load_career()
	if c != null:
		seasons = c.seasons_played
	SaveManager.archive_to_legends(p, reason, seasons)
	SaveManager.clear_player()
	SaveManager.clear_career()
	career_ended.emit(reason)
```

- [ ] **Step 4: Run suite. GREEN** (existing lifecycle tests still pass — no career save ⇒ default 1).
- [ ] **Step 5: Commit** — `git add scripts/services/save_manager.gd scripts/services/lifecycle_manager.gd tests/unit/test_save_manager.gd tests/unit/test_lifecycle_manager.gd && git commit -m "Career loop: CareerState persistence (user://career.tres) + LifecycleManager archives real seasons_played (DC14)"`

---

### Task 7: Eyeball oracle + viz (DC15, spec §6)

**Files:**
- Create: `tools/career_preview.gd`
- Create: `docs/mockups/career-loop-v1.html`

No unit tests — this is the eyeball deliverable (tools are not under GUT).

- [ ] **Step 1: Create `tools/career_preview.gd`:**

```gdscript
extends SceneTree

# Career-loop eyeball oracle (spec 2026-06-12-career-loop-design.md DC15/§6):
# N full Careers under a fixed naive policy, printing a DATA json for
# docs/mockups/career-loop-v1.html.
#
# Naive policy (NOT a policy search — that is E4):
#   tour:   lowest unbeaten unlocked Tour at the current Level; if all beaten,
#           Premium again (chasing the Level win)
#   offers: accept the first cross-up Offer once the current Level is won; never
#           move down (this line never needs DC16's safety net)
#   plans:  textbook (the OpponentBrain TEXTBOOK literals)
#   ₸:      round-robin +1 attribute upgrades while affordable, cap 60/attr
#
# Run:   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/career_preview.gd
# Smoke: CAREER_QUICK=1 (N=10). Full N=100 ≈ a few minutes; no nohup needed.

const SEASON_CAP := 120
const ATTR_CAP := 60.0

func _choose_tour(state: CareerState) -> int:
	var lvl := state.current_level()
	for t in state.playable_cells():
		if state.status_of(lvl, t) != CareerState.CellStatus.BEATEN:
			return t
	return state.playable_cells().back()

func _spend(player: Player, etun: EconomyTuning) -> void:
	var attrs := [&"power", &"composure", &"attack", &"control"]
	var k := 0
	var stalled := 0
	while stalled < 4:
		var name: StringName = attrs[k % 4]
		k += 1
		var cur: float = player.attributes.get(name)
		var cost := Economy.attr_upgrade_cost(cur, etun)
		if cur >= ATTR_CAP or player.tons_balance < cost:
			stalled += 1
			continue
		stalled = 0
		player.attributes.set(name, cur + 1.0)
		player.tons_balance -= cost

func _init() -> void:
	var quick := OS.get_environment("CAREER_QUICK") == "1"
	var n := 10 if quick else 100
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var etun := EconomyTuning.new()

	var seasons_to_complete: Array = []
	var capped := 0
	var visits: Array = []
	var beats: Array = []
	for i in range(24):
		visits.append(0)
		beats.append(0)
	var bank_sum: Array = []
	var bank_n: Array = []
	for i in range(SEASON_CAP):
		bank_sum.append(0.0)
		bank_n.append(0)

	for c in range(n):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + c
		var player := Player.new()
		var a := Attributes.new()
		a.power = 35.0; a.composure = 30.0; a.attack = 30.0; a.control = 30.0
		player.attributes = a
		var state := CareerResolver.start_career(0)
		var plans := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, rng)
		while not state.complete and state.seasons_played < SEASON_CAP:
			var lvl := state.current_level()
			var tour := _choose_tour(state)
			var out := CareerResolver.play_season(
				state, player, tour, tuning, itun, etun, rng, plans[0], plans[1])
			visits[lvl * 8 + tour] += 1
			if out["season"].beat:
				beats[lvl * 8 + tour] += 1
			bank_sum[state.seasons_played - 1] += player.tons_balance
			bank_n[state.seasons_played - 1] += 1
			_spend(player, etun)
			if state.complete:
				break
			var up: Offer = null
			for o in out["offers"]:
				if o.level > lvl and state.level_won[lvl]:
					up = o
					break
			if up != null:
				CareerResolver.accept_offer(state, player, up)
			else:
				CareerResolver.stay(state, player)
		if state.complete:
			seasons_to_complete.append(state.seasons_played)
		else:
			capped += 1
		print("career %d/%d: %s in %d seasons" % [c + 1, n,
			"COMPLETE" if state.complete else "capped", state.seasons_played])

	var bank_curve: Array = []
	for i in range(SEASON_CAP):
		if bank_n[i] > 0:
			bank_curve.append(snappedf(bank_sum[i] / bank_n[i], 0.1))
	var data := {
		"n": n,
		"season_cap": SEASON_CAP,
		"completed": seasons_to_complete.size(),
		"capped": capped,
		"seasons_to_complete": seasons_to_complete,
		"cell_visits": visits,
		"cell_beats": beats,
		"bank_curve": bank_curve,
	}
	print("DATA ", JSON.stringify(data))
	quit()
```

- [ ] **Step 2: Run `--import`, then the smoke:**
`CAREER_QUICK=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/career_preview.gd`
Expected: 10 `career k/10: …` lines then a `DATA {...}` json. Sanity: most quick careers should NOT instantly cap; bank curve rises.

- [ ] **Step 3: Run the full N=100** (same command without `CAREER_QUICK`; a few minutes, foreground is fine — it is well under the 10-min cap; do NOT run any other Godot process meanwhile).

- [ ] **Step 4: Create `docs/mockups/career-loop-v1.html`** with the full-run DATA pasted into the `DATA` const (style: self-contained dark-theme single file like the sibling mockups):

```html
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<title>Career loop v1 — naive-policy eyeball</title>
<style>
 body{background:#101418;color:#dde3ea;font:14px/1.45 -apple-system,sans-serif;margin:24px;max-width:1000px}
 h1{font-size:20px} h2{font-size:15px;margin-top:28px;color:#9fb3c8}
 .note{color:#8a97a5;font-size:12.5px;max-width:72em}
 table{border-collapse:collapse;margin-top:8px} td,th{padding:4px 8px;font-size:12.5px;text-align:center}
 th{color:#9fb3c8;font-weight:600}
 .bar{fill:#4fc3f7}.axis{stroke:#39434e}.lbl{fill:#8a97a5;font-size:11px}
</style></head><body>
<h1>Career loop v1 — naive-policy eyeball</h1>
<p class="note" id="head"></p>
<h2>Seasons to complete the Career (completed careers only)</h2>
<svg id="hist" width="960" height="220"></svg>
<h2>Mean ₸ bank by Season index (denominator shrinks as careers finish)</h2>
<svg id="bank" width="960" height="200"></svg>
<h2>Grid: visits → beat-rate per cell (naive line)</h2>
<div id="grid"></div>
<script>
const DATA = /* paste the DATA json from tools/career_preview.gd here */;
const LEVELS=["Club","City","Province"];
const TOURS=["Practise","Home sum","Home win","Home eve","Away sum","Away win","Away eve","Premium"];
document.getElementById("head").textContent =
 `N=${DATA.n} careers, season cap ${DATA.season_cap}. Completed: ${DATA.completed}/${DATA.n}; capped: ${DATA.capped}. `+
 `Policy: lowest unbeaten tour, premium-farm for the Level win, move up once won, round-robin attribute spending (cap 60).`;
// histogram
(()=>{const s=DATA.seasons_to_complete; if(!s.length) return;
 const svg=document.getElementById("hist"),W=960,H=220,P=30;
 const max=Math.max(...s),min=Math.min(...s),bins={};
 s.forEach(v=>bins[v]=(bins[v]||0)+1);
 const bw=(W-2*P)/(max-min+1),peak=Math.max(...Object.values(bins));
 let h=`<line class="axis" x1="${P}" y1="${H-P}" x2="${W-P}" y2="${H-P}"/>`;
 for(let v=min;v<=max;v++){const c=bins[v]||0,bh=c/peak*(H-2*P);
  h+=`<rect class="bar" x="${P+(v-min)*bw+1}" y="${H-P-bh}" width="${bw-2}" height="${bh}"/>`;
  if((v-min)%Math.ceil((max-min)/20||1)===0)h+=`<text class="lbl" x="${P+(v-min)*bw+bw/2}" y="${H-P+14}" text-anchor="middle">${v}</text>`;}
 svg.innerHTML=h;})();
// bank curve
(()=>{const b=DATA.bank_curve;if(!b.length)return;
 const svg=document.getElementById("bank"),W=960,H=200,P=30,max=Math.max(...b);
 let pts=b.map((v,i)=>`${P+i*(W-2*P)/(b.length-1||1)},${H-P-v/max*(H-2*P)}`).join(" ");
 svg.innerHTML=`<line class="axis" x1="${P}" y1="${H-P}" x2="${W-P}" y2="${H-P}"/>`+
  `<polyline fill="none" stroke="#81c784" stroke-width="2" points="${pts}"/>`+
  `<text class="lbl" x="${P}" y="${P}">peak mean bank ₸${Math.round(max)}</text>`;})();
// grid table
(()=>{let h="<table><tr><th></th>"+TOURS.map(t=>`<th>${t}</th>`).join("")+"</tr>";
 for(let l=2;l>=0;l--){h+=`<tr><th>${LEVELS[l]}</th>`;
  for(let t=0;t<8;t++){const i=l*8+t,v=DATA.cell_visits[i],b=DATA.cell_beats[i];
   const r=v?Math.round(b/v*100):0;
   h+=`<td style="background:rgba(79,195,247,${v?0.08+0.5*Math.min(1,r/100):0})">${v?`${r}%<br><span class="lbl">${b}/${v}</span>`:"—"}</td>`;}
  h+="</tr>";}
 h+="</table><p class='note'>Each cell: beat-rate, with beats/visits underneath (the denominator). “—” = the naive line never visited the cell.</p>";
 document.getElementById("grid").innerHTML=h;})();
</script></body></html>
```

- [ ] **Step 5: Eyeball in a browser** (open the html; per spec §6: completions happen, seasons-to-complete is "tens not 3 / not 500", bank rises, Province visited only late). Record headline numbers (completed/N, median seasons, peak bank) for spec §10.
- [ ] **Step 6: Commit** — `git add tools/career_preview.gd tools/career_preview.gd.uid docs/mockups/career-loop-v1.html && git commit -m "Career loop: career_preview eyeball oracle (naive policy, N=100) + career-loop-v1 viz"`

---

### Task 8: Close-out

- [ ] **Step 1: Full suite one last time** — expect ≥ 485 green (464 + ~21 new), `All tests passed`, zero new orphans (the 15 pre-existing HoF orphans stand).
- [ ] **Step 2: Spec §10 findings** — append measured numbers (completion rate /N, seasons-to-complete median + spread, bank trajectory peak, per-cell beat rates worth quoting) with denominators + the viz path, to `docs/superpowers/specs/2026-06-12-career-loop-design.md`.
- [ ] **Step 3: Commit, push, PR to `main`, merge** (per the global commit policy), then roadmap close-out.

---

## Self-review notes

- **Spec coverage:** DC4/DC6 grid+rosters → Task 2/3; DC7 pick → Task 3; DC8 mutation + DC9 pay + DC13 brains → Task 5; DC10 → Task 1; DC11/DC16 offers + DC12 affinity → Task 4; DC14 persistence/lifecycle → Task 6; DC15/§6 → Task 7. §5 test list items 1–8 all appear.
- **Type consistency:** `CareerState.CellStatus`, `cell_index/status_of/is_unlocked/mark_beaten/record_outcome/any_unlocked_at/lowest_star_club_indices/roster_of/opponents_of_current/playable_cells`, `CareerResolver.start_career/generate_offers/accept_offer/stay/play_season/_player_matches/_append_offer`, `Economy.win_bonus`, `SaveManager.has/save/load/clear_career` — names match across tasks.
- **Gotchas encoded:** `--import` before first post-add test run (Tasks 2/3/7); one Godot at a time; `Offer` does not collide with a built-in class; enum values stored as plain `int` fields (project GDScript rule); `floori` avoids the integer-division warning.
