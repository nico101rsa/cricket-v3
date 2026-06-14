# E4 — Optimal career-line search · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure which climb×spend career line is optimal (fastest reliable beat) and whether any line dominates, via a 9-arm headless Monte-Carlo search.

**Architecture:** One new pure harness class `CareerPolicy` (3 climb strategies: `rush`/`farm`/`trophy`, mirroring `ShopPolicy`) + one oracle `tools/career_search.gd` that grids `CareerPolicy × ShopPolicy` and reports completion-rate + time-to-beat. No domain/sim code is touched — zero ledger ripple by construction (spec §7).

**Tech Stack:** Godot 4.6.3 / GDScript, GUT 9.6 for tests, headless `SceneTree` tool for the oracle.

**Spec:** `docs/superpowers/specs/2026-06-14-e4-career-line-search-design.md`

---

## Conventions (project CLAUDE.md — read before starting)

- GDScript indentation is **tabs**.
- After adding any new script under `scripts/`, run `--import` **once** before tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- Run the suite (no per-file filter — GUT runs the whole `tests/unit` dir): `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- Judge **red** by a `Parse Error: Identifier "X" not declared`; judge **green** by the total count climbing past **547** and `All tests passed`.
- Commit the `*.gd.uid` for new `scripts/` files; test files under `tests/` get no `.uid`.
- **Quit the Godot editor before any headless run.** ONE Godot process at a time.
- If a run suddenly can't load GUT, clean iCloud junk: `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot` then re-`--import`.

---

## File Structure

- **Create** `scripts/harness/career_policy.gd` — pure `CareerPolicy` class (climb strategies). Sibling of `scripts/harness/shop_policy.gd`.
- **Create** `tests/unit/test_career_policy.gd` — unit tests for the climb decisions.
- **Create** `tools/career_search.gd` — the 9-arm grid oracle (headless `SceneTree`).
- **Create** `docs/mockups/career-search-v1.html` — the 9-arm comparison viz (built from the oracle's `DATA` json).
- **Modify** `PROJECT_ROADMAP.md` + spec §10 — findings (during execution).

---

### Task 1: `CareerPolicy.choose_tour` (the tour-choice axis)

**Files:**
- Create: `scripts/harness/career_policy.gd`
- Test: `tests/unit/test_career_policy.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_career_policy.gd`:

```gdscript
extends GutTest

# E4 climb-strategy unit tests (spec 2026-06-14-e4-career-line-search-design.md §6).


func _fresh_club_state() -> CareerState:
	# Club, only Tour 0 unlocked — the start of a career.
	return CareerResolver.start_career(0)


func test_rush_choose_tour_is_lowest_unbeaten() -> void:
	var state := _fresh_club_state()
	# Only T0 unlocked → that is the lowest unbeaten unlocked tour.
	assert_eq(CareerPolicy.choose_tour("rush", state), 0)
	# Beat T0 → T1 unlocks; lowest unbeaten is now T1.
	state.record_outcome(0, 0, true, false)
	assert_eq(CareerPolicy.choose_tour("rush", state), 1)


func test_farm_choose_tour_is_highest_unlocked() -> void:
	var state := _fresh_club_state()
	state.record_outcome(0, 0, true, false)   # unlock T1
	state.record_outcome(0, 1, true, false)   # unlock T2
	# Highest unlocked tour is T2 (farm replays the richest cell).
	assert_eq(CareerPolicy.choose_tour("farm", state), 2)


func test_trophy_choose_tour_is_lowest_unbeaten() -> void:
	var state := _fresh_club_state()
	state.record_outcome(0, 0, true, false)
	# trophy climbs lowest-unbeaten just like rush (they differ on OFFERS).
	assert_eq(CareerPolicy.choose_tour("trophy", state), 1)


func test_choose_tour_all_beaten_replays_premier() -> void:
	var state := _fresh_club_state()
	for t in range(CareerState.TOURS):
		state.record_outcome(0, t, true, false)   # beat every tour, no final win
	# No unbeaten cell left → fall back to the Premier (T7) to chase the final.
	assert_eq(CareerPolicy.choose_tour("rush", state), CareerState.PREMIER_TOUR)
	assert_eq(CareerPolicy.choose_tour("trophy", state), CareerState.PREMIER_TOUR)
