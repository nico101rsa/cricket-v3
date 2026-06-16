# Live League Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** From the Season Hub, play your 7 league fixtures forward one at a time — each interactively (Boost/DRS, the PR #67 screen) — with a real running league table that updates as you go, ending at the final league table.

**Architecture:** A new pure `SeasonPlay` driver (`scripts/domain/`) schedules the league in player-fixture order, auto-resolves the 21 AI-vs-AI fixtures once at `start` on held strengths (derived `simulate_match` path), and hands each of your fixtures to the existing interactive `MatchSession`. It grows a `LeagueResult` (running standings recomputed from revealed fixtures + your committed matches) and exposes a `SeasonResult`-shaped view so the existing `SeasonViewBuilder` renders the hub almost unchanged. `LeagueResolver`/`SeasonResolver` are never touched → zero balance-ledger risk.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6. Tabs for indent. Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`.

---

## Conventions for every task

- **Import before test** (registers new `class_name`s): run
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
  then the suite. Chain them in ONE command (never overlap Godot processes).
- **Run the suite (whole dir — `-gtest` does not filter here):**
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- **Red** = `SCRIPT ERROR: Parse Error: Identifier "SeasonPlay" not declared` (GUT logs + skips the file). **Green** = total test count climbs + `All tests passed`.
- Quit the Godot editor (⌘Q) before any headless run. If GUT fails to load, clean iCloud `" 2"` junk:
  `find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot` then re-import.
- Commit `scripts/**/*.gd.uid` (Godot generates them). Test files under `tests/` get **no** `.uid` — add only the `.gd`.
- Baseline before starting: **610 green** (per roadmap). Each task should keep the suite green.

---

## File Structure

- **Create** `scripts/domain/season_play.gd` — `SeasonPlay` driver (the whole rung's logic).
- **Create** `tests/unit/test_season_play.gd` — driver unit tests.
- **Modify** `scenes/season_hub/season_hub.gd` — forward-play render: PLAY control on the next fixture; boot builds a `SeasonPlay`; render via `SeasonViewBuilder` on `live_season()`.
- **Modify** `tests/unit/test_season_hub.gd` (if present) — inject a `SeasonPlay`, assert running table + PLAY control.
- **Modify** `scenes/main.gd` — `play_next` wiring: push the Interactive Match scene with `SeasonPlay.make_session()`, commit on `back`.
- **Create** `tools/preview_live_league.gd` — visual harness + screenshot.

---

## Task 1: `SeasonPlay` — construction, schedule, counts

**Files:**
- Create: `scripts/domain/season_play.gd`
- Test: `tests/unit/test_season_play.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# Build a CareerState-free fixture: a player team + 7 opponents, plain tour.
func _opps() -> Array:
	var out: Array = []
	for k in range(7):
		var t := Team.new()
		t.team_name = "Opp %d" % (k + 1)
		t.stars = 2.5
		out.append(t)
	return out

func _player_team() -> Team:
	var t := Team.new()
	t.team_name = "My XI"
	t.stars = 2.5
	return t

func _tour() -> TourDistribution:
	return TourDistribution.new()

func test_start_schedules_seven_player_fixtures() -> void:
	var sp := SeasonPlay.start(Attributes.new(), _player_team(), _opps(),
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)
	assert_eq(sp.total_player_fixtures(), 7, "7 league fixtures")
	assert_eq(sp.played_count(), 0, "none played at start")
	assert_false(sp.league_done(), "league not done at start")

func test_next_player_opponent_is_first_opponent() -> void:
	var opps := _opps()
	var sp := SeasonPlay.start(Attributes.new(), _player_team(), opps,
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)
	var nxt := sp.next_player_opponent()
	assert_eq(nxt["name"], "Opp 1", "fixtures run in opponents order")
	assert_eq(nxt["team_index"], 1, "team_index 1 = first opponent")
```

- [ ] **Step 2: Run the suite — verify RED**

Run the import+suite chain. Expected: `Parse Error: Identifier "SeasonPlay" not declared` for the new test file.

- [ ] **Step 3: Minimal implementation**

```gdscript
class_name SeasonPlay
extends RefCounted

