class_name LeagueResolver
extends RefCounted

# Resolves a Season's league phase: an 8-team single round-robin, every game
# simulated, into a points+NRR table. See spec
# 2026-06-07-season-league-7b2a-design.md and ADR 0002/0004/0009. No member state.

const NUM_TEAMS := 8
const PLAYOFF_CUTOFF := 4

# Every unique unordered pair (i, j) with i < j. 8 teams -> 28 fixtures.
static func round_robin(num_teams: int) -> Array:
	var fixtures: Array = []
	for i in range(num_teams):
		for j in range(i + 1, num_teams):
			fixtures.append(Vector2i(i, j))
	return fixtures

# Simulate the full league phase. teams = [player_team] + opponents (index 0 is
# the Player). Each team's strength is drawn ONCE (held all Season, ADR 0009);
# every game is simulated (Player games statted, others via simulate_match(null)).
# Deterministic given rng. See spec §4-§8.
static func simulate_league(
		player_attrs: Attributes,
		player_team: Team,
		opponents: Array,
		tour: TourDistribution,
		tuning: BallTuning,
		itun: InningsTuning,
		rng: RandomNumberGenerator,
		player_intent_plan: IntentPlan = null,
		player_bowling_plan: BowlingPlan = null,
		opp_spec: TourSpec = null,
		jokers: Array = [],
		shop_hook: Callable = Callable(),
		capture: bool = false,
		form_state: FormState = null
) -> LeagueResult:
	var teams: Array = [player_team]
	teams.append_array(opponents)
	var n := teams.size()

	# Per-Season strength draw, held all Season (fixed team order).
	var bat: Array = []
	var bowl: Array = []
	for t in teams:
		bat.append(t.batting_strength(tour, rng))
		bowl.append(t.bowling_strength(tour, rng))

	var rows: Array = []
	for idx in range(n):
		var row := StandingsRow.new()
		row.team_index = idx
		rows.append(row)

	var player_matches: Array = []

	# Career-fidelity CF1: every fixture runs the tuned ROSTER path (real XIs +
	# proportional bat factors), the same sim the balance ledger was tuned on.
	var rosters := build_rosters(player_attrs, itun, n)

	# Bowling budget conservation on the Player's fixtures (closes the CF1 deferred
	# gap): mirror simulate_match_teams — the Player bowls their quota at their own
	# attack/control, teammates bowl the conserved remainder so the team's total
	# bowling budget matches a no-Player team. Without this the season path handed
	# bowler builds a free ~+12% bowling budget (a ~+9pp fixture-win edge vs the
	# match harness). bowl[0] is the season-held draw, so compute once.
	var cons_attack: float = bowl[0]
	var cons_control: float = bowl[0]
	if player_attrs != null:
		var n_overs := InningsResolver.player_overs(player_attrs, itun)
		cons_attack = MatchResolver._conserved_bowling(bowl[0], n_overs, player_attrs.attack, itun.over_limit, itun.bowl_concentration_k)
		cons_control = MatchResolver._conserved_bowling(bowl[0], n_overs, player_attrs.control, itun.over_limit, itun.bowl_concentration_k)

	for fx in round_robin(n):
		var i: int = fx.x
		var j: int = fx.y
		var i_bats_first := MatchResolver._resolve_toss(rng)
		var p_attrs: Attributes = player_attrs if i == 0 else null
		var ip: IntentPlan = player_intent_plan if i == 0 else null
		var bp: BowlingPlan = player_bowling_plan if i == 0 else null
		# E3: the cell's opponent brain fires on Player-facing fixtures only
		# (DL5). round_robin has i < j, so the Player (index 0) is always i.
		var oip: IntentPlan = null
		var obp: BowlingPlan = null
		if opp_spec != null and i == 0:
			var plans := OpponentBrain.draw_plans(opp_spec.brain_tier, opp_spec.blend, rng)
			oip = plans[0]
			obp = plans[1]
		# Career-fidelity CF3: Player-facing fixtures play under base two-sided
		# DRS (the fair-fight rule) + the field/Boost plans the loadout wants.
		var fp: FieldPlan = null
		var bplan: BoostPlan = null
		var dp: DRSPolicy = null
		var odp: DRSPolicy = null
		if i == 0:
			var jplans := ShopResolver.plans_for(jokers)
			fp = jplans["field"]
			bplan = jplans["boost"]
			dp = DRSPolicy.new()
			odp = DRSPolicy.new()
		var bl1 = [] if (capture and i == 0) else null
		var bl2 = [] if (capture and i == 0) else null
		var m := MatchResolver.simulate_match(
			p_attrs,
			bat[i],
			cons_attack if i == 0 else bowl[i],
			cons_control if i == 0 else bowl[i],
			bat[j], bowl[j], bowl[j],
			i_bats_first, tuning, itun, rng, ip, bp,
			jokers if i == 0 else [], fp, null, oip, bplan, dp, null,
			rosters[i], rosters[j], bat[i] / MatchResolver.REF_SCALAR, bat[j] / MatchResolver.REF_SCALAR,
			null, odp, obp, bl1, bl2,
			form_state if i == 0 else null)  # DF8 -- the Player's fixtures only

		# Attribute innings (innings1 = first-batting side).
		var i_inns: InningsResult = m.innings1 if i_bats_first else m.innings2
		var j_inns: InningsResult = m.innings2 if i_bats_first else m.innings1
		var ri: StandingsRow = rows[i]
		var rj: StandingsRow = rows[j]
		ri.played += 1
		rj.played += 1
		ri.runs_for += i_inns.total
		ri.balls_for += i_inns.balls
		ri.runs_against += j_inns.total
		ri.balls_against += j_inns.balls
		rj.runs_for += j_inns.total
		rj.balls_for += j_inns.balls
		rj.runs_against += i_inns.total
		rj.balls_against += i_inns.balls

		match m.outcome:
			MatchResult.Outcome.PLAYER_WIN:
				ri.points += 2
			MatchResult.Outcome.OPPONENT_WIN:
				rj.points += 2
			MatchResult.Outcome.TIE:
				ri.points += 1
				rj.points += 1

		if i == 0:
			if capture:
				m.ball_log_innings1 = bl1
				m.ball_log_innings2 = bl2
			player_matches.append(m)
			# Shop visits V1/V2 (shop rung DK2): after Player matches 3 and 5.
			if shop_hook.is_valid() and (player_matches.size() == 3 or player_matches.size() == 5):
				jokers = shop_hook.call(player_matches.duplicate())

	# Rank: points desc, then NRR desc, then team_index asc.
	var cmp := func(a: StandingsRow, b: StandingsRow) -> bool:
		if a.points != b.points:
			return a.points > b.points
		var na := a.nrr()
		var nb := b.nrr()
		if not is_equal_approx(na, nb):
			return na > nb
		return a.team_index < b.team_index
	rows.sort_custom(cmp)

	var result := LeagueResult.new()
	result.standings = rows
	result.player_matches = player_matches
	result.team_bat = bat
	result.team_bowl = bowl
	for pos in range(rows.size()):
		if rows[pos].team_index == 0:
			result.player_position = pos + 1
			break
	result.made_playoffs = result.player_position <= PLAYOFF_CUTOFF
	return result


# Career-fidelity CF1: the rosters every fixture plays with — standard XIs for
# all teams, the Player's team built around their card at their build-driven
# batting position. Index-aligned with the league's team order (Player = 0).
static func build_rosters(player_attrs: Attributes, itun: InningsTuning, n: int) -> Array:
	var out: Array = []
	for k in range(n):
		out.append(Team.standard_xi())
	if player_attrs != null:
		out[0] = Team.build_xi(player_attrs, InningsResolver.player_position(player_attrs, itun))
	return out