```

- [ ] **Step 2: Run to verify it fails**

Run the suite. Expected: `Parse Error: Identifier "CareerPolicy" not declared` (file skipped) — this is **red**.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/harness/career_policy.gd`:

```gdscript
class_name CareerPolicy
extends RefCounted

# Climb strategies for the headless career search (E4, spec
# 2026-06-14-e4-career-line-search-design.md). Pure, static — mirrors
# ShopPolicy. Owns the two climb decisions each Season: which tour to play and
# whether to accept an end-of-Season cross-up Offer. The search tool
# (tools/career_search.gd) grids these × ShopPolicy spend presets.
#
# Single-agent: careers aren't adversarial (the opponent brain is fixed per
# cell), so these are honest named strategies, not a self-play search.

const KINDS := ["rush", "farm", "trophy"]


# Which unlocked tour to play at the current Level this Season.
static func choose_tour(kind: String, state: CareerState) -> int:
	var cells := state.playable_cells()   # unlocked tours, ascending
	if kind == "farm":
		# Highest unlocked tour — climb to the richest cell, then replay it.
		return cells.back()
	# rush & trophy: lowest unbeaten unlocked tour; if all beaten, the Premier
	# (T7) — replay it to chase the final win still owed.
	var lvl := state.current_level()
	for t in cells:
		if state.status_of(lvl, t) != CareerState.CellStatus.BEATEN:
			return t
	return CareerState.PREMIER_TOUR
```

- [ ] **Step 4: Run `--import` then the suite to verify pass**

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: `All tests passed`, count climbed to **551** (547 + 4 new).

- [ ] **Step 5: Commit**

```bash
git add scripts/harness/career_policy.gd scripts/harness/career_policy.gd.uid tests/unit/test_career_policy.gd
git commit -m "E4: CareerPolicy.choose_tour (rush/farm/trophy climb axis)"
```

---

### Task 2: `CareerPolicy.choose_offer` (the chase-up-vs-stay axis)

**Files:**
- Modify: `scripts/harness/career_policy.gd`
- Test: `tests/unit/test_career_policy.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_career_policy.gd`:

```gdscript
# A state crossed up to City (Level 1) with a single cross-up Offer back-down
# would never be generated for these poles; build a minimal Club state plus a
# fake higher-Level Offer to exercise choose_offer directly.
func _club_with_cross_offer() -> Array:
	var state := CareerResolver.start_career(0)
	# Pretend Club gate beaten so a City cross-up is legal.
	state.record_outcome(0, CareerState.LEAGUE_GATE_TOUR, true, false)
	var up := Offer.new()
	up.team_index = CareerState.TEAMS_PER_LEVEL   # first City slot
	up.level = 1
	up.stars = 3.0
	return [state, up]


func test_rush_offer_accepts_cross_up_immediately() -> void:
	var pair := _club_with_cross_offer()
	var state: CareerState = pair[0]
	var up: Offer = pair[1]
	var player := _fresh_player()
	# rush crosses the moment a higher Level is offered, even without level_won.
	var chosen: Offer = CareerPolicy.choose_offer("rush", state, [up], player)
	assert_eq(chosen, up)


func test_rush_offer_stays_when_no_higher_offer() -> void:
	var state := CareerResolver.start_career(0)
	var player := _fresh_player()
	assert_null(CareerPolicy.choose_offer("rush", state, [], player))


func test_farm_offer_stays_until_card_maxed() -> void:
	var pair := _club_with_cross_offer()
	var state: CareerState = pair[0]
	var up: Offer = pair[1]
	var player := _fresh_player()
	# Under-built card → farm stays.
	assert_null(CareerPolicy.choose_offer("farm", state, [up], player))
	# Max the card → farm now crosses.
	for a in ["power", "composure", "attack", "control"]:
		player.attributes.set(a, ShopResolver.ATTR_CAP)
	assert_eq(CareerPolicy.choose_offer("farm", state, [up], player), up)


func test_trophy_offer_stays_until_level_won() -> void:
	var pair := _club_with_cross_offer()
	var state: CareerState = pair[0]
	var up: Offer = pair[1]
	var player := _fresh_player()
	# Club Premier not yet won → trophy stays.
	assert_null(CareerPolicy.choose_offer("trophy", state, [up], player))
	# Win Club's Premier final → trophy crosses.
	state.level_won[0] = true
	assert_eq(CareerPolicy.choose_offer("trophy", state, [up], player), up)


func test_no_pole_accepts_a_down_offer() -> void:
	# A down Offer (lower Level) is never accepted by any pole.
	var state := CareerResolver.start_career(0)
	state.current_team_index = CareerState.TEAMS_PER_LEVEL   # sit in City (Level 1)
	var down := Offer.new()
	down.team_index = 0
	down.level = 0
	down.stars = 1.5
	var player := _fresh_player()
	player.attributes.power = ShopResolver.ATTR_CAP
	player.attributes.composure = ShopResolver.ATTR_CAP
	player.attributes.attack = ShopResolver.ATTR_CAP
	player.attributes.control = ShopResolver.ATTR_CAP
	state.level_won[1] = true
	for kind in CareerPolicy.KINDS:
		assert_null(CareerPolicy.choose_offer(kind, state, [down], player))


func _fresh_player() -> Player:
	var p := Player.new()
	var a := Attributes.new()
	a.power = 11.0
	a.composure = 11.0
	a.attack = 11.0
	a.control = 11.0
	p.attributes = a
	return p
```

