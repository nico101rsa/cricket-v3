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
				JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.78,
				BallResolver.Intent.DEFENSIVE),
			JokerEffect.make("carry_your_bat", "Carry Your Bat", "Rare",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.16,
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
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.18,
				-1, 1, 120, FieldPlan.Mode.DEFENSIVE),
			JokerEffect.make("dot_ball_pressure", "Dot Ball Pressure", "Rare",
				JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.84,
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
				JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.72,
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
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.55,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BOWL, 6),
			# Mechanic-change rung: economy/dot-pressure row. Extra wicket-chance only
			# pays off if a wicket falls; conceding fewer runs always converts. Same
			# 6-ball post-wicket window. Thematically a wicket-maiden = wicket + no runs.
			JokerEffect.make("wicket_maiden", "Wicket Maiden", "Rare",
				JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.55,
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
			_drs("cool_head", "Cool Head", "Common", JokerEffect.DRSRole.ACCURACY, 0.05)]),
		_g("captains_eye", "Captain's Eye", "Common", [
			_drs("captains_eye", "Captain's Eye", "Common", JokerEffect.DRSRole.ACCURACY, 0.20,
				BallResolver.Intent.DEFENSIVE)]),
		_g("spare_review", "Spare Review", "Common", [
			_drs("spare_review", "Spare Review", "Common", JokerEffect.DRSRole.EXTRA_REVIEW, 0.0)]),
		_g("hot_spot", "Hot Spot", "Common", [
			_drs("hot_spot", "Hot Spot", "Common", JokerEffect.DRSRole.FORM_ON_SUCCESS, 0.0)]),
		_g("snicko", "Snicko", "Rare", [
			_drs("snicko", "Snicko", "Rare", JokerEffect.DRSRole.ACCURACY, 0.10)]),
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
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.10,
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

# --- ₸ prices (rung 7c-D, spec 2026-06-10-tons-economy-7cD §5.3) ---
# Within-band linear interpolation of each joker's REALIZED win-delta (the
# standard-profile sweep of 2026-06-10 — the toss/conditions fire naturally, so
# the measured delta is already fire-rate-discounted) onto its rarity price
# band, rounded to ₸5. Code is the source of truth; docs/joker-pool-v1.md
# mirrors these numbers. Re-derive by re-running tools/sweep_jokers.gd.

const PRICE_BANDS := {"Common": Vector2i(30, 50), "Rare": Vector2i(90, 120), "Legendary": Vector2i(220, 250)}
const DELTA_BANDS := {"Common": Vector2(1.0, 4.0), "Rare": Vector2(4.0, 7.0), "Legendary": Vector2(7.0, 12.0)}

const PRICES := {
	"attack_the_stumps": 40,
	"block_the_shine": 30,
	"boost_adrenaline": 30,
	"boost_battery": 30,
	"boundary_hunter": 90,
	"bowlers_backing": 90,
	"building_phase": 90,
	"captains_eye": 30,
	"captains_statement": 30,
	"carry_your_bat": 95,
	"choke_hold": 225,
	"compounding_pressure": 95,
	"cool_head": 35,
	"cordon_killer": 35,
	"dead_bat": 30,
	"death_over_stranglehold": 110,
	"defensive_captain": 30,
	"dot_ball_pressure": 100,
	"field_restrictions": 45,
	"first_change_specialist": 90,
	"hot_spot": 30,
	"hot_streak": 90,
	"match_winners_vigil": 220,
	"pace_pack": 30,
	"pedal_to_the_metal": 30,
	"power_surge": 115,
	"power_up": 30,
	"powerplay_punch": 45,
	"pressure_cooker": 30,
	"ride_the_wave": 30,
	"rotate_the_strike": 30,
	"slog_over_specialist": 105,
	"snicko": 90,
	"spare_review": 45,
	"spinners_web": 30,
	"squeeze_the_middle": 40,
	"the_captains_call": 90,
	"the_chase_master": 225,
	"the_comeback_press": 220,
	"the_review_master": 225,
	"the_sheet_anchor": 30,
	"the_strike_bowler": 220,
	"the_trap": 90,
	"tight_lines": 35,
	"wicket_maiden": 90,
}


