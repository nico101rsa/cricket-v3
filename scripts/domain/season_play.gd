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

enum Phase { LEAGUE, PLAYOFFS, DONE }

var _attrs: Attributes
var _teams: Array            # [player_team] + opponents, index-aligned with the table
var _tour: TourDistribution
var _tuning: BallTuning
var _itun: InningsTuning
var _seed: int
var _opp_spec: TourSpec       # difficulty cell -> the interactive opponent's brain (DL5)
var _player_effects: Array = []   # owned-joker effect rows passed to every player match

# --- The Kit Room on the live driver (spec 2026-07-02, Rung 2) ---
var _shop: ShopState = null       # null = shop off (byte-identical pre-rung path)
var _shop_player: Player = null   # rebound every enable_shop (hub reloads the Player)
var _setun: EconomyTuning = null
var _shop_level: int = 0
var _shop_tour: int = 0
var _visits_mask: int = 0         # bit v set = visit v consumed (v0..v4)
var _paid_mask: int = 0           # bit v set = the visit's one paid action used (DK2-3)
var _shop_log: Array = []
var _offer_cache: Dictionary = {} # visit -> rolled offer (stable within a visit)

var _bat: Array = []         # held per-team batting strength (ADR 0009), index-aligned
var _bowl: Array = []        # held per-team bowling strength
var _ai_fixtures: Array = [] # resolved AI-vs-AI completed records (see _completed)
var _player_results: Array = []   # committed MatchResult, one per played player game
var _decisions: Array = []        # one decision Dictionary per committed player match
                                  # (cross-session save, spec 2026-06-23): the season
                                  # replays losslessly from the seed + this small log.

# --- Playoffs (Slice 1, spec 2026-06-22-live-season-loop-finish) ---
var _phase: int = Phase.LEAGUE
var _seeds: Array = []           # [s1,s2,s3,s4] team indices = league positions 1-4
var _player_seed: int = 0        # 1..4 if the Player made top-4, else 0
var _player_semi: String = ""    # "sf1" (seeds 1&4) or "sf2" (seeds 2&3)
var _pending_stage: String = ""  # "semi" | "final" | "third" | "" (player's next knockout)
var _sf1: Dictionary = {}        # {winner, loser, result} — seed1 v seed4
var _sf2: Dictionary = {}        # seed2 v seed3
var _final: Dictionary = {}      # the two semi winners
var _third: Dictionary = {}      # the two semi losers
var _po_rng: RandomNumberGenerator = null   # one stream for all auto-resolved knockouts
var _season_result: SeasonResult = null     # complete outcome once season_done()

# --- ₸ pay (Slice 3) — disabled until enable_pay(); then mirrors
# CareerResolver._settle_matches: each played match banks match_pay +
# match_win_prize (on a win); season_prizes added once at season end. ---
var _pay_player: Player = null
var _etun: EconomyTuning = null
var _pay_stars: float = 0.0
var _pay_level: int = 0
var _pay_tour: int = 0
var _pay_total: int = 0
var _wins: int = 0

static func start(player_attrs: Attributes, player_team: Team, opponents: Array,
		tour: TourDistribution, tuning: BallTuning, itun: InningsTuning,
		seed: int, opp_spec: TourSpec = null) -> SeasonPlay:
	var sp := SeasonPlay.new()
	sp._attrs = player_attrs
	sp._teams = [player_team]
	sp._teams.append_array(opponents)
	sp._tour = tour
	sp._tuning = tuning
	sp._itun = itun
	sp._seed = seed
	sp._opp_spec = _floored_spec(opp_spec)
	sp._draw_strengths()
	sp._resolve_ai_fixtures()
	return sp

# Owned-joker effect rows that fire in the player's live matches (spec 2026-06-26).
# [] = none (byte-identical). With the Kit Room live (Rung 2) the shop's loadout
# drives this via _refresh_loadout; the setter remains for tests/direct use.
func set_player_jokers(effects: Array) -> void:
	_player_effects = effects

# --- The Kit Room (spec 2026-07-02, Rung 2) ----------------------------------

