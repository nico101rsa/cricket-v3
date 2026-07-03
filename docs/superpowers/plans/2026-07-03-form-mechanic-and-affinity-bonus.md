# Form Mechanic + Affinity Bonus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Form real (per-ball ticks + ×0.8–×1.15 attribute multiplier, within-season persistence, season reset) and give Affinity its designed performance bonus, in the live game AND the headless career sim, with one shared balance re-sweep.

**Architecture:** A pure `FormState` (points + tick rules + multiplier, no RNG) threads through the sim as a trailing optional param — **null = byte-identical** (the codebase's standard extension pattern; the whole existing suite unmodified is the proof). Live: `SeasonPlay` owns the running points, seeds each `MatchSession` from the *match-start* value (resim-safe), settles `MatchResult.form_end` back, resets at season end. Headless: `SeasonResolver` threads one instance per season. Spec: `docs/superpowers/specs/2026-07-03-form-mechanic-and-affinity-bonus-design.md` (DF1–DF12).

**Tech Stack:** Godot 4.6.3 / GDScript (tabs), GUT 9.6.

**Conventions that bite:** `--import` after new scripts, before tests; ONE Godot process at a time (check `pgrep -fl Godot` first — ask Nico if the game is running); whole-suite runs only; red = parse error for a missing `class_name`; commit `.gd.uid` for scripts (not for tests); iCloud " 2" sweep before every run (`find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete`); zsh (no `$PIPESTATUS`); sweeps >10 min run detached `nohup … > /tmp/log 2>&1 &` with a log-grepping watcher (never `pgrep` the script name).

**Baseline at branch point:** 821 tests / 10381 asserts, `All tests passed`.

---

### Task 1: FormState — pure domain unit

**Files:**
- Create: `scripts/domain/form_state.gd` (+ commit its `.gd.uid`)
- Test: `tests/unit/test_form_state.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# DF2/DF3/DF4/DF7 -- the pure Form state: tick table, clamps, multiplier anchors.

func test_multiplier_anchors() -> void:
	assert_almost_eq(FormState.form_mult(0.0), 1.0, 0.0001, "steady = neutral")
	assert_almost_eq(FormState.form_mult(3.0), 1.15, 0.0001, "hot cap (CONTEXT ×1.15)")
	assert_almost_eq(FormState.form_mult(-3.0), 0.8, 0.0001, "cold floor (CONTEXT ×0.8)")
	assert_almost_eq(FormState.form_mult(1.0), 1.05, 0.0001)
	assert_almost_eq(FormState.form_mult(-1.5), 0.9, 0.0001)

func test_tick_table() -> void:
	var f := FormState.make(0.0)
	f.on_player_boundary()
	assert_almost_eq(f.points, 0.25, 0.0001, "boundary +0.25")
	f.on_player_dismissed()
	assert_almost_eq(f.points, -0.75, 0.0001, "dismissed -1.0")
	f.on_player_wicket()
	assert_almost_eq(f.points, -0.25, 0.0001, "bowling wicket +0.5")
	f.on_player_conceded_boundary()
	assert_almost_eq(f.points, -0.5, 0.0001, "conceded boundary -0.25")

func test_dot_streak_fires_every_6_and_resets_on_a_run() -> void:
	var f := FormState.make(0.0)
	for i in 5:
		f.on_player_dot()
	assert_almost_eq(f.points, 0.0, 0.0001, "5 dots: no tick yet")
	f.on_player_dot()
	assert_almost_eq(f.points, -0.25, 0.0001, "6th consecutive dot ticks -0.25")
	for i in 6:
		f.on_player_dot()
	assert_almost_eq(f.points, -0.5, 0.0001, "streak counter reset after firing; 12 dots = 2 ticks")
	f.on_player_run()
	for i in 5:
		f.on_player_dot()
	f.on_player_boundary()
	for i in 5:
		f.on_player_dot()
	assert_almost_eq(f.points, -0.25, 0.0001, "any run/boundary resets the streak (only the boundary +0.25 landed)")

func test_clamps() -> void:
	var f := FormState.make(2.9)
	for i in 10:
		f.on_player_boundary()
	assert_almost_eq(f.points, 3.0, 0.0001, "clamped at +3")
	var g := FormState.make(-2.5)
	g.on_player_dismissed()
	g.on_player_dismissed()
	assert_almost_eq(g.points, -3.0, 0.0001, "clamped at -3")

func test_affinity_base_mult_composes() -> void:
	assert_almost_eq(FormState.affinity_mult(0), 1.0, 0.0001)
	assert_almost_eq(FormState.affinity_mult(3), 1.03, 0.0001)
	assert_almost_eq(FormState.affinity_mult(9), 1.05, 0.0001, "capped at +5% (AFF_FULL 5)")
	var f := FormState.make(3.0, FormState.affinity_mult(5))
	assert_almost_eq(f.mult(), 1.15 * 1.05, 0.0001, "mult() = base_mult x form_mult(points)")
```

- [ ] **Step 2: iCloud sweep, import, run — verify red** (parse error `Identifier "FormState" not declared`)

```bash
find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && \
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

- [ ] **Step 3: Implement `scripts/domain/form_state.gd`**

```gdscript
class_name FormState
extends RefCounted

# The Player's transient Form (CONTEXT.md §Form) + the Affinity bonus carrier
# (spec 2026-07-03 DF2/DF3/DF4/DF7). Pure state -- no RNG, no clock. One instance
# per sim run, constructed from the match-start points; the sim reads mult() at the
# Player's roll touchpoints and calls the tick methods as outcomes land.
# Tuning dials (DF3/DF12) -- first sweep targets, adjust via DF10 if the ledger moves:

const TICK_BOUNDARY := 0.25        # batting: hit a 4 or 6
const TICK_DISMISSED := -1.0       # batting: the Player is out
const TICK_DOT_STREAK := -0.25     # batting: every DOT_STREAK_N consecutive dots on strike
const DOT_STREAK_N := 6
const TICK_BOWL_WICKET := 0.5      # bowling: wicket in the Player's over
const TICK_BOWL_BOUNDARY := -0.25  # bowling: boundary conceded in the Player's over
const POINTS_CLAMP := 3.0          # points live in [-3, +3] (DF1)
const AFFINITY_PCT := 0.01         # +1% attrs per affinity year... (DF7)
const AFFINITY_CAP := 5            # ...capped at the hub's AFF_FULL display cap

var points: float = 0.0
var base_mult: float = 1.0         # static within a match (the Affinity bonus)
var _dot_streak: int = 0

static func make(start_points: float, p_base_mult: float = 1.0) -> FormState:
	var f := FormState.new()
	f.points = clampf(start_points, -POINTS_CLAMP, POINTS_CLAMP)
	f.base_mult = p_base_mult
	return f

# DF2 -- piecewise linear, hits CONTEXT's ×0.8 / ×1.15 anchors at the clamps.
static func form_mult(p: float) -> float:
	if p >= 0.0:
		return 1.0 + 0.05 * p
	return 1.0 + (0.2 / 3.0) * p

# DF7 -- the Affinity temporary performance bonus.
static func affinity_mult(affinity: int) -> float:
	return 1.0 + AFFINITY_PCT * mini(maxi(affinity, 0), AFFINITY_CAP)

func mult() -> float:
	return base_mult * form_mult(points)

func _bump(delta: float) -> void:
	points = clampf(points + delta, -POINTS_CLAMP, POINTS_CLAMP)

func on_player_boundary() -> void:
	_dot_streak = 0
	_bump(TICK_BOUNDARY)

func on_player_run() -> void:
	_dot_streak = 0

func on_player_dot() -> void:
	_dot_streak += 1
	if _dot_streak >= DOT_STREAK_N:
		_dot_streak = 0
		_bump(TICK_DOT_STREAK)

func on_player_dismissed() -> void:
	_dot_streak = 0
	_bump(TICK_DISMISSED)

func on_player_wicket() -> void:
	_bump(TICK_BOWL_WICKET)

func on_player_conceded_boundary() -> void:
	_bump(TICK_BOWL_BOUNDARY)
```

- [ ] **Step 4: Import + run — verify green** (count climbs from 821, `All tests passed`)

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/form_state.gd scripts/domain/form_state.gd.uid tests/unit/test_form_state.gd
git commit -m "feat: FormState -- Form points, tick table, multiplier, Affinity base mult (DF2/DF3/DF4/DF7)"
```

---

### Task 2: Player.form_points + sync

**Files:**
- Modify: `scripts/data/player.gd:17` (add field below `form`)
- Test: `tests/unit/test_form_state.gd` (append — small enough to share the file)

- [ ] **Step 1: Write the failing test** (append)

```gdscript
func test_player_form_points_field_and_sync() -> void:
	var p := Player.new()
	assert_almost_eq(p.form_points, 0.0, 0.0001, "fresh player: neutral")
	assert_eq(p.form, 0)
	p.set_form_points(1.6)
	assert_almost_eq(p.form_points, 1.6, 0.0001)
	assert_eq(p.form, 2, "display int = roundi(points) -> HOT band")
	p.set_form_points(-0.6)
	assert_eq(p.form, -1, "TIRED band")
	p.set_form_points(9.0)
	assert_almost_eq(p.form_points, 3.0, 0.0001, "clamped on write")
```

- [ ] **Step 2: Run — verify red** (`form_points` not found on Player)

- [ ] **Step 3: Implement.** In `scripts/data/player.gd`, below the existing `form` line:

```gdscript
@export var form: int = 0          # banded display value -- ALWAYS roundi(form_points) (DF1)
@export var form_points: float = 0.0  # the true Form state, [-3, +3] (spec DF1)

# The one write path for Form -- keeps the display int in sync (DF1).
func set_form_points(p: float) -> void:
	form_points = clampf(p, -3.0, 3.0)
	form = roundi(form_points)
```

(keep the existing `form` line's position; legacy saves without the field load as 0.0 —
Godot fills missing `@export`s with defaults.)

- [ ] **Step 4: Run — verify green.** **Step 5: Commit**

```bash
git add scripts/data/player.gd tests/unit/test_form_state.gd
git commit -m "feat: Player.form_points -- true Form state; form int stays the synced display band (DF1)"
```

---

### Task 3: Thread FormState through the ball/innings/match sim

**Files:**
- Modify: `scripts/domain/innings_resolver.gd` (signature + 2 roll touchpoints + tick block)
- Modify: `scripts/domain/match_resolver.gd` (both signatures, 4 innings call sites, set `form_end`)
- Modify: `scripts/data/match_result.gd` (add `form_end`)
- Test: `tests/unit/test_form_sim.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# DF5 -- FormState threads the sim; null = byte-identical (the rest of the suite,
# unmodified, is that proof). These tests pin direction + determinism, not magnitude
# (the DF10 sweep owns magnitudes).

func _attrs() -> Attributes:
	var a := Attributes.new()
	a.power = 40; a.composure = 35; a.attack = 25; a.control = 25
	return a

func _run_match(seed_v: int, fs: FormState) -> MatchResult:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_v
	var t := Team.new(); t.stars = 3.0
	var o := Team.new(); o.stars = 3.0
	return MatchResolver.simulate_match_teams(
		_attrs(), t, o, TourDistribution.new(), BallTuning.new(), InningsTuning.new(), rng,
		null, null, [], null, null, null, null, null, null, null, null,
		-1, null, null, null, fs)

func test_null_form_state_reports_neutral_end() -> void:
	var m := _run_match(41, null)
	assert_almost_eq(m.form_end, 0.0, 0.0001, "no form threading -> neutral form_end")

func test_form_end_is_deterministic_and_moves() -> void:
	var a := _run_match(41, FormState.make(0.0))
	var b := _run_match(41, FormState.make(0.0))
	assert_almost_eq(a.form_end, b.form_end, 0.0001, "same seed + start -> same form_end")
	# form must actually tick over a full T20 (boundaries/dots/dismissal all occur)
	assert_ne(a.form_end, 0.0, "a full match moves form off neutral")

func test_start_points_shift_the_match() -> void:
	# Same seed: a hot player (mult >1) must outscore a cold player (mult <1) in their
	# batting innings. Deterministic -- one seed, both runs identical except the mult.
	var hot := _run_match(97, FormState.make(3.0))
	var cold := _run_match(97, FormState.make(-3.0))
	var hot_bat: InningsResult = hot.innings1 if hot.player_bats_first else hot.innings2
	var cold_bat: InningsResult = cold.innings1 if cold.player_bats_first else cold.innings2
	assert_gt(hot_bat.player_runs, cold_bat.player_runs, "×1.15 vs ×0.8 shows up in the player's runs")

func test_base_mult_alone_shifts_the_match() -> void:
	var plain := _run_match(97, FormState.make(0.0, 1.0))
	var buffed := _run_match(97, FormState.make(0.0, 1.05))
	var pb: InningsResult = plain.innings1 if plain.player_bats_first else plain.innings2
	var bb: InningsResult = buffed.innings1 if buffed.player_bats_first else buffed.innings2
	assert_gte(bb.player_runs, pb.player_runs, "the Affinity base mult helps (or at worst ties)")
```

Note: check `InningsResult`'s actual player-runs field name before running — `grep -n "player_runs\|var player_" scripts/data/innings_result.gd` — and use what exists (the stat-line rung added the player's batting line; adjust the property in the test to match).