- [ ] **Step 2: Run to verify it fails**

Run the suite. Expected: `Parse Error: Identifier "choose_offer" not declared` on the test file (the `class_name` already parses, but the new method is missing) — **red**.

- [ ] **Step 3: Write minimal implementation**

Append to `scripts/harness/career_policy.gd`:

```gdscript
# Accept one end-of-Season cross-up Offer, or stay (null). Never moves DOWN:
# the three poles only ever cross up or stay (the DC16 down-Offer exists for
# softlock recovery the naive line never triggers — E4-5).
static func choose_offer(kind: String, state: CareerState, offers: Array, player: Player) -> Offer:
	if not _wants_to_cross(kind, state, player):
		return null
	var lvl := state.current_level()
	for o in offers:
		if o.level > lvl:
			return o
	return null


# Whether this pole wants to leave the current Level now.
static func _wants_to_cross(kind: String, state: CareerState, player: Player) -> bool:
	match kind:
		"rush":
			return true                                # cross the instant offered
		"farm":
			return _card_maxed(player)                 # build the full card first
		"trophy":
			return state.level_won[state.current_level()]  # win the trophy first
	return false


static func _card_maxed(player: Player) -> bool:
	var a := player.attributes
	return a.power >= ShopResolver.ATTR_CAP \
		and a.composure >= ShopResolver.ATTR_CAP \
		and a.attack >= ShopResolver.ATTR_CAP \
		and a.control >= ShopResolver.ATTR_CAP
```

- [ ] **Step 4: Run the suite to verify pass**

Run the suite (no new script files, so no `--import` needed — but harmless to run it). Expected: `All tests passed`, count **557** (551 + 6 new).

- [ ] **Step 5: Commit**

```bash
git add scripts/harness/career_policy.gd tests/unit/test_career_policy.gd
git commit -m "E4: CareerPolicy.choose_offer (chase-up vs stay per pole)"
```

---

### Task 3: `tools/career_search.gd` (the 9-arm grid oracle)

**Files:**
- Create: `tools/career_search.gd`

This is an oracle (headless tool), not under unit test — consistent with `career_preview.gd` / `sweep_*.gd`. It is validated by a QUICK smoke run in Task 4.

- [ ] **Step 1: Write the oracle**

Create `tools/career_search.gd`:

```gdscript
extends SceneTree

# E4 optimal career-line search (spec 2026-06-14-e4-career-line-search-design.md).
# Grids 3 climb (CareerPolicy) × 3 spend (ShopPolicy) = 9 arms, N careers each,
# reporting completion-rate + time-to-beat (seasons / matches / hours) +
# card-max season + end bank, then the optimal arm and a dominance verdict.
# Single-agent: careers aren't adversarial (opponent brain fixed per cell), so
# this is an optimization over named strategies, not a self-play search.
#
# Run (full ~30 min, detached — over the 10-min Bash cap):
#   nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
#     -s tools/career_search.gd > /tmp/e4.log 2>&1 &
# Smoke: CAREER_QUICK=1 (N=10). N=<int> overrides. CLIMB=<kind>/SPEND=<kind>
#        restrict to a single arm.

const SEASON_CAP := 120
const MATCH_MINUTES := 2.75   # 2:45 per match — the roadmap time-to-beat unit


func _median(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s := arr.duplicate()
	s.sort()
	var m := int(s.size() / 2)
	if s.size() % 2 == 1:
		return float(s[m])
	return (float(s[m - 1]) + float(s[m])) / 2.0


func _fresh_player() -> Player:
	var p := Player.new()
	var a := Attributes.new()
	a.power = 11.0       # world-scale v2: fresh hero ≈ a weak Club player
	a.composure = 11.0
	a.attack = 11.0
	a.control = 11.0
	p.attributes = a
	return p


func _card_maxed_season(player: Player, state: CareerState, current: int) -> int:
	# Returns current if all 4 attrs just hit the cap and we have not recorded
	# it yet (caller passes the running value in `current`, 0 = not yet).
	if current != 0:
		return current
	var a := player.attributes
	if a.power >= ShopResolver.ATTR_CAP and a.composure >= ShopResolver.ATTR_CAP \
			and a.attack >= ShopResolver.ATTR_CAP and a.control >= ShopResolver.ATTR_CAP:
		return state.seasons_played
	return 0


func _run_arm(climb: String, spend: String, n: int,
		tuning: BallTuning, itun: InningsTuning, etun: EconomyTuning) -> Dictionary:
	var shop_policy := ShopPolicy.preset(spend)
	var completed_seasons: Array = []
	var completed_matches: Array = []
	var maxed: Array = []
	var end_banks: Array = []
	var completes := 0
	for c in range(n):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + c
		var player := _fresh_player()
		var state := CareerResolver.start_career(0)
		var plans := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, rng)
		var matches := 0
		var maxed_season := 0
		while not state.complete and state.seasons_played < SEASON_CAP:
			var tour := CareerPolicy.choose_tour(climb, state)
			var out := CareerResolver.play_season(
				state, player, tour, tuning, itun, etun, rng, plans[0], plans[1], shop_policy)
			matches += 7 + (2 if out["season"].league.made_playoffs else 0)
			maxed_season = _card_maxed_season(player, state, maxed_season)
			if state.complete:
				break
			var off: Offer = CareerPolicy.choose_offer(climb, state, out["offers"], player)
			if off != null:
				CareerResolver.accept_offer(state, player, off)
			else:
				CareerResolver.stay(state, player)
		maxed.append(maxed_season)
		end_banks.append(player.tons_balance)
		if state.complete:
			completes += 1
			completed_seasons.append(state.seasons_played)
			completed_matches.append(matches)
	var med_matches := _median(completed_matches)
	var maxed_nonzero := maxed.filter(func(x): return x > 0)
	return {
		"climb": climb,
		"spend": spend,
		"n": n,
		"completed": completes,
		"completion_pct": snappedf(100.0 * completes / n, 0.1),
		"median_seasons": snappedf(_median(completed_seasons), 0.5),
		"median_matches": int(round(med_matches)),
		"median_hours": snappedf(med_matches * MATCH_MINUTES / 60.0, 0.1),
		"median_maxed_season": snappedf(_median(maxed_nonzero), 0.5),
		"median_end_bank": int(round(_median(end_banks))),
	}


func _init() -> void:
	var quick := OS.get_environment("CAREER_QUICK") == "1"
	var n := 10 if quick else 60
	if OS.get_environment("N") != "":
		n = int(OS.get_environment("N"))
	var climbs: Array = CareerPolicy.KINDS.duplicate()
	var spends: Array = ShopPolicy.KINDS.duplicate()
	if OS.get_environment("CLIMB") != "":
		climbs = [OS.get_environment("CLIMB")]
	if OS.get_environment("SPEND") != "":
		spends = [OS.get_environment("SPEND")]

	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var etun := EconomyTuning.new()

	var arms: Array = []
	for climb in climbs:
		for spend in spends:
			var arm := _run_arm(climb, spend, n, tuning, itun, etun)
			arms.append(arm)
			print("arm %s x %s: %d/%d complete (%.1f%%), median %s seasons / %d matches / %.1fh, maxed S%s, bank %d" % [
				climb, spend, arm["completed"], n, arm["completion_pct"],
				str(arm["median_seasons"]), arm["median_matches"], arm["median_hours"],
				str(arm["median_maxed_season"]), arm["median_end_bank"]])

	# Optimal = fastest (fewest matches) among arms within 5 pts of the best
	# completion rate AND with at least one completion (E4-4).
	var best_completion := 0.0
	for arm in arms:
		best_completion = max(best_completion, arm["completion_pct"])
	var eligible: Array = arms.filter(func(x):
		return x["completed"] > 0 and x["completion_pct"] >= best_completion - 5.0)
	eligible.sort_custom(func(x, y): return x["median_matches"] < y["median_matches"])
	var optimal: Dictionary = eligible[0] if not eligible.is_empty() else {}

	# Dominant = strictly best on BOTH axes by a clear margin: highest completion
	# (>= 2nd-best + 3 pts) AND fewest matches (<= 2nd-fewest * 0.9).
	var by_completion: Array = arms.duplicate()
	by_completion.sort_custom(func(x, y): return x["completion_pct"] > y["completion_pct"])
	var by_speed: Array = eligible.duplicate()   # only completing arms have meaningful speed
	var dominant := false
	if by_completion.size() >= 2 and by_speed.size() >= 2:
		var top_c: Dictionary = by_completion[0]
		var top_s: Dictionary = by_speed[0]
		var same_arm: bool = top_c["climb"] == top_s["climb"] and top_c["spend"] == top_s["spend"]
		var c_margin: bool = top_c["completion_pct"] >= by_completion[1]["completion_pct"] + 3.0
		var s_margin: bool = top_s["median_matches"] <= by_speed[1]["median_matches"] * 0.9
		dominant = same_arm and c_margin and s_margin

	var data := {
		"n": n,
		"season_cap": SEASON_CAP,
		"arms": arms,
		"optimal": optimal,
		"dominant": dominant,
	}
	print("OPTIMAL ", "%s x %s" % [optimal.get("climb", "?"), optimal.get("spend", "?")],
		" dominant=", dominant)
	print("DATA ", JSON.stringify(data))
	quit()
```

