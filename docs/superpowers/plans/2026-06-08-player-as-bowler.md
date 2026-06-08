# Player-as-bowler Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Player's bowling Attributes (Attack/Control) into the sim so a bowling-heavy build bowls real overs and a bowling build wins meaningfully more — completing 7c harness layer B.

**Architecture:** Mirror build-driven batting position. A new `player_overs()` maps the same batting/bowling share to a 0–4 over quota; the Player's overs (evenly spaced) replace the team's generic bowling numbers on those overs during the opposition's batting innings. All threading is additive trailing-optional params (off by default), except `simulate_match` which turns it always-on (a deliberate, documented behaviour change). Pure domain logic, no RNG-order change.

**Tech Stack:** Godot 4.6.3 / GDScript, GUT 9.6 test suite. Spec: `docs/superpowers/specs/2026-06-08-player-as-bowler-design.md`.

**Conventions (project `CLAUDE.md`):** tabs in `.gd`; quit the Godot editor before headless runs (`pgrep Godot` first); after adding/renaming scripts run `--import` once; GUT `-gtest` does NOT filter — judge **red** by a `Parse Error: Identifier "X" not declared`, **green** by the total count climbing past **184** + `All tests passed`. Commit `*.gd.uid` for `scripts/` (not `tests/`). Run the suite with:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`

---

### Task 1: `player_overs` + `player_bowling_overs` (the build→quota map)

**Files:**
- Modify: `scripts/data/innings_tuning.gd` (add 3 strawman fields)
- Modify: `scripts/domain/innings_resolver.gd` (add 2 static helpers, after `partner_factor`)
- Test: `tests/unit/test_innings_resolver.gd`

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_innings_resolver.gd` (the `_attrs` helper and `itun` already exist at the top of the file):

```gdscript
func test_pure_batter_bowls_no_overs() -> void:
	# 8/8/2/2: share 0.2 -> 8*0.2 - 2.5 = -0.9 -> round -1 -> clamp 0
	assert_eq(InningsResolver.player_overs(_attrs(8, 8, 2, 2), itun), 0, "specialist batter doesn't bowl")

func test_even_build_bowls_part_time() -> void:
	# 5/5/5/5: share 0.5 -> 8*0.5 - 2.5 = 1.5 -> round 2
	assert_eq(InningsResolver.player_overs(_attrs(5, 5, 5, 5), itun), 2, "balanced build is a part-timer")

func test_pure_bowler_bowls_full_quota() -> void:
	# 2/2/8/8: share 0.8 -> 8*0.8 - 2.5 = 3.9 -> round 4 (== max)
	assert_eq(InningsResolver.player_overs(_attrs(2, 2, 8, 8), itun), 4, "specialist bowler bowls the full quota")

func test_overs_monotonic_in_bowling_share() -> void:
	var batter := InningsResolver.player_overs(_attrs(8, 8, 2, 2), itun)
	var mid := InningsResolver.player_overs(_attrs(5, 5, 5, 5), itun)
	var bowler := InningsResolver.player_overs(_attrs(2, 2, 8, 8), itun)
	assert_lte(batter, mid, "more bowling share never fewer overs (batter<=mid)")
	assert_lte(mid, bowler, "more bowling share never fewer overs (mid<=bowler)")

func test_bowling_over_set_evenly_spaced() -> void:
	assert_eq(InningsResolver.player_bowling_overs(0, 20), [], "zero overs -> empty set")
	var set4 := InningsResolver.player_bowling_overs(4, 20)
	assert_eq(set4.size(), 4, "4 overs -> 4 entries")
	# distinct + within 1..20
	var seen := {}
	for o in set4:
		assert_between(o, 1, 20, "over %d within innings" % o)
		assert_false(seen.has(o), "overs distinct")
		seen[o] = true
```

- [ ] **Step 2: Run the suite to verify red**

Run the suite command. Expected: `Parse Error: Identifier "player_overs" not declared` (and `player_bowling_overs`) — the new tests' file is skipped; count stays at 184.

- [ ] **Step 3: Add the tuning fields**

In `scripts/data/innings_tuning.gd`, after the tail-curve block, add:

```gdscript

# build -> bowling overs (0..bowl_max_overs): overs = clamp(round(gain*share + base), 0, max)
# where share = (attack+control)/(power+composure+attack+control). Strawman; harness-tunable.
@export var bowl_max_overs: int = 4
@export var bowl_overs_gain: float = 8.0
@export var bowl_overs_base: float = -2.5
```