# T7 (playtest): plain-English one-liners -- what each joker DOES, in cricket
# words. No percentages, no numbers (Nico's ruling); magnitudes live in the
# effect rows and docs/joker-pool-v1.md. Keep these honest to the real effects.
const DESC := {
	# Anchor -- survive, accumulate, deny the wicket
	"dead_bat": "While you bat Defensive, you are harder to get out.",
	"the_sheet_anchor": "Switching to Balanced batting lifts your Form.",
	"block_the_shine": "Early in your innings, while the ball is new, you are harder to get out.",
	"rotate_the_strike": "While you bat Balanced, the runs come a little easier.",
	"building_phase": "Every full over you survive batting Defensive lifts your Form.",
	"carry_your_bat": "While you bat Defensive, you are much harder to get out and still score.",
	"match_winners_vigil": "When your Form rises while batting, you drop anchor: Defensive, and very hard to dismiss for a long spell.",
	# Tempo -- score faster
	"powerplay_punch": "While you bat Aggressive, your scoring shots come off more often.",
	"field_restrictions": "Batting against a catching field, the runs come easier.",
	"ride_the_wave": "When your Form rises while batting, the next few balls score big.",
	"captains_statement": "Switching to Aggressive batting lifts your Form.",
	"slog_over_specialist": "In the death overs while Aggressive, your hitting goes up a gear.",
	"boundary_hunter": "When your Form rises while batting, you snap Aggressive and score quicker.",
	"hot_streak": "Two Form gains in one over spark a hot spell: big scoring and hard to dismiss.",
	"the_chase_master": "Chasing while Aggressive, you score much harder without throwing your wicket away.",
	# Strangler -- deny runs
	"tight_lines": "Bowling to a defensive field, your side leaks fewer runs.",
	"squeeze_the_middle": "Through the middle overs, your side concedes fewer runs.",
	"defensive_captain": "Going Defensive while bowling also pulls the field back for you.",
	"pressure_cooker": "Against batters who block, your side finds more wickets.",
	"dot_ball_pressure": "Bowling to a defensive field: more wickets and fewer runs conceded.",
	"death_over_stranglehold": "In the death overs, your side is harder to score off.",
	"choke_hold": "Defensive plans and a defensive field together strangle the scoring and bring wickets.",
	# Wicket Hunter -- take wickets
	"cordon_killer": "With a catching field set, the wickets come more often.",
	"pace_pack": "Bringing on a pace bowler makes the next over more dangerous.",
	"spinners_web": "Bringing on a spinner makes the next over more dangerous.",
	"attack_the_stumps": "Bowling under Aggressive captaincy brings more wickets.",
	"first_change_specialist": "Every bowling change attacks: extra wicket threat and a catching field snaps in.",
	"the_trap": "A catching field with spin on turns the screw for wickets.",
	"wicket_maiden": "When your Form rises while bowling, the next over hunts a wicket and gives nothing away.",
	"the_strike_bowler": "A bowling change into a catching field starts a fierce wicket-hunting spell and lifts your Form.",
	# Boost Stack -- amplify the Manager Boost
	"power_up": "Your Boost lasts longer.",
	"boost_battery": "Your Boost hits harder: runs when batting, wickets when bowling.",
	"boost_adrenaline": "Pressing Boost lifts your Form.",
	"pedal_to_the_metal": "Pressing Boost snaps your batting to Aggressive.",
	"power_surge": "Your Boost is stronger and lasts longer.",
	"compounding_pressure": "Boost while Aggressive becomes a surge: heavy scoring without the extra risk.",
	"the_comeback_press": "Every Boost lifts your Form, and your third Boost of the match is a monster.",
	# Reviewer -- DRS
	"cool_head": "Your DRS reviews succeed a little more often.",
	"captains_eye": "DRS reviews taken while Defensive succeed far more often.",
	"spare_review": "One extra DRS review each innings.",
	"hot_spot": "Winning a DRS review lifts your Form.",
	"snicko": "Your DRS reviews succeed more often.",
	"the_captains_call": "One extra DRS review each innings.",
	"bowlers_backing": "Winning a review while bowling fires the attack up for the next over.",
	"the_review_master": "Reviews succeed more often, you carry an extra one, and winning them lifts your Form.",
}


static func describe(id: String) -> String:
	return DESC.get(id, "")


static func price(id: String) -> int:
	return PRICES[id]


static func price_band(rarity: String) -> Vector2i:
	return PRICE_BANDS[rarity]


# Flat list of every implemented effect row (the form the resolver consumes).
static func implemented() -> Array:
	var out: Array = []
	for g in implemented_groups():
		out.append_array(g["effects"])
	return out

static func _g(id: String, jname: String, rarity: String, effects: Array) -> Dictionary:
	return {"id": id, "jname": jname, "rarity": rarity, "effects": effects}


# Sorted ids of one rarity — the Shop's draw pools (shop rung DK5/DK7).
static func ids_of_rarity(rarity: String) -> Array:
	var out: Array = []
	for g in implemented_groups():
		if g["rarity"] == rarity:
			out.append(g["id"])
	out.sort()
	return out


# Flattened effect rows for a set of owned ids — the loadout the sim consumes.
static func effects_of_ids(ids: Array) -> Array:
	var out: Array = []
	for g in implemented_groups():
		if g["id"] in ids:
			out.append_array(g["effects"])
	return out