# Live LEAGUE-phase driver for the forward-play Season Hub (spec
# 2026-06-16-live-league-loop §3). Pure: no scene tree, no SaveManager, no
# tuning literals. Schedules the league in player-fixture order, auto-resolves
# the 21 AI fixtures once at start (held strengths, derived simulate_match path),
# and hands each of your 7 fixtures to an interactive MatchSession. Grows a
# LeagueResult; LeagueResolver/SeasonResolver are untouched (zero ledger risk).

const NUM_TEAMS := 8
const PLAYER_FIXTURES := 7
const AI_PER_PLAYER_GAME := 3   # 21 AI fixtures / 7 player games (DS1 reveal cadence)

var _attrs: Attributes
var _teams: Array            # [player_team] + opponents, index-aligned with the table
var _tour: TourDistribution
var _tuning: BallTuning
var _itun: InningsTuning
var _seed: int

var _bat: Array = []         # held per-team batting strength (ADR 0009), index-aligned
var _bowl: Array = []        # held per-team bowling strength
var _ai_fixtures: Array = [] # resolved AI-vs-AI completed records (see _CompletedFixture)
var _player_results: Array = []   # committed MatchResult, one per played player game

static func start(player_attrs: Attributes, player_team: Team, opponents: Array,
		tour: TourDistribution, tuning: BallTuning, itun: InningsTuning,
		seed: int) -> SeasonPlay:
	var sp := SeasonPlay.new()
	sp._attrs = player_attrs
	sp._teams = [player_team]
	sp._teams.append_array(opponents)
	sp._tour = tour
	sp._tuning = tuning
	sp._itun = itun
	sp._seed = seed
	sp._draw_strengths()
	sp._resolve_ai_fixtures()
	return sp

func total_player_fixtures() -> int:
	return PLAYER_FIXTURES

func played_count() -> int:
	return _player_results.size()

func league_done() -> bool:
	return played_count() >= PLAYER_FIXTURES

# {name, team_index} of the next unplayed opponent, or {} when the league is done.
func next_player_opponent() -> Dictionary:
	if league_done():
		return {}
	var idx := played_count() + 1   # opponents are teams[1..7]; fixture k -> team idx k+1... (see note)
	var opp: Team = _teams[idx]
	return {"name": opp.team_name, "team_index": idx}

# --- internals (filled in Task 2) ---
func _draw_strengths() -> void:
	pass

func _resolve_ai_fixtures() -> void:
	pass
```

> Note on indices: player game *k* (0-based `played_count()`) is the fixture vs `_teams[k+1]`, so `next_player_opponent()` uses `idx = played_count() + 1`.

- [ ] **Step 4: Run the suite — verify GREEN** (count climbs by 2, `All tests passed`).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/season_play.gd scripts/domain/season_play.gd.uid tests/unit/test_season_play.gd
git commit -m "SeasonPlay: construction + player-fixture schedule (live league loop)"
```

---

## Task 2: held strengths + AI-fixture resolution + running standings

**Files:**
- Modify: `scripts/domain/season_play.gd`
- Test: `tests/unit/test_season_play.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
func test_standings_has_eight_rows_and_is_sorted() -> void:
	var sp := SeasonPlay.start(Attributes.new(), _player_team(), _opps(),
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)
	var lg := sp.live_league()
	assert_eq(lg.standings.size(), 8, "all 8 teams in the table")
	# sorted by points desc (ties broken later) — points are non-increasing
	for i in range(lg.standings.size() - 1):
		assert_true(lg.standings[i].points >= lg.standings[i + 1].points,
			"standings sorted by points desc")

func test_no_ai_revealed_before_first_game() -> void:
	var sp := SeasonPlay.start(Attributes.new(), _player_team(), _opps(),
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)
	# played_count 0 -> 0 AI fixtures revealed -> every row has 0 games played
	var lg := sp.live_league()
	var total_played := 0
	for r in lg.standings:
		total_played += r.played
	assert_eq(total_played, 0, "nothing revealed before you play")
```

- [ ] **Step 2: Run the suite — verify RED** (`live_league` not declared → these new tests error/skip; the file still parses since the method is missing → actually a missing method is a runtime error: the assert calls fail. Treat the failing/erroring new tests as RED.)

- [ ] **Step 3: Implementation**

Replace the two stub internals and add the standings builder + `live_league`/`live_season`:

```gdscript
func _draw_strengths() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	for t in _teams:
		_bat.append(t.batting_strength(_tour, rng))
		_bowl.append(t.bowling_strength(_tour, rng))

# Resolve the 21 AI-vs-AI fixtures (all pairs i<j with i>=1) once, in round_robin
# order, on a fresh seeded RNG. Derived simulate_match path (null player) =
# LeagueResolver's non-player path. Stored as completed records for the table.
func _resolve_ai_fixtures() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 1   # distinct stream from the strength draw
	for fx in LeagueResolver.round_robin(NUM_TEAMS):
		var i: int = fx.x
		var j: int = fx.y
		if i == 0:
			continue   # player fixtures are played interactively, not here
		var i_bats_first := MatchResolver._resolve_toss(rng)
		var m := MatchResolver.simulate_match(
			null, _bat[i], _bowl[i], _bowl[i],
			_bat[j], _bowl[j], _bowl[j],
			i_bats_first, _tuning, _itun, rng)
		_ai_fixtures.append(_completed(i, j, m, i_bats_first))

# Pack a finished match into the index-keyed totals the table needs.
func _completed(i: int, j: int, m: MatchResult, i_bats_first: bool) -> Dictionary:
	var i_inns: InningsResult = m.innings1 if i_bats_first else m.innings2
	var j_inns: InningsResult = m.innings2 if i_bats_first else m.innings1
	return {
		"i": i, "j": j,
		"i_total": i_inns.total, "i_balls": i_inns.balls,
		"j_total": j_inns.total, "j_balls": j_inns.balls,
		"outcome": m.outcome,   # PLAYER_WIN = team i won, OPPONENT_WIN = team j won
	}

# Rebuild the standings from the revealed fixture subset (DS1): the first
# 3*played_count AI fixtures + your played games. Recomputed each call (no
# incremental drift). Mirrors LeagueResolver's accumulation + sort.
func live_league() -> LeagueResult:
	var rows: Array = []
	for idx in range(NUM_TEAMS):
		var row := StandingsRow.new()
		row.team_index = idx
		rows.append(row)

	var ai_revealed := mini(_ai_fixtures.size(), AI_PER_PLAYER_GAME * played_count())
	for k in range(ai_revealed):
		_apply(rows, _ai_fixtures[k])

	var player_matches: Array = []
	for k in range(_player_results.size()):
		var m: MatchResult = _player_results[k]
		var i_bats_first := m.player_bats_first
		# Player is team 0 (i); opponent is team k+1 (j).
		_apply(rows, _completed(0, k + 1, m, i_bats_first))
		player_matches.append(m)

	rows.sort_custom(func(a: StandingsRow, b: StandingsRow) -> bool:
		if a.points != b.points:
			return a.points > b.points
		var na := a.nrr()
		var nb := b.nrr()
		if not is_equal_approx(na, nb):
			return na > nb
		return a.team_index < b.team_index)

	var result := LeagueResult.new()
	result.standings = rows
	result.player_matches = player_matches
	result.team_bat = _bat
	result.team_bowl = _bowl
	for pos in range(rows.size()):
		if rows[pos].team_index == 0:
			result.player_position = pos + 1
			break
	result.made_playoffs = result.player_position <= LeagueResolver.PLAYOFF_CUTOFF
	return result

func _apply(rows: Array, f: Dictionary) -> void:
	var ri: StandingsRow = rows[f["i"]]
	var rj: StandingsRow = rows[f["j"]]
	ri.played += 1
	rj.played += 1
	ri.runs_for += f["i_total"]; ri.balls_for += f["i_balls"]
	ri.runs_against += f["j_total"]; ri.balls_against += f["j_balls"]
	rj.runs_for += f["j_total"]; rj.balls_for += f["j_balls"]
	rj.runs_against += f["i_total"]; rj.balls_against += f["i_balls"]
	match f["outcome"]:
		MatchResult.Outcome.PLAYER_WIN: ri.points += 2
		MatchResult.Outcome.OPPONENT_WIN: rj.points += 2
		MatchResult.Outcome.TIE:
			ri.points += 1; rj.points += 1

# SeasonResult-shaped wrapper so the existing SeasonViewBuilder renders the hub.
func live_season() -> SeasonResult:
	var sr := SeasonResult.new()
	sr.league = live_league()
	sr.player_final_position = sr.league.player_position
	return sr
```

