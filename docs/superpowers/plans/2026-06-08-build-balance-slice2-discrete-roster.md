# Build-Balance Slice 2 — Discrete Roster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fake "every teammate is one cloned strength number" placeholder with a **real XI of 11 individual players** (each a 20-point `Attributes` build drawn from archetypes), so a team's batting card is a genuine top-order → tail of distinct individuals.

**Architecture:** A `Team` gains archetype factories + a fixed **standard XI** (6 BATTER · 1 ALLROUNDER · 4 BOWLER, batting order). `simulate_match_teams` builds each side's 11-player roster (the Player replaces the archetype at their build-driven batting position) and threads it as **optional trailing params** down through `simulate_match` → `simulate_innings` → `_build_batters`. When no roster is supplied (every existing scalar-path caller and test) the old clone path runs unchanged → byte-identical, all current tests stay green. Star-directionality is preserved by applying the team's existing star-derived batting strength as a **uniform offset** to every roster member (≈0 at even ★3, so the balance baseline is the pristine 20-point archetypes). See spec §4 + §8.5 (decisions D6–D10).

**Tech Stack:** Godot 4.6.3 / GDScript, GUT 9.6 test framework. Pure domain logic — no scenes.

---

## Conventions (read before starting)

- **Indentation is TABS** in `.gd` files (not spaces).
- **After adding/renaming any script**, run `--import` once before tests:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- **Run the whole suite** (the `-gtest` flag does NOT filter here):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- **Quit the Godot editor first** (`pgrep -x Godot` must be empty) — two importing instances deadlock.
- **Red** = a `SCRIPT ERROR: Parse Error: Identifier "X" not declared` for a not-yet-written `class_name`, OR a failing assertion. **Green** = `All tests passed` and the total count climbs. Baseline before this slice: **335 tests**.
- Clean iCloud junk before a run if a load suddenly breaks:
  `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot`
- Commit `*.gd.uid` for files under `scripts/` (NOT for `tests/` files — they generate no `.uid`).
- This slice adds **no new files** — only methods on existing scripts + new tests. So no new `class_name`s appear; judge red-for-a-new-method by the **failing assertion**, not a parse error.

---

## File structure (what changes)

- **Modify** `scripts/data/team.gd` — add archetype factories, `standard_xi()`, `build_xi()`. (Task 1)
- **Modify** `scripts/domain/innings_resolver.gd` — `_build_batters` gains a roster path; `simulate_innings` gains roster trailing params. (Tasks 2, 3)
- **Modify** `scripts/domain/match_resolver.gd` — `simulate_match` gains roster trailing params (4 call sites); `simulate_match_teams` assembles the rosters + offsets. (Task 4)
- **Test** `tests/unit/test_team.gd` — archetypes + standard XI + build_xi. (Task 1)
- **Test** `tests/unit/test_innings_resolver.gd` — `_build_batters` roster path; `simulate_innings` roster path. (Tasks 2, 3)
- **Test** `tests/unit/test_match_resolver.gd` — `simulate_match_teams` roster assembly + regressions. (Task 4)
- **Modify** the spec `docs/superpowers/specs/2026-06-08-build-balance-rating-and-team-design.md` — record the re-grounded sweep baseline (§9.5.2). (Task 5)

---

## Task 1: Archetypes + standard XI + `Team.build_xi()`

Pure data on `Team`. Each archetype is a fresh 20-point `Attributes`. The standard XI is a fixed batting order (positions 1→11). `build_xi` returns that order with the slot at the Player's 1-based position replaced by the Player's own `Attributes`.

**Files:**
- Modify: `scripts/data/team.gd`
- Test: `tests/unit/test_team.gd`

- [ ] **Step 1: Write the failing tests** — append to `tests/unit/test_team.gd`:

```gdscript
func test_archetypes_are_valid_20pt_builds() -> void:
	for a in [Team.archetype_batter(), Team.archetype_bowler(), Team.archetype_allrounder()]:
		assert_eq(a.sum(), 20, "archetype is a 20-point build")
		assert_true(a.is_valid_creation_distribution(), "archetype is a legal distribution")
	var bat := Team.archetype_batter()
	assert_eq([bat.power, bat.composure, bat.attack, bat.control], [8, 8, 2, 2], "BATTER 8/8/2/2")
	var bwl := Team.archetype_bowler()
	assert_eq([bwl.power, bwl.composure, bwl.attack, bwl.control], [2, 2, 8, 8], "BOWLER 2/2/8/8")
	var ar := Team.archetype_allrounder()
	assert_eq([ar.power, ar.composure, ar.attack, ar.control], [5, 5, 5, 5], "ALLROUNDER 5/5/5/5")

func test_standard_xi_shape_and_point_split() -> void:
	var xi := Team.standard_xi()
	assert_eq(xi.size(), 11, "a full XI of 11 players")
	# 6 BATTER (1..6), 1 ALLROUNDER (7), 4 BOWLER (8..11).
	for i in range(6):
		assert_eq(xi[i].power, 8, "slots 1..6 are top-order batters (power 8)")
	assert_eq(xi[6].power, 5, "slot 7 is the all-rounder")
	for i in range(7, 11):
		assert_eq(xi[i].power, 2, "slots 8..11 are bowlers (power 2)")
	var bat_pts := 0
	var bowl_pts := 0
	for p in xi:
		bat_pts += p.power + p.composure
		bowl_pts += p.attack + p.control
	assert_eq(bat_pts, 122, "team batting points = 122 (spec target)")
	assert_eq(bowl_pts, 98, "team bowling points = 98 (spec target)")

func test_build_xi_places_player_at_position() -> void:
	var player := Attributes.new()
	player.power = 7; player.composure = 6; player.attack = 4; player.control = 3
	var xi := Team.build_xi(player, 3)
	assert_eq(xi.size(), 11, "still a full XI")
	assert_true(xi[2] == player, "the Player object sits at 1-based position 3")
	# Every other slot is an archetype, not the Player.
	var player_slots := 0
	for p in xi:
		if p == player:
			player_slots += 1
	assert_eq(player_slots, 1, "the Player appears exactly once")
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — `Parse Error: Identifier "archetype_batter" not declared` (or the three new tests error/fail). Total still ~335.

- [ ] **Step 3: Implement the archetype + roster methods** — append to `scripts/data/team.gd` (above is fine too; keep with the other statics). Use TABS:

```gdscript
# --- Slice 2: discrete roster (spec §4) ---------------------------------------
# Archetypes are strawman 20-point builds (harness-tunable). Each call returns a
# FRESH Attributes so callers never share mutable state.

static func archetype_batter() -> Attributes:
	var a := Attributes.new()
	a.power = 8; a.composure = 8; a.attack = 2; a.control = 2
	return a

static func archetype_bowler() -> Attributes:
	var a := Attributes.new()
	a.power = 2; a.composure = 2; a.attack = 8; a.control = 8
	return a

static func archetype_allrounder() -> Attributes:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	return a

# The fixed standard XI, in batting order: 6 BATTER, 1 ALLROUNDER, 4 BOWLER.
# Point split = (122 batting / 98 bowling) per spec §4.2. Used unchanged by the
# opponent, and as the template the Player slots into (build_xi).
static func standard_xi() -> Array:
	var xi: Array = []
	for i in range(6):
		xi.append(archetype_batter())
	xi.append(archetype_allrounder())
	for i in range(4):
		xi.append(archetype_bowler())
	return xi

# The Player's team order: the standard XI with the archetype at the Player's
# 1-based batting position `ppos` replaced by the Player's own Attributes. Slice 2
# crude displacement (no gap-fill yet — that is Slice 3). ppos is 1..9 (< 11), safe.
static func build_xi(player_attrs: Attributes, ppos: int) -> Array:
	var xi := standard_xi()
	xi[ppos - 1] = player_attrs
	return xi