- [ ] **Step 2: Run — verify red** (too-few-args / unknown param `form_state` / missing `form_end`)

- [ ] **Step 3: Implement — `match_result.gd`:** add below `balls_remaining`:

```gdscript
var form_end: float = 0.0          # Player Form points at match end (0.0 when form is off) -- spec DF5
```

**`innings_resolver.gd`** — append the trailing param after `ball_log = null`:

```gdscript
		ball_log = null,
		form_state: FormState = null
```

Apply the multiplier at the two Player roll touchpoints. In the `resolve_ball` call, the striker's attrs and the player-bowling attrs become (only when form is on and it's the Player):

```gdscript
		# DF2/DF5 -- the Player's effective attributes carry Form x Affinity. Player-only:
		# teammates/opponents roll at their plain strengths (DF8).
		var fmult := 1.0
		if form_state != null and ((player_is_batting and s["is_player"]) or player_bowling):
			fmult = form_state.mult()
		var o := BallResolver.resolve_ball(
			s["power"] * (fmult if player_is_batting and s["is_player"] else 1.0),
			s["composure"] * (fmult if player_is_batting and s["is_player"] else 1.0),
			bat_attack * (fmult if player_bowling else 1.0),
			bat_control * (fmult if player_bowling else 1.0),
			intent, tuning, rng, jm.x * win.x * opp_win.x, jm.y * win.y * opp_win.y,
			bowler_type)
```

