# E3 Difficulty Ladder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the measured opponent-AI brain ladder + league-strength table as the game's per-cell difficulty system (spec `docs/superpowers/specs/2026-06-12-difficulty-ladder-7cE3-design.md`).

**Architecture:** Two data classes (`TourSpec` row, `DifficultyLadder` codified canon sheet) + one domain factory (`OpponentBrain` → IntentPlan/BowlingPlan per tier/blend), threaded as one optional trailing param through `LeagueResolver`/`SeasonResolver` into the existing `opp_intent_plan`/`opp_bowling_plan` seams. New oracle sweeps all 24 cells.

**Tech Stack:** Godot 4.6.3 GDScript (tabs), GUT 9.6. Test run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`. After adding any script: `--import` once first. Suite baseline **446 green**; judge red by parse error, green by count climbing. ONE Godot process at a time.

---

### Task 0: Confirm the re-anchored adaptive literal

The full-N re-anchor (`/tmp/e3_reanchor.log`) must be finished before Task 3.

- [ ] **Step 1:** `grep "DATA = " /tmp/e3_reanchor.log` and read the equilibrium labels (`A:`/`B:` lines). If the joint equilibrium's adaptive rules differ from E2's `+u11d6c4`, the new literal is what `OpponentBrain.adaptive_eq_plans()` ships (and spec §10 records both). The static-eq literal stays `B/A/B·P/S/P` unless the log says otherwise.
- [ ] **Step 2:** Record the four gap-arm numbers (vs naive/textbook/balanced/static-eq) in spec §10.

### Task 1: `TourSpec` (data row)

**Files:**
- Create: `scripts/data/tour_spec.gd`
- Test: `tests/unit/test_difficulty_ladder.gd` (new file, shared with Task 2)

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

# E3 (spec 2026-06-12-difficulty-ladder-7cE3-design.md): the codified canon
# difficulty sheet + per-cell TourSpec rows.


func test_tour_spec_mean_frac_endpoints() -> void:
	assert_almost_eq(TourSpec.mean_frac(1.0), 0.4, 0.0001)
	assert_almost_eq(TourSpec.mean_frac(12.0), 1.3, 0.0001)


func test_tour_spec_make_tour_arithmetic() -> void:
	var spec := TourSpec.new()
	spec.d = 12.0
	var tour := spec.make_tour()
	assert_almost_eq(tour.mean, 1.3 * 31.25, 0.001)
	assert_almost_eq(tour.spread, 0.3 * tour.mean, 0.001)


func test_tour_spec_mid_anchor_matches_ref_scalar() -> void:
	assert_almost_eq(TourSpec.MID_MEAN, MatchResolver.REF_SCALAR, 0.0001)
```

- [ ] **Step 2: Run suite — red.** Expect `Parse Error: Identifier "TourSpec" not declared` (GUT logs it and skips the file; that IS the red signal — count stays 446).
- [ ] **Step 3: Implement**

```gdscript
class_name TourSpec
extends RefCounted

# One Career-grid cell's difficulty row (E3, spec
# 2026-06-12-difficulty-ladder-7cE3-design.md §3.2). Pure data; DifficultyLadder
# builds the 24 of them, OpponentBrain interprets brain_tier/blend.

enum Tier { NAIVE, TEXTBOOK, STATIC_EQ, ADAPTIVE }

const MID_MEAN := 31.25         # the mid-league card anchor (= MatchResolver.REF_SCALAR)
const SPREAD_RATIO := 0.3       # today's mid-league spread/mean ratio (DL7)

var level: int = 0              # 0 Club, 1 City, 2 Province
var tour_index: int = 0         # 0..7 (Practise .. Premium)
var d: float = 1.0              # canon difficulty number (DL1)
var cell_name: String = ""
var brain_tier: int = Tier.NAIVE
var blend: float = 1.0          # P(tier); else one tier lower (DL4)
var opp_stars: Array = []       # the 7-opponent ★ field

# mean_frac spans 0.40 (d=1) .. 1.30 (d=12), linear (DL3).
static func mean_frac(p_d: float) -> float:
	return 0.4 + (p_d - 1.0) * 0.9 / 11.0

func make_tour() -> TourDistribution:
	var tour := TourDistribution.new()
	tour.tour_name = cell_name
	tour.mean = TourSpec.mean_frac(d) * MID_MEAN
	tour.spread = SPREAD_RATIO * tour.mean
	return tour
```