```

- [ ] **Step 4: Run the suite to verify the new tests pass**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS — `All tests passed`, total **338** (335 + 3).

- [ ] **Step 5: Commit**

```bash
git add scripts/data/team.gd scripts/data/team.gd.uid tests/unit/test_team.gd
git commit -m "Slice 2 Task 1: Team archetypes + standard XI + build_xi"
```

---

## Task 2: `_build_batters` roster path

`_build_batters` gains two optional params: `roster` (an `Array` of `Attributes` in batting order) and `team_offset` (an int added uniformly to every batter's power/composure, floored at 1). When `roster` is **empty**, the existing clone path runs unchanged (regression-safe). When supplied, each slot reads its real `Attributes`; the Player slot is detected by **reference identity** (`member == player_attrs`), so no position recomputation is needed and the synthetic `partner_factor` tail curve is dropped (the archetype order already encodes the tail).

**Files:**
- Modify: `scripts/domain/innings_resolver.gd:41-60` (`_build_batters`)
- Test: `tests/unit/test_innings_resolver.gd`

- [ ] **Step 1: Write the failing tests** — append to `tests/unit/test_innings_resolver.gd`:

```gdscript
func test_build_batters_clone_path_unchanged_when_no_roster() -> void:
	# Regression: empty roster -> the old clone behaviour (partner_factor tail).
	var batters := InningsResolver._build_batters(null, 5, itun)
	assert_eq(batters.size(), 11, "11 batters")
	assert_eq(batters[0]["power"], 5, "opener clone == partner_batting * factor(1)=1.0")
	assert_lt(batters[10]["power"], batters[0]["power"], "tail weaker than opener (clone path)")

func test_build_batters_uses_real_roster_individuals() -> void:
	# Opposition innings (player_attrs null): roster of 11 distinct archetypes,
	# zero offset -> each slot carries its archetype's own power/composure.
	var roster := Team.standard_xi()
	var batters := InningsResolver._build_batters(null, 5, itun, roster, 0)
	assert_eq(batters.size(), 11, "11 batters")
	assert_eq(batters[0]["power"], 8, "top order is a real BATTER (power 8, no tail-scaling)")
	assert_eq(batters[0]["composure"], 8, "composure also from the archetype")
	assert_eq(batters[10]["power"], 2, "tail is a real BOWLER (power 2)")
	for b in batters:
		assert_false(b["is_player"], "opposition roster has no Player slot")

func test_build_batters_offset_applied_and_floored() -> void:
	var roster := Team.standard_xi()
	# +2 offset: BATTER 8 -> 10, BOWLER 2 -> 4.
	var up := InningsResolver._build_batters(null, 5, itun, roster, 2)
	assert_eq(up[0]["power"], 10, "offset lifts the top order (8+2)")
	assert_eq(up[10]["power"], 4, "offset lifts the tail (2+2)")
	# -5 offset would push BOWLER 2 -> -3; must floor at 1.
	var down := InningsResolver._build_batters(null, 5, itun, roster, -5)
	assert_eq(down[10]["power"], 1, "power floored at 1 (2-5 clamped)")

func test_build_batters_flags_player_by_identity() -> void:
	var player := _attrs(8, 8, 2, 2)            # pure batter -> position 3
	var ppos := InningsResolver.player_position(player, itun)
	var roster := Team.build_xi(player, ppos)
	var batters := InningsResolver._build_batters(player, 5, itun, roster, 0)
	assert_true(batters[ppos - 1]["is_player"], "the Player slot is flagged at ppos")
	var player_flags := 0
	for b in batters:
		if b["is_player"]:
			player_flags += 1
	assert_eq(player_flags, 1, "exactly one Player slot")
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — the three roster tests fail (extra args ignored / wrong values), the clone-path test passes.

- [ ] **Step 3: Implement the roster path** — replace `_build_batters` in `scripts/domain/innings_resolver.gd` (currently lines 41-60) with:

```gdscript
# Build the 11-strong batting order.
#  - roster empty (default): the OLD path. With a statted Player the Player bats at
#    their build-driven position; every other slot is a clone of partner_batting
#    scaled by the weakening-tail curve. player_attrs == null -> all 11 derived.
#  - roster supplied (an Array of Attributes in batting order, length 11): each slot
#    reads its real Attributes. The Player slot is found by reference identity. A
#    uniform team_offset is added to power/composure (floored at 1) so star strength
#    still shifts the whole card; the synthetic tail curve is dropped (the archetype
#    order already provides the tail). See spec §8.5 (D6, D8, D10).
static func _build_batters(player_attrs: Attributes, partner_batting: int, itun: InningsTuning,
		roster: Array = [], team_offset: int = 0) -> Array:
	var batters: Array = []
	if not roster.is_empty():
		for order in range(1, 12):  # positions 1..11
			var m: Attributes = roster[order - 1]
			batters.append({
				"position": order,
				"is_player": player_attrs != null and m == player_attrs,
				"power": maxi(1, m.power + team_offset),
				"composure": maxi(1, m.composure + team_offset),
				"runs": 0, "balls": 0, "out": false,
			})
		return batters
	# --- clone path (unchanged) ---
	var ppos := -1
	if player_attrs != null:
		ppos = player_position(player_attrs, itun)
	for order in range(1, 12):  # positions 1..11
		if order == ppos:
			batters.append({
				"position": order, "is_player": true,
				"power": player_attrs.power, "composure": player_attrs.composure,
				"runs": 0, "balls": 0, "out": false,
			})
		else:
			var p := maxi(1, roundi(partner_batting * partner_factor(order, itun)))
			batters.append({
				"position": order, "is_player": false,
				"power": p, "composure": p,
				"runs": 0, "balls": 0, "out": false,
			})
	return batters
```

- [ ] **Step 4: Run the suite to verify the new tests pass**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS — `All tests passed`, total **342** (338 + 4). All prior innings tests still green (clone path untouched).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid tests/unit/test_innings_resolver.gd
git commit -m "Slice 2 Task 2: _build_batters real-roster path (offset + identity)"
```

---

## Task 3: Thread the roster through `simulate_innings`

`simulate_innings` gains two trailing params, `batting_roster: Array = []` and `team_bat_offset: int = 0`, passed straight into `_build_batters`. Default empty → unchanged behaviour (every existing caller). They go on the **end** of the long param list so all positional callers are unaffected.

**Files:**
- Modify: `scripts/domain/innings_resolver.gd:65-88` (signature) and `:88` (the `_build_batters` call)
- Test: `tests/unit/test_innings_resolver.gd`

- [ ] **Step 1: Write the failing tests** — append to `tests/unit/test_innings_resolver.gd`:

```gdscript
func test_simulate_innings_roster_default_unchanged() -> void:
	# No roster passed -> identical to the existing clone path (regression).
	var a := _attrs(5, 5, 5, 5)
	var rng1 := RandomNumberGenerator.new(); rng1.seed = 99
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 99
	var base := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, rng1)
	var same := InningsResolver.simulate_innings(a, 5, 5, 5, tuning, itun, rng2, 0,
		null, null, null, 0, 0, 0, [], true, null, null, null, null, null, [], 0)
	assert_eq(base.total, same.total, "empty roster == old behaviour (total)")
	assert_eq(base.wickets, same.wickets, "empty roster == old behaviour (wickets)")

func test_simulate_innings_roster_is_deterministic() -> void:
	var roster := Team.standard_xi()
	var rng1 := RandomNumberGenerator.new(); rng1.seed = 7
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 7
	var r1 := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, rng1, 0,
		null, null, null, 0, 0, 0, [], false, null, null, null, null, null, roster, 0)
	var r2 := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, rng2, 0,
		null, null, null, 0, 0, 0, [], false, null, null, null, null, null, roster, 0)
	assert_eq(r1.total, r2.total, "roster innings deterministic")

