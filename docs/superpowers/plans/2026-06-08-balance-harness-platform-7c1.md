# Balance harness platform (7c-1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the reusable balance-harness platform — a `Distribution` stats/histogram helper, a model-agnostic `Sweep` engine (arms × seeded scenarios), and a generic before/after distribution-overlay HTML viewer — and demo it on Player build (skills) impact.

**Architecture:** New tested `scripts/harness/` library (`Distribution`, `Sweep`); a throwaway `tools/sweep_skills.gd` runner that drives `Sweep` over three Attribute builds via the real match sim and prints JSON; a reusable `docs/mockups/distribution-viewer-v1.html` that overlays the arms' histograms. Additive — no existing file changes.

**Tech Stack:** Godot 4.6.3 (Standard) · GDScript (tabs) · GUT 9.6. Spec: `docs/superpowers/specs/2026-06-08-balance-harness-platform-7c1-design.md`.

---

## Conventions for every task (project `CLAUDE.md`)

- **Godot binary:** `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH). **`pgrep Godot` must be empty** before headless runs.
- **After adding a new `scripts/` file, run `--import` once** before tests:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
- **Run the whole suite** (the `-gtest` flag does NOT filter here):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- **Judge RED** by `Parse Error: Identifier "X" not declared` (file skipped). **Judge GREEN** by the count climbing + `All tests passed`.
- **iCloud junk guard:** if GUT suddenly fails to load, `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot` then re-`--import`.
- **Commit `*.gd.uid`** for `scripts/` (and `tools/`) files; NOT for `tests/`.
- Baseline before starting: **177 tests green**. New library lives in `scripts/harness/` (a fresh folder — fine, Godot imports recursively).

---

### Task 1: `Distribution` — stats + histogram

**Files:**
- Create: `scripts/harness/distribution.gd`
- Test: `tests/unit/test_distribution.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_distribution.gd`:

```gdscript
extends GutTest

func test_summary_stats() -> void:
	var d := Distribution.new([2, 4, 4, 4, 5, 5, 7, 9])
	assert_eq(d.count(), 8, "count")
	assert_almost_eq(d.mean(), 5.0, 0.0001, "mean")
	assert_almost_eq(d.sd(), 2.0, 0.0001, "population sd")
	assert_almost_eq(d.minimum(), 2.0, 0.0001, "min")
	assert_almost_eq(d.maximum(), 9.0, 0.0001, "max")

func test_empty_is_safe() -> void:
	var d := Distribution.new([])
	assert_eq(d.count(), 0, "empty count")
	assert_almost_eq(d.mean(), 0.0, 0.0001, "empty mean 0")
	assert_almost_eq(d.minimum(), 0.0, 0.0001, "empty min 0")
	assert_almost_eq(d.maximum(), 0.0, 0.0001, "empty max 0")

func test_histogram_bins_and_clamps() -> void:
	# bins over [0,10): values 1,3,5,7,9 land one per bin (width 2).
	var d := Distribution.new([1, 3, 5, 7, 9])
	var h := d.histogram(5, 0.0, 10.0)
	assert_eq(h.size(), 5, "5 bins")
	assert_eq(h, [1, 1, 1, 1, 1], "one per bin")
	# Out-of-range clamps into the end bins; counts still sum to count().
	var d2 := Distribution.new([-4, 1, 99])
	var h2 := d2.histogram(5, 0.0, 10.0)
	assert_eq(h2[0], 2, "negative + low value in bottom bin")
	assert_eq(h2[4], 1, "huge value in top bin")
	var total := 0
	for c in h2:
		total += c
	assert_eq(total, d2.count(), "histogram counts sum to count")
```

- [ ] **Step 2: Run the suite to verify RED**

Run the whole-suite command. Expected: `Parse Error: Identifier "Distribution" not declared`; count stays 177.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/harness/distribution.gd`:

```gdscript
class_name Distribution
extends RefCounted

# Summary stats + histogram over a list of numbers. Pure, no RNG. The numeric
# workhorse of the balance harness. See spec
# 2026-06-08-balance-harness-platform-7c1-design.md §3.

var values: Array = []

func _init(vals: Array = []) -> void:
	values = vals

func count() -> int:
	return values.size()

func mean() -> float:
	if values.is_empty():
		return 0.0
	var s := 0.0
	for v in values:
		s += v
	return s / values.size()

func sd() -> float:
	if values.size() < 2:
		return 0.0
	var m := mean()
	var ss := 0.0
	for v in values:
		ss += (v - m) * (v - m)
	return sqrt(ss / values.size())

func minimum() -> float:
	if values.is_empty():
		return 0.0
	var lo: float = values[0]
	for v in values:
		lo = minf(lo, v)
	return lo

func maximum() -> float:
	if values.is_empty():
		return 0.0
	var hi: float = values[0]
	for v in values:
		hi = maxf(hi, v)
	return hi

# Array[int] of length `bins`. Each value -> floor((v-lo)/(hi-lo)*bins), clamped
# to [0, bins-1] so out-of-range values fall into the end bins.
func histogram(bins: int, lo: float, hi: float) -> Array:
	var counts: Array = []
	for i in range(bins):
		counts.append(0)
	if bins <= 0 or hi <= lo:
		return counts
	for v in values:
		var idx := int(floor((v - lo) / (hi - lo) * bins))
		idx = clampi(idx, 0, bins - 1)
		counts[idx] += 1
	return counts

func to_dict() -> Dictionary:
	return {"count": count(), "mean": mean(), "sd": sd(), "min": minimum(), "max": maximum()}
```

- [ ] **Step 4: Re-import and run the suite to verify GREEN**

Run `--import`, then the whole-suite command. Expected: `All tests passed`, count = **180** (177 + 3).

- [ ] **Step 5: Commit**

```bash
git add scripts/harness/distribution.gd scripts/harness/distribution.gd.uid tests/unit/test_distribution.gd
git commit -m "7c-1 task 1: Distribution (stats + histogram)"
```

---

### Task 2: `Sweep` — run arms × seeded scenarios

**Files:**
- Create: `scripts/harness/sweep.gd`
- Test: `tests/unit/test_sweep.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_sweep.gd`:

```gdscript
extends GutTest

# A scenario that ignores config and returns the rng's first int — to inspect seeds.
func _seed_probe(_config, rng: RandomNumberGenerator) -> Dictionary:
	return {"r": rng.randi()}

# A scenario that echoes the config (a number) — to check config threading.
func _config_echo(config, _rng: RandomNumberGenerator) -> Dictionary:
	return {"v": config}

func test_run_shape() -> void:
	var arms := [{"name": "a", "config": 1}, {"name": "b", "config": 2}]
	var res := Sweep.run(arms, 5, _config_echo)
	assert_eq(res.size(), 2, "one entry per arm")
	assert_eq(res[0]["name"], "a", "arm name preserved")
	assert_eq(res[0]["records"].size(), 5, "n records for arm a")
	assert_eq(res[1]["records"].size(), 5, "n records for arm b")

func test_values_of() -> void:
	var arms := [{"name": "a", "config": 7}]
	var res := Sweep.run(arms, 4, _config_echo)
	var vals := Sweep.values_of(res[0]["records"], "v")
	assert_eq(vals, [7, 7, 7, 7], "config threaded into every record")

func test_paired_seeds_across_arms() -> void:
	# Both arms ignore config, so identical paired seeds -> identical record streams.
	var arms := [{"name": "a", "config": 0}, {"name": "b", "config": 0}]
	var res := Sweep.run(arms, 6, _seed_probe, 100)
	assert_eq(Sweep.values_of(res[0]["records"], "r"), Sweep.values_of(res[1]["records"], "r"),
		"arm a and arm b saw the same seed sequence (paired)")

func test_deterministic() -> void:
	var arms := [{"name": "a", "config": 0}]
	var r1 := Sweep.run(arms, 6, _seed_probe, 42)
	var r2 := Sweep.run(arms, 6, _seed_probe, 42)
	assert_eq(Sweep.values_of(r1[0]["records"], "r"), Sweep.values_of(r2[0]["records"], "r"),
		"same base_seed -> identical records")
```

- [ ] **Step 2: Run the suite to verify RED**

Run the whole-suite command. Expected: `Parse Error: Identifier "Sweep" not declared`; count stays 180.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/harness/sweep.gd`:

```gdscript
class_name Sweep
extends RefCounted

# Model-agnostic sweep engine: run each arm n times through a scenario Callable,
# collecting metric records. Paired seeds across arms (arm k's i-th run uses
# base_seed + i, the same for every arm) so arm-to-arm differences aren't RNG
# noise. See spec 2026-06-08-balance-harness-platform-7c1-design.md §4.