# Turn on the live Kit Room. Rebind + init-once (DK2-5/DK2-9): every call rebinds the
# (freshly re-loaded) Player and its Attributes; the ShopState itself initializes only
# on the first call — the carry-over joker enters free, exactly like headless V0 (DK2).
func enable_shop(player: Player, etun: EconomyTuning, level: int, tour_index: int,
		carryover_id: String = "") -> void:
	_shop_player = player
	_setun = etun
	_shop_level = level
	_shop_tour = tour_index
	_attrs = player.attributes   # training must stay visible to future matches (DK2-9)
	if _shop != null:
		return
	_shop = ShopState.new()
	if carryover_id != "":
		_shop.owned_ids.append(carryover_id)
		_shop.paid_prices[carryover_id] = 0
		_shop_log.append({"action": "carryover_in", "id": carryover_id})
	_refresh_loadout()

func shop_enabled() -> bool: return _shop != null
func shop() -> ShopState: return _shop
func shop_log() -> Array: return _shop_log
func shop_owned() -> Array: return _shop.owned_ids if _shop != null else []
func player_effects() -> Array: return _player_effects
func shop_balance() -> int: return _shop_player.tons_balance if _shop_player != null else 0
func sell_refund_of(id: String) -> int:
	return Economy.sell_refund(int(_shop.paid_prices.get(id, 0)), _setun)
func train_cost_of(attr: String) -> int:
	return Economy.attr_upgrade_cost(_shop_player.attributes.get(attr), _setun)
func train_value_of(attr: String) -> float:
	return _shop_player.attributes.get(attr) if _shop_player != null else 0.0
func paid_action_used() -> bool:
	var p := pending_shop_visit()
	return not p.is_empty() and (_paid_mask & (1 << int(p["visit"]))) != 0

func _refresh_loadout() -> void:
	_player_effects = ShopResolver.loadout_effects(_shop)

# The canon visit now due, or {} (DK2-1). Offers roll on a fresh per-visit RNG
# (_seed + 9000 + v, DK2-2) and are cached until the visit is consumed.
func pending_shop_visit() -> Dictionary:
	if _shop == null:
		return {}
	for v in range(5):
		if _visits_mask & (1 << v):
			continue
		if not _visit_open(v):
			continue
		if not _offer_cache.has(v):
			var rng := RandomNumberGenerator.new()
			rng.seed = _seed + 9000 + v
			_offer_cache[v] = ShopResolver.starter_offer(rng, _shop) if v == 0 \
				else ShopResolver.roll_offer(rng, _shop, _shop_level, _shop_tour, _setun)
		return {"kind": "starter" if v == 0 else "visit", "visit": v, "offer": _offer_cache[v]}
	return {}

func _visit_open(v: int) -> bool:
	match v:
		0: return _phase == Phase.LEAGUE and played_count() == 0
		1: return played_count() >= 3
		2: return played_count() >= 5
		3: return _phase == Phase.PLAYOFFS and _pending_stage == "semi"
		4: return _phase == Phase.PLAYOFFS and _pending_stage == "final"
	return false