func test_simulate_innings_real_roster_outscores_weak_clone() -> void:
	# A real standard XI (six 8-power batters) should, over many innings, post more
	# than a flat clone of weak partners (partner_batting = 2), all else equal.
	var roster := Team.standard_xi()
	var roster_runs := 0
	var clone_runs := 0
	for s in range(40):
		var rr := RandomNumberGenerator.new(); rr.seed = s
		roster_runs += InningsResolver.simulate_innings(null, 2, 5, 5, tuning, itun, rr, 0,
			null, null, null, 0, 0, 0, [], false, null, null, null, null, null, roster, 0).total
		var cr := RandomNumberGenerator.new(); cr.seed = s
		clone_runs += InningsResolver.simulate_innings(null, 2, 5, 5, tuning, itun, cr).total
	assert_gt(roster_runs, clone_runs, "real top-order roster outscores a weak flat clone")
```

> Note: the long positional arg lists above must match `simulate_innings`'s current signature exactly — count the params from `target` onward: `target, intent_plan, bowling_attack, bowling_plan, player_bowler_attack, player_bowler_control, player_bowler_overs, jokers, player_is_batting, field_plan, bowl_intent_plan, boost_plan, drs_policy, opp_field_plan,` then the **two new** `batting_roster, team_bat_offset`. That is 14 existing optional params after the 7 required ones, then +2.

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — `Invalid call ... expected at most N arguments` (the two extra args aren't accepted yet).

- [ ] **Step 3: Add the params + pass them through** — in `scripts/domain/innings_resolver.gd`:

  (a) Add the two params to the end of the `simulate_innings` signature (after `opp_field_plan: FieldPlan = null`):

```gdscript
		opp_field_plan: FieldPlan = null,
		batting_roster: Array = [],
		team_bat_offset: int = 0
) -> InningsResult:
```

  (b) Change the `_build_batters` call (currently line 88) from:

```gdscript
	var batters := _build_batters(player_attrs, partner_batting, itun)
```

  to:

```gdscript
	var batters := _build_batters(player_attrs, partner_batting, itun, batting_roster, team_bat_offset)
```

- [ ] **Step 4: Run the suite to verify the new tests pass**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS — `All tests passed`, total **345** (342 + 3).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid tests/unit/test_innings_resolver.gd
git commit -m "Slice 2 Task 3: thread batting_roster + offset through simulate_innings"
```

---

## Task 4: Assemble rosters in `simulate_match_teams` + thread through `simulate_match`