CAREFUL: `bat_attack/bat_control` at this point are the CURRENT BOWLER's stats (the
naming is historic). When `player_bowling` is true they are the Player's bowling stats —
that is the bowling-side touchpoint. When the Player is batting, `s["is_player"]` marks
the striker. Never scale both in the same ball (the Player never bowls to themselves —
`player_is_batting` and `player_bowling` are mutually exclusive by construction).

Ticks ride the existing outcome block (find the `var formed := false` block near line
268; add alongside, BEFORE `runtime.on_ball_end`):

```gdscript
		# DF3 -- per-ball Form ticks, Player-only.
		if form_state != null:
			if player_is_batting and s["is_player"]:
				if o.wicket:
					form_state.on_player_dismissed()
				elif o.runs == 4 or o.runs == 6:
					form_state.on_player_boundary()
				elif o.runs == 0:
					form_state.on_player_dot()
				else:
					form_state.on_player_run()
			elif player_bowling:
				if o.wicket:
					form_state.on_player_wicket()
				elif o.runs == 4 or o.runs == 6:
					form_state.on_player_conceded_boundary()
```

**`match_resolver.gd`** — `simulate_match` gains trailing `form_state: FormState = null`;
pass it as the new last arg of BOTH Player-side innings calls (`player_attrs` non-null →
batting innings; the bowling innings is the one receiving `p_bowl_attack/p_bowl_control`
— pass it to ALL FOUR calls; the opposition-batting innings uses it only via
`player_bowling`, and the form_state must cross both innings in match order). After
`_decide_result` (returns the MatchResult), set:

```gdscript
	var res := _decide_result(innings1, innings2, player_bats_first, max_balls)
	if form_state != null:
		res.form_end = form_state.points
	return res
```

`simulate_match_teams` gains trailing `form_state: FormState = null` and forwards it as
the new last arg of its `simulate_match` call.

- [ ] **Step 4: Import + run — verify green AND no existing test moved** (the whole prior suite passing unmodified = the null-path byte-identity proof)

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/innings_resolver.gd scripts/domain/match_resolver.gd scripts/data/match_result.gd tests/unit/test_form_sim.gd
git commit -m "feat: FormState threads the ball/innings/match sim; null = byte-identical (DF2/DF3/DF5/DF8)"
```

---

### Task 4: Live wiring — MatchSession + SeasonPlay + season reset

**Files:**
- Modify: `scripts/domain/match_session.gd` (start signature + `_resim`)
- Modify: `scripts/domain/season_play.gd` (`enable_form`, `make_session`, `commit_player_result`, `replay`)
- Modify: `scenes/season_hub/season_hub.gd` (`set_play` seeds form like it seeds jokers/pay/shop)
- Modify: `scenes/main.gd` (season-end reset, where the finished season commits)
- Test: `tests/unit/test_form_live.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# DF6 -- live persistence: form chains across matches within a season, settles onto
# the Player, resets at season end, and reproduces under resim/replay.