- [ ] **Step 4: Run the suite — verify GREEN** (count climbs by 2).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/season_play.gd tests/unit/test_season_play.gd
git commit -m "SeasonPlay: held strengths, AI-fixture resolution, running standings (DS1 reveal)"
```

---

## Task 3: `make_session` + `commit_player_result` + determinism

**Files:**
- Modify: `scripts/domain/season_play.gd`
- Test: `tests/unit/test_season_play.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
func test_make_session_then_commit_advances() -> void:
	var sp := SeasonPlay.start(Attributes.new(), _player_team(), _opps(),
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)
	var sess := sp.make_session()
	assert_not_null(sess, "a MatchSession for the next fixture")
	sp.commit_player_result(sess.result())
	assert_eq(sp.played_count(), 1, "one player game played")
	assert_eq(sp.next_player_opponent()["name"], "Opp 2", "advanced to opponent 2")

func test_full_league_finishes() -> void:
	var sp := SeasonPlay.start(Attributes.new(), _player_team(), _opps(),
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)
	for k in range(7):
		sp.commit_player_result(sp.make_session().result())
	assert_true(sp.league_done(), "league done after 7 games")
	assert_eq(sp.next_player_opponent(), {}, "no next fixture")
	assert_eq(sp.live_league().standings.size(), 8, "final table intact")

func test_determinism_same_seed_same_table() -> void:
	var a := SeasonPlay.start(Attributes.new(), _player_team(), _opps(),
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)
	var b := SeasonPlay.start(Attributes.new(), _player_team(), _opps(),
		_tour(), BallTuning.new(), InningsTuning.new(), 20260616)
	for k in range(3):
		a.commit_player_result(a.make_session().result())
		b.commit_player_result(b.make_session().result())
	var ta := a.live_league().standings
	var tb := b.live_league().standings
	for i in range(8):
		assert_eq(ta[i].team_index, tb[i].team_index, "row %d team matches" % i)
		assert_eq(ta[i].points, tb[i].points, "row %d points match" % i)
```

- [ ] **Step 2: Run the suite — verify RED** (`make_session`/`commit_player_result` missing → new tests error).

- [ ] **Step 3: Implementation** — append to `SeasonPlay`:

```gdscript
# An interactive MatchSession for the current (next unplayed) player fixture.
# Derived per-fixture seed so each game diverges only on its own decisions.
func make_session() -> MatchSession:
	if league_done():
		return null
	var opp: Team = _teams[played_count() + 1]
	var fixture_seed := _seed + 100 + played_count()
	return MatchSession.start(_attrs, _teams[0], opp, _tour, fixture_seed,
		-1, _tuning, _itun)

# Fold a finished player match into the league + advance. Caller passes the
# MatchSession's result (after the player's Boost/DRS decisions).
func commit_player_result(result: MatchResult) -> void:
	if league_done():
		return
	_player_results.append(result)
```

- [ ] **Step 4: Run the suite — verify GREEN** (count climbs by 3).

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/season_play.gd tests/unit/test_season_play.gd
git commit -m "SeasonPlay: make_session + commit_player_result + determinism"
```

---

## Task 4: Hub forward-play render (running table + PLAY control)

**Files:**
- Modify: `scenes/season_hub/season_hub.gd`
- Test: `tests/unit/test_season_hub.gd` (if it exists; else add a minimal one)

Replace the pre-sim boot with a `SeasonPlay`, render via `SeasonViewBuilder` on `live_season()` at `scrub_index = played_count()`, and emit a `play_next` signal for the next-fixture PLAY button. Keep the injected-view test path.

- [ ] **Step 1: Write the failing test** (append to `tests/unit/test_season_hub.gd`; if absent, create it with `extends GutTest` + the helper below)

