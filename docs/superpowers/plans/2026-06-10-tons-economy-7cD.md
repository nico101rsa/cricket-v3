# ₸ Economy (rung 7c-D) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the V1 ₸ economy: a tested `Economy.match_pay()` income function, measured ₸ prices for all 45 jokers in `JokerCatalog`, an attribute-upgrade cost curve, the 4-slot loadout cap as a dial, and a `sweep_economy.gd` oracle that verifies income fairness and skills-vs-jokers ROI.

**Architecture:** Pure static calculators (`Economy`) + a dials resource (`EconomyTuning`), mirroring the existing `RatingTuning`/`PlayerRating` pattern. Prices are a `const` dictionary in `JokerCatalog`, computed once from a fresh `sweep_jokers.gd` run via the spec §5.3 within-band interpolation rule. A new harness tool measures ₸/match per build and marginal Δwin% per +1 attribute.

**Tech Stack:** Godot 4.6.3 GDScript (tabs), GUT 9.6 (`tests/unit/`), harness `Sweep`/`Distribution`.

**Spec:** `docs/superpowers/specs/2026-06-10-tons-economy-7cD-design.md` (decisions DE1–DE10).

**Conventions reminders (project CLAUDE.md):** quit the Godot editor before headless runs (`pgrep -x Godot` must be empty); after adding new scripts run `--import` once; full suite is the only reliable run (`-gtest` does not filter); judge red by parse-error/failing-assert, green by count climbing past **366** + `All tests passed`; commit `*.gd.uid` for `scripts/` + `tools/` files but NOT `tests/`; clean iCloud `" 2"` conflict files if GUT suddenly breaks.

Test command:
```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
Import command (after each task that adds a new script):
```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
```

---

## File structure

- Create: `scripts/data/economy_tuning.gd` — the dials resource (one responsibility: economy constants).
- Create: `scripts/domain/economy.gd` — pure ₸ calculators (`match_pay`, `attr_upgrade_cost`, `sell_refund`).
- Modify: `scripts/data/joker_catalog.gd` — add `PRICE_BANDS`, `DELTA_BANDS`, `PRICES`, `price()`, `price_band()` (data lives beside the jokers it prices).
- Create: `tools/sweep_economy.gd` — the economy oracle (income per build + marginal attribute value).
- Create: `docs/mockups/economy-v1.html` — the eyeball viz.
- Create: `tests/unit/test_economy.gd` — unit tests for the calculators.
- Modify: `tests/unit/test_joker_catalog.gd` — price assertions.
- Modify: `docs/joker-pool-v1.md` (₸ column + header note), spec §10, `PROJECT_ROADMAP.md`.

---

### Task 1: `EconomyTuning` + `Economy` calculators (TDD)

**Files:**
- Create: `scripts/data/economy_tuning.gd`
- Create: `scripts/domain/economy.gd`
- Test: `tests/unit/test_economy.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_economy.gd` (tabs!):

```gdscript
extends GutTest

# Rung 7c-D (spec 2026-06-10-tons-economy-7cD §5.2/§7): pure ₸ calculators.

var _etun: EconomyTuning


func before_each() -> void:
	_etun = EconomyTuning.new()


# A MatchResult where the Player batted in innings `bat_first ? 1 : 2` scoring
# `runs`, and bowled in the other innings taking `wkts`.
func _result(runs: int, wkts: int, bat_first: bool = true) -> MatchResult:
	var player_batters := [{"position": 3, "is_player": true, "runs": runs, "balls": maxi(runs, 1), "out": false}]
	var opp_batters := [{"position": 1, "is_player": false, "runs": 30, "balls": 25, "out": true}]
	var player_inn := InningsResult.new(150, 4, 120, [], player_batters)
	var opp_inn := InningsResult.new(140, 6, 120, [], opp_batters, wkts, 24, 24)
	var m := MatchResult.new()
	m.player_bats_first = bat_first
	m.innings1 = player_inn if bat_first else opp_inn
	m.innings2 = opp_inn if bat_first else player_inn
	m.outcome = MatchResult.Outcome.PLAYER_WIN
	return m


