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
			JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.10,
			BallResolver.Intent.AGGRESSIVE),
		JokerEffect.make("block_the_shine", "Block the Shine", "Common",
			JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.90,
			-1, 1, 18),
		JokerEffect.make("squeeze_the_middle", "Squeeze the Middle", "Common",
			JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.92,
			-1, 36, 90),
		JokerEffect.make("death_over_stranglehold", "Death-Over Stranglehold", "Rare",
			JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.80,
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
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.10,
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
				JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.80,
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
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 0.90,
				BallResolver.Intent.DEFENSIVE)]),
		_g("slog_over_specialist", "Slog Over Specialist", "Rare", [
			JokerEffect.make("slog_over_specialist", "Slog Over Specialist", "Rare",
				JokerEffect.Side.BATTING, JokerEffect.Target.RUNS, 1.25,
				BallResolver.Intent.AGGRESSIVE, 90, 120)]),
		# --- C2a: field-gated (bowling side) ---
		_g("tight_lines", "Tight Lines", "Common", [
			JokerEffect.make("tight_lines", "Tight Lines", "Common",
				JokerEffect.Side.BOWLING, JokerEffect.Target.RUNS, 0.90,
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
				JokerEffect.Side.BOWLING, JokerEffect.Target.WICKET, 1.30,
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
				JokerEffect.Side.BATTING, JokerEffect.Target.WICKET, 0.80,
				-1, 1, 120, -1, -1, -1, JokerEffect.Trigger.FORM_BAT, 24)]),
	]

# Flat list of every implemented effect row (the form the resolver consumes).
static func implemented() -> Array:
	var out: Array = []
	for g in implemented_groups():
		out.append_array(g["effects"])
	return out

static func _g(id: String, jname: String, rarity: String, effects: Array) -> Dictionary:
	return {"id": id, "jname": jname, "rarity": rarity, "effects": effects}