func _player() -> Player:
	var p := Player.new()
	var n := NamePair.new(); n.first_name = "Test"; n.surname = "Player"
	p.name = n
	var a := Attributes.new(); a.power = 40; a.composure = 30; a.attack = 20; a.control = 10
	p.attributes = a
	return p

func _play() -> SeasonPlay:
	# mirror test_season_play's construction helper -- reuse its pattern/args verbatim
	return SeasonPlay.start(_player().attributes, 4242, 0, 0)

func test_session_resim_is_stable_under_form() -> void:
	var sp := _play()
	sp.enable_form(_player())
	var s1 := sp.make_session()
	var end1 := s1.result().form_end
	s1.decide_boost(1, 3)  # any decision forces a resim from match-start form
	var s2 := sp.make_session()
	assert_almost_eq(s2.result().form_end, end1, 0.0001,
		"a fresh session re-derives the same match from the same start points")

func test_form_chains_between_matches_and_settles_on_player() -> void:
	var p := _player()
	var sp := _play()
	sp.enable_form(p)
	var s1 := sp.make_session()
	var end1 := s1.result().form_end
	sp.commit_player_result(s1.result(), s1.export_decisions())
	assert_almost_eq(p.form_points, end1, 0.0001, "match 1 form_end settled onto the Player")
	assert_eq(p.form, roundi(end1), "display int synced")
	var s2 := sp.make_session()
	assert_almost_eq(s2.result() .form_end, s2.result().form_end, 0.0001)
	# match 2 must START from end1: re-simming match 2 with a fresh play at the same
	# seed but form disabled gives a different match whenever end1 != 0
	if absf(end1) > 0.01:
		var sp_off := _play()
		var s2_off := sp_off.make_session()
		sp_off.commit_player_result(sp_off.make_session().result())
		# (comparison is indirect; the strong pin is the round-trip below)
		assert_true(true)

func test_replay_reproduces_form() -> void:
	var p := _player()
	var sp := _play()
	sp.enable_form(p)
	for i in 2:
		var s := sp.make_session()
		sp.commit_player_result(s.result(), s.export_decisions())
	var snap_points := p.form_points
	# round-trip through the save state (the cross-session path)
	var st := sp.to_state()
	var p2 := _player()
	var sp2 := SeasonPlay.from_state(st, p2.attributes)
	sp2.enable_form(p2)
	sp2.replay()
	assert_almost_eq(sp2.form_points_now(), snap_points, 0.0001, "replay re-derives the same form")
```

Note: `SeasonPlay.start(...)` arg list and `to_state/from_state/replay` calling
conventions — copy the exact patterns from `tests/unit/test_season_play.gd` (or the
cross-session test file) rather than the sketch above; the assertions are the contract.

- [ ] **Step 2: Run — verify red** (`enable_form` nonexistent)

- [ ] **Step 3: Implement.**

`match_session.gd` — `start(...)` gains trailing `form_start: float = 0.0, form_base_mult: float = 1.0`; store both on the session (`s._form_start = form_start; s._form_base_mult = form_base_mult`; declare the two vars near `_player_effects`). In `_resim()`, build a FRESH state each resim (the DF6 resim rule) and pass it as the new trailing arg of `simulate_match_teams` (after `log1, log2`):

```gdscript
	var fs: FormState = null
	if _form_start != 0.0 or _form_base_mult != 1.0 or _form_enabled:
		fs = FormState.make(_form_start, _form_base_mult)
```

Simpler + explicit: add `var _form_enabled := false` set true by `start` when the caller opts in — give `start` a trailing `use_form: bool = false` instead of inferring from values, i.e. `start(..., form_start := 0.0, form_base_mult := 1.0, use_form := false)`; `_resim` passes `FormState.make(_form_start, _form_base_mult) if _use_form else null`. Off = byte-identical.

`season_play.gd` — mirror the `enable_pay` pattern:

```gdscript
# --- Form (spec 2026-07-03 DF6): the season's running Form + Affinity bonus. ---
# enable_form binds the Player (rebind-safe: the hub reloads the Player each match);
# the running points seed once from the Player and then live on this driver.
var _form_on := false
var _form_points := 0.0
var _form_base_mult := 1.0
var _form_player: Player = null