func test_base_pay_at_star3_is_the_base_dial() -> void:
	var pay := Economy.match_pay(_result(0, 0), 3.0, _etun)
	assert_eq(pay["base"], int(round(_etun.base_pay)))


func test_stronger_team_pays_less_base() -> void:
	var weak := Economy.match_pay(_result(0, 0), 1.0, _etun)["base"]
	var even := Economy.match_pay(_result(0, 0), 3.0, _etun)["base"]
	var strong := Economy.match_pay(_result(0, 0), 5.0, _etun)["base"]
	assert_gt(weak, even)
	assert_gt(even, strong)


func test_base_pay_floors_at_minimum() -> void:
	_etun.star_pay_slope = 30.0  # ★5 would be 50 - 60 = -10 without the floor
	var pay := Economy.match_pay(_result(0, 0), 5.0, _etun)
	assert_eq(pay["base"], Economy.MIN_BASE_PAY)


func test_perf_pays_runs_and_wickets_monotonically() -> void:
	var quiet := Economy.match_pay(_result(10, 0), 3.0, _etun)["perf"]
	var batted := Economy.match_pay(_result(50, 0), 3.0, _etun)["perf"]
	var starred := Economy.match_pay(_result(50, 3), 3.0, _etun)["perf"]
	assert_gt(batted, quiet)
	assert_gt(starred, batted)


func test_breakdown_sums_to_total() -> void:
	var pay := Economy.match_pay(_result(42, 2), 3.0, _etun)
	assert_eq(pay["total"], pay["base"] + pay["perf"])


func test_zero_performance_still_pays_base() -> void:
	var pay := Economy.match_pay(_result(0, 0), 3.0, _etun)
	assert_eq(pay["perf"], 0)
	assert_gt(pay["total"], 0)


func test_pay_reads_player_innings_when_batting_second() -> void:
	var first := Economy.match_pay(_result(42, 2, true), 3.0, _etun)
	var second := Economy.match_pay(_result(42, 2, false), 3.0, _etun)
	assert_eq(first["perf"], second["perf"])


func test_attr_upgrade_cost_scales_with_current_value() -> void:
	var low := Economy.attr_upgrade_cost(2, _etun)
	var high := Economy.attr_upgrade_cost(7, _etun)
	assert_gt(high, low)
	assert_eq(low, int(round(_etun.attr_cost_base * 2)))


func test_sell_refund_is_floored_fraction() -> void:
	assert_eq(Economy.sell_refund(45, _etun), int(floor(45 * _etun.sell_refund_frac)))
	assert_eq(Economy.sell_refund(0, _etun), 0)


func test_loadout_cap_dial_is_four() -> void:
	assert_eq(_etun.loadout_cap, 4)
```

- [ ] **Step 2: Run the suite to verify red**

Run the test command. Expected: `SCRIPT ERROR: Parse Error: Identifier "EconomyTuning" not declared` (GUT logs it and skips the file) — that parse error IS red here, per project conventions. Total stays 366.

- [ ] **Step 3: Implement the two classes**

Create `scripts/data/economy_tuning.gd`:

```gdscript
class_name EconomyTuning
extends Resource

# Dials for the V1 ₸ economy (spec 2026-06-10-tons-economy-7cD §5.1, DE2/DE3/
# DE7/DE8/DE9). All @export so the balance harness can sweep them. runs_rate /
# wicket_rate are tuned by tools/sweep_economy.gd for ±15% build pay-fairness;
# finals recorded in spec §10.

@export var base_pay: float = 50.0        # base contract ₸ per match at ★3 ("base 50 + perf 18")
@export var star_pay_slope: float = 8.0   # ₸ less per ★ above 3 — stronger Teams pay less (CONTEXT §Tons)
@export var runs_rate: float = 0.5        # perf ₸ per run scored
@export var wicket_rate: float = 11.0     # perf ₸ per wicket taken
@export var attr_cost_base: float = 12.0  # +1 attribute costs attr_cost_base × current value (DE7)
@export var sell_refund_frac: float = 0.5 # partial refund selling a joker back (DE9)
@export var loadout_cap: int = 4          # max active joker slots (CONTEXT.md 4 slots; DE8)
```

Create `scripts/domain/economy.gd`:

```gdscript
class_name Economy
extends RefCounted

