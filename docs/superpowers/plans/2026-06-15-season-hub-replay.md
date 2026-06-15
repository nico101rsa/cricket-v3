# Season Hub — scrubbable replay · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real, on-screen Season Hub that loads one genuinely-simulated season and lets the player scrub match-by-match through it, with every panel truthful.

**Architecture:** A pure read-model (`SeasonView`) + a pure builder (`SeasonViewBuilder`) sit between the headless sim and a new `season_hub` scene. The scene never touches resolvers — it renders a `SeasonView` and rebuilds it on scrub. No resolver changes ⇒ zero balance/ledger risk.

**Tech Stack:** Godot 4.6.3 / GDScript, GUT 9.6 tests. Domain logic in `scripts/domain/`, data in `scripts/data/`, scene in `scenes/season_hub/`.

---

## Conventions (read first — from project CLAUDE.md)

- **Run the suite:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- `-gtest=` does **not** filter — the whole suite runs. Judge **red** by a `SCRIPT ERROR: Parse Error: Identifier "X" not declared` (a not-yet-defined `class_name`) and **green** by the total count climbing past **566** and `All tests passed`.
- **One Godot process at a time.** Quit the editor before headless runs. Chain `--import && <test>` in one command.
- Tabs for indentation. Commit `*.gd.uid` for files under `scripts/` (Godot generates them); **test scripts in `tests/` get no `.uid`** — add only the `.gd`.
- Don't name identifiers after built-in Godot classes. `Label` is a node class — never an enum/var name.
- Scene tests: `queue_free()` is deferred, so detached children left at test-end count as GUT **orphans**. Isolate scene state (see `tests/unit/test_hall_of_fame_scene.gd` `before_each`).
- Unit tests can't catch invisibility. A `ScrollContainer` collapses to 0px in its scroll axis; a `flat` Button + `modulate` draws nothing. **Assert `size.y > 0` and `is_visible_in_tree()`, and always eyeball new UI in a real window.**

## Key signatures (verified in the codebase)