- [ ] **Step 4: Import + run suite — green.** `--import` first (new script). Count climbs 446 → 449, `All tests passed`.
- [ ] **Step 5: Commit** (`git add scripts/data/tour_spec.gd scripts/data/tour_spec.gd.uid tests/unit/test_difficulty_ladder.gd` — no `.uid` for the test file).

### Task 2: `DifficultyLadder` (the canon sheet)

**Files:**
- Create: `scripts/data/difficulty_ladder.gd`
- Test: append to `tests/unit/test_difficulty_ladder.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_ladder_has_24_cells_with_canon_bands() -> void:
	var cells := DifficultyLadder.all()
	assert_eq(cells.size(), 24)
	# Canon bands (CONTEXT.md): Club 1-8, City 2-10, Province 3-12.
	var lo := [1.0, 2.0, 3.0]
	var hi := [8.0, 10.0, 12.0]
	for lvl in range(3):
		assert_almost_eq(DifficultyLadder.spec_for(lvl, 0).d, lo[lvl], 0.0001)
		assert_almost_eq(DifficultyLadder.spec_for(lvl, 7).d, hi[lvl], 0.0001)


func test_ladder_d_monotone_within_level_with_canon_jumps() -> void:
	for lvl in range(3):
		for t in range(1, 8):
			assert_gt(DifficultyLadder.spec_for(lvl, t).d, DifficultyLadder.spec_for(lvl, t - 1).d)
		# Deliberate jumps at Home->Away (index 3->4) and ->Premium (6->7).
		assert_gte(DifficultyLadder.spec_for(lvl, 4).d - DifficultyLadder.spec_for(lvl, 3).d, 2.0)
		assert_gte(DifficultyLadder.spec_for(lvl, 7).d - DifficultyLadder.spec_for(lvl, 6).d, 2.0)


func test_ladder_levels_overlap() -> void:
	# A higher Level's Practise is gentler than the Level below's Away tours.
	for lvl in range(2):
		assert_lt(DifficultyLadder.spec_for(lvl + 1, 0).d, DifficultyLadder.spec_for(lvl, 4).d)


func test_ladder_brain_progression() -> void:
	var club_practise := DifficultyLadder.spec_for(0, 0)
	assert_eq(club_practise.brain_tier, TourSpec.Tier.NAIVE)
	assert_almost_eq(club_practise.blend, 1.0, 0.0001)
	var club_premium := DifficultyLadder.spec_for(0, 7)
	assert_eq(club_premium.brain_tier, TourSpec.Tier.STATIC_EQ)
	assert_almost_eq(club_premium.blend, 0.5, 0.0001)
	var province_premium := DifficultyLadder.spec_for(2, 7)
	assert_eq(province_premium.brain_tier, TourSpec.Tier.ADAPTIVE)
	assert_almost_eq(province_premium.blend, 1.0, 0.0001)


func test_ladder_star_field_shape() -> void:
	var spec := DifficultyLadder.spec_for(1, 3)
	assert_eq(spec.opp_stars.size(), 7)
	var total := 0.0
	for s in spec.opp_stars:
		total += s
	assert_almost_eq(total / 7.0, 3.0, 0.0001)
```

- [ ] **Step 2: Run suite — red** (`Identifier "DifficultyLadder" not declared`).
- [ ] **Step 3: Implement**