# Pure ₸ calculators (spec 2026-06-10-tons-economy-7cD §5.2). No state, no RNG —
# the Shop screen and the harness both call these. KMs are not in the sim yet,
# so perf pay reads runs + wickets only (DE3).

const MIN_BASE_PAY := 10


# ₸ earned by one match: Team base (stronger Teams pay less) + performance
# bonus. Returns the breakdown because the Result screen displays it
# ("base 50 + perf 18 = 68 ₸").
static func match_pay(result: MatchResult, team_stars: float, tuning: EconomyTuning) -> Dictionary:
	var base := int(round(tuning.base_pay - tuning.star_pay_slope * (team_stars - 3.0)))
	base = maxi(base, MIN_BASE_PAY)
	# The Player bats in their team's innings and bowls in the other one.
	var bat_inn := result.innings1
	var bowl_inn := result.innings2
	if result.innings1.player_line().is_empty():
		bat_inn = result.innings2
		bowl_inn = result.innings1
	var line := bat_inn.player_line()
	var perf := int(round(tuning.runs_rate * int(line.get("runs", 0))
		+ tuning.wicket_rate * bowl_inn.player_bowl_wickets))
	return {"base": base, "perf": perf, "total": base + perf}


static func attr_upgrade_cost(current_value: int, tuning: EconomyTuning) -> int:
	return int(round(tuning.attr_cost_base * current_value))


static func sell_refund(price: int, tuning: EconomyTuning) -> int:
	return int(floor(price * tuning.sell_refund_frac))
```

- [ ] **Step 4: Import, then run the suite to verify green**

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
Expected: count climbs 366 → 377, `All tests passed`.

- [ ] **Step 5: Commit**

```sh
git add scripts/data/economy_tuning.gd scripts/data/economy_tuning.gd.uid scripts/domain/economy.gd scripts/domain/economy.gd.uid tests/unit/test_economy.gd
git commit -m "Economy rung 7c-D Task 1: EconomyTuning dials + pure Economy calculators (match_pay, attr cost, sell refund)"
```
(If a `.uid` didn't generate, re-run `--import`; test files never get one.)

---

### Task 2: Fresh joker deltas + measured prices in `JokerCatalog` (TDD)

**Files:**
- Modify: `scripts/data/joker_catalog.gd` (append constants + two functions at the end, before `_g`)
- Test: `tests/unit/test_joker_catalog.gd` (append tests)

- [ ] **Step 1: Run the joker sweep for fresh deltas (backgrounded, ~60–80s)**

Verify no editor: `pgrep -x Godot` → empty. Then:
```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_jokers.gd > /tmp/joker_sweep_7cD.txt 2>&1
```
The output ends with a JSON blob: `"arms"` (standard profile — toss live) + `"chase_arms"`. **The standard-profile `win_delta` per single-joker arm is the realized strength** (conditional jokers fire at their natural rate under the toss), so it is the pricing input directly.

- [ ] **Step 2: Write the failing tests**

Append to `tests/unit/test_joker_catalog.gd`:

```gdscript
func test_every_joker_has_a_price_in_its_rarity_band() -> void:
	for g in JokerCatalog.implemented_groups():
		var id: String = g["id"]
		var band: Vector2i = JokerCatalog.price_band(g["rarity"])
		assert_true(JokerCatalog.PRICES.has(id), "%s has no price" % id)
		var p: int = JokerCatalog.price(id)
		assert_between(p, band.x, band.y, "%s priced ₸%d outside band %s" % [id, p, str(band)])
		assert_eq(p % 5, 0, "%s price ₸%d not a multiple of 5" % [id, p])


func test_price_count_matches_pool() -> void:
	assert_eq(JokerCatalog.PRICES.size(), JokerCatalog.implemented_groups().size())


func test_price_bands_match_pool_doc() -> void:
	assert_eq(JokerCatalog.price_band("Common"), Vector2i(30, 50))
	assert_eq(JokerCatalog.price_band("Rare"), Vector2i(90, 120))
	assert_eq(JokerCatalog.price_band("Legendary"), Vector2i(220, 250))