- [ ] **Step 4: Add the two helpers**

In `scripts/domain/innings_resolver.gd`, after `partner_factor` (around line 17), add:

```gdscript

# Build -> bowling overs (0..bowl_max_overs). Mirror of player_position: the same
# batting/bowling share that pushes a bowler-build down the order also gives them
# more overs. Strawman curve in InningsTuning; harness-tunable.
static func player_overs(attrs: Attributes, itun: InningsTuning) -> int:
	var batting := attrs.power + attrs.composure
	var bowling := attrs.attack + attrs.control
	var share := float(bowling) / float(batting + bowling)
	var overs := roundi(itun.bowl_overs_gain * share + itun.bowl_overs_base)
	return clampi(overs, 0, itun.bowl_max_overs)

# The set of 1-based overs the Player bowls: n overs spaced as evenly as possible
# across total_overs. Returns [] for n <= 0.
static func player_bowling_overs(n: int, total_overs: int) -> Array[int]:
	var overs: Array[int] = []
	for i in range(n):
		overs.append(clampi(roundi((i + 0.5) * float(total_overs) / float(n)), 1, total_overs))
	return overs
```

- [ ] **Step 5: Run `--import` then the suite to verify green**

Run (single chained command, editor closed):
`/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: `All tests passed`, count **189** (184 + 5 new).

- [ ] **Step 6: Commit**

```bash
git add scripts/data/innings_tuning.gd scripts/data/innings_tuning.gd.uid scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid tests/unit/test_innings_resolver.gd
git commit -m "Player-as-bowler task 1: build->bowling-overs map (player_overs + over set)"
```

---

### Task 2: thread the Player bowler into `simulate_innings`

**Files:**
- Modify: `scripts/domain/innings_resolver.gd` (`simulate_innings` signature + ball loop)
- Test: `tests/unit/test_innings_resolver.gd`

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_innings_resolver.gd`:

```gdscript
func test_player_bowler_off_matches_baseline() -> void:
	# New trailing params default to off -> byte-identical to a call without them.
	var base := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, _make_rng(777))
	var off := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, _make_rng(777), 0, null, null, null, 0, 0, 0)
	assert_eq(base.total, off.total, "off-by-default total identical")
	assert_eq(base.wickets, off.wickets, "off-by-default wickets identical")
	assert_eq(base.balls, off.balls, "off-by-default balls identical")

func _avg_conceded(p_attack: int, p_control: int, n: int) -> float:
	# Opposition (null Player) batting at strength 5 vs a team bowling 5/5, where the
	# Player bowls 4 overs at (p_attack, p_control). Paired seeds across the two arms.
	var total := 0
	for seed_value in range(1, n + 1):
		total += InningsResolver.simulate_innings(
			null, 5, 5, 5, tuning, itun, _make_rng(seed_value),
			0, null, null, null, p_attack, p_control, 4).total
	return float(total) / n

func test_strong_player_bowler_concedes_fewer_runs() -> void:
	var weak := _avg_conceded(2, 2, 80)
	var strong := _avg_conceded(8, 8, 80)
	assert_lt(strong, weak, "a strong Player bowler concedes fewer runs than a weak one")

func test_innings_deterministic_with_player_bowler() -> void:
	var r1 := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, _make_rng(99), 0, null, null, null, 8, 8, 4)
	var r2 := InningsResolver.simulate_innings(null, 5, 5, 5, tuning, itun, _make_rng(99), 0, null, null, null, 8, 8, 4)
	assert_eq(r1.total, r2.total, "deterministic total")
	assert_eq(r1.wickets, r2.wickets, "deterministic wickets")
```

- [ ] **Step 2: Run the suite to verify red**

Expected: `Parse Error` / argument-count error on the 7-arg `simulate_innings` calls — file skipped, count stays 189.

- [ ] **Step 3: Extend `simulate_innings`**

In `scripts/domain/innings_resolver.gd`, add three trailing params to the signature (after `bowling_plan`):

```gdscript
		bowling_plan: BowlingPlan = null,
		player_bowler_attack: int = 0,
		player_bowler_control: int = 0,
		player_bowler_overs: int = 0
```

