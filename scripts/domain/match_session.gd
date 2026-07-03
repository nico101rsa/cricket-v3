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
var _player_effects: Array = []   # owned-joker effect rows; [] = none (byte-identical)
# Form (spec 2026-07-03 DF6): the match-START points + Affinity base mult. _resim
# always rebuilds a FRESH FormState from these -- decisions re-sim the same match,
# never a compounded one.
var _form_start := 0.0
var _form_base_mult := 1.0
var _use_form := false

var _presses: Array = []         # [innings_no, within_innings_over] pairs
var _review_balls: Array = []    # [over, ball_in_over] pairs (Player batting innings)
var _reviews_used := 0           # FAILED reviews (T20 rule: success retains — DT9);
                                 # recomputed from the log after every re-sim
var _drs_moments: Array = []     # computed DRS decision moments (spec 2026-07-04 DT7)
var _moment_p_override := -1.0   # test seam: force every moment p (DT6); < 0 = hash
var _km_plan := KeyMomentPlan.new()   # accumulated Key Moment overrides (spec 2026-06-16)
var _km_moments: Array = []           # computed {title, prompt, from_over, cursor, choices, lever}
var _bowl_km_plan := BowlingKeyMomentPlan.new()  # accumulated bowling overrides (spec 2026-06-18)

var _result: MatchResult
var _events: Array = []
var _player := Player.new()      # carries attributes for the builder

static func start(attrs: Attributes, team: Team, opp: Team, tour: TourDistribution,
		seed: int, force_player_bats_first: int = -1,
		tuning: BallTuning = null, itun: InningsTuning = null,
		opp_spec: TourSpec = null, player_effects: Array = [],
		form_start: float = 0.0, form_base_mult: float = 1.0, use_form: bool = false) -> MatchSession:
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
	s._player_effects = player_effects
	s._form_start = form_start
	s._form_base_mult = form_base_mult
	s._use_form = use_form
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
	drs.moment_p_override = _moment_p_override
	# T8 symmetry (DT4): the live opponent holds base DRS too — it can overturn
	# your wickets and claim close dots, exactly like the headless fair fight.
	var odrs := DRSPolicy.new()
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
	# Player jokers (spec 2026-06-26): fire owned effects in the live match. The field
	# plan for gated jokers is derived exactly as the headless career does (CF3); boost
	# stays human-controlled (the player's presses), so boost-role jokers fire only when
	# the player presses Boost. Empty effects -> null field + [] jokers -> byte-identical.
	var fld: FieldPlan = null
	if not _player_effects.is_empty():
		fld = ShopResolver.plans_for(_player_effects)["field"]
	var log1: Array = []
	var log2: Array = []
	var fs: FormState = FormState.make(_form_start, _form_base_mult) if _use_form else null
	_result = MatchResolver.simulate_match_teams(
		_attrs, _team, _opp, _tour, _tuning, _itun, rng,
		ip, pbp, _player_effects, fld, null, oip,
		boost, drs, null, null, odrs, _force, obp, log1, log2, fs)
	_result.ball_log_innings1 = log1
	_result.ball_log_innings2 = log2
	_events = MatchViewBuilder.build_events(_result, _player)
	_compute_km_moments()
	_compute_drs_moments()
	# DT9: only FAILED reviews burn budget (the reviewed ball still reads as a
	# wicket); a successful review is retained, T20-style.
	_reviews_used = 0
	for bid in _review_balls:
		if ball_is_wicket(bid):
			_reviews_used += 1

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

# -- DRS review (DI3 + decision moments, spec 2026-07-04) --------------------

func reviews_left() -> int:
	return maxi(0, REVIEW_BUDGET - _reviews_used)

# Test seam (DT6): force every moment's success chance; re-sims so p_shown follows.
func set_moment_p_override(v: float) -> void:
	_moment_p_override = v
	_resim()

# Shown/rolled odds for a moment: the hash-drawn moment p plus the Reviewer-joker
# ACCURACY/MASTER bonuses that apply at this ball's intent — mirrors
# JokerRuntime.try_review, so the number on the card IS the number rolled (DT3).
func _drs_shown_p(base_p: float, intent: int) -> float:
	var p := base_p
	for j in _player_effects:
		match j.drs_role:
			JokerEffect.DRSRole.ACCURACY:
				if j.intent_req == -1 or intent == j.intent_req:
					p += j.drs_p_bonus
			JokerEffect.DRSRole.MASTER:
				p += JokerRuntime.DRS_MASTER_BONUS
	return clampf(p, 0.0, 1.0)

