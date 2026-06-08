class_name MatchResolver
extends RefCounted

# Pure resolution of one T20 match: two innings + a chase + a result.
# See spec 2026-06-07-full-match-design.md and ADR 0004. No member state.

# Decide the match result from the two innings. innings1 = first-batting side,
# innings2 = chasing side. player_bats_first maps the winning side to the Player's
# perspective. max_balls = the innings length (itun.over_limit * 6). Spec §5.
static func _decide_result(
		innings1: InningsResult,
		innings2: InningsResult,
		player_bats_first: bool,
		max_balls: int
) -> MatchResult:
	var r := MatchResult.new()
	r.innings1 = innings1
	r.innings2 = innings2
	r.player_bats_first = player_bats_first

	var t1 := innings1.total
	var t2 := innings2.total

	if t2 > t1:
		# Chasing side (innings2) won by wickets.
		r.margin_wickets = 10 - innings2.wickets
		r.balls_remaining = max_balls - innings2.balls
		var chasing_is_player := not player_bats_first
		r.outcome = MatchResult.Outcome.PLAYER_WIN if chasing_is_player else MatchResult.Outcome.OPPONENT_WIN
	elif t2 == t1:
		r.outcome = MatchResult.Outcome.TIE
	else:
		# Defending side (innings1) won by runs.
		r.margin_runs = t1 - t2
		var defending_is_player := player_bats_first
		r.outcome = MatchResult.Outcome.PLAYER_WIN if defending_is_player else MatchResult.Outcome.OPPONENT_WIN

	return r

# Seeded toss. Returns player_bats_first. Strawman: 50/50, winner bats first.
# A bat/bowl heuristic is deferred (spec §4). Consumes exactly one RNG draw.
static func _resolve_toss(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < 0.5

# Team-bundled match: derive six strength ints from the two Teams + Tour, flip
# the toss, then delegate to simulate_match(). Fixed RNG draw order (toss, then
# the four strength derivations) before the core sim consumes the rest, so a
# fixed seed + Teams + Tour -> identical MatchResult. The bowling number feeds
# both attack and control (spec §1/§5). See ADR 0009.
static func simulate_match_teams(
		player_attrs: Attributes,
		player_team: Team,
		opp_team: Team,
		tour: TourDistribution,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator,
		player_intent_plan: IntentPlan = null,
		player_bowling_plan: BowlingPlan = null,
		jokers: Array = [],
		field_plan: FieldPlan = null,
		player_bowl_intent_plan: IntentPlan = null,
		opp_intent_plan: IntentPlan = null,
		boost_plan: BoostPlan = null
) -> MatchResult:
	var player_bats_first := _resolve_toss(rng)
	var player_bat := player_team.batting_strength(tour, rng)
	var player_bowl := player_team.bowling_strength(tour, rng)
	var opp_bat := opp_team.batting_strength(tour, rng)
	var opp_bowl := opp_team.bowling_strength(tour, rng)

	return simulate_match(
		player_attrs,
		player_bat, player_bowl, player_bowl,
		opp_bat, opp_bowl, opp_bowl,
		player_bats_first, tuning, itun, rng,
		player_intent_plan, player_bowling_plan, jokers, field_plan,
		player_bowl_intent_plan, opp_intent_plan, boost_plan)

# Simulate a full T20 match: first innings, then a chase to target = total1 + 1,
# then decide the result. player_bats_first sets the toss (which side bats first).
# The statted Player features only in the Player's team innings; the opposition
# innings passes null. Flat param list mirrors simulate_innings (spec §2).
static func simulate_match(
		player_attrs: Attributes,
		player_team_batting: int,
		player_team_attack: int,
		player_team_control: int,
		opp_batting: int,
		opp_attack: int,
		opp_control: int,
		player_bats_first: bool,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator,
		player_intent_plan: IntentPlan = null,
		player_bowling_plan: BowlingPlan = null,
		jokers: Array = [],
		field_plan: FieldPlan = null,
		player_bowl_intent_plan: IntentPlan = null,
		opp_intent_plan: IntentPlan = null,
		boost_plan: BoostPlan = null
) -> MatchResult:
	var max_balls := itun.over_limit * 6
	var innings1: InningsResult
	var innings2: InningsResult

	# The Player bowls a build-driven quota in the opposition's batting innings.
	var p_bowl_overs := 0
	if player_attrs != null:
		p_bowl_overs = InningsResolver.player_overs(player_attrs, itun)
	var p_bowl_attack := player_attrs.attack if player_attrs != null else 0
	var p_bowl_control := player_attrs.control if player_attrs != null else 0

	# Rotation is opt-in: only when the Player supplies a bowling plan. Then both
	# sides rotate (Player's team via the plan; opposition via a textbook default).
	var rotate := player_bowling_plan != null
	var opp_bowl: BowlingAttack = null
	var player_bowl: BowlingAttack = null
	var ai_plan: BowlingPlan = null
	if rotate:
		opp_bowl = BowlingAttack.new(opp_attack, opp_control)
		player_bowl = BowlingAttack.new(player_team_attack, player_team_control)
		ai_plan = BowlingPlan.textbook()

	if player_bats_first:
		# Player's team posts (their intent), opposition chases.
		innings1 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, 0, player_intent_plan, opp_bowl, ai_plan,
			0, 0, 0, jokers, true, null, null, boost_plan)
		innings2 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, innings1.total + 1, opp_intent_plan, player_bowl, player_bowling_plan,
			p_bowl_attack, p_bowl_control, p_bowl_overs, jokers, false, field_plan, player_bowl_intent_plan, boost_plan)
	else:
		# Opposition posts, Player's team chases (their intent).
		innings1 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, 0, opp_intent_plan, player_bowl, player_bowling_plan,
			p_bowl_attack, p_bowl_control, p_bowl_overs, jokers, false, field_plan, player_bowl_intent_plan, boost_plan)
		innings2 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, innings1.total + 1, player_intent_plan, opp_bowl, ai_plan,
			0, 0, 0, jokers, true, null, null, boost_plan)

	return _decide_result(innings1, innings2, player_bats_first, max_balls)