```gdscript
class_name DifficultyLadder
extends RefCounted

# The Career grid's difficulty table (E3, spec
# 2026-06-12-difficulty-ladder-7cE3-design.md). Codifies the canon difficulty
# sheet (CONTEXT.md: overlapping bands Club 1-8 / City 2-10 / Province 3-12,
# jumps at Home->Away and ->Premium) and assigns each cell a brain + blend.

const LEVEL_NAMES := ["Club", "City", "Province"]
const TOUR_NAMES := [
	"Practise", "Home summer", "Home winter", "Home evening",
	"Away summer", "Away winter", "Away evening", "Premium",
]

# d per [level][tour_index] — the tunable artifact (DL1).
const D_SHEET := [
	[1.0, 2.0, 2.5, 3.0, 5.0, 5.5, 6.0, 8.0],
	[2.0, 3.0, 3.5, 4.0, 6.5, 7.0, 7.5, 10.0],
	[3.0, 4.5, 5.0, 5.5, 8.0, 8.5, 9.0, 12.0],
]

# Neutral 7-opponent ★ field, all cells this rung (DL2): mean 3.0.
const OPP_STARS := [2.0, 2.5, 3.0, 3.0, 3.0, 3.5, 4.0]

# d -> [tier, blend] (spec §3.2 strawman).
static func brain_for(d: float) -> Array:
	if d <= 2.0:
		return [TourSpec.Tier.NAIVE, 1.0]
	if d <= 4.0:
		return [TourSpec.Tier.TEXTBOOK, 0.5]
	if d <= 6.0:
		return [TourSpec.Tier.TEXTBOOK, 1.0]
	if d <= 8.0:
		return [TourSpec.Tier.STATIC_EQ, 0.5]
	if d <= 9.0:
		return [TourSpec.Tier.STATIC_EQ, 1.0]
	if d <= 11.0:
		return [TourSpec.Tier.ADAPTIVE, 0.5]
	return [TourSpec.Tier.ADAPTIVE, 1.0]

static func spec_for(level: int, tour_index: int) -> TourSpec:
	var spec := TourSpec.new()
	spec.level = level
	spec.tour_index = tour_index
	spec.d = D_SHEET[level][tour_index]
	spec.cell_name = "%s %s" % [LEVEL_NAMES[level], TOUR_NAMES[tour_index]]
	var brain := brain_for(spec.d)
	spec.brain_tier = brain[0]
	spec.blend = brain[1]
	spec.opp_stars = OPP_STARS.duplicate()
	return spec

static func all() -> Array:
	var out: Array = []
	for lvl in range(3):
		for t in range(8):
			out.append(spec_for(lvl, t))
	return out
```

- [ ] **Step 4: Import + run suite — green** (449 → 454).
- [ ] **Step 5: Commit.**

### Task 3: `OpponentBrain` (domain factory)

**Files:**
- Create: `scripts/domain/opponent_brain.gd`
- Test: `tests/unit/test_opponent_brain.gd` (new file)

Uses the Task-0 literal — code below shows E2's `B/A/A·P/S/P+u11d6c4`; substitute the re-anchored rules if Task 0 found different ones.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest

# E3 (spec §3.3): the opponent-brain factory. Tier literals are the measured
# self-play equilibria; NAIVE draws a uniform static policy.


func test_textbook_plans_are_the_textbook_factories() -> void:
	var plans := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, null)
	var ip: IntentPlan = plans[0]
	var bp: BowlingPlan = plans[1]
	assert_eq(ip.for_over(3), BallResolver.Intent.AGGRESSIVE)
	assert_eq(ip.for_over(10), BallResolver.Intent.BALANCED)
	assert_eq(bp.for_over(10), BowlingPlan.Kind.SPIN)
	assert_eq(ip.chase_up_rr, -1.0, "static tiers carry no state rules")


func test_static_eq_literal() -> void:
	var plans := OpponentBrain.draw_plans(TourSpec.Tier.STATIC_EQ, 1.0, null)
	var ip: IntentPlan = plans[0]
	var bp: BowlingPlan = plans[1]
	# B/A/B·P/S/P (E1/bowling-balance equilibrium).
	assert_eq(ip.for_over(3), BallResolver.Intent.BALANCED)
	assert_eq(ip.for_over(10), BallResolver.Intent.AGGRESSIVE)
	assert_eq(ip.for_over(18), BallResolver.Intent.BALANCED)
	assert_eq(bp.for_over(3), BowlingPlan.Kind.PACE)
	assert_eq(bp.for_over(10), BowlingPlan.Kind.SPIN)
	assert_eq(ip.collapse_wkts, -1)