- [ ] **Step 2: Commit**

```bash
git add tools/career_search.gd tools/career_search.gd.uid
git commit -m "E4: career_search oracle (9-arm climb x spend grid)"
```

(Note: `tools/` scripts DO generate a `.uid` — commit it. If the `.uid` was not generated yet, run `--import` once first.)

---

### Task 4: Smoke-validate, then run the full grid

**Files:** none (produces `/tmp/e4.log`).

- [ ] **Step 1: Quit the Godot editor** (⌘Q) — ONE Godot process at a time.

- [ ] **Step 2: QUICK smoke run** (validates the oracle end-to-end, ~3 min)

```
CAREER_QUICK=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/career_search.gd
```

Expected: 9 `arm … complete` lines, an `OPTIMAL …` line, and a `DATA {…}` json. Sanity-check: every arm prints, `trophy × *` completion is in the ballpark of `career_preview`'s naive numbers (attr_only ≈ 65% at N=100; at N=10 expect noise but non-zero).

- [ ] **Step 3: Full detached run** (~30 min, over the 10-min Bash cap → nohup)

```
nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/career_search.gd > /tmp/e4.log 2>&1 &
```

- [ ] **Step 4: Arm a log-grep watcher** (NOT pgrep — it self-matches; CLAUDE.md hazard). Poll until the final `DATA` line appears or Godot exits:

```bash
until grep -q "^DATA " /tmp/e4.log 2>/dev/null; do sleep 20; done; echo "E4 DONE"; tail -15 /tmp/e4.log
```

- [ ] **Step 5: Capture the `DATA` json** from `/tmp/e4.log` for the viz (Task 5) and the findings (Task 6).

