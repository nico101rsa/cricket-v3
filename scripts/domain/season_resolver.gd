class_name SeasonResolver
extends RefCounted

# Resolves a full Season: league phase (LeagueResolver) -> top-4 knockout
# playoffs -> outcome. Deterministic given rng (league draws, then SF1, SF2,
# Final, 3rd-place in order). See spec 2026-06-08-season-playoffs-7b2b-design.md.
# No member state.

# Play one knockout. Returns {winner, loser, result}. On a tie the better seed
# (lower league position) advances. The Player (team 0), when involved, is
# statted as the simulate_match "player slot"; otherwise both sides derived.
static func _knockout(
		a_idx: int, a_seed: int, b_idx: int, b_seed: int,
		team_bat: Array, team_bowl: Array,
		player_attrs: Attributes, tuning: BallTuning, itun: InningsTuning,
		rng: RandomNumberGenerator, ip: IntentPlan, bp: BowlingPlan,
		opp_spec: TourSpec = null,
		jokers: Array = [],
		rosters: Array = []
) -> Dictionary:
	var s1 := a_idx
	var s2 := b_idx
	if b_idx == 0:                # put the Player in the simulate_match player slot
		s1 = b_idx
		s2 = a_idx
	var pa: Attributes = player_attrs if s1 == 0 else null
	var ipp: IntentPlan = ip if s1 == 0 else null
	var bpp: BowlingPlan = bp if s1 == 0 else null
	var toss := MatchResolver._resolve_toss(rng)
	# E3 (DL5): the cell's brain fires only when the Player is in the knockout.
	# Fixed RNG order: toss -> brain draws -> match.
	var oip: IntentPlan = null
	var obp: BowlingPlan = null
	if opp_spec != null and s1 == 0:
		var plans := OpponentBrain.draw_plans(opp_spec.brain_tier, opp_spec.blend, rng)
		oip = plans[0]
		obp = plans[1]
	# Career-fidelity CF1/CF3: roster path + base DRS / loadout plans for the
	# Player's knockouts, mirroring the league fixtures.
	var pr: Array = []
	var orr: Array = []
	var pf := 1.0
	var of := 1.0
	if not rosters.is_empty():
		pr = rosters[s1]
		orr = rosters[s2]
		pf = team_bat[s1] / MatchResolver.REF_SCALAR
		of = team_bat[s2] / MatchResolver.REF_SCALAR
	var fp: FieldPlan = null
	var bplan: BoostPlan = null
	var dp: DRSPolicy = null
	var odp: DRSPolicy = null
	if s1 == 0:
		var jplans := ShopResolver.plans_for(jokers)
		fp = jplans["field"]
		bplan = jplans["boost"]
		dp = DRSPolicy.new()
		odp = DRSPolicy.new()
	var m := MatchResolver.simulate_match(
		pa, team_bat[s1], team_bowl[s1], team_bowl[s1],
		team_bat[s2], team_bowl[s2], team_bowl[s2],
		toss, tuning, itun, rng, ipp, bpp,
		jokers if s1 == 0 else [], fp, null, oip, bplan, dp, null,
		pr, orr, pf, of, null, odp, obp)
	var s1_won: bool
	if m.outcome == MatchResult.Outcome.TIE:
		var s1_seed := a_seed if s1 == a_idx else b_seed
		var s2_seed := b_seed if s1 == a_idx else a_seed
		s1_won = s1_seed < s2_seed       # better seed advances
	elif m.outcome == MatchResult.Outcome.PLAYER_WIN:
		s1_won = true
	else:
		s1_won = false
	var winner := s1 if s1_won else s2
	var loser := s2 if s1_won else s1
	return {"winner": winner, "loser": loser, "result": m}

static func simulate_season(
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
		capture: bool = false
) -> SeasonResult:
	var league := LeagueResolver.simulate_league(
		player_attrs, player_team, opponents, tour, tuning, itun, rng,
		player_intent_plan, player_bowling_plan, opp_spec, jokers, shop_hook, capture)
	# Career-fidelity CF2: knockouts play the same roster path as the league.
	var rosters := LeagueResolver.build_rosters(player_attrs, itun, opponents.size() + 1)
	var bat: Array = league.team_bat
	var bowl: Array = league.team_bowl

	# Seeds 1-4 = league positions 1-4 (their team_index).
	var s1i: int = league.standings[0].team_index
	var s2i: int = league.standings[1].team_index
	var s3i: int = league.standings[2].team_index
	var s4i: int = league.standings[3].team_index

	# Shop visit V3 (DK2): before the semi-final, only if the Player seeded top-4.
	var player_seed := 0
	for s in range(4):
		if league.standings[s].team_index == 0:
			player_seed = s + 1
	if shop_hook.is_valid() and player_seed > 0:
		jokers = shop_hook.call(league.player_matches.duplicate())

	# Semi-finals: 1v4, 2v3.
	var sf1 := _knockout(s1i, 1, s4i, 4, bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan, opp_spec, jokers, rosters)
	var sf2 := _knockout(s2i, 2, s3i, 3, bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan, opp_spec, jokers, rosters)

	# Seed lookup for the bracket (team_index -> league position 1..4).
	var seed_of := {s1i: 1, s2i: 2, s3i: 3, s4i: 4}

	# Shop visit V4 (DK2): before the Player's championship match (Final or
	# 3rd-place playoff). Matches-so-far includes the Player's semi.
	if shop_hook.is_valid() and player_seed > 0:
		var pm_so_far: Array = league.player_matches.duplicate()
		var player_semi: Dictionary = sf1 if (player_seed == 1 or player_seed == 4) else sf2
		pm_so_far.append(player_semi["result"])
		jokers = shop_hook.call(pm_so_far)

	# Final: the two semi winners (better seed first). 3rd-place: the two losers.
	var fw_a: int = sf1["winner"]
	var fw_b: int = sf2["winner"]
	var final_kn: Dictionary
	if seed_of[fw_a] <= seed_of[fw_b]:
		final_kn = _knockout(fw_a, seed_of[fw_a], fw_b, seed_of[fw_b], bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan, opp_spec, jokers, rosters)
	else:
		final_kn = _knockout(fw_b, seed_of[fw_b], fw_a, seed_of[fw_a], bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan, opp_spec, jokers, rosters)

	var tl_a: int = sf1["loser"]
	var tl_b: int = sf2["loser"]
	var third_kn: Dictionary
	if seed_of[tl_a] <= seed_of[tl_b]:
		third_kn = _knockout(tl_a, seed_of[tl_a], tl_b, seed_of[tl_b], bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan, opp_spec, jokers, rosters)
	else:
		third_kn = _knockout(tl_b, seed_of[tl_b], tl_a, seed_of[tl_a], bat, bowl, player_attrs, tuning, itun, rng, player_intent_plan, player_bowling_plan, opp_spec, jokers, rosters)

	var result := SeasonResult.new()
	result.league = league
	result.semi1 = sf1["result"]
	result.semi2 = sf2["result"]
	result.final_match = final_kn["result"]
	result.third_place = third_kn["result"]

	var order: Array = [
		final_kn["winner"], final_kn["loser"],
		third_kn["winner"], third_kn["loser"],
	]
	for k in range(4, 8):
		order.append(league.standings[k].team_index)
	result.final_order = order

	for pos in range(order.size()):
		if order[pos] == 0:
			result.player_final_position = pos + 1
			break
	result.beat = result.player_final_position <= 3
	result.won_final = result.player_final_position == 1
	return result
