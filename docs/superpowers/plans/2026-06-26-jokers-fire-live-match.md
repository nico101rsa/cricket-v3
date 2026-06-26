# Jokers Fire in the Live Match — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thread the player's owned-joker effects (and their derived field plan) into the live interactive match so jokers fire faithfully; empty = byte-identical to today.

**Architecture:** A new trailing optional `player_effects` on `MatchSession.start` fills the `jokers` + `field_plan` slots of `simulate_match_teams` (field via `ShopResolver.plans_for`; boost stays human). `SeasonPlay` carries the effects to every `make_session`; `season_hub.set_play` seeds them from the persisted `CareerState.carryover_joker_id` (the bridge to Rung 2).

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Run headless (`--import` once after adding/renaming scripts, then the GUT cmdln); editor must be quit; only one Godot process at a time. Judge red by the parse-error skip, green by the count climbing + `All tests passed`.

---

## File structure

- `scripts/domain/match_session.gd` — **modify**: `start` gains `player_effects`; `_resim` fills `jokers`/`field_plan`.
- `scripts/domain/season_play.gd` — **modify**: hold `_player_effects`, add `set_player_jokers`, pass it in `make_session` (both branches).
- `scenes/season_hub/season_hub.gd` — **modify**: `set_play` seeds effects from `career.carryover_joker_id`.
- Tests: `tests/unit/test_match_session*.gd`, `tests/unit/test_season_play*.gd`, `tests/unit/test_season_hub_scene.gd` (read each before appending to match its helpers).

**Test commands:**
- Import: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- Suite: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- Chain both in one command; never run two Godot processes at once.

Test joker throughout: **`block_the_shine`** — BATTING/WICKET mult 0.90, any intent, balls 1–18, **ungated** (no field/boost dependency). `JokerCatalog.effects_of_ids(["block_the_shine"])` returns its effect rows.

---

## Task 1: `MatchSession` accepts and fires player joker effects

**Files:**
- Modify: `scripts/domain/match_session.gd`
- Test: `tests/unit/test_match_session*.gd` (find the file: `ls tests/unit | grep match_session`)

- [ ] **Step 1: Write the failing tests** (append to the match_session test file; reuse its existing team/attrs/tour helpers — read the top of the file first)

```gdscript
# --- Player jokers fire in the live match (spec 2026-06-26, Rung 1) ---

func _bts_effects() -> Array:
	return JokerCatalog.effects_of_ids(["block_the_shine"])

func test_empty_player_effects_is_byte_identical() -> void:
	# Build the two sessions the same way this file's existing tests do, on one seed.
	var a := _attrs()           # existing helper
	var t := _team()            # existing helper (player team)
	var o := _opp()             # existing helper (opponent)
	var tour := _tour()         # existing helper
	var base := MatchSession.start(a, t, o, tour, 7777)
	var withEmpty := MatchSession.start(a, t, o, tour, 7777, -1, null, null, null, [])
	assert_eq(withEmpty.result().innings1.runs, base.result().innings1.runs)
	assert_eq(withEmpty.result().innings2.runs, base.result().innings2.runs)

func test_block_the_shine_raises_player_batting_total_over_seeds() -> void:
	var a := _attrs(); var t := _team(); var o := _opp(); var tour := _tour()
	var sum_base := 0
	var sum_joker := 0
	for s in range(20):
		var seed := 4200 + s
		var base := MatchSession.start(a, t, o, tour, seed, 0)   # force player bats first
		var jk := MatchSession.start(a, t, o, tour, seed, 0, null, null, null, _bts_effects())
		sum_base += base.result().innings1.runs
		sum_joker += jk.result().innings1.runs
	assert_gt(sum_joker, sum_base, "block_the_shine (fewer early wickets) lifts the player's total")
```

(If the helper names differ — e.g. `_player_team()` / `_opponent()` / `_tour_dist()` — use whatever the file already defines. `force_player_bats_first = 0` makes innings1 the player's batting innings so `innings1.runs` is the player's score.)

- [ ] **Step 2: Run suite, verify the new asserts fail** (parse/behaviour — `start` has no 10th param yet, or the totals are equal because effects are dropped). Run the chained import+suite.

- [ ] **Step 3: Implement** in `match_session.gd`.

Add the member (near the other `var _` fields, by `_opp_spec`):

```gdscript
var _player_effects: Array = []   # owned-joker effect rows; [] = none (byte-identical)
```

Extend `start` (add the trailing param + assignment):