# One per-tap Kit Room action against the pending visit. All money/slot maths stays
# in ShopResolver (which push_warnings + no-ops illegal input). Paid actions (buy OR
# train) are capped at one per visit (_paid_mask, DK2-3); sell/hold are free; pick
# and skip consume the visit. Returns success.
func apply_shop_action(act: Dictionary) -> bool:
	var pending := pending_shop_visit()
	if pending.is_empty():
		push_warning("shop action with no pending visit")
		return false
	var v: int = pending["visit"]
	var paid_used := (_paid_mask & (1 << v)) != 0
	match act.get("kind", ""):
		"pick":
			if pending["kind"] != "starter" or not act.get("id", "") in (pending["offer"] as Array):
				return false
			_shop.owned_ids.append(act["id"])
			_shop.paid_prices[act["id"]] = 0
			_shop_log.append({"action": "starter", "id": act["id"]})
			_consume(v)
			_refresh_loadout()
			return true
		"skip":
			_consume(v)
			return true
		"buy":
			if pending["kind"] != "visit" or paid_used:
				return false
			var offer: Dictionary = pending["offer"]
			var price: int = offer["prices"].get(act.get("id", ""), -1)
			if price < 0:
				push_warning("buy not in offer: %s" % act.get("id", ""))
				return false
			if ShopResolver.buy(_shop, _shop_player, act["id"], price, _setun, act.get("replace", "")):
				_shop_log.append({"action": "buy", "id": act["id"], "tons": price})
				_paid_mask |= 1 << v
				_refresh_loadout()
				return true
			return false
		"train":
			if pending["kind"] != "visit" or paid_used:
				return false
			if ShopResolver.upgrade_attribute(_shop_player, act.get("attr", ""), _setun):
				_shop_log.append({"action": "upgrade", "id": act["attr"]})
				_paid_mask |= 1 << v
				return true
			return false
		"sell":
			if pending["kind"] != "visit":
				return false
			if ShopResolver.sell(_shop, _shop_player, act.get("id", ""), _setun):
				_shop_log.append({"action": "sell", "id": act["id"]})
				_refresh_loadout()
				return true
			return false
		"hold":
			if pending["kind"] != "visit":
				return false
			if ShopResolver.hold(_shop, pending["offer"], act.get("id", "")):
				_shop_log.append({"action": "hold", "id": act["id"]})
				return true
			return false
	return false

func _consume(v: int) -> void:
	_visits_mask |= 1 << v
	_offer_cache.erase(v)

# The marquee interactive opponent always plays at least competent textbook cricket.
# The difficulty ladder dumbs the entry tours with a sub-textbook NAIVE blend
# (TEXTBOOK p0.4 — a league-realism device, PL2): in a 1-v-1 that's just a random
# opponent who plays badly and HANDS the underdog wins (measured 2026-06-18: faithful
# p0.4 read base 58.9% vs floored textbook 43.8% for the 1.5★ ref build). So floor the
# brain at full textbook (no naive drop); difficulty still SCALES above it
# (static_eq -> adaptive) as you climb. null = no brain (unchanged).
static func _floored_spec(opp_spec: TourSpec) -> TourSpec:
	if opp_spec == null:
		return null
	var f := TourSpec.new()
	f.level = opp_spec.level
	f.tour_index = opp_spec.tour_index
	f.d = opp_spec.d
	f.cell_name = opp_spec.cell_name
	f.opp_stars = opp_spec.opp_stars
	f.brain_tier = maxi(opp_spec.brain_tier, TourSpec.Tier.TEXTBOOK)
	# blend < 1.0 drops one tier; at textbook that drop is NAIVE (random) — disallowed.
	f.blend = 1.0 if f.brain_tier == TourSpec.Tier.TEXTBOOK else opp_spec.blend
	return f

func total_player_fixtures() -> int:
	return PLAYER_FIXTURES

func played_count() -> int:
	return _player_results.size()

func league_done() -> bool:
	return played_count() >= PLAYER_FIXTURES

# "league" | "playoffs" | "done" — the live Season's lifecycle (Slice 1).
func phase() -> String:
	match _phase:
		Phase.LEAGUE: return "league"
		Phase.PLAYOFFS: return "playoffs"
		_: return "done"

func season_done() -> bool:
	return _phase == Phase.DONE

# {name, team_index} of the next opponent the Player must play, or {} when there
# is nothing pending. League: the next of the 7 fixtures. Playoffs: the Player's
# pending knockout, with a "stage" key ("semi"/"final"/"third").
func next_player_opponent() -> Dictionary:
	if _phase == Phase.LEAGUE:
		if league_done():
			return {}
		var idx := played_count() + 1
		var opp: Team = _teams[idx]
		return {"name": opp.team_name, "team_index": idx}
	if _phase == Phase.PLAYOFFS:
		var opp_idx := _pending_opponent_index()
		if opp_idx < 0:
			return {}
		return {"name": _teams[opp_idx].team_name, "team_index": opp_idx, "stage": _pending_stage}
	return {}

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