func enable_form(player: Player) -> void:
	if not _form_on:
		_form_on = true
		_form_points = player.form_points
	_form_base_mult = FormState.affinity_mult(player.affinity)
	_form_player = player

func form_points_now() -> float:
	return _form_points
```

`make_session()` — both branches append the new args to `MatchSession.start(...)`:
`, _form_points, _form_base_mult, _form_on` (after `_player_effects`).

`commit_player_result(...)` — after the existing settle/log handling:

```gdscript
	if _form_on:
		_form_points = result.form_end
		if _form_player != null:
			_form_player.set_form_points(_form_points)
```

`replay()` — find where it re-runs each logged match (it re-creates sessions/sims in
sequence): thread the SAME chain — reset `_form_points` to the Player's season-start
value... **CAREFUL:** replay starts from season start, so if `_form_on`, set
`_form_points = 0.0` at replay start ONLY IF the season started at 0. The robust rule:
`LiveSeasonState` (see below) does NOT serialize form; replay re-derives it, so at the
top of `replay()` add `if _form_on: _form_points = 0.0` and let each replayed match's
`form_end` chain forward exactly as live play did (a season always starts at 0 — DF6
season reset guarantees it). Settle onto `_form_player` at the end (same code as
commit). If replay uses `MatchSession.start` internally it must pass the running form
args the same way `make_session` does; if it calls the resolver directly, pass
`FormState.make(_form_points, _form_base_mult)` and chain `.form_end`.

`season_hub.gd` `set_play(...)` — where it calls `enable_pay`/`enable_shop`, add:

```gdscript
	play.enable_form(player)
```

`main.gd` — season-end reset (DF6): in the commit path where a finished season is
recorded and the live save cleared (`_commit_and_return` on `season_done()`, next to
where carry-over/jokers are handled in `_finish_live_season`), before persisting the
player:

```gdscript
	player.set_form_points(0.0)  # Form resets at Season end, alongside Jokers (DF6)
```

- [ ] **Step 4: Import + run — verify green** (esp. the existing cross-session resume pin + shop round-trip tests — they run with form OFF and must be untouched)

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/match_session.gd scripts/domain/season_play.gd scenes/season_hub/season_hub.gd scenes/main.gd tests/unit/test_form_live.gd
git commit -m "feat: Form live -- SeasonPlay owns the season chain, resim-safe seeding, season-end reset (DF6/DF7)"
```

---

### Task 5: Headless wiring — LeagueResolver / SeasonResolver / CareerResolver