func test_adaptive_eq_literal_carries_rules() -> void:
	var plans := OpponentBrain.draw_plans(TourSpec.Tier.ADAPTIVE, 1.0, null)
	var ip: IntentPlan = plans[0]
	assert_eq(ip.for_over(3), BallResolver.Intent.BALANCED)
	assert_eq(ip.for_over(10), BallResolver.Intent.AGGRESSIVE)
	assert_eq(ip.for_over(18), BallResolver.Intent.AGGRESSIVE)
	assert_true(ip.chase_up_rr > 0.0, "adaptive brain reads the chase")
	assert_true(ip.collapse_wkts > 0, "adaptive brain protects a collapse")


func test_naive_is_seed_deterministic_and_legal() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 7
	var b := RandomNumberGenerator.new()
	b.seed = 7
	var pa := OpponentBrain.draw_plans(TourSpec.Tier.NAIVE, 1.0, a)
	var pb := OpponentBrain.draw_plans(TourSpec.Tier.NAIVE, 1.0, b)
	for over in [3, 10, 18]:
		assert_eq(pa[0].for_over(over), pb[0].for_over(over))
		assert_eq(pa[1].for_over(over), pb[1].for_over(over))
		assert_true(pa[0].for_over(over) >= BallResolver.Intent.DEFENSIVE)
		assert_true(pa[0].for_over(over) <= BallResolver.Intent.AGGRESSIVE)


func test_full_blend_consumes_no_rng_for_fixed_tiers() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 11
	var b := RandomNumberGenerator.new()
	b.seed = 11
	OpponentBrain.draw_plans(TourSpec.Tier.STATIC_EQ, 1.0, a)
	assert_eq(a.randf(), b.randf(), "blend 1.0 on a fixed tier must not touch the rng")


func test_blend_downgrades_about_half_the_time() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var downgraded := 0
	for i in range(200):
		var plans := OpponentBrain.draw_plans(TourSpec.Tier.STATIC_EQ, 0.5, rng)
		var ip: IntentPlan = plans[0]
		# STATIC_EQ mid = AGGRESSIVE; the tier below (TEXTBOOK) mid = BALANCED.
		if ip.for_over(10) == BallResolver.Intent.BALANCED:
			downgraded += 1
	assert_between(downgraded, 60, 140)
```

- [ ] **Step 2: Run suite — red** (`Identifier "OpponentBrain" not declared`).
- [ ] **Step 3: Implement**

```gdscript
class_name OpponentBrain
extends RefCounted

# E3 (spec §3.3): turns a TourSpec brain tier + blend into the opponent's
# IntentPlan/BowlingPlan via the existing opp_* seams. Tier literals are the
# measured self-play equilibria (E1 PR #42, E2 PR #45, re-anchored full-N
# post-rescale 2026-06-12 — see the E3 spec §10). Game code: independent of
# scripts/harness (DL6). NAIVE re-draws the E1 216-space uniformly.

static func textbook_plans() -> Array:
	return [IntentPlan.textbook(), BowlingPlan.textbook()]

# B/A/B·P/S/P — the static equilibrium (bowling-balance + E1).
static func static_eq_plans() -> Array:
	var ip := IntentPlan.new()
	ip.powerplay = BallResolver.Intent.BALANCED
	ip.middle = BallResolver.Intent.AGGRESSIVE
	ip.death = BallResolver.Intent.BALANCED
	return [ip, BowlingPlan.textbook()]

