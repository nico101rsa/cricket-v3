class_name JokerCatalog
extends RefCounted

# The 5 vertical-slice jokers (spec §4). Magnitudes verbatim from
# docs/joker-pool-v1.md; conditions use only state the sim already tracks.
static func slice_v1() -> Array:
	return [
		JokerEffect.make("dead_bat", "Dead Bat", "Common",
			JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.92,
			BallResolver.Intent.DEFENSIVE),
		JokerEffect.make("powerplay_punch", "Powerplay Punch", "Common",
			JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.06,
			BallResolver.Intent.AGGRESSIVE),
		JokerEffect.make("block_the_shine", "Block the Shine", "Common",
			JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.90,
			-1, 1, 18),
		JokerEffect.make("squeeze_the_middle", "Squeeze the Middle", "Common",
			JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.92,
			-1, 36, 90),
		JokerEffect.make("death_over_stranglehold", "Death-Over Stranglehold", "Rare",
			JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.83,
			-1, 90, 120),
	]

# The implemented pool, grouped so a multi-buff joker is one group with several
# effect rows. Each entry: {"id","jname","rarity","effects":[JokerEffect,...]}.
# C2a (PR pending) grows this from the 5 slice jokers to 11. Magnitudes verbatim
# from docs/joker-pool-v1.md; conditions use only state the sim now tracks
# (intent band, ball window, side, field mode).
static func implemented_groups() -> Array:
	return [
		# --- the original slice (single-effect) ---
		_g("dead_bat", "Dead Bat", "Common", [
			JokerEffect.make("dead_bat", "Dead Bat", "Common",
				JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.92,
				BallResolver.Intent.DEFENSIVE)]),
		_g("powerplay_punch", "Powerplay Punch", "Common", [
			JokerEffect.make("powerplay_punch", "Powerplay Punch", "Common",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.05,
				BallResolver.Intent.AGGRESSIVE)]),
		_g("block_the_shine", "Block the Shine", "Common", [
			JokerEffect.make("block_the_shine", "Block the Shine", "Common",
				JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.90,
				-1, 1, 18)]),
		_g("squeeze_the_middle", "Squeeze the Middle", "Common", [
			JokerEffect.make("squeeze_the_middle", "Squeeze the Middle", "Common",
				JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.92,
				-1, 36, 90)]),
		_g("death_over_stranglehold", "Death-Over Stranglehold", "Rare", [
			JokerEffect.make("death_over_stranglehold", "Death-Over Stranglehold", "Rare",
				JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.83,
				-1, 90, 120)]),
		# --- C2a: stateless leftovers (intent / ball-window only) ---
		_g("rotate_the_strike", "Rotate the Strike", "Common", [
			JokerEffect.make("rotate_the_strike", "Rotate the Strike", "Common",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.08,
				BallResolver.Intent.BALANCED)]),
		_g("carry_your_bat", "Carry Your Bat", "Rare", [
			JokerEffect.make("carry_your_bat", "Carry Your Bat", "Rare",
				JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.85,
				BallResolver.Intent.DEFENSIVE),
			JokerEffect.make("carry_your_bat", "Carry Your Bat", "Rare",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.12,
				BallResolver.Intent.DEFENSIVE)]),
		_g("slog_over_specialist", "Slog Over Specialist", "Rare", [
			JokerEffect.make("slog_over_specialist", "Slog Over Specialist", "Rare",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.35,
				BallResolver.Intent.AGGRESSIVE, 90, 120)]),
		# --- C2a: field-gated (bowling side) ---
		_g("tight_lines", "Tight Lines", "Common", [
			JokerEffect.make("tight_lines", "Tight Lines", "Common",
				JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.93,
				-1, 1, 120, FieldPlan.Mode.DEFENSIVE)]),
		_g("dot_ball_pressure", "Dot Ball Pressure", "Rare", [
			JokerEffect.make("dot_ball_pressure", "Dot Ball Pressure", "Rare",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.12,
				-1, 1, 120, FieldPlan.Mode.DEFENSIVE),
			JokerEffect.make("dot_ball_pressure", "Dot Ball Pressure", "Rare",
				JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.88,
				-1, 1, 120, FieldPlan.Mode.DEFENSIVE)]),
		_g("cordon_killer", "Cordon Killer", "Common", [
			JokerEffect.make("cordon_killer", "Cordon Killer", "Common",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.10,
				-1, 1, 120, FieldPlan.Mode.CATCHING)]),
		# --- C2b: bowling-side intent (bowl_intent / opposing-batsman intent) ---
		# #26 reads the Player's own bowling-captain intent (Aggressive).
		_g("attack_the_stumps", "Attack the Stumps", "Common", [
			JokerEffect.make("attack_the_stumps", "Attack the Stumps", "Common",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.12,
				-1, 1, 120, -1, BallResolver.Intent.AGGRESSIVE)]),
		# #19 reads the opposing batsman's intent (Defensive) via intent_req.
		_g("pressure_cooker", "Pressure Cooker", "Common", [
			JokerEffect.make("pressure_cooker", "Pressure Cooker", "Common",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.10,
				BallResolver.Intent.DEFENSIVE)]),
		# #22 Choke Hold (Legendary, multi-buff): defensive field + Defensive captain.
		_g("choke_hold", "Choke Hold", "Legendary", [
			JokerEffect.make("choke_hold", "Choke Hold", "Legendary",
				JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.75,
				-1, 1, 120, FieldPlan.Mode.DEFENSIVE, BallResolver.Intent.DEFENSIVE),
			JokerEffect.make("choke_hold", "Choke Hold", "Legendary",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.15,
				-1, 1, 120, FieldPlan.Mode.DEFENSIVE, BallResolver.Intent.DEFENSIVE)]),
		# #18 enabler: Defensive captaincy sets a defensive field (mult 1.0, sets_field).
		_g("defensive_captain", "Defensive Captain", "Common", [
			JokerEffect.make("defensive_captain", "Defensive Captain", "Common",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.0,
				-1, 1, 120, -1, BallResolver.Intent.DEFENSIVE, FieldPlan.Mode.DEFENSIVE)]),
		# --- C2c: Form events -> windowed-trigger buffs (JokerRuntime) ---
		# #10 Ride the Wave: Player boundary -> runs x1.20 for 3 balls.
		_g("ride_the_wave", "Ride the Wave", "Common", [
			JokerEffect.make("ride_the_wave", "Ride the Wave", "Common",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.20,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BAT, 3)]),
		# #29 Wicket Maiden: Player wicket while bowling -> wicket x1.30 for 6 balls.
		_g("wicket_maiden", "Wicket Maiden", "Rare", [
			JokerEffect.make("wicket_maiden", "Wicket Maiden", "Rare",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.45,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BOWL, 6),
			# Mechanic-change rung: economy/dot-pressure row. Extra wicket-chance only
			# pays off if a wicket falls; conceding fewer runs always converts. Same
			# 6-ball post-wicket window. Thematically a wicket-maiden = wicket + no runs.
			JokerEffect.make("wicket_maiden", "Wicket Maiden", "Rare",
				JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.62,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BOWL, 6)]),
		# #14 Hot Streak (multi-buff): 2 Form events within 6 balls (batting) ->
		# runs x1.30 AND wicket x0.85 for 6 balls.
		_g("hot_streak", "Hot Streak", "Rare", [
			JokerEffect.make("hot_streak", "Hot Streak", "Rare",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.30,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_DOUBLE_BAT, 6),
			JokerEffect.make("hot_streak", "Hot Streak", "Rare",
				JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.85,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_DOUBLE_BAT, 6)]),
		# #7 Match-Winner's Vigil (Legendary): Player boundary -> wicket x0.80 for 24
		# balls. The "snap to Defensive" intent write is simplified away (spec D5).
		_g("match_winners_vigil", "Match-Winner's Vigil", "Legendary", [
			JokerEffect.make("match_winners_vigil", "Match-Winner's Vigil", "Legendary",
				JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.62,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BAT, 24)]),
		# --- C2d: setNextBowler-fire (bowling-change windows) ---
		# #24 Pace Pack: change to pace -> wicket x1.15 for 6 balls.
		_g("pace_pack", "Pace Pack", "Common", [
			JokerEffect.make("pace_pack", "Pace Pack", "Common",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.15,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.CHANGE_PACE, 6)]),
		# #25 Spinner's Web: change to spin -> wicket x1.15 for 6 balls.
		_g("spinners_web", "Spinner's Web", "Common", [
			JokerEffect.make("spinners_web", "Spinner's Web", "Common",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.15,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.CHANGE_SPIN, 6)]),
		# #27 First-Change Specialist: any change -> wicket x1.20 for 6 balls.
		# (The catching-field set is simplified away, spec D3.)
		_g("first_change_specialist", "First-Change Specialist", "Rare", [
			JokerEffect.make("first_change_specialist", "First-Change Specialist", "Rare",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.20,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.CHANGE_ANY, 6)]),
		# #30 The Strike Bowler (Legendary): change into a catching field -> wicket
		# x1.35 for 12 balls. (The Form +1 grant is simplified away, spec D3.)
		_g("the_strike_bowler", "The Strike Bowler", "Legendary", [
			JokerEffect.make("the_strike_bowler", "The Strike Bowler", "Legendary",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.35,
				-1, 1, 120, FieldPlan.Mode.CATCHING, -1, -1, JokerEffect.Trigger.CHANGE_ANY, 12)]),
		# #28 The Trap (stateless): catching field AND current bowler = spin -> wicket x1.25.
		_g("the_trap", "The Trap", "Rare", [
			JokerEffect.make("the_trap", "The Trap", "Rare",
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.25,
				-1, 1, 120, FieldPlan.Mode.CATCHING, -1, -1, JokerEffect.Trigger.NONE, 0,
				BowlingPlan.Kind.SPIN)]),
		# --- C2e: Manager Boost (Boost Stack) — boost_role modifies the press ---
		_g("power_up", "Power Up", "Common", [
			_boost("power_up", "Power Up", "Common", JokerEffect.BoostRole.EXTEND)]),
		_g("boost_battery", "Boost Battery", "Common", [
			_boost("boost_battery", "Boost Battery", "Common", JokerEffect.BoostRole.BATTERY)]),
		_g("boost_adrenaline", "Boost Adrenaline", "Common", [
			_boost("boost_adrenaline", "Boost Adrenaline", "Common", JokerEffect.BoostRole.ADRENALINE)]),
		_g("pedal_to_the_metal", "Pedal to the Metal", "Common", [
			_boost("pedal_to_the_metal", "Pedal to the Metal", "Common", JokerEffect.BoostRole.PEDAL)]),
		_g("power_surge", "Power Surge", "Rare", [
			_boost("power_surge", "Power Surge", "Rare", JokerEffect.BoostRole.AMPLIFY)]),
		_g("compounding_pressure", "Compounding Pressure", "Rare", [
			_boost("compounding_pressure", "Compounding Pressure", "Rare", JokerEffect.BoostRole.COMPOUND)]),
		_g("the_comeback_press", "The Comeback Press", "Legendary", [
			_boost("the_comeback_press", "The Comeback Press", "Legendary", JokerEffect.BoostRole.COMEBACK)]),
		# --- C2f: DRS / tryReview (Reviewer archetype) ---
		_g("cool_head", "Cool Head", "Common", [
			_drs("cool_head", "Cool Head", "Common", JokerEffect.DRSRole.ACCURACY, 0.10)]),
		_g("captains_eye", "Captain's Eye", "Common", [
			_drs("captains_eye", "Captain's Eye", "Common", JokerEffect.DRSRole.ACCURACY, 0.20,
				BallResolver.Intent.DEFENSIVE)]),
		_g("spare_review", "Spare Review", "Common", [
			_drs("spare_review", "Spare Review", "Common", JokerEffect.DRSRole.EXTRA_REVIEW, 0.0)]),
		_g("hot_spot", "Hot Spot", "Common", [
			_drs("hot_spot", "Hot Spot", "Common", JokerEffect.DRSRole.FORM_ON_SUCCESS, 0.0)]),
		_g("snicko", "Snicko", "Rare", [
			_drs("snicko", "Snicko", "Rare", JokerEffect.DRSRole.ACCURACY, 0.12)]),
		_g("the_captains_call", "The Captain's Call", "Rare", [
			_drs("the_captains_call", "The Captain's Call", "Rare", JokerEffect.DRSRole.RETAIN, 0.0)]),
		_g("bowlers_backing", "Bowler's Backing", "Rare", [
			_drs("bowlers_backing", "Bowler's Backing", "Rare", JokerEffect.DRSRole.BOWLING_BUFF, 0.0)]),
		_g("the_review_master", "The Review Master", "Legendary", [
			_drs("the_review_master", "The Review Master", "Legendary", JokerEffect.DRSRole.MASTER, 0.0)]),
		# --- C2g: Form sources & intent dynamics (sim-owned; enablers) ---
		# #2 Sheet Anchor: switch to Balanced -> Form event.
		_g("the_sheet_anchor", "The Sheet Anchor", "Common", [
			_source("the_sheet_anchor", "The Sheet Anchor", "Common", JokerEffect.FormSource.ON_BALANCED)]),
		# #11 Captain's Statement: switch to Aggressive -> Form event.
		_g("captains_statement", "Captain's Statement", "Common", [
			_source("captains_statement", "Captain's Statement", "Common", JokerEffect.FormSource.ON_AGGRESSIVE)]),
		# #5 Building Phase: survive 6 Defensive balls -> Form event (repeats).
		_g("building_phase", "Building Phase", "Rare", [
			_source("building_phase", "Building Phase", "Rare", JokerEffect.FormSource.ON_DEFENSIVE_OVER)]),
		# #13 Boundary Hunter: a Form event snaps the Player's intent to Aggressive.
		_g("boundary_hunter", "Boundary Hunter", "Rare", [
			JokerEffect.make("boundary_hunter", "Boundary Hunter", "Rare",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.0,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.NONE, 0, -1,
				JokerEffect.BoostRole.NONE, JokerEffect.DRSRole.NONE, 0.0,
				JokerEffect.FormSource.NONE, BallResolver.Intent.AGGRESSIVE)]),
		# --- C2h: the final two (full pool) ---
		# #9 Field Restrictions: batting against a catching (opposition) field -> runs x1.12.
		_g("field_restrictions", "Field Restrictions", "Common", [
			JokerEffect.make("field_restrictions", "Field Restrictions", "Common",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.05,
				-1, 1, 120, FieldPlan.Mode.CATCHING)]),
		# #15 The Chase Master: 2nd innings (chasing) + Aggressive -> runs x1.20.
		_g("the_chase_master", "The Chase Master", "Legendary", [
			JokerEffect.make("the_chase_master", "The Chase Master", "Legendary",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.40,
				BallResolver.Intent.AGGRESSIVE, 1, 120, -1, -1, -1,
				JokerEffect.Trigger.NONE, 0, -1, JokerEffect.BoostRole.NONE,
				JokerEffect.DRSRole.NONE, 0.0, JokerEffect.FormSource.NONE, -1, 1),
			# Mechanic-change rung: composure/survival row. Runs saturate vs the chase
			# win-ceiling, so a dismissal-chance reduction converts where extra runs are
			# wasted. Same gate (chasing + Aggressive). See capped-joker spec.
			JokerEffect.make("the_chase_master", "The Chase Master", "Legendary",
				JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.62,
				BallResolver.Intent.AGGRESSIVE, 1, 120, -1, -1, -1,
				JokerEffect.Trigger.NONE, 0, -1, JokerEffect.BoostRole.NONE,
				JokerEffect.DRSRole.NONE, 0.0, JokerEffect.FormSource.NONE, -1, 1)]),
	]

