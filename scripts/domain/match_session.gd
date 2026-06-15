class_name MatchSession
extends RefCounted

# The interactive Match controller (spec DI1, Approach C). Holds the match seed +
# the accumulating Player decisions (presses / review_balls). Every decision re-runs
# the PURE MatchResolver with rebuilt policies + re-captures the ball-logs, producing
# a fresh event stream the interactive_match scene replays. No live loop, no member
# RNG (a fresh seeded RNG per re-sim) → the prefix you've already watched is
# byte-identical; only the future diverges. Spec §3.

const BOOST_BUDGET := 2   # presses per innings (DI5, strawman)
const REVIEW_BUDGET := 2  # batting-side reviews per innings (DI6)

var _attrs: Attributes
var _team: Team
var _opp: Team
var _tour: TourDistribution
var _tuning: BallTuning
var _itun: InningsTuning
var _seed: int
var _force: int                  # force_player_bats_first (-1 toss / 1 / 0)

var _presses: Array = []         # [innings_no, within_innings_over] pairs
var _review_balls: Array = []    # [over, ball_in_over] pairs (Player batting innings)
var _reviews_used := 0           # batting-side reviews the Player has committed

var _result: MatchResult
var _events: Array = []
var _player := Player.new()      # carries attributes for the builder

static func start(attrs: Attributes, team: Team, opp: Team, tour: TourDistribution,
		seed: int, force_player_bats_first: int = -1,
		tuning: BallTuning = null, itun: InningsTuning = null) -> MatchSession:
	var s := MatchSession.new()
	s._attrs = attrs
	s._team = team
	s._opp = opp
	s._tour = tour
	s._seed = seed
	s._force = force_player_bats_first
	s._tuning = tuning if tuning != null else BallTuning.new()
	s._itun = itun if itun != null else InningsTuning.new()
	s._player.attributes = attrs
	s._resim()
	return s

func result() -> MatchResult:
	return _result

func events() -> Array:
	return _events

func player() -> Player:
	return _player

# Re-run the resolver from the seed with the current accumulated policy, then rebuild
# the event stream. Called on start and after every decision. Attaches the captured
# ball-logs to the MatchResult (mirrors LeagueResolver — the resolver fills the arrays
# by reference but the caller wires them onto the result).
func _resim() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = _seed
	var boost := BoostPlan.new()
	for p in _presses:
		boost.press_overs.append(p[1])   # 1-based within-innings; resolver checks per innings
	var drs := DRSPolicy.new()
	drs.review_balls = _review_balls
	var log1: Array = []
	var log2: Array = []
	_result = MatchResolver.simulate_match_teams(
		_attrs, _team, _opp, _tour, _tuning, _itun, rng,
		null, null, [], null, null, null,
		boost, drs, null, null, null, _force, null, log1, log2)
	_result.ball_log_innings1 = log1
	_result.ball_log_innings2 = log2
	_events = MatchViewBuilder.build_events(_result, _player)

# -- Boost (DI2) -------------------------------------------------------------

# Is innings_no (1/2) the Player's batting innings?
func player_bats_this(innings_no: int) -> bool:
	return (innings_no == 1) == _result.player_bats_first

func _presses_in(innings_no: int) -> int:
	var n := 0
	for p in _presses:
		if p[0] == innings_no:
			n += 1
	return n

func presses_left(innings_no: int) -> int:
	return maxi(0, BOOST_BUDGET - _presses_in(innings_no))

func can_boost(innings_no: int) -> bool:
	return presses_left(innings_no) > 0

# Add a Boost press at 1-based within-innings over in innings_no, re-sim.
func decide_boost(innings_no: int, over: int) -> void:
	if presses_left(innings_no) <= 0:
		return
	_presses.append([innings_no, over])
	_resim()

# Back-compat helper: boost innings 1.
func decide_boost_over(over: int) -> void:
	decide_boost(1, over)

# -- DRS review (DI3) --------------------------------------------------------

func reviews_left() -> int:
	return maxi(0, REVIEW_BUDGET - _reviews_used)

# Given the playback cursor (index of the event about to be shown), is it a Player
# dismissal the Player can review? Returns {ball_id:[over,ball], over, ball} or {}.
func review_offer(cursor: int) -> Dictionary:
	if reviews_left() <= 0:
		return {}
	if cursor < 0 or cursor >= _events.size():
		return {}
	var e: Dictionary = _events[cursor]
	if e["type"] == "ball" and e.get("player_batting", false) and e["wicket"]:
		return {"ball_id": [e["over"], e["ball"]], "over": e["over"], "ball": e["ball"]}
	return {}

# Commit a review of the dismissal at ball_id [over, ball_in_over], re-sim.
func decide_review(ball_id: Array) -> void:
	if reviews_left() <= 0:
		return
	if not _review_balls.has(ball_id):
		_review_balls.append(ball_id)
	_reviews_used += 1
	_resim()