# B/A/A·P/S/P+u11d6c4 — the adaptive equilibrium (E2; rules re-anchored at
# full N on the /100 scale — Task 0 of the E3 plan pins the shipped values).
static func adaptive_eq_plans() -> Array:
	var ip := IntentPlan.new()
	ip.powerplay = BallResolver.Intent.BALANCED
	ip.middle = BallResolver.Intent.AGGRESSIVE
	ip.death = BallResolver.Intent.AGGRESSIVE
	ip.chase_up_rr = 11.0
	ip.chase_down_rr = 6.0
	ip.collapse_wkts = 4
	return [ip, BowlingPlan.textbook()]

# A uniform draw over the E1 static space (3 intents x 2 kinds per phase).
# Draw order fixed: pp/mid/death intent, then pp/mid/death kind.
static func naive_plans(rng: RandomNumberGenerator) -> Array:
	var intents := [BallResolver.Intent.DEFENSIVE, BallResolver.Intent.BALANCED, BallResolver.Intent.AGGRESSIVE]
	var kinds := [BowlingPlan.Kind.PACE, BowlingPlan.Kind.SPIN]
	var ip := IntentPlan.new()
	ip.powerplay = intents[rng.randi_range(0, 2)]
	ip.middle = intents[rng.randi_range(0, 2)]
	ip.death = intents[rng.randi_range(0, 2)]
	var bp := BowlingPlan.new()
	bp.powerplay = kinds[rng.randi_range(0, 1)]
	bp.middle = kinds[rng.randi_range(0, 1)]
	bp.death = kinds[rng.randi_range(0, 1)]
	return [ip, bp]

# The cell's draw: the tier with P(blend), else one tier lower (DL4).
# blend 1.0 on a fixed tier consumes no RNG. rng may be null only when the
# outcome cannot need it (fixed tier, blend 1.0).
static func draw_plans(tier: int, blend: float, rng: RandomNumberGenerator) -> Array:
	var t := tier
	if blend < 1.0 and rng.randf() >= blend:
		t = maxi(t - 1, TourSpec.Tier.NAIVE)
	if t == TourSpec.Tier.NAIVE:
		return naive_plans(rng)
	if t == TourSpec.Tier.TEXTBOOK:
		return textbook_plans()
	if t == TourSpec.Tier.STATIC_EQ:
		return static_eq_plans()
	return adaptive_eq_plans()
```

- [ ] **Step 4: Import + run suite — green** (454 → 460).
- [ ] **Step 5: Commit.**

### Task 4: Thread the brain through `LeagueResolver`

**Files:**
- Modify: `scripts/domain/league_resolver.gd` (signature + fixture loop)
- Test: append to `tests/unit/test_league_resolver.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
func _ladder_league(seed_v: int, spec: TourSpec) -> LeagueResult:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var attrs := Attributes.new()
	attrs.power = 35.0
	attrs.composure = 30.0
	attrs.attack = 30.0
	attrs.control = 30.0
	var player_team := Team.new()
	player_team.stars = 3.0
	var opponents: Array = []
	for s in DifficultyLadder.OPP_STARS:
		var t := Team.new()
		t.stars = s
		opponents.append(t)
	var tour := spec.make_tour() if spec != null else TourDistribution.new()
	return LeagueResolver.simulate_league(
		attrs, player_team, opponents, tour,
		BallTuning.new(), InningsTuning.new(), rng,
		IntentPlan.textbook(), BowlingPlan.textbook(), spec)


func test_league_with_brain_is_deterministic() -> void:
	var a := _ladder_league(31, DifficultyLadder.spec_for(2, 7))
	var b := _ladder_league(31, DifficultyLadder.spec_for(2, 7))
	assert_eq(a.player_position, b.player_position)
	for k in range(8):
		assert_eq(a.standings[k].points, b.standings[k].points)
		assert_eq(a.standings[k].team_index, b.standings[k].team_index)


func test_league_null_spec_matches_omitted_param() -> void:
	var a := _ladder_league(47, null)
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var attrs := Attributes.new()
	attrs.power = 35.0
	attrs.composure = 30.0
	attrs.attack = 30.0
	attrs.control = 30.0
	var player_team := Team.new()
	player_team.stars = 3.0
	var opponents: Array = []
	for s in DifficultyLadder.OPP_STARS:
		var t := Team.new()
		t.stars = s
		opponents.append(t)
	var b := LeagueResolver.simulate_league(
		attrs, player_team, opponents, TourDistribution.new(),
		BallTuning.new(), InningsTuning.new(), rng,
		IntentPlan.textbook(), BowlingPlan.textbook())
	assert_eq(a.player_position, b.player_position)
	for k in range(8):
		assert_eq(a.standings[k].points, b.standings[k].points)