# A Form-source joker (#2/#5/#11): only form_source matters; the sim fires the Form
# channel when its condition holds. Stored on the BATTING side (Player captaincy).
static func _source(id: String, jname: String, rarity: String, source: int) -> JokerEffect:
	return JokerEffect.make(id, jname, rarity,
		JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.0,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.NONE, 0, -1,
		JokerEffect.BoostRole.NONE, JokerEffect.DRSRole.NONE, 0.0, source)

# A Boost Stack joker: side/target/mult/window are irrelevant (the runtime drives
# the press), only boost_role matters. Stored on the BOWLING side as a neutral default.
static func _boost(id: String, jname: String, rarity: String, role: int) -> JokerEffect:
	return JokerEffect.make(id, jname, rarity,
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.0,
		-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.NONE, 0, -1, role)

# A Reviewer joker: only drs_role (+ p_bonus, + intent_req for Captain's Eye) matter;
# the runtime drives the review. Stored on the BOWLING side as a neutral default.
static func _drs(id: String, jname: String, rarity: String, role: int, p_bonus: float,
		intent_req: int = -1) -> JokerEffect:
	return JokerEffect.make(id, jname, rarity,
		JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.0,
		intent_req, 1, 120, -1, -1, -1, JokerEffect.Trigger.NONE, 0, -1,
		JokerEffect.BoostRole.NONE, role, p_bonus)

# Flat list of every implemented effect row (the form the resolver consumes).
static func implemented() -> Array:
	var out: Array = []
	for g in implemented_groups():
		out.append_array(g["effects"])
	return out

static func _g(id: String, jname: String, rarity: String, effects: Array) -> Dictionary:
	return {"id": id, "jname": jname, "rarity": rarity, "effects": effects}