```gdscript
func test_live_play_renders_running_table_and_play_control() -> void:
	var hub = preload("res://scenes/season_hub/season_hub.tscn").instantiate()
	add_child_autofree(hub)
	# Build a SeasonPlay + a player/career to render.
	var opps: Array = []
	for k in range(7):
		var t := Team.new(); t.team_name = "Opp %d" % (k + 1); t.stars = 2.5
		opps.append(t)
	var pt := Team.new(); pt.team_name = "My XI"; pt.stars = 2.5
	var career := CareerResolver.start_career(0)
	# Make the career's opponents match (the builder reads opponents_of_current()).
	var player := Player.new()
	var sp := SeasonPlay.start(player.attributes, pt, career.opponents_of_current(),
		TourDistribution.new(), BallTuning.new(), InningsTuning.new(), 20260616)
	sp.commit_player_result(sp.make_session().result())   # play 1 game
	hub.set_play(player, career, sp)
	# Running table renders 8 rows.
	var standings_box: VBoxContainer = hub.get_node("Scroll/Margin/Root/StandingsBox")
	# header label + 8 rows
	assert_true(standings_box.get_child_count() >= 8, "running table rows present")
	# The PLAY control for the next fixture exists + is visible.
	assert_true(hub.has_play_control(), "next-fixture PLAY control present")
```

- [ ] **Step 2: Run the suite — verify RED** (`set_play`/`has_play_control` undeclared → error).

- [ ] **Step 3: Implementation** — in `scenes/season_hub/season_hub.gd`:

Add a `_play: SeasonPlay` field and a `play_next` signal near the top (after `signal open_match`):

```gdscript
# Emitted when the player taps PLAY on their next fixture. main.gd pushes the
# Interactive Match scene; on return it commits the result back into _play.
signal play_next(team_index: int)

var _play: SeasonPlay
```

Replace `boot()` so production builds a `SeasonPlay` instead of a pre-simmed season:

```gdscript
func boot() -> void:
	if _view != null or _play != null:
		return   # a test injected a view or a play
	if not SaveManager.has_player():
		return
	var player := SaveManager.load_player()
	var career: CareerState = SaveManager.load_career() if SaveManager.has_career() \
		else CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(career.current_level(), 0)
	var team: Team = career.teams[career.current_team_index]
	var sp := SeasonPlay.start(player.attributes, team, career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), BOOT_SEED)
	set_play(player, career, sp)
```

Add the live source + render (alongside the existing `set_source`):

```gdscript
# Live forward-play source. Renders via SeasonViewBuilder on the growing league,
# with the scrub head pinned to how many games you've played.
func set_play(player: Player, career: CareerState, play: SeasonPlay) -> void:
	_player = player
	_career = career
	_play = play
	_rebuild_live()

func _rebuild_live() -> void:
	if _play == null:
		return
	set_view(SeasonViewBuilder.build(_player, _career, _play.live_season(), _play.played_count()))

func live_play() -> SeasonPlay:
	return _play

func has_play_control() -> bool:
	return _play != null and not _play.league_done() \
		and _root.get_node_or_null("PlayNextBtn") != null
```

In `_render()`, after `_render_fixtures(accent)` (or at the end), add the PLAY button render:

```gdscript
	_render_play_next(accent)
```

And the method:

```gdscript
# The next-fixture PLAY button (live path only). A solid StyleBoxFlat tile (not a
# flat button — flat+modulate renders invisibly, per CLAUDE.md), placed under the
# fixtures. Hidden once the league is done.
func _render_play_next(accent: Color) -> void:
	var existing := _root.get_node_or_null("PlayNextBtn")
	if existing != null:
		existing.queue_free()
	if _play == null or _play.league_done():
		return
	var nxt := _play.next_player_opponent()
	var btn := Button.new()
	btn.name = "PlayNextBtn"
	btn.text = "▶ PLAY  —  v %s" % nxt["name"]
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var idx: int = nxt["team_index"]
	btn.pressed.connect(func(): play_next.emit(idx))
	# Insert right after the fixtures box.
	var fixtures := _root.get_node("FixturesBox")
	_root.add_child(btn)
	_root.move_child(btn, fixtures.get_index() + 1)
```

> Render guard: `_render()` runs for both injected-view tests and live play. The added calls are null-safe (`_play == null` → no PLAY button), so the existing watch-only/scrub tests stay green.

Also relabel the table when live (so the partial table reads honestly). In `_render_standings()`, change the head text:

```gdscript
	head.text = "FINAL TABLE" if _play == null else "LEAGUE TABLE · your matches %d/7" % _play.played_count()
```

- [ ] **Step 4: Run import+suite — verify GREEN.** Then **eyeball** (Task 7 preview) — a scene test cannot prove the PLAY tile is visible (CLAUDE.md: flat+modulate invisibility class of bug).

