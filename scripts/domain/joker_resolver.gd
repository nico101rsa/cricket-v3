class_name JokerResolver
extends RefCounted

# Per-ball product of active jokers' roll multipliers. Pure, static — the
# model-agnostic seam the balance harness sweeps. See spec §5.2.
# Returns Vector2(wicket_mult, runs_mult); empty / no-match -> (1.0, 1.0).
static func roll_mults(jokers: Array, player_is_batting: bool, intent: int, ball: int, field_mode: int = FieldPlan.Mode.NEUTRAL, bowl_intent: int = -1) -> Vector2:
	# Pre-pass: an enabler joker (sets_field, e.g. Defensive Captain) upgrades the
	# effective field mode when its conditions hold, so field-gated jokers read the
	# upgraded field. Runs before the multiplier loop. field_req is -1 on enablers,
	# so matches() ignores the field it is about to set.
	var eff_field := field_mode
	for j in jokers:
		if j.sets_field != -1 and j.matches(player_is_batting, intent, ball, eff_field, bowl_intent):
			eff_field = j.sets_field

	var wm := 1.0
	var rm := 1.0
	for j in jokers:
		if j.sets_field != -1:
			continue  # enabler, not a roll modifier
		if j.matches(player_is_batting, intent, ball, eff_field, bowl_intent):
			if j.target == JokerEffect.Target.WICKET:
				wm *= j.mult
			else:
				rm *= j.mult
	return Vector2(wm, rm)
