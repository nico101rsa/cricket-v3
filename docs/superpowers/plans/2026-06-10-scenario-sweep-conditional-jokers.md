# Scenario-sweep (conditional & synergy jokers) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure conditional & synergy jokers in contexts where their triggers fire, then buff the genuinely under-powered *uncontrollable* ones to realized-band — closing the rung-2 participation residual and producing the fire-rate input for rung-D pricing.

**Architecture:** One small additive sim seam (force the toss so the Player bats 2nd → the chase condition fires), then the joker oracle (`tools/sweep_jokers.gd`) grows scenario *profiles* (each with its own no-joker baseline), a chase fire-rate readout, and a marginal-combo baseline. Buffing is the same empirical dial loop as rung 2, gated on the controllability guardrail.

**Tech Stack:** Godot 4.6.3 headless · GDScript · GUT 9.6. Spec: `docs/superpowers/specs/2026-06-10-scenario-sweep-conditional-jokers-design.md`.

**Conventions reminder:** tabs in `.gd`; run `--import` once after adding scripts; quit the Godot editor before headless runs (`pgrep -x Godot`); GUT `-gtest` does NOT filter — judge red by parse-error/failing-assert, green by total count climbing past **363** + `All tests passed`; commit `*.gd.uid` for `scripts/`+`tools/` not `tests/`; clean iCloud `" 2"` files before a run. Test command:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Sweep command (~40s, background it):
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_jokers.gd`

---

## Task 1: Toss-force seam (`simulate_match_teams`)

Add an optional, off-by-default param that overrides the toss result **without changing the RNG draw order** (so the default path stays byte-identical and forced runs stay deterministic). The chase profile uses it to make the Player bat 2nd → `target > 0` → `is_chase` true → The Chase Master fires.

**Files:**
- Modify: `scripts/domain/match_resolver.gd:71-91`
- Test: `tests/unit/test_match_resolver.gd`

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_match_resolver.gd`:

```gdscript
func test_force_bats_first_overrides_toss():
	var a := Attributes.new(); a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	var tour := TourDistribution.new()
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	# force = 1 -> Player bats first; force = 0 -> Player bats second, every seed.
	for seed in [1, 2, 3, 7, 99]:
		var r1 := RandomNumberGenerator.new(); r1.seed = seed
		var m1 := MatchResolver.simulate_match_teams(a, pt, ot, tour, tuning, itun, r1,
			null, null, [], null, null, null, null, null, null, null, null, 1)
		assert_true(m1.player_bats_first, "force=1 -> Player bats first (seed %d)" % seed)
		var r0 := RandomNumberGenerator.new(); r0.seed = seed
		var m0 := MatchResolver.simulate_match_teams(a, pt, ot, tour, tuning, itun, r0,
			null, null, [], null, null, null, null, null, null, null, null, 0)
		assert_false(m0.player_bats_first, "force=0 -> Player bats second (seed %d)" % seed)

func test_force_default_is_byte_identical_to_toss():
	var a := Attributes.new(); a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	var tour := TourDistribution.new()
	var tuning := BallTuning.new(); var itun := InningsTuning.new()
	# Omitting the param and passing -1 must produce the identical match (the override
	# must not perturb the RNG stream when not forcing).
	var ra := RandomNumberGenerator.new(); ra.seed = 42
	var ma := MatchResolver.simulate_match_teams(a, pt, ot, tour, tuning, itun, ra)
	var rb := RandomNumberGenerator.new(); rb.seed = 42
	var mb := MatchResolver.simulate_match_teams(a, pt, ot, tour, tuning, itun, rb,
		null, null, [], null, null, null, null, null, null, null, null, -1)
	assert_eq(ma.player_bats_first, mb.player_bats_first, "default == explicit -1: toss")
	assert_eq(ma.innings1.total, mb.innings1.total, "default == explicit -1: innings1 total")
	assert_eq(ma.innings2.total, mb.innings2.total, "default == explicit -1: innings2 total")
	assert_eq(ma.outcome, mb.outcome, "default == explicit -1: outcome")
```

- [ ] **Step 2: Run tests to verify they fail**

Run the test command above.
Expected: the two new tests FAIL (too many arguments to `simulate_match_teams` → parse error, GUT skips/logs; or arg-count mismatch). Total count does not climb.

- [ ] **Step 3: Add the param and the determinism-preserving override**

In `scripts/domain/match_resolver.gd`, extend the signature (after `opp_drs_policy`):

