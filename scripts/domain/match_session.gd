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
var _opp_spec: TourSpec           # difficulty cell -> OpponentBrain plans; null = brainless (pre-rung)

var _presses: Array = []         # [innings_no, within_innings_over] pairs
var _review_balls: Array = []    # [over, ball_in_over] pairs (Player batting innings)
var _reviews_used := 0           # batting-side reviews the Player has committed
var _km_plan := KeyMomentPlan.new()   # accumulated Key Moment overrides (spec 2026-06-16)
var _km_moments: Array = []           # computed {title, prompt, from_over, cursor, choices, lever}
var _bowl_km_plan := BowlingKeyMomentPlan.new()  # accumulated bowling overrides (spec 2026-06-18)

var _result: MatchResult
var _events: Array = []
var _player := Player.new()      # carries attributes for the builder

static func start(attrs: Attributes, team: Team, opp: Team, tour: TourDistribution,
		seed: int, force_player_bats_first: int = -1,
		tuning: BallTuning = null, itun: InningsTuning = null,
		opp_spec: TourSpec = null) -> MatchSession:
	var s := MatchSession.new()
	s._attrs = attrs
	s._team = team
	s._opp = opp
	s._tour = tour
	s._seed = seed
	s._force = force_player_bats_first
	s._tuning = tuning if tuning != null else BallTuning.new()
	s._itun = itun if itun != null else InningsTuning.new()
	s._opp_spec = opp_spec
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
	# The cell's opponent brain (DL5, mirrors LeagueResolver): the AI now bats to a
	# difficulty-scaled Intent plan (defends/attacks by state at higher tiers) and
	# rotates its own bowling, instead of the old brainless default. Drawn first thing
	# off the re-seeded RNG so every re-sim is identical (the prefix-stable contract);
	# null _opp_spec draws nothing -> byte-identical to the pre-rung brainless match.
	var oip: IntentPlan = null
	var obp: BowlingPlan = null
	if _opp_spec != null:
		var plans := OpponentBrain.draw_plans(_opp_spec.brain_tier, _opp_spec.blend, rng)
		oip = plans[0]
		obp = plans[1]
	var boost := BoostPlan.new()
	for p in _presses:
		boost.press_overs.append(p[1])   # 1-based within-innings; resolver checks per innings
	var drs := DRSPolicy.new()
	drs.review_balls = _review_balls
	var ip := IntentPlan.new()         # all-BALANCED base; carries the Key Moment overrides
	ip.key_moments = _km_plan
	# Player bowling plan rides the existing player_bowling_plan slot. Only passed when
	# the opponent brain has rotation on (_opp_spec != null) — then textbook+empty-KM ==
	# the null->textbook() path the live game already runs (byte-identical), and a KM
	# override changes only the future. In the standalone path (_opp_spec == null) we keep
	# null so every pre-rung test/preview is byte-identical (spec §5 gotcha).
	var pbp: BowlingPlan = null
	if _opp_spec != null:
		pbp = BowlingPlan.new()
		pbp.key_moments = _bowl_km_plan
	var log1: Array = []
	var log2: Array = []
	_result = MatchResolver.simulate_match_teams(
		_attrs, _team, _opp, _tour, _tuning, _itun, rng,
		ip, pbp, [], null, null, oip,
		boost, drs, null, null, null, _force, obp, log1, log2)
	_result.ball_log_innings1 = log1
	_result.ball_log_innings2 = log2
	_events = MatchViewBuilder.build_events(_result, _player)
	_compute_km_moments()

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

# Is the ball at ball_id [over, ball_in_over] currently a wicket in the player's
# batting innings? Drives the post-review outcome popup (spec 2026-06-17). After a
# decide_review re-sim a successful review flips the ball to not-out (false here).
func ball_is_wicket(ball_id: Array) -> bool:
	for b in _player_batting_log():
		if b["over"] == ball_id[0] and b["ball_in_over"] == ball_id[1]:
			return b["wicket"]
	return true

# Commit a review of the dismissal at ball_id [over, ball_in_over], re-sim.
func decide_review(ball_id: Array) -> void:
	if reviews_left() <= 0:
		return
	if not _review_balls.has(ball_id):
		_review_balls.append(ball_id)
	_reviews_used += 1
	_resim()

# -- Key Moments (spec 2026-06-16) ------------------------------------------

# The player's batting-innings raw ball-log (triggers read the ball-log, not the
# player-centric event stream — a teammate's wicket lives in an over summary; D7).
func _player_batting_log() -> Array:
	return _result.ball_log_innings1 if _result.player_bats_first else _result.ball_log_innings2

# Over of the first team wicket falling in overs 7..14, else -1 (Wicket Crisis source).
# Capped at 14 so the override over (wicket+1) stays in the middle phase (<= 15) and
# never collides with Death Plan at over 16.
func _first_middle_wicket_over() -> int:
	for b in _player_batting_log():
		if b["wicket"] and b["over"] >= 7 and b["over"] <= 14:
			return b["over"]
	return -1