```gdscript
static func start(attrs: Attributes, team: Team, opp: Team, tour: TourDistribution,
		seed: int, force_player_bats_first: int = -1,
		tuning: BallTuning = null, itun: InningsTuning = null,
		opp_spec: TourSpec = null, player_effects: Array = []) -> MatchSession:
	var s := MatchSession.new()
	s._attrs = attrs
	s._team = team
	s._opp = opp
	s._tour = tour
	s._seed = seed
	s._force = force_player_bats_first
	s._tuning = tuning if tuning != null else BallTuning.new()
	s._itun = itun if itun != null else InningsTuning.new()
	s._opp_spec = opp_spec
	s._player_effects = player_effects
	s._player.attributes = attrs
	s._resim()
	return s
```

In `_resim`, replace the resolver call (currently passes `[], null` for `jokers, field_plan`) with effects + the derived field plan:

```gdscript
	# Player jokers (spec 2026-06-26): fire owned effects in the live match. The field
	# plan for gated jokers is derived exactly as the headless career does (CF3); boost
	# stays human-controlled (the player's presses), so boost-role jokers fire only when
	# the player presses Boost. Empty effects -> null field + [] jokers -> byte-identical.
	var fld: FieldPlan = null
	if not _player_effects.is_empty():
		fld = ShopResolver.plans_for(_player_effects)["field"]
	_result = MatchResolver.simulate_match_teams(
		_attrs, _team, _opp, _tour, _tuning, _itun, rng,
		ip, pbp, _player_effects, fld, null, oip,
		boost, drs, null, null, null, _force, obp, log1, log2)
```

- [ ] **Step 4: Run suite, verify green.**

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_session.gd tests/unit/test_match_session*.gd
git commit -m "feat: MatchSession fires player joker effects in the live match

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `SeasonPlay` carries player effects to every match

**Files:**
- Modify: `scripts/domain/season_play.gd`
- Test: `tests/unit/test_season_play*.gd` (find: `ls tests/unit | grep season_play`)

