class_name JokerRuntime
extends RefCounted

# Per-innings stateful layer for windowed-trigger jokers (C2c). The stateless
# JokerResolver handles per-ball conditions; this owns the decaying buffs that a
# Form event fires. See spec 2026-06-08-jokers-in-sim-7cC2c-form-windowed-design.md.
#
# Determinism: every method is driven by resolve_ball's deterministic output and
# the ball index — no RNG. An innings with no trigger jokers leaves `active` empty
# and tick_mults returns (1,1), so behaviour is byte-identical to pre-C2c.

const FORM_DOUBLE_WINDOW := 6  # Hot Streak: 2 Form events within this many balls

# Active buffs: each {side:int, target:int, mult:float, balls_left:int}.
var active: Array = []
# Innings-ball indices where a Player Form event fired (for the double trigger).
var form_event_balls: Array[int] = []

# Product of active buffs on the side that's batting/bowling this innings. Call at
# ball start; the returned (wicket_mult, runs_mult) multiplies the stateless mults.
func tick_mults(player_is_batting: bool) -> Vector2:
	var wm := 1.0
	var rm := 1.0
	for b in active:
		if (b["side"] == JokerEffect.Side.BATTING) != player_is_batting:
			continue
		if b["target"] == JokerEffect.Target.WICKET:
			wm *= b["mult"]
		else:
			rm *= b["mult"]
	return Vector2(wm, rm)

# Advance the runtime after a ball is resolved. Decays existing buffs first (those
# applied to the ball just played), then — if a Player Form event fired this ball —
# pushes new buffs from each matching trigger joker (so a window_n buff covers the
# *next* N balls). `ball` is the 1-based innings ball index just resolved.
func on_ball_end(jokers: Array, player_is_batting: bool, ball: int, formed: bool) -> void:
	# 1. decay
	for b in active:
		b["balls_left"] -= 1
	var kept: Array = []
	for b in active:
		if b["balls_left"] > 0:
			kept.append(b)
	active = kept

	if not formed:
		return

	# 2. a Form event fired this ball — is it the 2nd within the double window?
	var is_double := false
	for prev in form_event_balls:
		if ball - prev < FORM_DOUBLE_WINDOW:
			is_double = true
			break
	form_event_balls.append(ball)

	# 3. push buffs from each trigger joker whose trigger matches this event
	for j in jokers:
		if j.trigger == JokerEffect.Trigger.NONE:
			continue
		var fires := false
		match j.trigger:
			JokerEffect.Trigger.FORM_BAT:
				fires = player_is_batting and j.side == JokerEffect.Side.BATTING
			JokerEffect.Trigger.FORM_BOWL:
				fires = not player_is_batting and j.side == JokerEffect.Side.BOWLING
			JokerEffect.Trigger.FORM_DOUBLE_BAT:
				fires = player_is_batting and j.side == JokerEffect.Side.BATTING and is_double
		if fires:
			active.append({"side": j.side, "target": j.target, "mult": j.mult, "balls_left": j.window_n})

# C2d — a bowling change (setNextBowler) at a spell start. Pushes buffs that apply
# from the change over onward (balls_left = window_n), so call this *before*
# tick_mults at the spell's first ball. bowler_kind is a BowlingPlan.Kind; a
# CHANGE_* joker fires if its kind matches and its field_req (if any) matches.
func on_bowling_change(jokers: Array, bowler_kind: int, field_mode: int) -> void:
	for j in jokers:
		var fires := false
		match j.trigger:
			JokerEffect.Trigger.CHANGE_PACE:
				fires = bowler_kind == BowlingPlan.Kind.PACE
			JokerEffect.Trigger.CHANGE_SPIN:
				fires = bowler_kind == BowlingPlan.Kind.SPIN
			JokerEffect.Trigger.CHANGE_ANY:
				fires = true
		if fires and (j.field_req == -1 or field_mode == j.field_req):
			active.append({"side": j.side, "target": j.target, "mult": j.mult, "balls_left": j.window_n})