func test_smarter_brain_wins_more_player_games() -> void:
	# Same tour strength, only the brain differs: adaptive-eq opponent should
	# take more games off the Player than a naive one (seed-summed, N=20 leagues
	# x 7 player games each = 140 games per arm; ladder gap ~24 pts).
	var naive_spec := DifficultyLadder.spec_for(1, 2)
	naive_spec.brain_tier = TourSpec.Tier.NAIVE
	naive_spec.blend = 1.0
	var smart_spec := DifficultyLadder.spec_for(1, 2)
	smart_spec.brain_tier = TourSpec.Tier.ADAPTIVE
	smart_spec.blend = 1.0
	var naive_wins := 0
	var smart_wins := 0
	for s in range(20):
		for m in _ladder_league(100 + s, naive_spec).player_matches:
			if m.player_won():
				naive_wins += 1
		for m in _ladder_league(100 + s, smart_spec).player_matches:
			if m.player_won():
				smart_wins += 1
	assert_lt(smart_wins, naive_wins, "adaptive opponent must beat the Player more often than naive")
```

- [ ] **Step 2: Run suite — red.** The new tests fail with a wrong-arg-count parse/call error (`simulate_league` takes 9 args, called with 10).
- [ ] **Step 3: Implement** — in `scripts/domain/league_resolver.gd`:

Signature gains one trailing param:

```gdscript
static func simulate_league(
		player_attrs: Attributes,
		player_team: Team,
		opponents: Array,
		tour: TourDistribution,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator,
		player_intent_plan: IntentPlan = null,
		player_bowling_plan: BowlingPlan = null,
		opp_spec: TourSpec = null
) -> LeagueResult:
```

In the fixture loop, replace the `simulate_match` call block with:

```gdscript
		var i_bats_first := MatchResolver._resolve_toss(rng)
		var p_attrs: Attributes = player_attrs if i == 0 else null
		var ip: IntentPlan = player_intent_plan if i == 0 else null
		var bp: BowlingPlan = player_bowling_plan if i == 0 else null
		# E3: the cell's opponent brain fires on Player-facing fixtures only
		# (DL5). round_robin has i < j, so the Player (index 0) is always i.
		var oip: IntentPlan = null
		var obp: BowlingPlan = null
		if opp_spec != null and i == 0:
			var plans := OpponentBrain.draw_plans(opp_spec.brain_tier, opp_spec.blend, rng)
			oip = plans[0]
			obp = plans[1]
		var m := MatchResolver.simulate_match(
			p_attrs,
			bat[i], bowl[i], bowl[i],
			bat[j], bowl[j], bowl[j],
			i_bats_first, tuning, itun, rng, ip, bp,
			[], null, null, oip, null, null, null, [], [], 1.0, 1.0, null, null, obp)