- [ ] **Step 1: Write the failing test** (append; reuse the file's existing season/team/attrs helpers — read the top first)

```gdscript
func test_set_player_jokers_lifts_league_batting_total() -> void:
	# Same season setup the existing tests use, played twice: with and without a joker.
	var effects := JokerCatalog.effects_of_ids(["block_the_shine"])
	var sum_base := 0
	var sum_joker := 0
	for s in range(8):
		var base := _new_season(3300 + s)   # existing helper that builds a SeasonPlay
		var jk := _new_season(3300 + s)
		jk.set_player_jokers(effects)
		# Play the 7 league fixtures on each.
		for i in range(7):
			sum_base += _player_innings_runs(base)
			base.commit_player_result(base.make_session().result())
		for i in range(7):
			sum_joker += _player_innings_runs(jk)
			jk.commit_player_result(jk.make_session().result())
	assert_gt(sum_joker, sum_base, "owned joker fires across the live league fixtures")

# Helper: the player's batting-innings runs for the next fixture's session.
func _player_innings_runs(sp: SeasonPlay) -> int:
	var r := sp.make_session().result()
	return r.innings1.runs if r.player_bats_first else r.innings2.runs
```

(Adapt `_new_season(seed)` to however the file constructs a `SeasonPlay` — likely `SeasonPlay.start(attrs, team, opps, tour, BallTuning.new(), InningsTuning.new(), seed)`. The two `make_session()` calls per fixture — one in the helper, one in the loop — are fine: `make_session` is pure until `commit_player_result`.)

- [ ] **Step 2: Run suite, verify fail** (`set_player_jokers` not declared / totals equal).

- [ ] **Step 3: Implement** in `season_play.gd`.

Add the member (by the other match-construction fields, near `_opp_spec`):

```gdscript
var _player_effects: Array = []   # owned-joker effect rows passed to every player match
```

Add the setter (near `start` / the public API):

```gdscript
# Owned-joker effect rows that fire in the player's live matches (spec 2026-06-26).
# [] = none (byte-identical). Seeded by the hub from CareerState.carryover_joker_id.
func set_player_jokers(effects: Array) -> void:
	_player_effects = effects
```

Pass `_player_effects` as the trailing arg in **both** `make_session` branches:

```gdscript
func make_session() -> MatchSession:
	if _phase == Phase.LEAGUE:
		if league_done():
			return null
		var opp: Team = _teams[played_count() + 1]
		var fixture_seed := _seed + 100 + played_count()
		return MatchSession.start(_attrs, _teams[0], opp, _tour, fixture_seed,
			-1, _tuning, _itun, _opp_spec, _player_effects)
	if _phase == Phase.PLAYOFFS:
		var opp_idx := _pending_opponent_index()
		if opp_idx < 0:
			return null
		var offset: int = {"semi": 0, "final": 1, "third": 2}[_pending_stage]
		var po_seed: int = _seed + 200 + offset
		return MatchSession.start(_attrs, _teams[0], _teams[opp_idx], _tour, po_seed,
			-1, _tuning, _itun, _opp_spec, _player_effects)
	return null
```

- [ ] **Step 4: Run suite, verify green.**

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/season_play.gd tests/unit/test_season_play*.gd
git commit -m "feat: SeasonPlay carries player joker effects to every live match

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Hub seeds effects from the carry-over joker (the Rung-2 bridge)

**Files:**
- Modify: `scenes/season_hub/season_hub.gd`
- Test: `tests/unit/test_season_hub_scene.gd`

- [ ] **Step 1: Write the failing test** (append; reuse `_player()` + the save before_all/after_all already in the file)

```gdscript
# Live career advance bridge (spec 2026-06-26): the hub seeds the live play's player
# jokers from the persisted carry-over, so a carried joker fires in live matches.
func test_boot_seeds_player_jokers_from_carryover() -> void:
	SaveManager.clear_career(); SaveManager.clear_live_season()
	var career := CareerResolver.start_career(0)
	career.carryover_joker_id = "block_the_shine"
	SaveManager.save_career(career)
	SaveManager.save_player(_player())
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	hub.boot()
	var play: SeasonPlay = hub.live_play()
	assert_not_null(play, "boot built a live play")
	# The carried joker measurably lifts the player's first-fixture batting total vs a
	# no-carryover boot on the same seed.
	var with_runs := _first_fixture_runs(play)
	SaveManager.clear_live_season()
	var career2 := CareerResolver.start_career(0)   # no carryover
	SaveManager.save_career(career2)
	var hub2 = SeasonHubScene.instantiate()
	add_child_autofree(hub2)
	hub2.boot()
	var without_runs := _first_fixture_runs(hub2.live_play())
	assert_gt(with_runs, without_runs, "carry-over joker fires in the live match")
	SaveManager.clear_career(); SaveManager.clear_player(); SaveManager.clear_live_season()

func _first_fixture_runs(sp: SeasonPlay) -> int:
	var r := sp.make_session().result()
	return r.innings1.runs if r.player_bats_first else r.innings2.runs
```

(`block_the_shine` lifts the batting total on average; both boots use the same `BOOT_SEED + seasons_played = BOOT_SEED` fixture seed, so the only difference is the joker. If a single fixture's seed happens not to separate them, widen to a 2–3 fixture sum — but the same-seed single fixture should differ given the 0.90 wicket mult over 18 balls.)

- [ ] **Step 2: Run suite, verify fail** (effects not seeded → totals equal).

- [ ] **Step 3: Implement** in `season_hub.gd` `set_play` (the single funnel both `boot` and `_show_live_hub` pass through). After the `enable_pay` line, add:

```gdscript
	# Seed the player's live jokers from the persisted carry-over (spec 2026-06-26 — the
	# bridge to the Kit Room rung). "" until the shop sets one => empty => byte-identical.
	var cj := career.carryover_joker_id
	play.set_player_jokers(JokerCatalog.effects_of_ids([cj]) if cj != "" else [])
```

- [ ] **Step 4: Run suite, verify green.**

- [ ] **Step 5: Commit**

```bash
git add scenes/season_hub/season_hub.gd tests/unit/test_season_hub_scene.gd
git commit -m "feat: hub seeds live player jokers from the carry-over (Rung 2 bridge)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Full-suite verification + roadmap

- [ ] **Step 1: Run the whole suite**, confirm green and the count climbed (expect +~5 from 749).

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . \
  && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -12
```

- [ ] **Step 2: Roadmap + PR** (done at PR time): record the rung in `PROJECT_ROADMAP.md` (history + Next-session block: Rung 1 done, Rung 2 = Kit Room in the live season is next).

---

## Self-review notes

- **Spec coverage:** DLF1 (trailing optional param + setter) → Tasks 1/2; DLF2 (`plans_for` field) → Task 1 Step 3; DLF-BOOST (human boost, no auto-schedule) → Task 1 keeps `boost` unchanged, never injects `plans_for`'s boost; DLF3 (carry-over seed) → Task 3; DLF4 (effects not in the decision log) → no change to `to_state`/`replay`, effects re-seeded by the hub each boot (Task 3). §6 tests all present (empty guard + directional sweep Task 1; SeasonPlay threading Task 2; hub bridge Task 3).
- **Type consistency:** `player_effects: Array` everywhere; `set_player_jokers(effects: Array)`; `ShopResolver.plans_for(effects)["field"]` returns a `FieldPlan` (or null) → assigned to the `field_plan` slot. `JokerCatalog.effects_of_ids([...])` returns the effect-row Array consumed by `simulate_match_teams`'s `jokers` param (same type the headless `loadout_effects` produces).
- **Byte-identical guarantee:** empty `_player_effects` ⇒ `fld = null`, `jokers = []` ⇒ the exact pre-rung call; the whole existing suite (incl. the cross-session resume test, which doesn't set jokers) stays green.