- [ ] **Step 5: Commit**

```bash
git add scenes/season_hub/season_hub.gd tests/unit/test_season_hub.gd
git commit -m "Season Hub: forward-play render — running table + next-fixture PLAY"
```

---

## Task 5: `main.gd` — play the next fixture, commit, return

**Files:**
- Modify: `scenes/main.gd`

- [ ] **Step 1: Write the failing test** — none (router wiring; covered by the preview eyeball in Task 7). Skip straight to implementation.

- [ ] **Step 2: Implementation** — in `scenes/main.gd`:

Add the interactive scene preload near the others:

```gdscript
const INTERACTIVE_MATCH := preload("res://scenes/interactive_match/interactive_match.tscn")
```

Wire `play_next` in `_push_hub()` (alongside the existing `open_match` connect):

```gdscript
func _push_hub() -> void:
	var hub := SEASON_HUB.instantiate()
	hub.open_match.connect(_push_match)
	hub.play_next.connect(_play_next.bind(hub))
	_push(hub)
	hub.boot()
```

> `bind(hub)` is wrong order — `play_next` emits `team_index` first. Use a lambda to keep arg order clear:

```gdscript
	hub.play_next.connect(func(team_index: int): _play_next(team_index))
```

Add the handler. It reads the **live** hub's `SeasonPlay`, opens the interactive scene with a fresh session, and on `back` commits the result + returns to a freshly-booted-from-the-same-play hub:

```gdscript
# Tap PLAY on the next fixture → play it interactively. The hub owns the live
# SeasonPlay; we pull a MatchSession off it, push the Interactive Match scene,
# and on back commit the result into the SAME SeasonPlay and re-show the hub.
func _play_next(_team_index: int) -> void:
	var hub = _slot.get_child(0)        # the live Season Hub
	var play: SeasonPlay = hub.live_play()
	if play == null or play.league_done():
		return
	var player: Player = SaveManager.load_player()
	var career: CareerState = hub.current_career()
	var nxt := play.next_player_opponent()
	var team: Team = career.teams[career.current_team_index]
	var opp: Team = career.opponents_of_current()[_team_index - 1]
	var session := play.make_session()
	var screen := INTERACTIVE_MATCH.instantiate()
	screen.back.connect(func(): _commit_and_return(play, session, player, career))
	_push(screen)
	screen.set_session(session, team.team_name, opp.team_name)
	screen.boot()

func _commit_and_return(play: SeasonPlay, session: MatchSession,
		player: Player, career: CareerState) -> void:
	play.commit_player_result(session.result())
	var hub := SEASON_HUB.instantiate()
	hub.open_match.connect(_push_match)
	hub.play_next.connect(func(team_index: int): _play_next(team_index))
	_push(hub)
	hub.set_play(player, career, play)   # re-show with the advanced league
```

The hub needs a `current_career()` getter — add to `season_hub.gd`:

```gdscript
func current_career() -> CareerState:
	return _career
```

> Note: `_push_match` (watch-only replay) currently re-derives from `hub.season()`/`current_view()`. On the live path the played matches live in `_play.live_league().player_matches`. Update `_push_match` to read from the live league when `_play != null`:

```gdscript
func _push_match(match_index: int) -> void:
	var player := SaveManager.load_player()
	var hub = _slot.get_child(0)
	var view: SeasonView = hub.current_view()
	var mr: MatchResult
	var play: SeasonPlay = hub.live_play()
	if play != null:
		mr = play.live_league().player_matches[match_index]
	else:
		mr = hub.season().league.player_matches[match_index]
	var opp: String = view.fixtures[match_index]["opponent_name"]
	var screen := MATCH_VIEW.instantiate()
	screen.back.connect(func(): _push_hub())
	_push(screen)
	screen.set_match(mr, player, view.team_name, opp)
	screen.boot()
```

> Important: `back` from the watch-only screen calls `_push_hub()` which **re-boots a fresh SeasonPlay** — losing your progress. Fix: on the live path, return to the live hub instead. Change the watch-only `back` to `_return_to_live_hub(play, player, career)` mirroring `_commit_and_return` but WITHOUT committing (no new result). Since `_push_match` already has `play`, wire:

```gdscript
	if play != null:
		screen.back.connect(func(): _show_live_hub(play, hub.current_career()))
	else:
		screen.back.connect(func(): _push_hub())
```