```

(The positional tail matches `simulate_match`'s declared order: jokers, field_plan, player_bowl_intent_plan, **opp_intent_plan**, boost_plan, drs_policy, opp_field_plan, player_roster, opp_roster, player_bat_factor, opp_bat_factor, opp_boost_plan, opp_drs_policy, **opp_bowling_plan**.)

- [ ] **Step 4: Run suite — green** (460 → 464). All 446 pre-rung tests must still pass (null spec → no draws → byte-identical).
- [ ] **Step 5: Commit.**

### Task 5: Thread the brain through `SeasonResolver`

**Files:**
- Modify: `scripts/domain/season_resolver.gd` (both signatures)
- Test: append to `tests/unit/test_season_resolver.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
func test_season_with_brain_is_deterministic() -> void:
	var spec := DifficultyLadder.spec_for(2, 7)
	var results: Array = []
	for rep in range(2):
		var rng := RandomNumberGenerator.new()
		rng.seed = 91
		var attrs := Attributes.new()
		attrs.batting_power = 35
		attrs.batting_composure = 30
		attrs.bowling_attack = 30
		attrs.bowling_control = 30
		var player_team := Team.new()
		player_team.stars = 3.0
		var opponents: Array = []
		for s in DifficultyLadder.OPP_STARS:
			var t := Team.new()
			t.stars = s
			opponents.append(t)
		results.append(SeasonResolver.simulate_season(
			attrs, player_team, opponents, spec.make_tour(),
			BallTuning.new(), InningsTuning.new(), rng,
			IntentPlan.textbook(), BowlingPlan.textbook(), spec))
	assert_eq(results[0].player_final_position, results[1].player_final_position)
	assert_eq(results[0].final_order, results[1].final_order)
```

- [ ] **Step 2: Run suite — red** (wrong-arg-count on `simulate_season`).
- [ ] **Step 3: Implement** — in `scripts/domain/season_resolver.gd`:

`simulate_season` gains `opp_spec: TourSpec = null` (trailing), forwards it to `simulate_league(..., player_intent_plan, player_bowling_plan, opp_spec)`, and passes it to every `_knockout(...)` call as a new trailing arg.

`_knockout` gains `opp_spec: TourSpec = null` and draws plans only when the Player is in the game, after the toss (fixed RNG order: toss → brain draws → match):

```gdscript
	var toss := MatchResolver._resolve_toss(rng)
	# E3 (DL5): the cell's brain fires only when the Player is in the knockout.
	var oip: IntentPlan = null
	var obp: BowlingPlan = null
	if opp_spec != null and s1 == 0:
		var plans := OpponentBrain.draw_plans(opp_spec.brain_tier, opp_spec.blend, rng)
		oip = plans[0]
		obp = plans[1]
	var m := MatchResolver.simulate_match(
		pa, team_bat[s1], team_bowl[s1], team_bowl[s1],
		team_bat[s2], team_bowl[s2], team_bowl[s2],
		toss, tuning, itun, rng, ipp, bpp,
		[], null, null, oip, null, null, null, [], [], 1.0, 1.0, null, null, obp)
```

- [ ] **Step 4: Run suite — green** (464 → 465).
- [ ] **Step 5: Commit.**

### Task 6: The ladder oracle + viz

**Files:**
- Create: `tools/sweep_difficulty_ladder.gd`
- Create: `docs/mockups/difficulty-ladder-v1.html` (DATA-block viewer, same pattern as `policy-state-v1.html`)

- [ ] **Step 1: Write the oracle** (no unit test — tools are diagnostics; the smoke run is the test):

```gdscript
extends SceneTree

# E3 oracle (spec 2026-06-12-difficulty-ladder-7cE3-design.md §3.5): the
# reference build plays N Seasons at every Career-grid cell -> beat-rate +
# win-Final-rate per cell, + a brain-isolation pair at mid-City strength.
# Quick smoke: E3_QUICK=1. Full run ~20-40 min: nohup-detach + log-grep watcher.
# /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_difficulty_ladder.gd

const FULL_N := 200
const QUICK_N := 20


func _init() -> void:
	var quick := OS.get_environment("E3_QUICK") == "1"
	var n := QUICK_N if quick else FULL_N
	if quick:
		print("[quick mode]")
	var t0 := Time.get_ticks_msec()
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()

	var cells: Array = []
	for spec in DifficultyLadder.all():
		var r := _run_cell(spec, n, tuning, itun, 0)
		cells.append(r)
		print("%-22s d=%4.1f  beat %5.1f%%  win-final %5.1f%%" % [
			spec.cell_name, spec.d, 100.0 * r["beat"], 100.0 * r["won"]])

	# Brain isolation: same strength (City Home winter), naive vs adaptive.
	print("\n== brain isolation (City Home winter strength) ==")
	var iso: Array = []
	for tier in [TourSpec.Tier.NAIVE, TourSpec.Tier.ADAPTIVE]:
		var spec := DifficultyLadder.spec_for(1, 2)
		spec.brain_tier = tier
		spec.blend = 1.0
		var r := _run_cell(spec, n, tuning, itun, 777)
		iso.append(r)
		print("tier %d: beat %5.1f%%  player-game win %5.1f%%" % [
			tier, 100.0 * r["beat"], 100.0 * r["game_win"]])

	print("\nelapsed %.1f min" % ((Time.get_ticks_msec() - t0) / 60000.0))
	print("DATA = " + JSON.stringify({"n": n, "cells": cells, "iso": iso}))
	quit()