```

Run the suite. Expected: failing asserts / parse error on `PRICES` — red.

- [ ] **Step 3: Compute the 45 prices and implement**

For each single-joker arm in the standard-profile JSON, apply spec §5.3 (delta bands Common 1–4 / Rare 4–7 / Legendary 7–12; price bands per below):

```
frac  = clamp((win_delta − delta_lo) / (delta_hi − delta_lo), 0, 1)
price = round_to_5(price_lo + frac × (price_hi − price_lo))
```

The clamp handles enablers and under-band conditionals automatically (they fall to the band floor — the fire-rate discount expressed within the band). Cross-check The Chase Master: its standard delta should be ≈ chase-profile delta × ~0.5 (the realized number, ~+6.6%).

Append to `scripts/data/joker_catalog.gd` (above `_g`, matching file style):

```gdscript
# --- ₸ prices (rung 7c-D, spec 2026-06-10-tons-economy-7cD §5.3) ---
# Within-band linear interpolation of each joker's REALIZED win-delta (the
# standard-profile sweep of 2026-06-10 — the toss/conditions fire naturally, so
# the measured delta is already fire-rate-discounted) onto its rarity price
# band, rounded to ₸5. Code is the source of truth; docs/joker-pool-v1.md
# mirrors these numbers. Re-derive by re-running tools/sweep_jokers.gd.

const PRICE_BANDS := {"Common": Vector2i(30, 50), "Rare": Vector2i(90, 120), "Legendary": Vector2i(220, 250)}
const DELTA_BANDS := {"Common": Vector2(1.0, 4.0), "Rare": Vector2(4.0, 7.0), "Legendary": Vector2(7.0, 12.0)}

const PRICES := {
	# (45 entries, id: ₸int — COMPUTED AT BUILD from /tmp/joker_sweep_7cD.txt
	# via the formula above; e.g. "dead_bat": 40, "the_chase_master": 220, ...)
}


static func price(id: String) -> int:
	return PRICES[id]


static func price_band(rarity: String) -> Vector2i:
	return PRICE_BANDS[rarity]
```

(The `PRICES` literal is filled with the 45 computed numbers — it is measured data, not authorable in this plan. Every other line above is exact.)

- [ ] **Step 4: Run the suite to verify green**

Expected: 377 → 380, `All tests passed`.

- [ ] **Step 5: Commit**

```sh
git add scripts/data/joker_catalog.gd tests/unit/test_joker_catalog.gd
git commit -m "Economy rung 7c-D Task 2: measured ₸ prices for all 45 jokers (within-band interpolation of realized win-delta)"
```

---

### Task 3: Mirror prices into the pool doc

**Files:**
- Modify: `docs/joker-pool-v1.md`

- [ ] **Step 1: Fill the ₸ column** of all six archetype tables with the exact `PRICES` numbers from Task 2.

- [ ] **Step 2: Update the header + open-questions note.** Add to the header block:

```markdown
> **₸ prices set (2026-06-10, rung 7c-D).** Tons inflow is now defined (`Economy.match_pay`: base 50 at ★3 ± 8/★, + perf ₸/run + ₸/wicket — see spec `2026-06-10-tons-economy-7cD-design.md`), and every joker is priced by within-band interpolation of its realized (fire-rate-discounted) win-delta onto the rarity price band. Prices live in `JokerCatalog.PRICES` (code is source of truth); this doc mirrors them.
```

And replace open-tuning-question #5 ("Price bands are V1 strawman…") with a line noting prices are now harness-derived (rung 7c-D) and rescale via `EconomyTuning`.

- [ ] **Step 3: Commit**

```sh
git add docs/joker-pool-v1.md
git commit -m "Economy rung 7c-D Task 3: pool doc mirrors the 45 measured ₸ prices"
```

---

### Task 4: The economy oracle (`tools/sweep_economy.gd`) + dial tune

**Files:**
- Create: `tools/sweep_economy.gd`

- [ ] **Step 1: Write the tool** (modeled on `tools/build_spectrum_sweep.gd`):

```gdscript
extends SceneTree