And add the shared re-show helper (used by both commit-return and watch-return):

```gdscript
func _show_live_hub(play: SeasonPlay, career: CareerState) -> void:
	var player := SaveManager.load_player()
	var hub := SEASON_HUB.instantiate()
	hub.open_match.connect(_push_match)
	hub.play_next.connect(func(team_index: int): _play_next(team_index))
	_push(hub)
	hub.set_play(player, career, play)
```

Refactor `_commit_and_return` to commit then call `_show_live_hub(play, career)` (DRY).

- [ ] **Step 3: Run import+suite — verify still GREEN** (no new unit tests; ensure nothing broke).

- [ ] **Step 4: Commit**

```bash
git add scenes/main.gd scenes/season_hub/season_hub.gd
git commit -m "main: live league wiring — PLAY next fixture, commit, return to live hub"
```

---

## Task 6: preview harness + screenshot + spec §10

**Files:**
- Create: `tools/preview_live_league.gd`
- Modify: `docs/superpowers/specs/2026-06-16-live-league-loop-design.md` (§10)

- [ ] **Step 1: Write the preview tool** (mirrors `tools/preview_season_hub.gd` — boot a SeasonPlay, play 3 fixtures headlessly, inject into the hub WITH rendering, screenshot)

```gdscript
extends SceneTree

# Visual harness: boot a SeasonPlay, auto-play 3 fixtures, render the forward-play
# hub, screenshot it. Run WITH rendering (no --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_live_league.gd
const HUB := preload("res://scenes/season_hub/season_hub.tscn")

func _initialize() -> void:
	var opps: Array = []
	for k in range(7):
		var t := Team.new(); t.team_name = "Team %d" % (k + 1); t.stars = 2.5
		opps.append(t)
	var career := CareerResolver.start_career(0)
	var player := Player.new()
	var pt := career.teams[career.current_team_index]
	var sp := SeasonPlay.start(player.attributes, pt, career.opponents_of_current(),
		DifficultyLadder.spec_for(0, 0).make_tour(),
		BallTuning.new(), InningsTuning.new(), 20260615)
	for k in range(3):
		sp.commit_player_result(sp.make_session().result())
	var hub := HUB.instantiate()
	get_root().add_child(hub)
	hub.set_play(player, career, sp)
	# Let one frame render, then screenshot.
	await process_frame
	await process_frame
	var img := get_root().get_viewport().get_texture().get_image()
	img.save_png("res://docs/mockups/live-league-loop-built-v1.png")
	quit()
```

- [ ] **Step 2: Run it** (editor closed):

`/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_live_league.gd`
Expected: writes `docs/mockups/live-league-loop-built-v1.png`.

- [ ] **Step 3: Eyeball the screenshot** with the Read tool. Confirm: running table with your real W/L record, the PLAY tile visible (solid accent, not invisible), folded card showing your played games. Fix any invisibility/layout issue in `season_hub.gd` and re-run.

- [ ] **Step 4: Fill in spec §10 findings** — schedule sanity, a sample running-table line, test-count delta (expect +7 driver tests +1 scene test), screenshot path, any GDScript gotchas hit.

- [ ] **Step 5: Commit**

```bash
git add tools/preview_live_league.gd docs/mockups/live-league-loop-built-v1.png docs/superpowers/specs/2026-06-16-live-league-loop-design.md
git commit -m "Live league loop: preview harness + screenshot + spec findings"
```

---

## Self-Review (run after the build)

- **Spec coverage:** D1 (SeasonPlay, resolvers untouched) ✓ Task 1-3. D2 (league only) ✓ scope. D3 (two sim paths) ✓ Task 2-3. D4 (strength difficulty via make_tour) ✓ boot/preview. D5 (running ladder) ✓ Task 2/4. D6 (forward-play hub, replay preserved) ✓ Task 4-5. D7 (in-memory) ✓ (no SaveManager writes). DS1 (reveal 3/game) ✓ Task 2.
- **Determinism** ✓ Task 3 test.
- **Eyeball gate** ✓ Task 6 (CLAUDE.md invisibility rule).
- **Ledger:** no resolver/tuning file touched → env probe unchanged by construction (note in §10; optional `probe_scoring_env.gd` spot-check).
```