# An interactive MatchSession for the Player's pending match (league fixture or
# playoff knockout). Derived per-match seed so each game diverges only on its own
# decisions. null when nothing is pending.
# --- Form (spec 2026-07-03 DF6): the season's running Form + Affinity bonus. ---
# enable_form binds the Player (rebind-safe: the hub reloads the Player each match);
# the running points seed once from the Player, then live on this driver and settle
# back on every commit. Off (never enabled) = byte-identical.
var _form_on := false
var _form_points := 0.0
var _form_base_mult := 1.0
var _form_player: Player = null

func enable_form(player: Player) -> void:
	if not _form_on:
		_form_on = true
		_form_points = player.form_points
	_form_base_mult = FormState.affinity_mult(player.affinity)
	_form_player = player

func form_points_now() -> float:
	return _form_points

func make_session() -> MatchSession:
	if _phase == Phase.LEAGUE:
		if league_done():
			return null
		var opp: Team = _teams[played_count() + 1]
		var fixture_seed := _seed + 100 + played_count()
		return MatchSession.start(_attrs, _teams[0], opp, _tour, fixture_seed,
			-1, _tuning, _itun, _opp_spec, _player_effects,
			_form_points, _form_base_mult, _form_on)
	if _phase == Phase.PLAYOFFS:
		var opp_idx := _pending_opponent_index()
		if opp_idx < 0:
			return null
		var offset: int = {"semi": 0, "final": 1, "third": 2}[_pending_stage]
		var po_seed: int = _seed + 200 + offset
		return MatchSession.start(_attrs, _teams[0], _teams[opp_idx], _tour, po_seed,
			-1, _tuning, _itun, _opp_spec, _player_effects,
			_form_points, _form_base_mult, _form_on)
	return null

# Fold a finished player match into the live Season + advance. Caller passes the
# MatchSession's result (after the player's Boost/DRS/Key-Moment decisions) and,
# for the save system, the session's decisions (export_decisions()); the default
# empty dict keeps the pre-save callers byte-identical. One log entry per committed
# match keeps the log index-aligned with the matches it reproduces (spec 2026-06-23).
func commit_player_result(result: MatchResult, decisions: Dictionary = {}) -> void:
	var entry := decisions.duplicate(true)
	# Replay context (spec 2026-07-02 DK2-4): the jokers + attrs this match was played
	# with, so a resumed season re-simulates it identically even after mid-season
	# shopping. Stamp-if-absent: replayed entries keep their saved context.
	if not entry.has("jokers"):
		entry["jokers"] = _shop.owned_ids.duplicate() if _shop != null else []
	if not entry.has("attrs"):
		entry["attrs"] = [_attrs.power, _attrs.composure, _attrs.attack, _attrs.control]
	# DF6 -- the committed match's end form becomes the next match's start; settle
	# onto the bound Player so the hub (portrait/chip) and the save see it.
	if _form_on:
		_form_points = result.form_end
		if _form_player != null:
			_form_player.set_form_points(_form_points)
	if _phase == Phase.LEAGUE:
		if league_done():
			return
		_decisions.append(entry)
		_player_results.append(result)
		_settle(result)
		if played_count() >= PLAYER_FIXTURES:
			_start_playoffs()
	elif _phase == Phase.PLAYOFFS:
		_decisions.append(entry)
		_settle(result)
		_record_playoff_result(result)
	# DONE: ignore.

# The complete Season outcome (league + playoffs), or null until season_done().
func season_result() -> SeasonResult:
	return _season_result

# --- Cross-session save: replay-from-decisions (spec 2026-06-23) ---

func seed() -> int:
	return _seed

# The per-match decision log (one entry per committed player match, in order).
func decisions_log() -> Array:
	return _decisions

# Restore the running pay tally after a replay (which runs pay-off so it can't
# double-bank the already-persisted Player.tons_balance — see spec "Pay").
func restore_pay_tally(total: int, wins: int) -> void:
	_pay_total = total
	_wins = wins