```gdscript
		opp_drs_policy: DRSPolicy = null,
		force_player_bats_first: int = -1
) -> MatchResult:
```

Replace line 91 (`var player_bats_first := _resolve_toss(rng)`) with:

```gdscript
	# Always consume the toss draw so the RNG stream (and the default path) is
	# unchanged; only the *result* is overridden when forced (-1 = use toss,
	# 1 = Player bats first, 0 = Player bats second). Used by the chase sweep profile.
	var tossed := _resolve_toss(rng)
	var player_bats_first := tossed if force_player_bats_first == -1 else (force_player_bats_first == 1)
```

- [ ] **Step 4: Run tests to verify they pass**

Run the test command.
Expected: PASS; total count climbs (363 → 365) and `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_resolver.gd scripts/domain/match_resolver.gd.uid tests/unit/test_match_resolver.gd
git commit -m "Scenario-sweep Task 1: toss-force seam (force_player_bats_first, determinism-preserving)"
```

---

## Task 2: Chase scenario profile in the sweep (`tools/sweep_jokers.gd`)

Run the joker oracle under two profiles — **standard** (today's scenario; the unconditional anchor) and **chase** (Player forced to bat 2nd) — each with its **own no-joker baseline arm** so win-delta is measured against the same context. Emit both as labelled JSON blocks.

**Files:**
- Modify: `tools/sweep_jokers.gd`

- [ ] **Step 1: Add a profile field and thread the toss-force**

Add a module var near the other state (after `var _tour: TourDistribution`):

```gdscript
var _profile := "standard"   # "standard" or "chase"
```

In `_scenario`, change the `simulate_match_teams(...)` call (line ~207) to pass the toss-force as its final argument — `0` (bat 2nd) for the chase profile, `-1` (toss) otherwise:

```gdscript
	var force := 0 if _profile == "chase" else -1
	var m := MatchResolver.simulate_match_teams(a, pt, ot, _tour, _tuning, _itun, rng, _intent_plan(), _bowling_plan(), config, _field_plan(), _bowl_intent_plan(), _intent_plan(), _boost_plan(), _drs_policy(), _opp_field_plan(), _opp_boost_plan(), _opp_drs_policy(), force)
```

- [ ] **Step 2: Build a focused chase-arm list and run both passes**

In `_init`, after the existing `var arms` is built and before `var n := 2000`, build a smaller chase arm-set (the conditional jokers the chase profile exists to measure) plus its own baseline:

```gdscript
	# Chase profile: only the jokers whose trigger needs batting 2nd. Each block
	# carries its own "Baseline (no jokers)" arm so win-delta is same-context.
	var chase_ids := {"the_chase_master": true, "match_winners_vigil": true}
	var chase_arms: Array = [{"name": "Baseline (no jokers)", "config": []}]
	for g in groups:
		if chase_ids.has(g["id"]):
			chase_arms.append({"name": g["jname"], "config": g["effects"]})
```

Replace the single `var swept := Sweep.run(arms, n, _scenario)` with two passes:

```gdscript
	var n := 2000
	_profile = "standard"
	var swept := Sweep.run(arms, n, _scenario)
	_profile = "chase"
	var swept_chase := Sweep.run(chase_arms, n, _scenario)
```

- [ ] **Step 3: Emit the chase block alongside the standard block**

The existing arm→JSON loop builds `arms_json` from `swept`. After it, add the same reduction for `swept_chase` into a `chase_json` array (copy the per-arm stats/win_rate/win_delta logic, resetting `baseline_win`/`baseline_margin` from the chase block's own arm 0), and include it in the final print:

```gdscript
	print(JSON.stringify({"metric": "player_runs", "arms": arms_json, "chase_arms": chase_json}))
```

(Factor the per-arm reduction into a small local helper `func _reduce(swept_block: Array) -> Array:` to avoid duplicating the loop — DRY.)

- [ ] **Step 4: Run the sweep and eyeball**

Run the sweep command (background it). When it finishes, confirm the JSON has a `chase_arms` block and that **The Chase Master's `win_delta` in the chase block is materially higher than its ~+3% standard reading** (it should now fire every match). Record the number.

Expected: Chase Master in-condition delta lands well above its dormant +3% (the §10.3 prediction). If it's already in Legendary band (+7–12%) it needs no buff; if below, Task 4 buffs it.

- [ ] **Step 5: Commit**

```bash
git add tools/sweep_jokers.gd tools/sweep_jokers.gd.uid
git commit -m "Scenario-sweep Task 2: chase profile (Player bats 2nd) with own baseline in the joker oracle"
```

---

## Task 3: Chase fire-rate + a marginal-combo baseline (`tools/sweep_jokers.gd`)

Produce the two remaining rung-D pricing inputs: the passive **fire-rate** of the chase condition (how often the Player bats 2nd in normal play), and a **marginal-in-combo** number for the Form synergy cluster (the representative enabler→consumer pattern).

**Files:**
- Modify: `tools/sweep_jokers.gd`

- [ ] **Step 1: Emit a `chasing` flag from `_scenario`**

In `_scenario`, after `var won := ...`, add whether the Player batted second this match (the chase trigger's passive occurrence):

```gdscript
	var batted_second := (p_inn == m.innings2)
	return {"player_runs": player_runs, "won": won, "margin": margin, "batted_second": 1 if batted_second else 0}
```

- [ ] **Step 2: Average it over the standard baseline arm → the fire-rate**

In `_init`, after the standard `swept` reduction, compute the chase fire-rate from the standard baseline arm (arm 0) and log it:

```gdscript
	var base_bs := Sweep.values_of(swept[0]["records"], "batted_second")
	var bs_sum := 0
	for v in base_bs:
		bs_sum += v
	var chase_fire_rate := float(bs_sum) / base_bs.size()
	print("CHASE_FIRE_RATE %f" % chase_fire_rate)
```

(Expected ≈ 0.50 — the toss is 50/50. This is the discount factor: realized = in-condition × ~0.5.)

- [ ] **Step 3: Add the Form-cluster marginal baseline arm**

The sweep already has a `form_combo` arm (sources + consumers). Add a **consumers-only** arm (the same cluster minus the Form *sources*) so the sources' marginal value = `form_combo_delta − form_consumers_delta`:

```gdscript
	var form_consumer_ids := {"ride_the_wave": true, "hot_streak": true}
	var form_consumers: Array = []
	for g in groups:
		if form_consumer_ids.has(g["id"]):
			form_consumers.append_array(g["effects"])
	# (append after the existing "Form-source combo" arm)
	arms.append({"name": "Form-consumers only", "config": form_consumers})
```

- [ ] **Step 4: Run the sweep and record the numbers**

Run the sweep command. Record: `CHASE_FIRE_RATE`, and the marginal value of the Form sources = `Form-source combo` win_delta − `Form-consumers only` win_delta. Confirm the marginal is positive (the sources earn their slot) — if ~0, note it as a flagged enabler in the findings.

- [ ] **Step 5: Commit**

```bash
git add tools/sweep_jokers.gd tools/sweep_jokers.gd.uid
git commit -m "Scenario-sweep Task 3: chase fire-rate readout + Form-cluster marginal baseline"
```

---

## Task 4: Measure & buff the uncontrollable under-band jokers (`scripts/data/joker_catalog.gd`)

Empirical dial loop (same as rung 2 §5.3). Using the chase-profile in-condition deltas + the fire-rate, buff the **uncontrollable** under-band jokers so **realized ≈ band** (in-condition × achievable fire-rate ≈ rarity band). Leave controllable jokers untouched. The exact final magnitudes are discovered by iterating against the sweep; the asserts are rebaselined to whatever lands.

**Buff candidates (uncontrollable, per spec §4):**
- **The Chase Master** (Legendary, `mult=1.20` at `joker_catalog.gd:223`) — fire-rate ~0.5. For a realized +7–12% Legendary at ~50% fire-rate, the in-condition (chase-profile) delta should sit ~+14–24%. Raise `mult` (1.20 → ~1.35–1.50) until the chase-block delta reaches that range. **Guardrail check:** the in-condition delta may exceed Legendary band — that is intended (nuclear-when-it-fires); only the *realized* number is band-bound, and the toss caps fire-rate at ~50% so it cannot be farmed.
- **Match-Winner's Vigil** (Legendary, `mult=0.80` wicket at `:133`) — measure under the chase profile (it fires on a batting Form event; chasing aggressively generates more). If still under realized-band, strengthen the wicket guard (0.80 → ~0.70). If it only fires with a Form *source* present, treat it as combo-measured (note in findings) rather than over-buffing solo.
- **Wicket Maiden** (Rare, `mult=1.30` at `:118`) — fires on a Player bowling wicket (emergent, ~uncontrollable). If under realized Rare band once its fire-rate is accounted for, raise toward ~1.45.

Do **not** buff: Strike Bowler, Pace Pack, Spinner's Web, First-Change, The Trap, Attack the Stumps, Cordon Killer, Dead Bat, Block the Shine, Rotate the Strike, or any Boost-press joker (all player-controllable → already fair at in-condition band).

**Files:**
- Modify: `scripts/data/joker_catalog.gd`
- Test: `tests/unit/test_joker_catalog.gd`

- [ ] **Step 1: Iterate the buffs against the sweep**

For each buff candidate: edit its `mult` in `joker_catalog.gd` → run the sweep → read the chase-block (Chase Master / Vigil) or standard-block (Wicket Maiden) win_delta → multiply by its fire-rate to get realized → check against the rarity band → repeat (2–4 iterations). Stop when realized lands in band (±~1%). Record the final magnitude + in-condition delta + realized delta for each in the findings.

- [ ] **Step 2: Rebaseline the magnitude asserts**

Update the corresponding asserts in `tests/unit/test_joker_catalog.gd` to the final magnitudes (grep the test for `chase_master` / `match_winners_vigil` / `wicket_maiden` and set the expected `mult`).

- [ ] **Step 3: Run the suite to verify green**

Run the test command.
Expected: PASS; total count ≥ 365 (Task 1's +2 plus any new), `All tests passed`.

- [ ] **Step 4: Confirm no auto-win (ceiling check)**

Re-run the sweep. Confirm: no single joker's realized win_delta exceeds its band ceiling; the strongest realistic synergy stack arm stays ≤ ~+20% (spec §5.4). Record the strongest-stack number.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/joker_catalog.gd scripts/data/joker_catalog.gd.uid tests/unit/test_joker_catalog.gd
git commit -m "Scenario-sweep Task 4: buff uncontrollable under-band jokers to realized-band (Chase Master/Vigil/Wicket Maiden)"
```

---

## Task 5: Docs — findings, pool doc, viewer, roadmap

**Files:**
- Modify: `docs/superpowers/specs/2026-06-10-scenario-sweep-conditional-jokers-design.md` (§10)
- Modify: `docs/joker-pool-v1.md`
- Modify: `docs/mockups/distribution-viewer-v1.html` (the `DATA` block)
- Modify: `PROJECT_ROADMAP.md`

- [ ] **Step 1: Fill in spec §10 (findings)**

Replace the §10 placeholder with: the honest in-condition delta table for the measured conditional jokers; the chase fire-rate; the realized deltas after buffing; the Form-cluster marginal number; the strongest-stack ceiling figure; and the final magnitudes.

- [ ] **Step 2: Refresh the pool doc**

In `docs/joker-pool-v1.md`, update the buffed jokers' magnitudes and add a **fire-rate** note for the conditional jokers (the rung-D pricing input).

- [ ] **Step 3: Refresh the viewer DATA**

Paste the latest sweep JSON into the `DATA` const in `docs/mockups/distribution-viewer-v1.html` so the overlaid histogram reflects the new magnitudes (include the chase block if the viewer supports labelled blocks; else the standard block).

- [ ] **Step 4: Update the roadmap**

Move this rung to done in `PROJECT_ROADMAP.md` (status + history), and refresh the **Next session** handoff: state, tests green count, the next step (= **rung D, the ₸ economy** — now unblocked, with the fire-rate table as the pricing input), key seams, anything awaiting Nico.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-06-10-scenario-sweep-conditional-jokers-design.md docs/joker-pool-v1.md docs/mockups/distribution-viewer-v1.html PROJECT_ROADMAP.md
git commit -m "Scenario-sweep Task 5: findings, pool-doc fire-rates, viewer DATA, roadmap handoff"
```

---

## Done criteria (verify before PR)

- [ ] Every conditional joker in the chase set has a measured in-condition delta (chase block).
- [ ] Chase fire-rate recorded; realized deltas computed for buffed jokers.
- [ ] Form-cluster marginal contribution recorded.
- [ ] Uncontrollable under-band jokers buffed to realized-band; controllable ones untouched.
- [ ] No single joker or realistic stack is an auto-win (ceiling check passed).
- [ ] Full GUT suite green (≥365), `All tests passed`.
- [ ] Spec §10, pool doc, viewer, roadmap updated.
- [ ] PR opened, merged to `main`, branch deleted, local `main` synced.