# Economy oracle (rung 7c-D, spec §5.4). Two questions:
#   1. ₸ income per match for the three canonical builds (pay-fairness ±15%).
#   2. Marginal Δwin% of +1 attribute around the balanced build (skills-vs-
#      jokers ROI input).
# Both teams even ★3, N matches/arm, paired seeds via Sweep. Not a unit test.
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_economy.gd

var _tuning: BallTuning
var _itun: InningsTuning
var _tour: TourDistribution
var _etun: EconomyTuning

func _init() -> void:
	_tuning = BallTuning.new()
	_itun = InningsTuning.new()
	_tour = TourDistribution.new()
	_tour.mean = 5
	_tour.spread = 1.5
	_tour.noise = 1
	_etun = EconomyTuning.new()

	var arms: Array = [
		{"name": "batter 8/8/2/2", "config": {"power": 8, "composure": 8, "attack": 2, "control": 2}},
		{"name": "balanced 5/5/5/5", "config": {"power": 5, "composure": 5, "attack": 5, "control": 5}},
		{"name": "bowler 2/2/8/8", "config": {"power": 2, "composure": 2, "attack": 8, "control": 8}},
		{"name": "+1 power 6/5/5/5", "config": {"power": 6, "composure": 5, "attack": 5, "control": 5}},
		{"name": "+1 composure 5/6/5/5", "config": {"power": 5, "composure": 6, "attack": 5, "control": 5}},
		{"name": "+1 attack 5/5/6/5", "config": {"power": 5, "composure": 5, "attack": 6, "control": 5}},
		{"name": "+1 control 5/5/5/6", "config": {"power": 5, "composure": 5, "attack": 5, "control": 6}},
	]

	var n := 2000
	var swept := Sweep.run(arms, n, _scenario)

	var balanced_win := 0.0
	var rows: Array = []
	print("arm                    win%   base   perf   total ₸/match   season(×8)")
	for ai in swept.size():
		var recs = swept[ai]["records"]
		var win := 100.0 * _sum(Sweep.values_of(recs, "won")) / n
		var base := _mean(Sweep.values_of(recs, "base"))
		var perf := _mean(Sweep.values_of(recs, "perf"))
		var total := _mean(Sweep.values_of(recs, "total"))
		if swept[ai]["name"] == "balanced 5/5/5/5":
			balanced_win = win
		rows.append({"name": swept[ai]["name"], "win_rate": win, "base": base, "perf": perf,
			"pay": total, "season": total * 8.0})
		print("%-22s %5.1f %6.1f %6.1f %7.1f       %6.0f" % [swept[ai]["name"], win, base, perf, total, total * 8.0])

	print("")
	print("marginal Δwin%% vs balanced (the +1-attribute value):")
	for r in rows:
		if String(r["name"]).begins_with("+1"):
			r["delta_win"] = r["win_rate"] - balanced_win
			print("  %-22s %+0.1f%%" % [r["name"], r["delta_win"]])

	print("")
	print("JSON: %s" % JSON.stringify({"arms": rows}))
	quit()

func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var a := Attributes.new()
	a.power = config["power"]; a.composure = config["composure"]
	a.attack = config["attack"]; a.control = config["control"]
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	var m := MatchResolver.simulate_match_teams(a, pt, ot, _tour, _tuning, _itun, rng)
	var pay := Economy.match_pay(m, pt.stars, _etun)
	return {
		"won": 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0,
		"base": pay["base"], "perf": pay["perf"], "total": pay["total"],
	}

func _sum(arr: Array) -> float:
	var s := 0.0
	for x in arr:
		s += x
	return s