func _run_cell(spec: TourSpec, n: int, tuning: BallTuning, itun: InningsTuning, seed_base: int) -> Dictionary:
	var beat := 0
	var won := 0
	var games := 0
	var game_wins := 0
	for k in range(n):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + seed_base + k
		var attrs := Attributes.new()
		attrs.batting_power = 35
		attrs.batting_composure = 30
		attrs.bowling_attack = 30
		attrs.bowling_control = 30
		var player_team := Team.new()
		player_team.stars = 3.0
		var opponents: Array = []
		for s in spec.opp_stars:
			var t := Team.new()
			t.stars = s
			opponents.append(t)
		var season := SeasonResolver.simulate_season(
			attrs, player_team, opponents, spec.make_tour(),
			tuning, itun, rng,
			IntentPlan.textbook(), BowlingPlan.textbook(), spec)
		if season.beat:
			beat += 1
		if season.won_final:
			won += 1
		for m in season.league.player_matches:
			games += 1
			if m.player_won():
				game_wins += 1
	return {
		"cell": spec.cell_name, "level": spec.level, "tour": spec.tour_index,
		"d": spec.d, "tier": spec.brain_tier, "blend": spec.blend,
		"beat": float(beat) / float(n), "won": float(won) / float(n),
		"game_win": float(game_wins) / float(games),
	}
```

- [ ] **Step 2: Smoke run.** `E3_QUICK=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_difficulty_ladder.gd` (after `--import`). Expected: 24 cell lines + iso pair + `DATA =` JSON; beat-rate broadly falling with d.
- [ ] **Step 3: Build the viz** — `docs/mockups/difficulty-ladder-v1.html`: copy the DATA-block pattern from `docs/mockups/policy-state-v1.html`; render a 3×8 beat-rate heatmap (Levels × Tours), per-Level ladder lines (beat-rate vs d), and the iso pair as two bars. Paste the full run's DATA when it lands.
- [ ] **Step 4: Launch the full run detached** (ONE Godot at a time — only after the suite + smoke are done):

```bash
nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_difficulty_ladder.gd > /tmp/e3_ladder_full.log 2>&1 &
```

Watcher greps the LOG for `DATA = ` / `SCRIPT ERROR` / process exit — never pgrep the script name.

- [ ] **Step 5: Commit** the oracle + viz (with `tools/*.gd.uid`).

### Task 7: Findings, env probes, close-out

- [ ] **Step 1: Env texture probes** (after the full run frees Godot): `ENV_TOUR_MEAN=12.5` (Club Practise) and `ENV_TOUR_MEAN=40.6` (Province Premium) via `tools/probe_scoring_env.gd`; record both in spec §10 (eyeball, not gated).
- [ ] **Step 2: Floor-bind check (DL3):** Club Practise mean_frac 0.40 < 0.5 — confirm from the band-1-style probe + `InningsResolver` whether `team_bat_factor`'s 0.5 safety floor binds there, record where it starts binding in §10.
- [ ] **Step 3: Fill spec §10** — re-anchored ladder numbers (Task 0), the 24-cell beat-rate surface, iso pair, monotonicity/overlap acceptance verdicts (DL10), env textures.
- [ ] **Step 4: Paste full-run DATA into the viz; eyeball it in a browser.**
- [ ] **Step 5: Full suite green; commit; PR; merge; sync main; roadmap close-out + Session Handoff.**
