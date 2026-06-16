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
var _ai_fixtures: Array = [] # resolved AI-vs-AI completed records (see _completed)
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
# Player game k (0-based played_count()) is the fixture vs _teams[k+1].
func next_player_opponent() -> Dictionary:
	if league_done():
		return {}
	var idx := played_count() + 1
	var opp: Team = _teams[idx]
	return {"name": opp.team_name, "team_index": idx}

# --- internals ---

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
		# Player is team 0 (i); opponent is team k+1 (j).
		_apply(rows, _completed(0, k + 1, m, m.player_bats_first))
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