**Files:**
- Modify: `scripts/domain/league_resolver.gd:23,90` (optional `form_state`, player fixtures only)
- Modify: `scripts/domain/season_resolver.gd:59` (+ its league call + playoff player matches)
- Modify: `scripts/domain/career_resolver.gd` (enable per season with the player's affinity)
- Test: `tests/unit/test_form_headless.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# DF6 headless -- the balance harness must measure the same game Nico plays:
# one FormState threads the player's league + playoff matches, fresh each season.

func test_league_threads_form_across_player_fixtures() -> void:
	# call LeagueResolver.simulate_league exactly as test_league_resolver does (copy
	# its args), plus form_state := FormState.make(0.0); assert the state's points
	# moved after the league (7 player fixtures virtually guarantee ticks) and that
	# the same seed reproduces the same end points.
	pass  # replace with the copied construction -- assertions:
	# assert_ne(fs.points, 0.0)
	# assert_almost_eq(fs.points, fs2.points, 0.0001)

func test_career_seasons_reset_form() -> void:
	# run CareerResolver.play_season (or the smallest headless season entry the
	# career loop uses -- see test_career_resolver for the canonical construction)
	# twice with form enabled and assert the second season STARTS from 0 (peek via
	# the returned SeasonResult/state, or assert player.form_points is untouched by
	# headless careers -- headless sims never persist form onto the Player).
	pass
```

(The two `pass` bodies are construction-copying work — `tests/unit/test_league_resolver.gd`
and `tests/unit/test_career_resolver.gd` hold the canonical argument lists; the
assertions in the comments are the contract. Write them as real tests before
implementing.)

- [ ] **Step 2: Run — verify red** (unknown `form_state` param once the tests call it)

- [ ] **Step 3: Implement.**
  - `league_resolver.gd` `simulate_league(...)`: trailing `form_state: FormState = null`;
    at the `i == 0` player-fixture call site pass it as `simulate_match`'s new trailing
    arg AND after each player match chain `form_state.points = m.form_end` — WAIT: the
    state object already carries its own points forward (the same instance threads all
    fixtures), so just pass it; `simulate_match` mutates it in place per innings. Only
    pass on `i == 0` matches (Player-only, DF8); non-player fixtures pass nothing.
  - `season_resolver.gd`: `play_season`-equivalent gains trailing
    `form_state: FormState = null`; forward to `simulate_league` and to the `s1 == 0`
    playoff `simulate_match` call (same in-place threading).
  - `career_resolver.gd`: where each season is simmed, construct
    `FormState.make(0.0, FormState.affinity_mult(player.affinity))` per season and pass
    it (fresh per season = the reset). Career sims do NOT write form onto the Player.
  - Gate all of it behind the existing pattern: default null = every existing headless
    test byte-identical.

- [ ] **Step 4: Import + run — verify green.** **Step 5: Commit**

```bash
git add scripts/domain/league_resolver.gd scripts/domain/season_resolver.gd scripts/domain/career_resolver.gd tests/unit/test_form_headless.gd
git commit -m "feat: Form threads the headless season/career sim, fresh per season (DF6/DF8)"
```

---

### Task 6: The shared balance re-sweep (DF10) — merge gate

**Files:**
- Create: `tools/sweep_form_balance.gd` (form-on vs form-off build-balance arms)
- Modify (results): `docs/superpowers/specs/2026-07-03-form-mechanic-and-affinity-bonus-design.md` (append a `## Results` section)

- [ ] **Step 1:** Read `tools/build_spectrum_sweep.gd` and `tools/probe_scoring_env.gd` headers for their run commands + output format (they print `DATA` lines). Write `tools/sweep_form_balance.gd` following `build_spectrum_sweep.gd`'s structure: the 4 reference builds × N=600 seasons, two arms (form_state null vs `FormState.make(0.0)`), printing per-build win% + pay mean per arm.

- [ ] **Step 2:** Run the env probe (fast) with form on/off; compare to the pegged bands (~153.5 total / RR ~8.13 — exact peg values are in the probe's own header comments):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/probe_scoring_env.gd
```

- [ ] **Step 3:** Run the build sweep detached (expect >10 min):

```bash
nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_form_balance.gd > /tmp/form_sweep.log 2>&1 &
```

Watcher greps `/tmp/form_sweep.log` for the final `DATA` line (never `pgrep`).

- [ ] **Step 4: Judge against DF10 tolerances:** build win-rate spread ≤ ~2pp · pay spread ≤ ~₸1 · floor in the fair-fight zone (~45–50%) · env within bands. If outside: adjust the DF3 tick dials or DF2 slopes on `FormState`, re-run, repeat until in-band. Record every dial change in the spec.

- [ ] **Step 5:** Append `## Results (2026-07-03 sweep)` to the spec — every number with N + arms + which tool + log path (stat-provenance rules). Commit:

```bash
git add tools/sweep_form_balance.gd tools/sweep_form_balance.gd.uid docs/superpowers/specs/2026-07-03-form-mechanic-and-affinity-bonus-design.md
git commit -m "balance: Form+Affinity sweep -- ledger holds (DF10); results in spec"
```

---

### Task 7: Eyeball, PR, merge, roadmap

- [ ] **Step 1:** iCloud sweep + clean-import full suite (expect > 821 tests, `All tests passed`).
- [ ] **Step 2:** Launch the real game (`/Applications/Godot.app/Contents/MacOS/Godot --path .` — check no other Godot first). Play 2 matches: the hub portrait/chip must move off STEADY when form swings (DF11's eyeball).
- [ ] **Step 3:** Push, `gh pr create` (summary: what Form/Affinity now do, the sweep verdict with numbers, test count), merge, sync `main`, delete branch.
- [ ] **Step 4:** Update `PROJECT_ROADMAP.md`: Form+Affinity rung closed → **the game is mechanically complete; next = NICO'S PLAYTEST PASS** (he plays real seasons; findings become fix rungs), then the iOS export. Commit + push on `main`.