---

### Task 5: `docs/mockups/career-search-v1.html` (the 9-arm comparison viz)

**Files:**
- Create: `docs/mockups/career-search-v1.html`

- [ ] **Step 1: Build the viz** from the captured `DATA` json. A single self-contained HTML page (match the style of `docs/mockups/career-loop-v1.html` — open it first to mirror the palette/layout). Requirements (stat-provenance + learn-by-seeing memories):
  - A 3×3 grid (rows = climb `rush`/`farm`/`trophy`, cols = spend `attr_only`/`joker_only`/`balanced`), each cell showing **completion %** (with `k/N` count) and **time-to-beat** (median hours + seasons).
  - The **optimal** cell highlighted, with a one-line plain-English caption ("Fastest reliable line: `<climb> + <spend>` — beats the game in ~Xh, completes Y/N careers").
  - A **dominance verdict** banner: either "No dominant line — the player faces a real trade-off (healthy, ADR-0003)" or "⚠ Dominant line found: `<arm>` wins on both completion and speed — solved-meta risk."
  - Plain descriptive labels, N visible on every number. Embed the raw `DATA` json in a `<script>` block so the page is reproducible.

- [ ] **Step 2: Eyeball** the page in a browser (open the file) — confirm all 9 cells render, the optimal highlight and verdict read correctly.

- [ ] **Step 3: Commit**

```bash
git add docs/mockups/career-search-v1.html
git commit -m "E4: career-search 9-arm comparison viz"
```

---

### Task 6: Findings + roadmap + PR

**Files:**
- Modify: `docs/superpowers/specs/2026-06-14-e4-career-line-search-design.md` (§10)
- Modify: `PROJECT_ROADMAP.md`

- [ ] **Step 1: Fill spec §10** with the measured optimal line, dominance verdict, optimal time-to-beat (seasons / matches / hours), the **number the pacing re-peg should target**, the viz path, and the final test count. State the ledger is **untouched (not re-run)** per §7.

- [ ] **Step 2: Update `PROJECT_ROADMAP.md`** — move E4 into the "Prior" prose chain (one dense entry), refresh the **"Next session"** handoff block: state (branch merged, test count), the next recommended rung, and surface the **pacing re-peg** decision now armed with E4's number.

- [ ] **Step 3: Final full-suite green check**

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

Expected: `All tests passed`, count **557**.

- [ ] **Step 4: Commit, push, open + merge PR** (global commit policy — auto-merge completed verified work)

```bash
git add -A && git commit -m "E4: findings + roadmap handoff"
git push -u origin e4-career-line-search
gh pr create --title "E4: optimal career-line search" --body "<summary>" --base main
gh pr merge --merge --delete-branch
git checkout main && git pull
```

---

## Self-Review

- **Spec coverage:** §2 metrics → Task 3 `_run_arm` (completion/seasons/matches/hours/maxed/bank). §3.1 CareerPolicy → Tasks 1–2. §3.3 grid + §4 oracle → Task 3. §5 deliverables → Tasks 5–6. §6 tests → Tasks 1–2. §7 zero-ripple → asserted in Task 6 §10. §8 decisions are all reflected (E4-2 single-agent in oracle header; E4-4 optimal rule in `_init`; E4-5 no-down-offer in Task 2 + test). ✓
- **Type consistency:** `CareerPolicy.choose_tour(kind, state)` / `choose_offer(kind, state, offers, player)` / `KINDS` used identically across tasks. `ShopResolver.ATTR_CAP`, `CareerState.PREMIER_TOUR`/`LEAGUE_GATE_TOUR`/`TOURS`/`TEAMS_PER_LEVEL`/`CellStatus.BEATEN`, `Offer.level/team_index/stars`, `out["season"].league.made_playoffs`, `player.tons_balance` — all match the source read during planning. ✓
- **Placeholder scan:** no TBD/TODO in code steps; the viz body (Task 5) is spec'd by requirement list, not boilerplate, because its exact numbers come from the run. ✓
- **Test count arithmetic:** 547 → +4 (Task 1) = 551 → +6 (Task 2) = 557. ✓
```