- `SeasonResolver.simulate_season(player_attrs: Attributes, player_team: Team, opponents: Array, tour: TourDistribution, tuning: BallTuning, itun: InningsTuning, rng, intent_plan=null, bowling_plan=null, opp_spec: TourSpec=null, jokers:=[], shop_hook:=Callable()) -> SeasonResult`
- `SeasonResult`: `.league: LeagueResult`, `.player_final_position: int`, `.beat`, `.won_final`.
- `LeagueResult`: `.standings: Array[StandingsRow]` (ranked), `.player_position: int`, `.player_matches: Array[MatchResult]` (the Player's 7 league games, in order), `.team_bat`, `.team_bowl`.
- `StandingsRow`: `.team_index, .played, .points, .runs_for, .balls_for, .runs_against, .balls_against`.
- `MatchResult`: `.innings1: InningsResult`, `.innings2: InningsResult`, `.player_bats_first: bool`, `.player_won() -> bool`, `.margin_text() -> String`.
- `InningsResult`: `.total, .wickets, .balls`, `.player_bowl_wickets/runs/balls: int`, `.player_line() -> Dictionary` (`{position, is_player, runs, balls, out}`).
- `CareerState`: `.teams: Array[Team]`, `.current_team_index: int`, `.current_level() -> int`, `.opponents_of_current() -> Array`, `.carryover_joker_id: String`.
- `Team`: `.team_name: String`, `.stars: float`.
- `DifficultyLadder.spec_for(level: int, tour_index: int) -> TourSpec` (in `scripts/data/difficulty_ladder.gd`); `TourSpec.make_tour() -> TourDistribution`, `.cell_name: String`, `.d: float`, `.level`, `.tour_index`.
- `CareerResolver.start_career(picked_club_slot: int) -> CareerState`.
- `Player`: `.name: NamePair` (`.display_caps()`), `.city`, `.country` (`Country.Code`), `.appearance`, `.form`, `.affinity: int`, `.tons_balance: int`, `.attributes: Attributes` (`.power/.composure/.attack/.control: float`).
- `JokerCatalog.implemented_groups() -> Array` of `{"id","jname","rarity","effects":[...]}`.
- `Country.to_key(code) -> String`.

## Visual-fidelity scope (honest)

This rung delivers a **structurally faithful, functional** hub: every panel from `around-the-match-v1.html` §1 present, populated with **real data**, country-aware palette (SA green default / AUS amber per ADR 0001), scrubbable. It does **not** chase pixel-art parity — illustrated hero portraits, rarity glow rings, and the gradient chrome are approximated with solid colors / the existing appearance bucket. Art parity is a later polish rung.

---

## Task 1: `SeasonView` read-model

**Files:**
- Create: `scripts/data/season_view.gd`
- Test: `tests/unit/test_season_view.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# SeasonView — the read-model the Season Hub renders (spec 2026-06-15-season-hub-replay §4).

func test_defaults_are_empty_and_typed() -> void:
	var v := SeasonView.new()
	assert_eq(v.match_count, 7, "a league season is 7 Player games")
	assert_eq(v.scrub_index, 0, "boots before match 1")
	assert_eq(v.fixtures.size(), 0, "no fixtures until built")
	assert_eq(v.card_matches, 0, "empty card")
	assert_eq(v.tons_balance, 0)

func test_fields_round_trip() -> void:
	var v := SeasonView.new()
	v.player_name = "B. KGOSI"
	v.tour_name = "Flat & Warm"
	v.tons_balance = 120
	v.scrub_index = 3
	assert_eq(v.player_name, "B. KGOSI")
	assert_eq(v.tour_name, "Flat & Warm")
	assert_eq(v.tons_balance, 120)
	assert_eq(v.scrub_index, 3)
```

- [ ] **Step 2: Run to verify it fails**

Run the suite (command above). Expected: `Parse Error: Identifier "SeasonView" not declared`.

- [ ] **Step 3: Write the read-model**

```gdscript
class_name SeasonView
extends RefCounted

# Transient read-model for the Season Hub (spec 2026-06-15-season-hub-replay §4).
# Pure data — no node or resolver dependencies. Built by SeasonViewBuilder.

# --- Context ---
var level: int = 0
var tour: int = 0
var tour_name: String = ""
var difficulty_label: String = ""
var country: int = 0
var team_name: String = ""
var team_stars: float = 0.0

# --- Player snapshot ---
var player_name: String = ""
var city: String = ""
var form: int = 0
var appearance: int = 0
var power: float = 0.0
var composure: float = 0.0
var attack: float = 0.0
var control: float = 0.0
var ovr: int = 0

# --- Wallet / loyalty ---
var tons_balance: int = 0
var affinity: int = 0

# --- Fixtures chain (one dict per league game, in order) ---
# {opponent_name, opponent_stars, played, player_won, margin_text, score_text}
var fixtures: Array = []

# --- Final standings (ranked) ---
# {team_name, played, won, points, nrr, is_player}
var standings: Array = []
var player_final_position: int = 0

# --- Jokers owned ({id, name, rarity}) ---
var jokers: Array = []

# --- Scrub ---
var scrub_index: int = 0
var match_count: int = 7

# --- Career card (folded over player_matches[0 .. scrub_index-1]) ---
var card_matches: int = 0
var card_runs: int = 0
var card_balls_faced: int = 0
var card_dismissals: int = 0
var card_high_score: int = 0
var card_strike_rate: float = 0.0
var card_batting_avg: float = 0.0
var card_wickets: int = 0
var card_runs_conceded: int = 0
var card_balls_bowled: int = 0
var card_economy: float = 0.0
var card_best_bowling: String = "—"
```

- [ ] **Step 4: Run to verify it passes** — count climbs by 2, `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/season_view.gd scripts/data/season_view.gd.uid tests/unit/test_season_view.gd
git commit -m "SeasonView read-model for the Season Hub"
```

---

## Task 2: `SeasonViewBuilder` — context, snapshot, passthrough, OVR

**Files:**
- Create: `scripts/domain/season_view_builder.gd`
- Test: `tests/unit/test_season_view_builder.gd`

Builds the non-fold fields. Later tasks extend `build()` for fixtures, standings, card, jokers.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

# SeasonViewBuilder — pure builder of the hub read-model
# (spec 2026-06-15-season-hub-replay §3, §6).

func _player() -> Player:
	var p := Player.new()
	var n := NamePair.new()
	n.first_name = "Bongani"; n.surname = "Kgosi"
	p.name = n
	p.city = "Durban"
	p.country = Country.Code.SA
	p.tons_balance = 120
	p.affinity = 3
	var a := Attributes.new()
	a.power = 40.0; a.composure = 30.0; a.attack = 20.0; a.control = 10.0
	p.attributes = a
	return p

func _career() -> CareerState:
	# A real fresh career; player team = current_team_index, opponents = the rest.
	return CareerResolver.start_career(0)

func _empty_season() -> SeasonResult:
	# Minimal SeasonResult with an empty league — enough for context/snapshot tests.
	var sr := SeasonResult.new()
	var lr := LeagueResult.new()
	lr.standings = []
	lr.player_matches = []
	sr.league = lr
	return sr

func test_context_and_snapshot() -> void:
	var p := _player()
	var cs := _career()
	var v := SeasonViewBuilder.build(p, cs, _empty_season(), 0)
	assert_eq(v.player_name, p.name.display_caps(), "name from Player")
	assert_eq(v.city, "Durban")
	assert_eq(v.country, Country.Code.SA)
	assert_eq(v.tons_balance, 120, "tons passthrough")
	assert_eq(v.affinity, 3, "affinity passthrough")
	assert_almost_eq(v.power, 40.0, 0.001)
	assert_eq(v.team_name, cs.teams[cs.current_team_index].team_name)
	assert_false(v.tour_name.is_empty(), "tour name from DifficultyLadder")

func test_ovr_is_attribute_mean_rounded() -> void:
	var v := SeasonViewBuilder.build(_player(), _career(), _empty_season(), 0)
	# (40 + 30 + 20 + 10) / 4 = 25
	assert_eq(v.ovr, 25, "OVR = rounded mean of the four attributes")
```

- [ ] **Step 2: Run to verify it fails** — `Parse Error: Identifier "SeasonViewBuilder" not declared`.

- [ ] **Step 3: Write the builder (context/snapshot only for now)**

```gdscript
class_name SeasonViewBuilder
extends RefCounted

# Pure builder of SeasonView from real game state (spec 2026-06-15 §3/§6).
# No RNG, no UI, no resolver mutation. Folds the Player's real match lines into
# the career card; everything else is passthrough/mapping.

static func build(player: Player, career_state: CareerState,
		season_result: SeasonResult, scrub_index: int) -> SeasonView:
	var v := SeasonView.new()
	var level := career_state.current_level()
	var tour_index := 0   # this slice boots the current Level's first cell; real
	                      # tour selection arrives with the Career Grid rung.
	var spec := DifficultyLadder.spec_for(level, tour_index)
	var team: Team = career_state.teams[career_state.current_team_index]

	# Context
	v.level = level
	v.tour = tour_index
	v.tour_name = spec.cell_name
	v.difficulty_label = "d %.1f" % spec.d
	v.country = player.country
	v.team_name = team.team_name
	v.team_stars = team.stars

	# Snapshot
	v.player_name = player.name.display_caps()
	v.city = player.city
	v.form = player.form
	v.appearance = player.appearance
	v.power = player.attributes.power
	v.composure = player.attributes.composure
	v.attack = player.attributes.attack
	v.control = player.attributes.control
	v.ovr = int(round((v.power + v.composure + v.attack + v.control) / 4.0))

	# Wallet / loyalty
	v.tons_balance = player.tons_balance
	v.affinity = player.affinity

	# Scrub
	v.match_count = 7
	v.scrub_index = clampi(scrub_index, 0, v.match_count)

	return v
```

- [ ] **Step 4: Run to verify it passes** — count climbs by 2.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/season_view_builder.gd scripts/domain/season_view_builder.gd.uid tests/unit/test_season_view_builder.gd
git commit -m "SeasonViewBuilder: context + snapshot + OVR"
```

---

## Task 3: `SeasonViewBuilder` — fixtures chain

**Files:**
- Modify: `scripts/domain/season_view_builder.gd`
- Test: `tests/unit/test_season_view_builder.gd` (add cases)

A fixture row per Player league game. `played = index < scrub_index`. Opponent identity comes from `opponents_of_current()` (7 teams, same order the league iterates Player games).

- [ ] **Step 1: Write the failing test (append)**

```gdscript
func _match(player_first: bool, won: bool) -> MatchResult:
	var m := MatchResult.new()
	m.player_bats_first = player_first
	var bat := InningsResult.new(150, 5, 120, [], [
		{"position": 3, "is_player": true, "runs": 40, "balls": 28, "out": true}])
	var bowl := InningsResult.new(140, 8, 120, [], [], 2, 26, 24)  # player 2/26 in 24 balls
	if player_first:
		m.innings1 = bat; m.innings2 = bowl
	else:
		m.innings1 = bowl; m.innings2 = bat
	m.outcome = (Outcome.WIN_BATTING if won else Outcome.LOSS_BATTING) if player_first \
		else (Outcome.WIN_CHASING if won else Outcome.LOSS_CHASING)
	return m

func _season_with(n_matches: int) -> SeasonResult:
	var sr := SeasonResult.new()
	var lr := LeagueResult.new()
	var pms: Array = []
	for i in range(n_matches):
		pms.append(_match(i % 2 == 0, i % 3 != 0))
	lr.player_matches = pms
	lr.standings = []
	sr.league = lr
	return sr

func test_fixtures_chain_length_and_played_flag() -> void:
	var v := SeasonViewBuilder.build(_player(), _career(), _season_with(7), 3)
	assert_eq(v.fixtures.size(), 7, "7 league fixtures")
	assert_true(v.fixtures[2]["played"], "match 3 (index 2) is before the scrub head")
	assert_false(v.fixtures[3]["played"], "match 4 (index 3) is pending at scrub_index 3")
	assert_false(v.fixtures[0]["opponent_name"].is_empty(), "opponent named")

func test_played_fixture_carries_result_text() -> void:
	var v := SeasonViewBuilder.build(_player(), _career(), _season_with(7), 7)
	for f in v.fixtures:
		assert_true(f["played"], "all played at scrub_index 7")
		assert_false(f["score_text"].is_empty(), "played fixture shows a score line")
```

- [ ] **Step 2: Run to verify it fails** — `assert_eq(v.fixtures.size(), 7)` fails (size 0).

- [ ] **Step 3: Extend `build()` — insert before `return v`**

```gdscript
	# Fixtures chain — Player league games in order, opponent identity from the
	# current cell's opponent field. simulate_league iterates the Player's games in
	# opponents_of_current() order, so they align by index.
	var opps := career_state.opponents_of_current()
	var pms: Array = season_result.league.player_matches
	for i in range(v.match_count):
		var opp: Team = opps[i] if i < opps.size() else null
		var row := {
			"opponent_name": (opp.team_name if opp != null else "TBD"),
			"opponent_stars": (opp.stars if opp != null else 0.0),
			"played": i < v.scrub_index,
			"player_won": false,
			"margin_text": "",
			"score_text": "",
		}
		if i < v.scrub_index and i < pms.size():
			var m: MatchResult = pms[i]
			row["player_won"] = m.player_won()
			row["margin_text"] = m.margin_text()
			var your := (m.innings1 if m.player_bats_first else m.innings2)
			var their := (m.innings2 if m.player_bats_first else m.innings1)
			row["score_text"] = "%d/%d  v  %d/%d" % [your.total, your.wickets, their.total, their.wickets]
		v.fixtures.append(row)
```

- [ ] **Step 4: Run to verify it passes** — count climbs by 2.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/season_view_builder.gd tests/unit/test_season_view_builder.gd
git commit -m "SeasonViewBuilder: fixtures chain with played/pending + result text"
```

---

## Task 4: `SeasonViewBuilder` — final standings

**Files:**
- Modify: `scripts/domain/season_view_builder.gd`
- Test: `tests/unit/test_season_view_builder.gd` (add cases)

Map `league.standings` → display rows with team name + NRR + the Player flag. NRR = run-rate-for − run-rate-against (runs per over). This is the **final** table (labeled "Final" in the scene).

- [ ] **Step 1: Write the failing test (append)**

```gdscript
func _row(team_index: int, played: int, points: int, rf: int, bf: int, ra: int, ba: int) -> StandingsRow:
	var r := StandingsRow.new()
	r.team_index = team_index; r.played = played; r.points = points
	r.runs_for = rf; r.balls_for = bf; r.runs_against = ra; r.balls_against = ba
	return r

func test_standings_mapped_with_name_and_nrr_and_player_flag() -> void:
	var cs := _career()
	var sr := _season_with(0)
	sr.league.standings = [
		_row(0, 7, 10, 1200, 840, 1100, 840),  # player team (index 0)
		_row(1, 7, 8, 1100, 840, 1150, 840),
	]
	sr.league.player_position = 1
	sr.player_final_position = 1
	var v := SeasonViewBuilder.build(_player(), cs, sr, 7)
	assert_eq(v.standings.size(), 2)
	assert_eq(v.standings[0]["team_name"], cs.teams[0].team_name, "name resolved from team_index")
	assert_true(v.standings[0]["is_player"], "team_index 0 is the Player")
	assert_eq(v.player_final_position, 1)
	# NRR for row 0: 1200/140 - 1100/140 = 8.571 - 7.857 = 0.714
	assert_almost_eq(v.standings[0]["nrr"], 0.714, 0.01)
```

- [ ] **Step 2: Run to verify it fails** — `v.standings.size()` is 0.

- [ ] **Step 3: Extend `build()` — insert before `return v`**

```gdscript
	# Final standings (labeled "Final" in the UI — provenance honest, §5).
	for r in season_result.league.standings:
		var rr_for := (float(r.runs_for) / (r.balls_for / 6.0)) if r.balls_for > 0 else 0.0
		var rr_against := (float(r.runs_against) / (r.balls_against / 6.0)) if r.balls_against > 0 else 0.0
		v.standings.append({
			"team_name": career_state.teams[r.team_index].team_name,
			"played": r.played,
			"won": r.points / 2,   # 2 points a win
			"points": r.points,
			"nrr": rr_for - rr_against,
			"is_player": r.team_index == 0,
		})
	v.player_final_position = season_result.player_final_position
```

- [ ] **Step 4: Run to verify it passes** — count climbs by 1.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/season_view_builder.gd tests/unit/test_season_view_builder.gd
git commit -m "SeasonViewBuilder: final standings with name + NRR + player flag"
```

---

## Task 5: `SeasonViewBuilder` — career card fold

**Files:**
- Modify: `scripts/domain/season_view_builder.gd`
- Test: `tests/unit/test_season_view_builder.gd` (add cases)

Fold batting + bowling over `player_matches[0 .. scrub_index-1]`. `_match()` in Task 3 gives each match: bat 40 (28 balls, out), bowl 2/26 (24 balls).

- [ ] **Step 1: Write the failing test (append)**

```gdscript
func test_card_empty_at_scrub_zero() -> void:
	var v := SeasonViewBuilder.build(_player(), _career(), _season_with(7), 0)
	assert_eq(v.card_matches, 0)
	assert_eq(v.card_runs, 0)
	assert_eq(v.card_best_bowling, "—", "no figures yet — sentinel, not 0/0")

func test_card_folds_batting_and_bowling() -> void:
	# 3 matches scrubbed: each bat 40 off 28 (out), bowl 2/26 off 24.
	var v := SeasonViewBuilder.build(_player(), _career(), _season_with(7), 3)
	assert_eq(v.card_matches, 3)
	assert_eq(v.card_runs, 120, "3 x 40")
	assert_eq(v.card_balls_faced, 84, "3 x 28")
	assert_eq(v.card_dismissals, 3, "out each time")
	assert_eq(v.card_high_score, 40)
	assert_almost_eq(v.card_batting_avg, 40.0, 0.01, "120 / 3")
	assert_almost_eq(v.card_strike_rate, 142.857, 0.01, "100 * 120 / 84")
	assert_eq(v.card_wickets, 6, "3 x 2")
	assert_eq(v.card_runs_conceded, 78, "3 x 26")
	assert_eq(v.card_balls_bowled, 72, "3 x 24")
	assert_almost_eq(v.card_economy, 6.5, 0.01, "78 / (72/6)")
	assert_eq(v.card_best_bowling, "2/26", "best (most wickets, fewest runs)")
```

- [ ] **Step 2: Run to verify it fails** — `card_matches` is 0 at scrub 3.

- [ ] **Step 3: Extend `build()` — insert before `return v`**

```gdscript
	# Career card — fold the Player's real match lines up to the scrub head (§6).
	# Empty at scrub 0 (sentinels, never zeros-as-data).
	var best_w := -1
	var best_r := 0
	for i in range(min(v.scrub_index, pms.size())):
		var m: MatchResult = pms[i]
		var bat_inns := (m.innings1 if m.player_bats_first else m.innings2)
		var line := bat_inns.player_line()
		if not line.is_empty():
			v.card_matches += 1
			v.card_runs += int(line["runs"])
			v.card_balls_faced += int(line["balls"])
			if line["out"]:
				v.card_dismissals += 1
			v.card_high_score = max(v.card_high_score, int(line["runs"]))
		# Bowling: sum across both innings (only the bowling innings is non-zero).
		var mw := m.innings1.player_bowl_wickets + m.innings2.player_bowl_wickets
		var mr := m.innings1.player_bowl_runs + m.innings2.player_bowl_runs
		var mb := m.innings1.player_bowl_balls + m.innings2.player_bowl_balls
		v.card_wickets += mw
		v.card_runs_conceded += mr
		v.card_balls_bowled += mb
		if mb > 0 and (mw > best_w or (mw == best_w and mr < best_r)):
			best_w = mw; best_r = mr
	if v.card_dismissals > 0:
		v.card_batting_avg = float(v.card_runs) / v.card_dismissals
	elif v.card_matches > 0:
		v.card_batting_avg = float(v.card_runs)   # not-out average (flagged * in UI)
	if v.card_balls_faced > 0:
		v.card_strike_rate = 100.0 * v.card_runs / v.card_balls_faced
	if v.card_balls_bowled > 0:
		v.card_economy = float(v.card_runs_conceded) / (v.card_balls_bowled / 6.0)
	if best_w >= 0:
		v.card_best_bowling = "%d/%d" % [best_w, best_r]
```

- [ ] **Step 4: Run to verify it passes** — count climbs by 2.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/season_view_builder.gd tests/unit/test_season_view_builder.gd
git commit -m "SeasonViewBuilder: career card fold (batting + bowling, scrubbed)"
```

---

## Task 6: `SeasonViewBuilder` — jokers panel

**Files:**
- Modify: `scripts/domain/season_view_builder.gd`
- Test: `tests/unit/test_season_view_builder.gd` (add cases)

This slice shows the carry-over joker if present (mid-season Shop acquisitions are a later rung). Resolve `{id, name, rarity}` by scanning `JokerCatalog.implemented_groups()`.

- [ ] **Step 1: Write the failing test (append)**

```gdscript
func test_jokers_empty_when_no_carryover() -> void:
	var cs := _career()
	cs.carryover_joker_id = ""
	var v := SeasonViewBuilder.build(_player(), cs, _season_with(0), 0)
	assert_eq(v.jokers.size(), 0, "fresh career, no carry-over")

func test_carryover_joker_resolves_name_and_rarity() -> void:
	var cs := _career()
	var groups := JokerCatalog.implemented_groups()
	var first_id: String = groups[0]["id"]
	cs.carryover_joker_id = first_id
	var v := SeasonViewBuilder.build(_player(), cs, _season_with(0), 0)
	assert_eq(v.jokers.size(), 1)
	assert_eq(v.jokers[0]["id"], first_id)
	assert_eq(v.jokers[0]["name"], groups[0]["jname"])
	assert_eq(v.jokers[0]["rarity"], groups[0]["rarity"])
```

- [ ] **Step 2: Run to verify it fails** — `v.jokers.size()` mismatch (no jokers code yet).

- [ ] **Step 3: Extend `build()` — insert before `return v`, and add a helper**

Insert in `build()`:

```gdscript
	# Jokers owned this slice = the carry-over joker, if any (§4). Mid-season Shop
	# acquisitions on the bench arrive with the Shop screen rung.
	if career_state.carryover_joker_id != "":
		var meta := _joker_meta(career_state.carryover_joker_id)
		if not meta.is_empty():
			v.jokers.append(meta)
```

Add at the bottom of the file:

```gdscript
static func _joker_meta(id: String) -> Dictionary:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return {"id": id, "name": g["jname"], "rarity": g["rarity"]}
	return {}
```

- [ ] **Step 4: Run to verify it passes** — count climbs by 2.

- [ ] **Step 5: Commit**

```bash
git add scripts/domain/season_view_builder.gd tests/unit/test_season_view_builder.gd
git commit -m "SeasonViewBuilder: jokers panel (carry-over resolve)"
```

---

## Task 7: Season Hub scene — structure + render

**Files:**
- Create: `scenes/season_hub/season_hub.tscn`
- Create: `scenes/season_hub/season_hub.gd`
- Test: `tests/unit/test_season_hub_scene.gd`

The scene renders a `SeasonView` via `set_view()`. Dynamic lists (fixtures, standings, jokers) are built in code into containers. Static shell is a root `Control` → `MarginContainer` → `VBoxContainer` ("Root") holding named child containers. Country palette via a constant map.

**`season_hub.tscn`** node tree (author in the editor or by hand; the script's `@onready` paths must match):

```
SeasonHub (Control, script season_hub.gd)
└─ Margin (MarginContainer, anchors full rect, theme_constant margins 16)
   └─ Root (VBoxContainer)
      ├─ Header (HBoxContainer)
      │  ├─ TitleLabel (Label)
      │  └─ TonsChip (Label)            # "₸ 120"
      ├─ ContextLabel (Label)           # "Club · Flat & Warm · d 1.0"
      ├─ FixturesBox (VBoxContainer)     # filled in code
      ├─ PlayerCard (VBoxContainer)
      │  ├─ NameLabel (Label)
      │  ├─ AttrLabel (Label)            # "PWR 40  COM 30  ATT 20  CON 10"
      │  └─ CareerLabel (Label)          # "3 inns · 40.0 avg · SR 142.9 · 6 wkts · best 2/26 · OVR 25"
      ├─ JokersBox (HBoxContainer)        # filled in code
      ├─ AffinityLabel (Label)           # "Affinity 3"
      ├─ StandingsBox (VBoxContainer)     # filled in code; header row "FINAL TABLE"
      └─ ScrubBar (HBoxContainer)
         ├─ PrevBtn (Button)  "‹"
         ├─ ScrubLabel (Label) "Match 0 / 7"
         └─ NextBtn (Button)  "›"
```

> **Invisibility guard:** give `FixturesBox`/`StandingsBox` a `custom_minimum_size.y` (e.g. 80) so they never collapse to 0px (CLAUDE.md `ScrollContainer` gotcha applies to any list container that might end up empty). Use plain `Button`s (not `flat`) for Prev/Next so they actually draw.

- [ ] **Step 1: Write the failing scene test**

```gdscript
extends GutTest

# Season Hub scene — renders a SeasonView (spec 2026-06-15-season-hub-replay §5).

const SeasonHubScene = preload("res://scenes/season_hub/season_hub.tscn")

func _view() -> SeasonView:
	var p := Player.new()
	var n := NamePair.new(); n.first_name = "Bongani"; n.surname = "Kgosi"
	p.name = n; p.city = "Durban"; p.country = Country.Code.SA
	p.tons_balance = 120; p.affinity = 3
	var a := Attributes.new(); a.power = 40; a.composure = 30; a.attack = 20; a.control = 10
	p.attributes = a
	return SeasonViewBuilder.build(p, CareerResolver.start_career(0), _empty_season(), 0)

func _empty_season() -> SeasonResult:
	var sr := SeasonResult.new(); var lr := LeagueResult.new()
	lr.standings = []; lr.player_matches = []; sr.league = lr
	return sr

func test_scene_renders_view_and_panels_are_visible() -> void:
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	hub.set_view(_view())
	var root := hub.get_node("Margin/Root")
	assert_true(root.get_node("Header/TonsChip").text.contains("120"), "tons chip shows balance")
	assert_true(root.get_node("FixturesBox").get_child_count() >= 7, "7 fixture rows")
	assert_gt(root.get_node("FixturesBox").size.y, 0.0, "fixtures box not collapsed")
	assert_true(root.get_node("PlayerCard/NameLabel").is_visible_in_tree(), "name visible")
	assert_true(root.get_node("ScrubBar/ScrubLabel").text.contains("0"), "scrub readout")
```

- [ ] **Step 2: Run to verify it fails** — scene/script missing → load error / `set_view` not found.

- [ ] **Step 3: Write `season_hub.gd`**

```gdscript
extends Control

# The Season Hub — renders a SeasonView (spec 2026-06-15-season-hub-replay §5).
# Boot + scrub wiring land in later tasks; this task is pure render.

const RARITY_COLOR := {
	"Common": Color("e8e8e8"),
	"Rare": Color("4f8cff"),
	"Legendary": Color("ffc23c"),
}
# Country accent (ADR 0001): SA green, AUS amber. Keyed by Country.Code.
const COUNTRY_ACCENT := {
	Country.Code.SA: Color("1f7a4d"),
	Country.Code.AUS: Color("e3a008"),
}

@onready var _root: VBoxContainer = $Margin/Root

var _view: SeasonView

func set_view(view: SeasonView) -> void:
	_view = view
	_render()

func _render() -> void:
	if _view == null:
		return
	var accent: Color = COUNTRY_ACCENT.get(_view.country, Color("1f7a4d"))
	_root.get_node("Header/TitleLabel").text = "%s · %s" % [_view.team_name, _country_word(_view.country)]
	_root.get_node("Header/TitleLabel").add_theme_color_override("font_color", accent)
	_root.get_node("Header/TonsChip").text = "₸ %d" % _view.tons_balance
	_root.get_node("ContextLabel").text = "%s · %s · %s" % [
		_level_word(_view.level), _view.tour_name, _view.difficulty_label]
	_render_fixtures(accent)
	_render_card()
	_render_jokers()
	_root.get_node("AffinityLabel").text = "Affinity %d" % _view.affinity
	_render_standings()
	_render_scrub()

func _render_fixtures(accent: Color) -> void:
	var box: VBoxContainer = _root.get_node("FixturesBox")
	for c in box.get_children():
		c.queue_free()
	for i in range(_view.fixtures.size()):
		var f: Dictionary = _view.fixtures[i]
		var row := Label.new()
		if f["played"]:
			var tag := "WON " if f["player_won"] else "LOST "
			row.text = "%d. v %s — %s%s" % [i + 1, f["opponent_name"], tag, f["score_text"]]
			row.add_theme_color_override("font_color",
				accent if f["player_won"] else Color("a05050"))
		else:
			row.text = "%d. v %s — to play" % [i + 1, f["opponent_name"]]
			row.add_theme_color_override("font_color", Color("808080"))
		if i == _view.scrub_index:
			row.text = "▶ " + row.text   # the scrub head
		box.add_child(row)

func _render_card() -> void:
	_root.get_node("PlayerCard/NameLabel").text = "%s · %s" % [_view.player_name, _view.city]
	_root.get_node("PlayerCard/AttrLabel").text = "PWR %d  COM %d  ATT %d  CON %d" % [
		int(_view.power), int(_view.composure), int(_view.attack), int(_view.control)]
	if _view.card_matches == 0:
		_root.get_node("PlayerCard/CareerLabel").text = "no matches yet — OVR %d" % _view.ovr
	else:
		var avg_txt := "%.1f%s" % [_view.card_batting_avg, ("*" if _view.card_dismissals == 0 else "")]
		_root.get_node("PlayerCard/CareerLabel").text = \
			"%d inns · %s avg · SR %.1f · %d wkts · best %s · OVR %d" % [
				_view.card_matches, avg_txt, _view.card_strike_rate,
				_view.card_wickets, _view.card_best_bowling, _view.ovr]

func _render_jokers() -> void:
	var box: HBoxContainer = _root.get_node("JokersBox")
	for c in box.get_children():
		c.queue_free()
	if _view.jokers.is_empty():
		var empty := Label.new()
		empty.text = "(no jokers)"
		empty.add_theme_color_override("font_color", Color("808080"))
		box.add_child(empty)
		return
	for j in _view.jokers:
		var chip := Label.new()
		chip.text = " %s " % j["name"]
		chip.add_theme_color_override("font_color", RARITY_COLOR.get(j["rarity"], Color.WHITE))
		box.add_child(chip)

func _render_standings() -> void:
	var box: VBoxContainer = _root.get_node("StandingsBox")
	for c in box.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "FINAL TABLE"
	box.add_child(head)
	for i in range(_view.standings.size()):
		var s: Dictionary = _view.standings[i]
		var row := Label.new()
		row.text = "%d. %s  %dpts  NRR %+.2f" % [i + 1, s["team_name"], s["points"], s["nrr"]]
		if s["is_player"]:
			row.add_theme_color_override("font_color", Color("ffc23c"))
		box.add_child(row)

func _render_scrub() -> void:
	_root.get_node("ScrubBar/ScrubLabel").text = "Match %d / %d" % [_view.scrub_index, _view.match_count]

func _country_word(code: int) -> String:
	return "Australia" if code == Country.Code.AUS else "South Africa"

func _level_word(level: int) -> String:
	return ["Club", "City", "Province"][clampi(level, 0, 2)]
```

- [ ] **Step 4: Author `season_hub.tscn`** with the node tree above (root `Control` has the script attached; `FixturesBox`/`StandingsBox` get `custom_minimum_size = Vector2(0, 80)`). Run to verify the test passes — count climbs by 1.

- [ ] **Step 5: Commit**

```bash
git add scenes/season_hub/season_hub.gd scenes/season_hub/season_hub.gd.uid scenes/season_hub/season_hub.tscn tests/unit/test_season_hub_scene.gd
git commit -m "Season Hub scene: render a SeasonView (all panels, country accent)"
```

---

## Task 8: Scrub interaction

**Files:**
- Modify: `scenes/season_hub/season_hub.gd`
- Test: `tests/unit/test_season_hub_scene.gd` (add a case)

Prev/Next step the scrub head; tapping a fixture jumps to it. The hub holds the source data so it can rebuild the view at a new index.

- [ ] **Step 1: Write the failing test (append)**

```gdscript
func test_next_advances_scrub_and_grows_card() -> void:
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	# Source data with 7 real-ish matches so scrubbing changes the card.
	var p := Player.new(); var n := NamePair.new()
	n.first_name = "B"; n.surname = "K"; p.name = n
	p.attributes = Attributes.new()
	var cs := CareerResolver.start_career(0)
	hub.set_source(p, cs, _season7())
	assert_eq(hub.scrub_index(), 0, "boots at 0")
	hub.step(1)
	assert_eq(hub.scrub_index(), 1, "next advances")
	var lbl := hub.get_node("Margin/Root/ScrubBar/ScrubLabel")
	assert_true(lbl.text.contains("1"), "readout updated")

func _season7() -> SeasonResult:
	var sr := SeasonResult.new(); var lr := LeagueResult.new()
	var pms: Array = []
	for i in range(7):
		var m := MatchResult.new()
		m.player_bats_first = true
		m.innings1 = InningsResult.new(150, 5, 120, [], [
			{"position": 3, "is_player": true, "runs": 30, "balls": 24, "out": true}])
		m.innings2 = InningsResult.new(140, 8, 120, [], [], 2, 26, 24)
		m.outcome = Outcome.WIN_BATTING
		pms.append(m)
	lr.player_matches = pms; lr.standings = []
	sr.league = lr
	return sr
```

- [ ] **Step 2: Run to verify it fails** — `set_source` / `step` / `scrub_index` not defined.

- [ ] **Step 3: Add source-holding + scrub to `season_hub.gd`**

Add fields + methods:

```gdscript
var _player: Player
var _career: CareerState
var _season: SeasonResult

func set_source(player: Player, career: CareerState, season: SeasonResult) -> void:
	_player = player
	_career = career
	_season = season
	_rebuild(0)

func _rebuild(index: int) -> void:
	set_view(SeasonViewBuilder.build(_player, _career, _season, index))

func scrub_index() -> int:
	return _view.scrub_index if _view != null else 0

func step(delta: int) -> void:
	if _view == null:
		return
	_rebuild(clampi(_view.scrub_index + delta, 0, _view.match_count))
```

Wire the buttons + fixture taps. In `_render()` connect once (guard against double-connect) — simplest: connect in an `_ready()` that runs after the scene tree is built:

```gdscript
func _ready() -> void:
	_root.get_node("ScrubBar/PrevBtn").pressed.connect(func(): step(-1))
	_root.get_node("ScrubBar/NextBtn").pressed.connect(func(): step(1))
```

Add a jump-to-fixture: make each fixture row a `Button` instead of a `Label` in `_render_fixtures` (so it's tappable), connecting `pressed` to a jump. Replace the `var row := Label.new()` block with:

```gdscript
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		row.pressed.connect(func(): _rebuild(idx))
```

(keep the `.text` / color assignments; `Button` has `add_theme_color_override("font_color", …)` too. Do **not** set `flat = true` — a flat text Button still draws its label, but keep it non-flat for a visible tap target per the CLAUDE.md gotcha.)

- [ ] **Step 4: Run to verify it passes** — count climbs by 1. (The Task-7 render test still passes via `set_view`.)

- [ ] **Step 5: Commit**

```bash
git add scenes/season_hub/season_hub.gd tests/unit/test_season_hub_scene.gd
git commit -m "Season Hub: scrub (prev/next + tap-to-jump) rebuilds the view"
```

---

## Task 9: Boot wiring + router

**Files:**
- Modify: `scenes/season_hub/season_hub.gd` (boot in `_ready`)
- Modify: `scenes/main.gd` (route to the real hub)
- Modify: `scripts/services/lifecycle_manager.gd` — only if the Retire/dev-win hooks need a new home (verify; likely no change — keep them reachable from a dev affordance)
- Test: `tests/unit/test_season_hub_scene.gd` (boot smoke) + check `tests/unit/test_main_router.gd` still green

Boot a real season when the scene loads standalone (no source injected by a test). Simulate the saved Player's current cell; if no career, `start_career(0)`. Seeded with a dev seed (re-roll via Prev/Next on a long-press is out of scope — just a constant seed field for now).

- [ ] **Step 1: Write the failing boot test (append)**

```gdscript
func test_boots_a_real_season_when_player_saved() -> void:
	# A saved player but no career → hub starts a default career and sims a season.
	var p := Player.new(); var nm := NamePair.new()
	nm.first_name = "Boot"; nm.surname = "Test"; p.name = nm
	p.attributes = Attributes.new()
	SaveManager.save_player(p)
	var hub = SeasonHubScene.instantiate()
	add_child_autofree(hub)
	# _ready() boots; the view must exist with 7 fixtures and a named team.
	assert_not_null(hub._view, "boot built a view")
	assert_eq(hub._view.fixtures.size(), 7)
	assert_false(hub._view.team_name.is_empty())
	SaveManager.clear_player()
```

> If `SaveManager` writes to `user://`, restore any pre-existing save in `before_each`/`after_each` like `test_hall_of_fame_scene.gd` does, to avoid clobbering a real save during the run.

- [ ] **Step 2: Run to verify it fails** — `hub._view` is null (no boot yet).

- [ ] **Step 3: Add boot to `_ready()`**

```gdscript
const BOOT_SEED := 20260615

func _ready() -> void:
	_root.get_node("ScrubBar/PrevBtn").pressed.connect(func(): step(-1))
	_root.get_node("ScrubBar/NextBtn").pressed.connect(func(): step(1))
	if _view == null and _season == null and SaveManager.has_player():
		_boot_real_season()

func _boot_real_season() -> void:
	var player := SaveManager.load_player()
	var career: CareerState = SaveManager.load_career() if SaveManager.has_career() \
		else CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(career.current_level(), 0)
	var team: Team = career.teams[career.current_team_index]
	var rng := RandomNumberGenerator.new()
	rng.seed = BOOT_SEED
	var season := SeasonResolver.simulate_season(
		player.attributes, team, career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), rng)
	set_source(player, career, season)
```

> Verify `SaveManager.has_career()` / `load_career()` exist (they were added in the Career-loop rung — `user://career.tres`). If the saved career's `current_team_index` is not in the current level's roster, `opponents_of_current()` still returns the level's other 7 teams — fine.

- [ ] **Step 4: Run to verify it passes** — count climbs by 1.

- [ ] **Step 5: Point the router at the real hub.** In `scenes/main.gd`, change:

```gdscript
const SEASON_HUB := preload("res://scenes/stubs/season_hub_stub.tscn")
```

to:

```gdscript
const SEASON_HUB := preload("res://scenes/season_hub/season_hub.tscn")
```

Run the full suite — `test_main_router.gd` must stay green (it routes to `SEASON_HUB` on `has_player()`; the real hub boots a season in `_ready`, which the router test tolerates as long as it only asserts the scene type/instance). If the router test asserts stub-specific nodes (e.g. `RetireBtn`), update it to the hub or move that assertion. Keep the stub file in place (still referenced by its own test) until a later rung deletes it.

- [ ] **Step 6: Commit**

```bash
git add scenes/season_hub/season_hub.gd scenes/main.gd tests/unit/test_season_hub_scene.gd tests/unit/test_main_router.gd
git commit -m "Season Hub: boot a real season on load + route main.tscn to the hub"
```

---

## Task 10: Manual eyeball, screenshot, docs

**Files:**
- Modify: `docs/superpowers/specs/2026-06-15-season-hub-replay-design.md` (§10 findings)
- Modify: `PROJECT_ROADMAP.md` (status + Next session)

- [ ] **Step 1: Full suite green.** Run the headless suite; confirm count climbed (~566 → ~576) and `All tests passed`. Record the exact number.

- [ ] **Step 2: Eyeball in a real Godot window** (mandatory — unit tests can't see invisibility). Launch the project (`/Applications/Godot.app/Contents/MacOS/Godot --path .`), reach the hub (it boots the season). Verify: fixtures chain renders, scrub Prev/Next moves the head and the career card grows, tapping a fixture jumps, the FINAL table shows with the Player highlighted, the ₸ chip + Affinity show, the country accent is right. Fix any invisible/collapsed panel (`custom_minimum_size`, non-flat buttons).

- [ ] **Step 3: Screenshot** the hub (and one scrubbed-forward state) and save under `docs/mockups/` (e.g. `season-hub-built-v1.png`) — Nico learns by seeing.

- [ ] **Step 4: Fill spec §10** — final test count, the visual-fidelity deltas vs the hi-fi (what's approximated), the screenshot path, anything surprising (e.g. a default fresh career has only the carry-over-less empty jokers bench — expected).

- [ ] **Step 5: Update `PROJECT_ROADMAP.md`** — move the rung to done in Current status, refresh the Next-session block (next rung = the Play→match screen, or true mid-season state; seams: `SeasonView`/`SeasonViewBuilder`/`season_hub`).

- [ ] **Step 6: Commit, push, open PR, merge** (per the global commit policy — branch `season-hub-replay` → PR → merge to `main` → sync → delete branch).

```bash
git add -A && git commit -m "Season Hub replay: spec §10 findings + screenshot + roadmap"
git push -u origin season-hub-replay
gh pr create --fill && gh pr merge --merge --delete-branch
```

---

## Self-review notes (author)

- **Spec coverage:** §3 seam → Tasks 1–7; §4 fields → Tasks 1–6; §5 scene → Tasks 7–8; §6 card fold → Task 5; §7 boot → Task 9; §8 testing → every task + Task 10 eyeball. All covered.
- **Provenance:** the league table is labeled "FINAL TABLE" (Task 7 `_render_standings`); empty card shows "no matches yet", never zeros-as-data (Task 5 sentinel + Task 7 render). Matches the spec's honesty rule.
- **No ledger risk:** no resolver/tuning file is modified — only new read-model/scene code + a one-line router preload swap.
- **Type consistency:** `build(player, career_state, season_result, scrub_index)` signature identical across Tasks 2–9; `set_view`/`set_source`/`step`/`scrub_index` consistent Tasks 7–9; card field names identical Task 1 ↔ 5 ↔ 7.
- **Open risk to watch at execution:** `test_main_router.gd` may assert stub nodes — Task 9 Step 5 flags the fix. Confirm `SaveManager.has_career/load_career` exist before Task 9 (added in the Career-loop rung).