`simulate_match` gains four trailing params — `player_roster`, `opp_roster`, `player_bat_offset`, `opp_bat_offset` — routed to the correct innings (the Player's batting innings gets `player_roster`/`player_bat_offset`; the opposition innings gets `opp_roster`/`opp_bat_offset`). `simulate_match_teams` builds those: the Player's roster via `Team.build_xi(player_attrs, ppos)`, the opponent via `Team.standard_xi()`, and each offset = that team's derived batting scalar minus `ref3 = tour.percentile(0.6)` (the even-★3 no-noise scalar). No new RNG draws → determinism preserved.

**Files:**
- Modify: `scripts/domain/match_resolver.gd:50-81` (`simulate_match_teams`), `:86-151` (`simulate_match` signature + 4 inner `simulate_innings` calls)
- Test: `tests/unit/test_match_resolver.gd`

- [ ] **Step 1: Write the failing tests** — append to `tests/unit/test_match_resolver.gd`:

```gdscript
func test_teams_player_innings_uses_real_batting_card() -> void:
	# Through the team entry point, the Player's batting innings now has a real
	# top-order/tail spread (not a flat clone). Find the Player's innings and check
	# slot 1 (a top-order BATTER, power 8 +/- offset) outranks slot 11 (a BOWLER).
	var p := _attrs(5, 5, 5, 5)
	var m := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(2024))
	var inn := m.innings1 if not m.innings1.player_line().is_empty() else m.innings2
	var card: Array = inn.batters
	assert_eq(card.size(), 11, "a full XI")
	assert_gt(card[0]["power"], card[10]["power"], "real card: opener stronger than #11")
	assert_gte(card[0]["power"], 6, "top order is a real batter, not a ~5 clone")

func test_teams_determinism_with_roster() -> void:
	var p := _attrs(5, 5, 5, 5)
	var r1 := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(2024))
	var r2 := MatchResolver.simulate_match_teams(p, _team(3.0), _team(3.0), _tour(), tuning, itun, _make_rng(2024))
	assert_eq(r1.innings1.total, r2.innings1.total, "still deterministic (innings1)")
	assert_eq(r1.innings2.total, r2.innings2.total, "still deterministic (innings2)")
	assert_eq(r1.outcome, r2.outcome, "still deterministic (outcome)")
```

> The existing `test_teams_directional_strong_beats_weak` and `test_teams_even_roughly_balanced` are the regression guard for D6 — they must stay green after this task.

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: FAIL — `test_teams_player_innings_uses_real_batting_card` fails (`card[0]["power"]` is still ~5, the clone value), because `simulate_match_teams` doesn't build rosters yet. `test_teams_determinism_with_roster` passes already.

- [ ] **Step 3a: Add the four params to `simulate_match`** — in `scripts/domain/match_resolver.gd`, extend the `simulate_match` signature (after `opp_field_plan: FieldPlan = null`):

```gdscript
		opp_field_plan: FieldPlan = null,
		player_roster: Array = [],
		opp_roster: Array = [],
		player_bat_offset: int = 0,
		opp_bat_offset: int = 0
) -> MatchResult:
```

- [ ] **Step 3b: Route the rosters into the four inner `simulate_innings` calls.** Each call ends with a trailing argument list; append the two roster args matching that innings. The Player's batting innings (the call that passes `player_attrs`, `true`) gets `player_roster, player_bat_offset`; the opposition innings (passes `null`, `false`) gets `opp_roster, opp_bat_offset`.

  Replace the `player_bats_first` block (currently lines 130-149) with:

```gdscript
	if player_bats_first:
		# Player's team posts (their intent), opposition chases.
		innings1 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, 0, player_intent_plan, opp_bowl, ai_plan,
			0, 0, 0, jokers, true, null, null, boost_plan, drs_policy, opp_field_plan,
			player_roster, player_bat_offset)
		innings2 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, innings1.total + 1, opp_intent_plan, player_bowl, player_bowling_plan,
			p_bowl_attack, p_bowl_control, p_bowl_overs, jokers, false, field_plan, player_bowl_intent_plan, boost_plan, drs_policy, null,
			opp_roster, opp_bat_offset)
	else:
		# Opposition posts, Player's team chases (their intent).
		innings1 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, 0, opp_intent_plan, player_bowl, player_bowling_plan,
			p_bowl_attack, p_bowl_control, p_bowl_overs, jokers, false, field_plan, player_bowl_intent_plan, boost_plan, drs_policy, null,
			opp_roster, opp_bat_offset)
		innings2 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, innings1.total + 1, player_intent_plan, opp_bowl, ai_plan,
			0, 0, 0, jokers, true, null, null, boost_plan, drs_policy, opp_field_plan,
			player_roster, player_bat_offset)
```

> Note: the opposition-innings calls pass `opp_field_plan` as `null` (unchanged from the original — only the Player's batting innings reads the opposition field), then the two new roster args.

- [ ] **Step 3c: Build the rosters + offsets in `simulate_match_teams`.** Replace the body of `simulate_match_teams` (currently lines 68-80) with:

```gdscript
	var player_bats_first := _resolve_toss(rng)
	var player_bat := player_team.batting_strength(tour, rng)
	var player_bowl := player_team.bowling_strength(tour, rng)
	var opp_bat := opp_team.batting_strength(tour, rng)
	var opp_bowl := opp_team.bowling_strength(tour, rng)

	# Slice 2: real rosters. The Player replaces the archetype at their build-driven
	# batting position; the opponent is the fixed standard XI. Star strength is applied
	# as a uniform batting offset (~0 at even ★3) so directionality survives. No new
	# RNG draws -> determinism preserved. See spec §8.5 (D6-D9).
	var ref3 := tour.percentile(3.0 / 5.0)
	var ppos := InningsResolver.player_position(player_attrs, itun)
	var player_roster := Team.build_xi(player_attrs, ppos)
	var opp_roster := Team.standard_xi()

	return simulate_match(
		player_attrs,
		player_bat, player_bowl, player_bowl,
		opp_bat, opp_bowl, opp_bowl,
		player_bats_first, tuning, itun, rng,
		player_intent_plan, player_bowling_plan, jokers, field_plan,
		player_bowl_intent_plan, opp_intent_plan, boost_plan, drs_policy, opp_field_plan,
		player_roster, opp_roster, player_bat - ref3, opp_bat - ref3)
```

- [ ] **Step 4: Run the suite to verify all tests pass**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: PASS — `All tests passed`, total **347** (345 + 2). Crucially the pre-existing `test_teams_directional_strong_beats_weak` and `test_teams_even_roughly_balanced` must still pass (D6 directionality regression). If `directional` fails, the offset is too weak — re-check `ref3 = tour.percentile(0.6)` and that the offset reaches `_build_batters`.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_resolver.gd scripts/domain/match_resolver.gd.uid tests/unit/test_match_resolver.gd
git commit -m "Slice 2 Task 4: assemble real rosters in simulate_match_teams"
```

---

## Task 5: Re-ground the sweep baseline + record findings

No code change — the build-spectrum sweep already runs through `simulate_match_teams`, so it now exercises the real-roster path automatically. Run it, capture the new numbers (they will shift from §9.5.1 because teams are now real individuals), and record them in the spec so Slice 3 calibrates against the correct baseline.

**Files:**
- Modify: `docs/superpowers/specs/2026-06-08-build-balance-rating-and-team-design.md` (add §9.5.2)

- [ ] **Step 1: Run the build-spectrum sweep**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/build_spectrum_sweep.gd`
Capture the printed table (win% / rating / r-bat / r-bowl per build, plus bat-avg, wkts, team/opp scores).

- [ ] **Step 2: Record the re-grounded baseline** — add a `### 9.5.2 Slice 2 re-grounded baseline (2026-06-08)` subsection to the spec with the new table and a one-paragraph read of how the win-rate spread moved vs §9.5.1 (it will NOT be flat yet — that is Slice 3's gap-fill job; the point is just to capture the honest post-roster numbers).

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-06-08-build-balance-rating-and-team-design.md
git commit -m "Slice 2 Task 5: record re-grounded sweep baseline (§9.5.2)"
```

---

## Done criteria

- All five tasks committed; `All tests passed` at **~347** tests (335 + 12 new).
- The pre-existing team directional + even-balance regressions stay green (D6 holds).
- The build-spectrum sweep runs clean through the real-roster path; §9.5.2 records the new baseline.
- No new files, so no new `class_name`s; clone path byte-identical for every scalar caller.

Then: finishing-a-development-branch (PR → merge → roadmap handoff refresh).

## Self-review notes (checked against spec)

- **§3 (rating)** — untouched this slice (shipped Slice 1); the sweep still prints it. ✓
- **§4.1 roster model / §4.2 standard XI** — Task 1 (`standard_xi` = 6/1/4, 122/98 split asserted). ✓
- **§4.3 gap-fill** — explicitly Slice 3; Slice 2 does only the crude `build_xi` displacement (D9). Not in scope here. ✓
- **§4.4 wiring** — `_build_batters` real order (Task 2), `simulate_match_teams` assembles XIs (Task 4). Bowling stays scalar per D7 (husbanding deferred to 4c). ✓
- **§8.5 D6 directionality** — offset = `team_bat − tour.percentile(0.6)`, regression-guarded by the existing directional test (Task 4 Step 4). ✓
- **§8.5 D8 null path** — every existing scalar caller passes no roster → clone path; regression tests Task 2 Step 1 + Task 3 Step 1. ✓
- **Type consistency** — `build_xi(player_attrs, ppos)`, `standard_xi()`, `archetype_*()`, `_build_batters(..., roster, team_offset)`, `simulate_innings(..., batting_roster, team_bat_offset)`, `simulate_match(..., player_roster, opp_roster, player_bat_offset, opp_bat_offset)` — names used identically across tasks. ✓