Just before the `while` loop (after `var fall: Array = []`), precompute the Player's over set:

```gdscript
	var player_overs_set: Array[int] = []
	if player_bowler_overs > 0:
		player_overs_set = player_bowling_overs(player_bowler_overs, itun.over_limit)
```

Inside the loop, immediately AFTER the `if bowling_attack != null and bowling_plan != null:` profile block (after `bat_control = prof.y`), add the Player-over override so it wins for those overs:

```gdscript
			if player_bowler_overs > 0 and player_overs_set.has(over):
				bat_attack = player_bowler_attack
				bat_control = player_bowler_control
```

- [ ] **Step 4: Run `--import` then the suite to verify green**

Run the `--import && suite` command. Expected: `All tests passed`, count **193** (189 + 4 new).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/innings_resolver.gd scripts/domain/innings_resolver.gd.uid tests/unit/test_innings_resolver.gd
git commit -m "Player-as-bowler task 2: thread Player bowler into simulate_innings"
```

---

### Task 3: wire the Player bowler into `simulate_match` (the lever goes live)

**Files:**
- Modify: `scripts/domain/match_resolver.gd` (`simulate_match` — compute quota, thread into the opposition innings)
- Test: `tests/unit/test_match_resolver.gd`

- [ ] **Step 1: Read the existing match-test helpers**

Open `tests/unit/test_match_resolver.gd` and note the `_attrs`, `_make_rng`, and any `simulate_match` wrapper helpers already defined (reuse them; do not redefine). If a `_make_rng(seed)` and `_attrs(p,c,a,co)` helper exist, use them in the tests below; otherwise add the same two helpers shown in Task 1/2.

- [ ] **Step 2: Write the failing tests**

Add to `tests/unit/test_match_resolver.gd` (using that file's existing `tuning`/`itun` members and helpers):

```gdscript
func _wins_over_matches(attrs: Attributes, n: int) -> int:
	# Even team strength (all 5s), Player bats first fixed, only the build varies.
	var wins := 0
	for seed_value in range(1, n + 1):
		var m := MatchResolver.simulate_match(
			attrs, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(seed_value))
		if m.outcome == MatchResult.Outcome.PLAYER_WIN:
			wins += 1
	return wins

func test_bowling_build_wins_more_than_batting_build() -> void:
	# The headline: with Player-as-bowler live, a bowling build's bowling now bites.
	# A pure-bowling build should out-win a pure-batting build over many even matches.
	var bowling_wins := _wins_over_matches(_attrs(2, 2, 8, 8), 120)
	var batting_wins := _wins_over_matches(_attrs(8, 8, 2, 2), 120)
	assert_gt(bowling_wins, batting_wins, "bowling build wins more than batting build at even strength")

func test_match_deterministic_with_player_bowler() -> void:
	var a := _attrs(2, 2, 8, 8)
	var m1 := MatchResolver.simulate_match(a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(31))
	var m2 := MatchResolver.simulate_match(a, 5, 5, 5, 5, 5, 5, true, tuning, itun, _make_rng(31))
	assert_eq(m1.outcome, m2.outcome, "deterministic outcome")
	assert_eq(m1.innings1.total, m2.innings1.total, "deterministic innings1")
	assert_eq(m1.innings2.total, m2.innings2.total, "deterministic innings2")
```

Note: `test_bowling_build_wins_more_than_batting_build` is the test that would have FAILED before this rung (bowling was inert) and passes after. If a paired-seed comparison is flaky at n=120, raise n; do not weaken the assertion.

- [ ] **Step 3: Run the suite to verify red**

Expected: `test_bowling_build_wins_more_than_batting_build` FAILS (bowling currently inert → roughly equal wins) — a real assertion failure, not a parse error, since `simulate_match` already exists. Count 193 with 1 failing.

- [ ] **Step 4: Thread the quota into `simulate_match`**

In `scripts/domain/match_resolver.gd`, inside `simulate_match`, after `var max_balls := itun.over_limit * 6`, compute the Player's bowling once:

```gdscript
	# The Player bowls a build-driven quota in the opposition's batting innings.
	var p_bowl_overs := 0
	if player_attrs != null:
		p_bowl_overs = InningsResolver.player_overs(player_attrs, itun)
	var p_bowl_attack := player_attrs.attack if player_attrs != null else 0
	var p_bowl_control := player_attrs.control if player_attrs != null else 0
