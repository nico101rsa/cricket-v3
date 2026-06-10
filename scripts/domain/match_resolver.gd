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

# Bowling budget conservation (Slice 3 D12 + 2026-06-09 exact-float fix). When the
# Player bowls `n` of the innings' `overs` at their own `player_stat` (attack or
# control), the other (overs - n) bowlers bowl at this conserved value so the team's
# total bowling (n*player_stat + (overs-n)*result) == overs*team_scalar EXACTLY —
# identical to a team with no Player bowling, and to the opponent. Returns an exact
# float (no rounding): a weak part-timer is compensated by teammates bowling slightly
# ABOVE the scalar — integer rounding under-compensated this and dragged weak-bowler
# builds below par. Floors at 1.0. Pure. Spec §3.3 of the all-rounder-viability design.
#
# `concentration_k` (calibration dial, default 0 = pure linear conservation) charges
# a strong Player spell EXTRA, because n concentrated overs at a high attack take
# convexly more wickets than the same linear attack-over budget spread thin — without
# it, bowling builds keep a residual win edge (spec §8.6 D14 / §9.5.3). Penalty only
# applies when the Player bowls ABOVE the team average (player_stat > team_scalar).
static func _conserved_bowling(team_scalar: float, n: int, player_stat: int, overs: int,
		concentration_k: float = 0.0) -> float:
	if n <= 0 or n >= overs:
		return team_scalar
	var penalty := concentration_k * n * maxf(0.0, player_stat - team_scalar)
	return maxf(1.0, (overs * team_scalar - n * player_stat - penalty) / float(overs - n))

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
		boost_plan: BoostPlan = null,
		drs_policy: DRSPolicy = null,
		opp_field_plan: FieldPlan = null,
		opp_boost_plan: BoostPlan = null,
		opp_drs_policy: DRSPolicy = null,
		force_player_bats_first: int = -1
) -> MatchResult:
	# Always consume the toss draw so the RNG stream (and the default path) is
	# unchanged; only the *result* is overridden when forced (-1 = use toss,
	# 1 = Player bats first, 0 = Player bats second). The chase sweep profile forces
	# 0 so the Player's innings carries a target (is_chase) -> The Chase Master fires.
	var tossed := _resolve_toss(rng)
	var player_bats_first := tossed if force_player_bats_first == -1 else (force_player_bats_first == 1)
	var player_bat := player_team.batting_strength(tour, rng)
	var player_bowl := player_team.bowling_strength(tour, rng)
	var opp_bat := opp_team.batting_strength(tour, rng)
	var opp_bowl := opp_team.bowling_strength(tour, rng)

	# Slice 2: real rosters. The Player replaces the archetype at their build-driven
	# batting position; the opponent is the fixed standard XI. Star strength is applied
	# as a uniform batting offset (~0 at even ★3) so directionality survives. No new
	# RNG draws -> determinism preserved. See spec §8.5 (D6-D9).
	var ref3 := tour.percentile(3.0 / 5.0)
	var ppos := InningsResolver.player_position(player_attrs, itun)
	var player_roster := Team.build_xi(player_attrs, ppos)
	var opp_roster := Team.standard_xi()

	# Bowling budget conservation (Slice 3, D12): the Player bowls a 0-4 over quota
	# at their own attack/control; the other overs are scaled down so the team's
	# total bowling stays at over_limit*player_bowl — removing the free bowling
	# lever a bowler-build otherwise got. No new RNG draws -> determinism preserved.
	var n_overs := InningsResolver.player_overs(player_attrs, itun)
	var cons_attack := _conserved_bowling(player_bowl, n_overs, player_attrs.attack, itun.over_limit, itun.bowl_concentration_k)
	var cons_control := _conserved_bowling(player_bowl, n_overs, player_attrs.control, itun.over_limit, itun.bowl_concentration_k)

	return simulate_match(
		player_attrs,
		player_bat, cons_attack, cons_control,
		opp_bat, opp_bowl, opp_bowl,
		player_bats_first, tuning, itun, rng,
		player_intent_plan, player_bowling_plan, jokers, field_plan,
		player_bowl_intent_plan, opp_intent_plan, boost_plan, drs_policy, opp_field_plan,
		player_roster, opp_roster, player_bat - ref3, opp_bat - ref3,
		opp_boost_plan, opp_drs_policy)

# Simulate a full T20 match: first innings, then a chase to target = total1 + 1,
# then decide the result. player_bats_first sets the toss (which side bats first).
# The statted Player features only in the Player's team innings; the opposition
# innings passes null. Flat param list mirrors simulate_innings (spec §2).
static func simulate_match(
		player_attrs: Attributes,
		player_team_batting: int,
		player_team_attack: float,
		player_team_control: float,
		opp_batting: int,
		opp_attack: float,
		opp_control: float,
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
		boost_plan: BoostPlan = null,
		drs_policy: DRSPolicy = null,
		opp_field_plan: FieldPlan = null,
		player_roster: Array = [],
		opp_roster: Array = [],
		player_bat_offset: int = 0,
		opp_bat_offset: int = 0,
		opp_boost_plan: BoostPlan = null,
		opp_drs_policy: DRSPolicy = null
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
		# BowlingAttack works in integer pace/spin profiles; round the (now float) scalars.
		# Rotation is opt-in and not used in the balance sweep, so exact conservation lives
		# in the constant-scalar path below, not here.
		opp_bowl = BowlingAttack.new(roundi(opp_attack), roundi(opp_control))
		player_bowl = BowlingAttack.new(roundi(player_team_attack), roundi(player_team_control))
		ai_plan = BowlingPlan.textbook()

	if player_bats_first:
		# Player's team posts (their intent), opposition chases.
		innings1 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, 0, player_intent_plan, opp_bowl, ai_plan,
			0, 0, 0, jokers, true, null, null, boost_plan, drs_policy, opp_field_plan,
			player_roster, player_bat_offset, opp_boost_plan, opp_drs_policy)
		innings2 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, innings1.total + 1, opp_intent_plan, player_bowl, player_bowling_plan,
			p_bowl_attack, p_bowl_control, p_bowl_overs, jokers, false, field_plan, player_bowl_intent_plan, boost_plan, drs_policy, null,
			opp_roster, opp_bat_offset, opp_boost_plan, opp_drs_policy)
	else:
		# Opposition posts, Player's team chases (their intent).
		innings1 = InningsResolver.simulate_innings(
			null, opp_batting, player_team_attack, player_team_control,
			tuning, itun, rng, 0, opp_intent_plan, player_bowl, player_bowling_plan,
			p_bowl_attack, p_bowl_control, p_bowl_overs, jokers, false, field_plan, player_bowl_intent_plan, boost_plan, drs_policy, null,
			opp_roster, opp_bat_offset, opp_boost_plan, opp_drs_policy)
		innings2 = InningsResolver.simulate_innings(
			player_attrs, player_team_batting, opp_attack, opp_control,
			tuning, itun, rng, innings1.total + 1, player_intent_plan, opp_bowl, ai_plan,
			0, 0, 0, jokers, true, null, null, boost_plan, drs_policy, opp_field_plan,
			player_roster, player_bat_offset, opp_boost_plan, opp_drs_policy)

	return _decide_result(innings1, innings2, player_bats_first, max_balls)