func _mean(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	return _sum(arr) / arr.size()
```

- [ ] **Step 2: Import + run it** (editor closed; ~2–3 min for 7 arms × 2000):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_economy.gd | tee /tmp/sweep_economy_7cD.txt
```

- [ ] **Step 3: Check pay-fairness (spec §5.5).** The three canonical builds' mean `total` within ±15% of their average. If the bowler (or batter) is outside, retune `EconomyTuning.runs_rate`/`wicket_rate` (e.g. bowler underpaid → raise `wicket_rate`; solve linearly from the measured mean runs ≈44 batter / wickets ≈1.9 bowler), update the defaults in `scripts/data/economy_tuning.gd`, re-run, repeat until within band. Record final dials + table for spec §10.

- [ ] **Step 4: Run the unit suite** (the dial change must not break Task 1 tests — they reference dials, not literals). Expected: 380 green.

- [ ] **Step 5: Commit**

```sh
git add tools/sweep_economy.gd tools/sweep_economy.gd.uid scripts/data/economy_tuning.gd
git commit -m "Economy rung 7c-D Task 4: sweep_economy oracle — pay-fairness tuned, marginal attribute values measured"
```

---

### Task 5: ROI + scarcity acceptance checks (spec §5.5) — analysis, no code

**Files:** none (numbers land in spec §10 in Task 7)

Using Task 2 prices, Task 4 income + marginals:

- [ ] **Step 1: Scarcity.** Full-greed Season spend = (mid Common + mid Rare + mid Legendary + one more mid joker) + Σ attr upgrades (4 visits × `attr_upgrade_cost(5..6)`) vs measured Season income (balanced build, ×8). Must exceed income.
- [ ] **Step 2: Affordability pacing.** Income after 3 matches ≥ mid Common price; Legendary price ≈ 40–60% of Season income.
- [ ] **Step 3: No dominant spend.** ₸-per-+1%-win for: a mid-band Common / Rare / Legendary (price ÷ its realized delta) and +1 best attribute (`attr_upgrade_cost(5)` ÷ its measured Δwin%). All within a factor ~3, attributes allowed up to ~2× premium (Career-permanent). If attributes are *cheaper* per point than jokers, raise `attr_cost_base` in `EconomyTuning`, re-assert Task 1 tests, and note the final dial.
- [ ] **Step 4:** Write all numbers down for Task 7 (spec §10).

---

### Task 6: The eyeball viz (`docs/mockups/economy-v1.html`)

**Files:**
- Create: `docs/mockups/economy-v1.html`

- [ ] **Step 1: Create the page** — static, self-contained, same spirit as the other mockups (swap `DATA` to refresh). Bars are plain divs; no libraries.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>₸ Economy V1 — income, prices, ROI (rung 7c-D)</title>
<style>
	body { font-family: -apple-system, sans-serif; background: #14181f; color: #e8e6e1; max-width: 880px; margin: 24px auto; padding: 0 16px; }
	h1 { font-size: 1.3rem; } h2 { font-size: 1.05rem; margin-top: 2em; color: #f0c75e; }
	.bar-row { display: flex; align-items: center; gap: 10px; margin: 6px 0; }
	.bar-label { width: 220px; font-size: .85rem; text-align: right; color: #b8b4ac; }
	.bar { height: 22px; border-radius: 3px; background: #4a90d9; min-width: 2px; }
	.bar.gold { background: #f0c75e; } .bar.green { background: #5cb85c; } .bar.red { background: #d9534f; }
	.bar-val { font-size: .8rem; color: #e8e6e1; }
	.note { font-size: .8rem; color: #8a867e; margin-top: .5em; }
</style>
</head>
<body>
<h1>₸ Economy V1 <span style="color:#8a867e;font-size:.8em">— rung 7c-D, even ★3, N=2000/arm</span></h1>
<div id="income"></div>
<div id="prices"></div>
<div id="roi"></div>
<script>
// Paste fresh numbers from tools/sweep_economy.gd + JokerCatalog.PRICES here.
const DATA = {
	income: [ /* {name, pay, season, win} per build — Task 4 table */ ],
	priceLadder: [ /* {name, price, rarity} — band floor/mid/ceiling examples + season income marker */ ],
	seasonIncome: 0, // balanced build ×8
	roi: [ /* {name, tonsPerWinPoint} — mid C/R/L joker + best +1 attribute */ ],
};
function bars(el, title, rows, valueKey, fmt, colorFn, maxOverride) {
	const max = maxOverride || Math.max(...rows.map(r => r[valueKey]));
	let h = `<h2>${title}</h2>`;
	for (const r of rows)
		h += `<div class="bar-row"><div class="bar-label">${r.name}</div>
			<div class="bar ${colorFn ? colorFn(r) : ''}" style="width:${(r[valueKey] / max * 540).toFixed(0)}px"></div>
			<div class="bar-val">${fmt(r)}</div></div>`;
	el.innerHTML = h;
}
bars(document.getElementById('income'), '₸ per match by build (season ×8 in label)', DATA.income, 'pay',
	r => `₸${r.pay.toFixed(0)} /match · ₸${r.season.toFixed(0)} /season · ${r.win.toFixed(1)}% win`);
bars(document.getElementById('prices'), `Price ladder vs a season's income (₸${DATA.seasonIncome})`, DATA.priceLadder, 'price',
	r => `₸${r.price}`, r => r.rarity === 'Legendary' ? 'gold' : (r.rarity === 'Rare' ? 'green' : ''), DATA.seasonIncome);
bars(document.getElementById('roi'), 'Spend ROI — ₸ per +1% win (lower = better value)', DATA.roi, 'tonsPerWinPoint',
	r => `₸${r.tonsPerWinPoint.toFixed(0)} per +1%`, r => r.name.includes('attribute') ? 'red' : '');
document.body.insertAdjacentHTML('beforeend',
	'<p class="note">Attribute points are Career-permanent (jokers are Season-scoped) — they are allowed up to ~2× the ₸-per-point of a joker. Prices: JokerCatalog.PRICES · income: tools/sweep_economy.gd · spec 2026-06-10-tons-economy-7cD §5.5.</p>');
</script>
</body>
</html>
```

- [ ] **Step 2: Fill `DATA`** with the Task 4/5 numbers, open the file in a browser (or the static preview server) and **eyeball it** — bars render, no NaN, the price ladder visibly crowds the season-income ceiling (the scarcity story).

- [ ] **Step 3: Commit**

```sh
git add docs/mockups/economy-v1.html
git commit -m "Economy rung 7c-D Task 6: economy-v1 viz — income per build, price ladder vs season income, spend ROI"
```

---

### Task 7: Findings + docs + handoff

**Files:**
- Modify: `docs/superpowers/specs/2026-06-10-tons-economy-7cD-design.md` (§10)
- Modify: `PROJECT_ROADMAP.md`

- [ ] **Step 1: Fill spec §10** — final dial values (EconomyTuning), the 45-price table, income per build, marginal attribute Δwin%, the ROI table, scarcity/pacing numbers, residuals/threads for the next rung (7c-E or Career).
- [ ] **Step 2: Update `PROJECT_ROADMAP.md`** — Current status line, "Last closed" entry, and rewrite the **Next session** handoff block (state, next step = 7c-E self-play AI per the 7c plan, key seams: `Economy`/`EconomyTuning`/`JokerCatalog.PRICES`/`tools/sweep_economy.gd`, awaiting-Nico items).
- [ ] **Step 3: Run the full suite one last time** — green past 380, `All tests passed`.
- [ ] **Step 4: Commit**

```sh
git add docs/superpowers/specs/2026-06-10-tons-economy-7cD-design.md PROJECT_ROADMAP.md
git commit -m "Economy rung 7c-D Task 7: findings (spec §10), roadmap handoff"
```

- [ ] **Step 5: PR + merge** (AFK policy): push branch, open PR, merge, sync local `main`, delete branch — via the finishing-a-development-branch flow.

---

## Self-review

- **Spec coverage:** §5.1/5.2 → Task 1 · §5.3 → Task 2 (+ doc mirror Task 3) · §5.4 → Task 4 · §5.5 → Tasks 4 (fairness) + 5 (ROI/scarcity) · viz DE10 → Task 6 · §9.6 docs → Tasks 3+7 · loadout cap DE8 → Task 1 (dial + test). Covered.
- **Placeholders:** the `PRICES` literal and viz `DATA` are *measured at build* (sweep outputs) — explicitly marked, formula given; everything authorable ahead of time is written out.
- **Type consistency:** `Economy.match_pay(result, team_stars: float, tuning) -> Dictionary{base,perf,total}` used identically in tests (Task 1) and the oracle (Task 4); `price(id) -> int` / `price_band(rarity) -> Vector2i` consistent across Tasks 2 tests and code; `EconomyTuning` field names match across Tasks 1/4.