# Rebuild an identical SeasonPlay by replaying a saved decision log. Same start
# inputs + same seed + same per-match decisions => byte-identical results, so the
# driver lands at the same phase / progress it was saved at. Pay is intentionally
# left off here (the caller restores the tally) to avoid re-banking.
static func replay(player_attrs: Attributes, player_team: Team, opponents: Array,
		tour: TourDistribution, tuning: BallTuning, itun: InningsTuning,
		seed_value: int, opp_spec: TourSpec, decisions_log_in: Array,
		form_player: Player = null) -> SeasonPlay:
	var sp := SeasonPlay.start(player_attrs, player_team, opponents, tour,
		tuning, itun, seed_value, opp_spec)
	# DF6 -- form is never serialized: a season always starts at 0 (season-end reset
	# guarantees it), so replay re-derives the chain match by match. The persisted
	# Player's mid-season form_points is OVERWRITTEN by the re-derived value (they
	# are equal by construction; the replay is the authority).
	if form_player != null:
		sp._form_on = true
		sp._form_points = 0.0
		sp._form_base_mult = FormState.affinity_mult(form_player.affinity)
		sp._form_player = form_player
	for entry in decisions_log_in:
		if sp.season_done():
			break
		# Replay context (spec 2026-07-02 DK2-4): run each match with the loadout +
		# attrs it was originally played with (also fixes the Rung-1 carry-over
		# replay divergence — effects used to be dropped on replay).
		sp._player_effects = JokerCatalog.effects_of_ids(entry.get("jokers", []))
		if entry.has("attrs"):
			var arr: Array = entry["attrs"]
			var ca := Attributes.new()
			ca.power = arr[0]; ca.composure = arr[1]; ca.attack = arr[2]; ca.control = arr[3]
			sp._attrs = ca
		var sess := sp.make_session()
		if sess == null:
			break
		sess.apply_decisions(entry)
		sp.commit_player_result(sess.result(), entry)
	return sp

# Pack the current progress into a serialisable LiveSeasonState (level/tour_index =
# the career cell this season is being played at, pinned so the save is self-describing).
func to_state(level_at: int, tour_index_at: int) -> LiveSeasonState:
	var s := LiveSeasonState.new()
	s.seed = _seed
	s.level = level_at
	s.tour_index = tour_index_at
	s.pay_total = _pay_total
	s.wins = _wins
	s.decisions = _decisions.duplicate(true)
	s.form_enabled = _form_on
	if _shop != null:
		s.shop_enabled = true
		s.shop_owned = _shop.owned_ids.duplicate()
		s.shop_paid = _shop.paid_prices.duplicate()
		s.shop_held = _shop.held_id
		s.shop_visits_mask = _visits_mask
		s.shop_paid_mask = _paid_mask
	return s

# Resume an in-progress season from a saved LiveSeasonState. Rebuilds the difficulty
# cell from the pinned level/tour_index, replays the decision log against the (still
# separately-persisted) Player + CareerState, and restores the pay tally. The result
# is a SeasonPlay at exactly the phase/progress it was saved at; the caller (hub) then
# binds enable_pay for the matches still to come.
static func from_state(state: LiveSeasonState, player: Player, career: CareerState) -> SeasonPlay:
	var spec := DifficultyLadder.spec_for(state.level, state.tour_index)
	var team: Team = career.teams[career.current_team_index]
	var sp := SeasonPlay.replay(player.attributes, team, career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), state.seed, spec, state.decisions,
		player if state.form_enabled else null)
	sp.restore_pay_tally(state.pay_total, state.wins)
	sp.restore_shop(state, player, EconomyTuning.new())
	return sp

# Rebuild the live ShopState from a save (spec 2026-07-02 DK2-4). Re-binds the
# freshly-loaded Player (whose balance/attrs are the persisted truth) and re-derives
# the loadout effects for the matches still to come. Pre-v2 saves (shop_enabled
# false) no-op; the hub's enable_shop then initializes a fresh shop.
func restore_shop(state: LiveSeasonState, player: Player, etun: EconomyTuning) -> void:
	if not state.shop_enabled:
		return
	_shop = ShopState.new()
	_shop.owned_ids.assign(state.shop_owned)
	_shop.paid_prices = state.shop_paid.duplicate()
	_shop.held_id = state.shop_held
	_visits_mask = state.shop_visits_mask
	_paid_mask = state.shop_paid_mask
	_shop_player = player
	_setun = etun
	_shop_level = state.level
	_shop_tour = state.tour_index
	_attrs = player.attributes
	_refresh_loadout()