# arms: Array of {name: String, config: Variant}
# scenario: Callable(config, rng: RandomNumberGenerator) -> Dictionary
# Returns: Array of {name: String, records: Array[Dictionary]} in arm order.
static func run(arms: Array, n: int, scenario: Callable, base_seed: int = 1) -> Array:
	var out: Array = []
	for arm in arms:
		var records: Array = []
		for i in range(n):
			var rng := RandomNumberGenerator.new()
			rng.seed = base_seed + i
			records.append(scenario.call(arm["config"], rng))
		out.append({"name": arm["name"], "records": records})
	return out

# Pull one numeric field across an arm's records into a flat Array.
static func values_of(records: Array, field: String) -> Array:
	var v: Array = []
	for r in records:
		v.append(r[field])
	return v
```

- [ ] **Step 4: Re-import and run the suite to verify GREEN**

Run `--import`, then the whole-suite command. Expected: `All tests passed`, count = **184** (180 + 4).

- [ ] **Step 5: Commit**

```bash
git add scripts/harness/sweep.gd scripts/harness/sweep.gd.uid tests/unit/test_sweep.gd
git commit -m "7c-1 task 2: Sweep (arms x seeded scenarios, paired seeds)"
```

---

### Task 3: Demo runner — `tools/sweep_skills.gd`

**Files:**
- Create: `tools/sweep_skills.gd`

No unit tests — diagnostic runner. It exercises `Sweep`/`Distribution` (both tested) over the real match sim.

- [ ] **Step 1: Write the runner**

Create `tools/sweep_skills.gd`:

```gdscript
extends SceneTree

# Demo sweep for the 7c-1 harness platform: vary the Player's Attribute build,
# hold both teams even (3.0 stars), run N matches per build, and print JSON of the
# player-runs distribution + win-rate per build for docs/mockups/distribution-viewer-v1.html.
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_skills.gd

var _tuning: BallTuning
var _itun: InningsTuning
var _tour: TourDistribution

func _init() -> void:
	_tuning = BallTuning.new()
	_itun = InningsTuning.new()
	_tour = TourDistribution.new()
	_tour.mean = 5
	_tour.spread = 1.5
	_tour.noise = 1

	var arms := [
		{"name": "Batting build (8/8/2/2)", "config": {"power": 8, "composure": 8, "attack": 2, "control": 2}},
		{"name": "Balanced (5/5/5/5)", "config": {"power": 5, "composure": 5, "attack": 5, "control": 5}},
		{"name": "Bowling build (2/2/8/8)", "config": {"power": 2, "composure": 2, "attack": 8, "control": 8}},
	]
	var n := 2000
	var swept := Sweep.run(arms, n, _scenario)

	var colors := ["#5ac77a", "#4a90d9", "#f2b134"]
	var arms_json: Array = []
	var ai := 0
	for arm in swept:
		var runs := Sweep.values_of(arm["records"], "player_runs")
		var wins := Sweep.values_of(arm["records"], "won")
		var dist := Distribution.new(runs)
		var win_sum := 0
		for w in wins:
			win_sum += w
		# Stride values to <= 400 points for inlining.
		var stride: int = maxi(1, runs.size() / 400)
		var sampled: Array = []
		var k := 0
		while k < runs.size():
			sampled.append(runs[k])
			k += stride
		arms_json.append({
			"name": arm["name"],
			"color": colors[ai % colors.size()],
			"values": sampled,
			"stats": dist.to_dict(),
			"win_rate": float(win_sum) / runs.size(),
		})
		ai += 1

	print(JSON.stringify({"metric": "player_runs", "arms": arms_json}))
	quit()

func _scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var a := Attributes.new()
	a.power = config["power"]
	a.composure = config["composure"]
	a.attack = config["attack"]
	a.control = config["control"]
	var pt := Team.new()
	pt.stars = 3.0
	var ot := Team.new()
	ot.stars = 3.0
	var m := MatchResolver.simulate_match_teams(a, pt, ot, _tour, _tuning, _itun, rng)
	var line := m.innings1.player_line()
	if line.is_empty():
		line = m.innings2.player_line()
	var player_runs := int(line.get("runs", 0))
	var won := 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0
	return {"player_runs": player_runs, "won": won}
