class_name JokerResolver
extends RefCounted

# Per-ball product of active jokers' roll multipliers. Pure, static — the
# model-agnostic seam the balance harness sweeps. See spec §5.2.
# Returns Vector2(wicket_mult, runs_mult); empty / no-match -> (1.0, 1.0).
static func roll_mults(jokers: Array, player_is_batting: bool, intent: int, ball: int) -> Vector2:
	var wm := 1.0
	var rm := 1.0
	for j in jokers:
		if j.matches(player_is_batting, intent, ball):
			if j.target == JokerEffect.Target.WICKET:
				wm *= j.mult
			else:
				rm *= j.mult
	return Vector2(wm, rm)