# --- ₸ pay (Slice 3) ---

# Turn on pay banking for this live Season. stars_at_play / level / tour_index are
# the career-cell context the prizes scale with (DC8-DC10, DV7-DV9). Off until
# called -> the pre-pay live path is byte-identical (all existing tests).
func enable_pay(player: Player, etun: EconomyTuning, stars_at_play: float,
		level: int, tour_index: int) -> void:
	_pay_player = player
	_etun = etun
	_pay_stars = stars_at_play
	_pay_level = level
	_pay_tour = tour_index

func pay_so_far() -> int:
	return _pay_total

func season_wins() -> int:
	return _wins

# The Player object pay is banked into (bound by enable_pay), so the UI can
# persist it after each committed match. null until enable_pay() is called.
func pay_player() -> Player:
	return _pay_player

# The _settle inputs, read-only — lets the Result screen recompute the pay
# breakdown for display with the exact ints _settle banked (nav-shell spec
# 2026-07-03, Slice 2). {} until enable_pay().
func pay_context() -> Dictionary:
	if _etun == null:
		return {}
	return {"stars": _pay_stars, "level": _pay_level, "tour": _pay_tour, "etun": _etun}

# Bank one played Player match (mirrors CareerResolver._settle_matches).
func _settle(result: MatchResult) -> void:
	if _etun == null:
		return
	var p: int = Economy.match_pay(result, _pay_stars, _etun)["total"]
	if result.outcome == MatchResult.Outcome.PLAYER_WIN:
		_wins += 1
		p += Economy.match_win_prize(_pay_level, _pay_tour, _etun)
	_pay_total += p
	if _pay_player != null:
		_pay_player.tons_balance += p

# --- Playoff bracket (Slice 1) ---

# League just finished: seed the top-4 bracket (1v4, 2v3), then either auto-resolve
# the whole bracket (Player out of top-4) or set up the Player's interactive semi.
func _start_playoffs() -> void:
	var st: Array = live_league().standings
	_seeds = [st[0].team_index, st[1].team_index, st[2].team_index, st[3].team_index]
	_player_seed = _seeds.find(0) + 1   # 0 if the Player is not seeded
	_po_rng = RandomNumberGenerator.new()
	_po_rng.seed = _seed + 2            # distinct from strength (_seed) + AI (_seed+1)

	if _player_seed == 0:
		# Nothing for the Player to play — resolve everything and finish.
		_sf1 = _auto_knockout(_seeds[0], 1, _seeds[3], 4)
		_sf2 = _auto_knockout(_seeds[1], 2, _seeds[2], 3)
		_final = _auto_knockout(_sf1["winner"], _seed_of(_sf1["winner"]),
			_sf2["winner"], _seed_of(_sf2["winner"]))
		_third = _auto_knockout(_sf1["loser"], _seed_of(_sf1["loser"]),
			_sf2["loser"], _seed_of(_sf2["loser"]))
		_finish_season()
		return

	# Player is seeded: auto-resolve the OTHER semi now; the Player plays theirs.
	_phase = Phase.PLAYOFFS
	if _player_seed == 1 or _player_seed == 4:
		_player_semi = "sf1"
		_sf2 = _auto_knockout(_seeds[1], 2, _seeds[2], 3)
	else:
		_player_semi = "sf2"
		_sf1 = _auto_knockout(_seeds[0], 1, _seeds[3], 4)
	_pending_stage = "semi"