```

Then pass `p_bowl_attack, p_bowl_control, p_bowl_overs` as the three new trailing args to the **opposition** innings call in BOTH branches (the call where the first arg is `null`):

In the `player_bats_first` branch, the `innings2` call becomes:
```gdscript
			innings2 = InningsResolver.simulate_innings(
				null, opp_batting, player_team_attack, player_team_control,
				tuning, itun, rng, innings1.total + 1, null, player_bowl, player_bowling_plan,
				p_bowl_attack, p_bowl_control, p_bowl_overs)
```

In the `else` branch, the `innings1` call becomes:
```gdscript
		innings1 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, 0, null, player_bowl, player_bowling_plan,
			p_bowl_attack, p_bowl_control, p_bowl_overs)
```

Leave the Player's OWN batting innings calls untouched (the Player doesn't bowl when their side bats).

- [ ] **Step 5: Run `--import` then the suite to verify green**

Run the `--import && suite` command. Expected: `All tests passed`, count **195** (193 + 2 new). If any pre-existing `test_match_resolver` snapshot test pins an absolute opposition total against the old (no-Player-bowler) baseline, update that expected value — the behaviour change is intentional (spec D1) — and note it in the commit message.

- [ ] **Step 6: Commit**

```bash
git add scripts/domain/match_resolver.gd scripts/domain/match_resolver.gd.uid tests/unit/test_match_resolver.gd
git commit -m "Player-as-bowler task 3: wire build-driven bowling into simulate_match"
```

---

### Task 4: re-run the skills sweep — show the lever moved

**Files:**
- Run: `tools/sweep_skills.gd` (no change needed — it already varies build + reports win-rate)
- Modify: `docs/mockups/distribution-viewer-v1.html` (refresh the embedded `DATA` + caption if the viewer inlines it) OR just capture the new figures
- Test: none (diagnostic rung deliverable)

- [ ] **Step 1: Run the sweep and capture win-rates**

Run (editor closed):
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_skills.gd`
Capture the JSON. Read each arm's `win_rate`. Expected (directional, not exact): the **Bowling build (2/2/8/8)** win-rate now sits **meaningfully above ~48%** (the 7c-1 inert reading), and ideally near or above the batting build — confirming Attack/Control now bite. Record the three win-rates (batting / balanced / bowling) before→after.

- [ ] **Step 2: Refresh the viewer data + caption (if it inlines DATA)**

If `docs/mockups/distribution-viewer-v1.html` embeds a `DATA`/`const` block from this sweep, replace it with the new JSON and update any caption that states the old "bowling build ~48%, inert lever" finding to the new "bowling build now wins X%" reading. If the viewer loads data dynamically, just update the caption text. Keep the change minimal and factual.

- [ ] **Step 3: Eyeball the viewer**

Open `docs/mockups/distribution-viewer-v1.html` in a browser (or via the project's static preview launch) and confirm the bowling-build curve/figure reflects the new win-rate. This is the "see the lever" deliverable (Nico learns by seeing).

- [ ] **Step 4: Commit**

```bash
git add docs/mockups/distribution-viewer-v1.html
git commit -m "Player-as-bowler task 4: skills sweep shows bowling build win-rate now bites"
```

---

## Self-review notes

- **Spec coverage:** §2 mechanic → Tasks 1–3; §3 code changes → Tasks 1–3 (tuning fields T1, helpers T1, `simulate_innings` T2, `simulate_match` T3); §5 testing → tests in every task; §6 deliverable → Task 4; §4 scope decisions are design-level (no task needed). D5 (no bowling stat line) and §7 deferrals correctly produce no tasks.
- **Type consistency:** `player_overs(attrs, itun)`, `player_bowling_overs(n, total_overs)`, and the three `player_bowler_*` params are named identically across Tasks 1–3. Tuning fields `bowl_max_overs` / `bowl_overs_gain` / `bowl_overs_base` match between `innings_tuning.gd` and `player_overs`.
- **Count math:** 184 → +5 (T1) = 189 → +4 (T2) = 193 → +2 (T3) = 195. Stated expected counts match.
- **Determinism:** no new RNG draws anywhere (the override only swaps `resolve_ball` inputs), so the off-by-default regression test (T2 Step 1) is the guarantee that existing seeds are preserved for batters.