# Cursor of the event CONTAINING this ball in the player's batting innings: the
# hero's own deliveries are "ball" events; a teammate's wicket lives inside its
# over-summary event. The pause fires before the event shows (prefix untouched).
func _cursor_for_ball(player_innings: int, over: int, bio: int, hero_ball: bool) -> int:
	for i in range(_events.size()):
		var e: Dictionary = _events[i]
		if e.get("innings", -1) != player_innings:
			continue
		if hero_ball:
			if e["type"] == "ball" and e["over"] == over and e.get("ball", -1) == bio:
				return i
		else:
			if e["type"] == "over" and e["over"] == over:
				return i
	return -1

# Walk the team-batting ball log for qualifying wickets (DT2 gate) — ANY batter,
# not just the hero — and anchor each to its playback cursor with the shown odds.
func _compute_drs_moments() -> void:
	_drs_moments = []
	var log := _player_batting_log()
	var pbi := 1 if _result.player_bats_first else 2
	var faced := {}    # striker_pos -> balls faced before the current delivery
	var scored := {}   # striker_pos -> runs scored so far
	for b in log:
		var pos: int = b["striker_pos"]
		var before: int = faced.get(pos, 0)
		faced[pos] = before + 1
		if not b["wicket"]:
			scored[pos] = scored.get(pos, 0) + b["runs"]
			continue
		var flavour: String = DRSMoments.flavour_of(b["player_batting"], b["over"], b["ball_in_over"])
		if not DRSMoments.is_moment(flavour, before, b["over"]):
			continue
		var c := _cursor_for_ball(pbi, b["over"], b["ball_in_over"], bool(b["is_player"]))
		if c == -1:
			continue
		var base_p: float = _moment_p_override if _moment_p_override >= 0.0 \
			else DRSMoments.moment_p(b["player_batting"], b["over"], b["ball_in_over"])
		_drs_moments.append({
			"cursor": c, "ball_id": [b["over"], b["ball_in_over"]],
			"over": b["over"], "ball": b["ball_in_over"],
			"batter_pos": pos, "batter_runs": scored.get(pos, 0), "batter_balls": before,
			"is_player": b["is_player"], "flavour": flavour,
			"p_shown": _drs_shown_p(base_p, b["intent"]),
			"death": b["over"] >= DRSMoments.DEATH_OVER,
		})

# Given the playback cursor (index of the event about to be shown), is there a DRS
# decision moment here? Returns the enriched moment dict (DT7) or {}. A ball the
# player already reviewed (and lost) is not re-offered.
func review_offer(cursor: int) -> Dictionary:
	if reviews_left() <= 0:
		return {}
	for m in _drs_moments:
		if m["cursor"] == cursor and not _review_balls.has(m["ball_id"]):
			return m
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
# Budget accounting happens in _resim (failed reviews only — DT9).
func decide_review(ball_id: Array) -> void:
	if reviews_left() <= 0:
		return
	if not _review_balls.has(ball_id):
		_review_balls.append(ball_id)
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

# -- Cross-session save: replay-from-decisions (spec 2026-06-23) -------------
# The match is fully reproducible from the seed + this small set of player decisions
# (the determinism contract). export_decisions() snapshots them as plain serialisable
# data; apply_decisions() rebuilds the internal plans and re-sims once, so a fresh
# same-seed session reaches the identical result. Deep-duplicated so the caller can
# serialise/mutate the snapshot without aliasing the live session.

func export_decisions() -> Dictionary:
	return {
		"presses": _presses.duplicate(true),
		"review_balls": _review_balls.duplicate(true),
		"km": _km_plan.overrides.duplicate(true),
		"bowl_km": _bowl_km_plan.overrides.duplicate(true),
	}

func apply_decisions(d: Dictionary) -> void:
	_presses = (d.get("presses", []) as Array).duplicate(true)
	_review_balls = (d.get("review_balls", []) as Array).duplicate(true)
	_km_plan = KeyMomentPlan.new()
	_km_plan.overrides = (d.get("km", []) as Array).duplicate(true)
	_bowl_km_plan = BowlingKeyMomentPlan.new()
	_bowl_km_plan.overrides = (d.get("bowl_km", []) as Array).duplicate(true)
	_resim()