# Record the Player's just-played knockout, advance the bracket, auto-resolve the
# now-determined non-player match, and finish when both player knockouts are in.
func _record_playoff_result(result: MatchResult) -> void:
	var opp_idx := _pending_opponent_index()
	var won := _player_won(result, opp_idx)
	var kn := {"winner": 0 if won else opp_idx, "loser": opp_idx if won else 0, "result": result}
	if _pending_stage == "semi":
		if _player_semi == "sf1":
			_sf1 = kn
		else:
			_sf2 = kn
		_pending_stage = "final" if won else "third"
	elif _pending_stage == "final":
		_final = kn
		# The Player won their semi, so both semi losers are non-player teams.
		_third = _auto_knockout(_sf1["loser"], _seed_of(_sf1["loser"]),
			_sf2["loser"], _seed_of(_sf2["loser"]))
		_finish_season()
	elif _pending_stage == "third":
		_third = kn
		# The Player lost their semi, so both semi winners are non-player teams.
		_final = _auto_knockout(_sf1["winner"], _seed_of(_sf1["winner"]),
			_sf2["winner"], _seed_of(_sf2["winner"]))
		_finish_season()

# team_index the Player faces in the current pending stage, or -1.
func _pending_opponent_index() -> int:
	if _phase != Phase.PLAYOFFS:
		return -1
	match _pending_stage:
		"semi": return _player_semi_opponent()
		"final": return _other_semi()["winner"]
		"third": return _other_semi()["loser"]
	return -1

func _player_semi_opponent() -> int:
	if _player_semi == "sf1":
		return _seeds[3] if _player_seed == 1 else _seeds[0]
	return _seeds[2] if _player_seed == 2 else _seeds[1]

func _other_semi() -> Dictionary:
	return _sf2 if _player_semi == "sf1" else _sf1

func _seed_of(team_index: int) -> int:
	return _seeds.find(team_index) + 1

# Player win, with a tie broken by the better seed advancing (knockout rule).
func _player_won(result: MatchResult, opp_idx: int) -> bool:
	if result.outcome == MatchResult.Outcome.TIE:
		return _player_seed < _seed_of(opp_idx)
	return result.outcome == MatchResult.Outcome.PLAYER_WIN

# Auto-resolve one non-player knockout on the held strengths (the league's derived
# AI path). Team a is the simulate_match "player slot" (PLAYER_WIN = a won); a tie
# goes to the better (lower) seed.
func _auto_knockout(a_idx: int, a_seed: int, b_idx: int, b_seed: int) -> Dictionary:
	var a_bats_first := MatchResolver._resolve_toss(_po_rng)
	var m := MatchResolver.simulate_match(
		null, _bat[a_idx], _bowl[a_idx], _bowl[a_idx],
		_bat[b_idx], _bowl[b_idx], _bowl[b_idx],
		a_bats_first, _tuning, _itun, _po_rng)
	var a_won: bool
	if m.outcome == MatchResult.Outcome.TIE:
		a_won = a_seed < b_seed
	else:
		a_won = m.outcome == MatchResult.Outcome.PLAYER_WIN
	return {"winner": a_idx if a_won else b_idx, "loser": b_idx if a_won else a_idx, "result": m}

# Assemble the complete SeasonResult and mark the Season done.
func _finish_season() -> void:
	_phase = Phase.DONE
	var sr := SeasonResult.new()
	sr.league = live_league()
	sr.semi1 = _sf1["result"]
	sr.semi2 = _sf2["result"]
	sr.final_match = _final["result"]
	sr.third_place = _third["result"]
	var order: Array = [_final["winner"], _final["loser"], _third["winner"], _third["loser"]]
	for k in range(4, NUM_TEAMS):
		order.append(sr.league.standings[k].team_index)
	sr.final_order = order
	for pos in range(order.size()):
		if order[pos] == 0:
			sr.player_final_position = pos + 1
			break
	sr.beat = sr.player_final_position <= 3
	sr.won_final = sr.player_final_position == 1
	_season_result = sr
	# Season-level prizes (DV9) — once, on the final table position.
	if _etun != null:
		var sp_prize := Economy.season_prizes(
			sr.player_final_position, sr.won_final, _pay_level, _pay_tour, _etun)
		_pay_total += sp_prize
		if _pay_player != null:
			_pay_player.tons_balance += sp_prize