# Cursor (event index) of the first event of `over` in the player's batting innings,
# or -1 if the innings never reaches it (all out earlier). The pause fires BEFORE this
# event shows, so overs < `over` are byte-identical.
func _cursor_for_over(player_innings: int, over: int) -> int:
	for i in range(_events.size()):
		var e: Dictionary = _events[i]
		if e.get("innings", -1) == player_innings and e.has("over") and e["over"] == over:
			return i
	return -1

func _add_moment(player_innings: int, title: String, prompt: String, from_over: int, choices: Array, lever: String = "intent") -> void:
	var c := _cursor_for_over(player_innings, from_over)
	if c == -1:
		return  # the innings never reached this over (e.g. all out) — moment doesn't fire
	_km_moments.append({"title": title, "prompt": prompt, "from_over": from_over,
		"cursor": c, "choices": choices, "lever": lever})

# The opposition's batting-innings raw ball-log (the innings where the Player bowls).
func _opp_batting_log() -> Array:
	return _result.ball_log_innings2 if _result.player_bats_first else _result.ball_log_innings1

# Over of the first opposition wicket falling in overs 7..14, else -1 (New Batsman source).
# Capped at 14 so the override over (wicket+1) stays <= 15, never colliding with Death (16).
func _first_opp_middle_wicket_over() -> int:
	for b in _opp_batting_log():
		if b["wicket"] and b["over"] >= 7 and b["over"] <= 14:
			return b["over"]
	return -1

func _compute_km_moments() -> void:
	_km_moments = []
	var pbi := 1 if _result.player_bats_first else 2
	_add_moment(pbi, "⚡ Powerplay Exit", "How do you play the middle overs?", 7,
		[{"label": "Anchor", "band": BallResolver.Intent.DEFENSIVE},
		 {"label": "Hunt", "band": BallResolver.Intent.AGGRESSIVE}])
	var wo := _first_middle_wicket_over()
	if wo != -1:
		_add_moment(pbi, "🩸 Wicket Crisis", "A wicket's down — how do you respond?", wo + 1,
			[{"label": "Settle", "band": BallResolver.Intent.DEFENSIVE},
			 {"label": "Counter-attack", "band": BallResolver.Intent.AGGRESSIVE}])
	_add_moment(pbi, "💀 Death Plan", "Last five overs — what's the play?", 16,
		[{"label": "Milk it", "band": BallResolver.Intent.BALANCED},
		 {"label": "Go big", "band": BallResolver.Intent.AGGRESSIVE}])
	# Bowling moments fire in the opposition's batting innings and override the team's
	# bowler kind (Pace/Spin). Only when rotation is on (_opp_spec != null) — see Task 3 /
	# spec §5: the player bowling plan is passed only then, so prefixes stay byte-identical.
	if _opp_spec != null:
		var obi := 2 if _result.player_bats_first else 1
		_add_moment(obi, "🎯 Powerplay Exit", "Powerplay's done — how do you bowl the middle?", 7,
			[{"label": "Spin", "kind": BowlingPlan.Kind.SPIN},
			 {"label": "Pace", "kind": BowlingPlan.Kind.PACE}], "bowling")
		var owo := _first_opp_middle_wicket_over()
		if owo != -1:
			_add_moment(obi, "🔥 New Batsman In", "A new batter's in — how do you attack?", owo + 1,
				[{"label": "Pace", "kind": BowlingPlan.Kind.PACE},
				 {"label": "Spin", "kind": BowlingPlan.Kind.SPIN}], "bowling")
		_add_moment(obi, "💀 Death Defence", "Last five overs — how do you defend?", 16,
			[{"label": "Pace", "kind": BowlingPlan.Kind.PACE},
			 {"label": "Spin", "kind": BowlingPlan.Kind.SPIN}], "bowling")

func _km_decided(from_over: int, lever: String = "intent") -> bool:
	var plan: Variant = _bowl_km_plan if lever == "bowling" else _km_plan
	for o in plan.overrides:
		if o["from_over"] == from_over:
			return true
	return false

# Given the playback cursor (index of the event about to be shown), return the Key
# Moment to pause on — {title, prompt, from_over, lever, choices:[{label,band|kind}]} — or {}.
func key_moment_offer(cursor: int) -> Dictionary:
	for m in _km_moments:
		var lever: String = m.get("lever", "intent")
		if m["cursor"] == cursor and not _km_decided(m["from_over"], lever):
			return {"title": m["title"], "prompt": m["prompt"],
				"from_over": m["from_over"], "choices": m["choices"], "lever": lever}
	return {}

# Commit a Key Moment: override batting Intent to `band` from `from_over` onward, re-sim.
func decide_key_moment(from_over: int, band: int) -> void:
	if _km_decided(from_over, "intent"):
		return
	_km_plan.overrides.append({"from_over": from_over, "band": band})
	_resim()

# Commit a bowling Key Moment: override bowler kind to `kind` from `from_over` onward, re-sim.
func decide_bowling_key_moment(from_over: int, kind: int) -> void:
	if _km_decided(from_over, "bowling"):
		return
	_bowl_km_plan.overrides.append({"from_over": from_over, "kind": kind})
	_resim()