```

- [ ] **Step 2: Run the runner and capture the JSON**

Run:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_skills.gd`
Expected: one JSON line `{"metric":"player_runs","arms":[...3 arms...]}`. Each arm has `stats` (mean/sd/min/max/count) and `win_rate`. Sanity: the batting build's `stats.mean` (player runs) is clearly higher than the bowling build's; win-rate for batting ≥ bowling, and the bowling vs balanced win-rate gap is ~0 (bowling attrs are inert today). Keep the JSON for Step 3.

- [ ] **Step 3: Commit**

```bash
git add tools/sweep_skills.gd
# add tools/sweep_skills.gd.uid only if git status shows it
git commit -m "7c-1 task 3: sweep_skills demo runner (build -> player-runs distribution)"
```

---

### Task 4: Reusable viewer — `docs/mockups/distribution-viewer-v1.html`

**Files:**
- Create: `docs/mockups/distribution-viewer-v1.html`

No unit tests — visualisation. Eyeballed in a browser.

- [ ] **Step 1: Write the viewer with the demo data inlined**

Create `docs/mockups/distribution-viewer-v1.html` — a self-contained page (inline `<canvas>`, no libs). Paste the Task 3 JSON into `const DATA = {...}`. The renderer must:
- Pool all arms' `values` to compute a shared x-range `[min, max]`; pick `bins` (e.g. 24).
- For each arm, compute its histogram over that range and draw it as a **semi-transparent filled step/bar series** in the arm's `color`, plus a **vertical dashed mean line** at `stats.mean`.
- Draw axis labels (x = the metric name `DATA.metric`, e.g. "player_runs"; y = "matches").
- Render a **legend** (arm name + color swatch) and a **summary table** (per arm: mean ± sd, min–max, count, win-rate %).
- Caption: "Real Godot sim — outcome distribution per Player build, even ★3 vs ★3 match, N per build. This is the reusable before/after distribution-shift viewer (7c-1 platform); swap `DATA` for any sweep."

Use the existing mockups' dark theme tokens (`--bg:#0f1419; --panel:#1a212b; --ink:#e8edf2; --muted:#8b98a5; --line:#2b3642`).

- [ ] **Step 2: Eyeball in a browser**

Serve and open `docs/mockups/distribution-viewer-v1.html` (reuse `.claude/launch.json`'s `mockups` server). Confirm three overlaid histograms with the batting build shifted right of the bowling build, mean lines visible, and the summary table populated (batting mean runs > balanced > bowling; bowling win-rate ≈ balanced). Manual check — the rung's "learn by seeing" gate.

- [ ] **Step 3: Commit**

```bash
git add docs/mockups/distribution-viewer-v1.html
git commit -m "7c-1 task 4: reusable distribution-overlay viewer + skills demo"
```

---

## Self-review notes

- **Spec coverage:** §3 Distribution → Task 1; §4 Sweep → Task 2; §5 demo runner → Task 3; §6 viewer → Task 4; §7 backward-compat → additive (no existing-file edits); §8 tests 1–2 → Task 1, tests 3–5 → Task 2 (demo/viewer have no unit tests per spec).
- **Type consistency:** `Distribution.new(vals)` + `count/mean/sd/minimum/maximum/histogram/to_dict`; `Sweep.run(arms, n, scenario, base_seed)` returning `[{name, records}]` + `Sweep.values_of(records, field)`; scenario `Callable(config, rng) -> Dictionary`. Demo uses `MatchResolver.simulate_match_teams`, `InningsResult.player_line()`, `MatchResult.Outcome.PLAYER_WIN`, `Team.stars`, `TourDistribution` — all as defined in 7b-1/7b-2a. Viewer reads `DATA.metric` + `DATA.arms[].{name,color,values,stats,win_rate}` exactly as the runner emits.
- **Counts:** 177 → 180 (T1) → 184 (T2). T3/T4 add no tests.
- **No placeholders:** all code complete; commands exact. (Task 4 step 1 specifies the renderer behaviour precisely rather than pasting ~120 lines of canvas code, since the exact pixel code is non-load-bearing and the data contract + required elements are fully given — consistent with how the prior chart tasks were executed.)
- **GDScript notes:** `JSON.stringify` for the JSON blob. Scenario is a non-static method passed as `_scenario` Callable from `_init` (bound to the SceneTree instance, so it can read `_tour`/`_tuning`/`_itun`). New `scripts/harness/` folder imports fine.
</content>
