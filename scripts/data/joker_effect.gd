class_name JokerEffect
extends RefCounted

# One Joker as a per-ball conditional roll modifier — a pure data tuple.
# See spec 2026-06-08-jokers-in-sim-7cC-slice-design.md §5.1 and ADR 0007.

enum Target { WICKET, RUNS }
enum Side { BATTING, BOWLING }
# C2c — windowed-trigger jokers fire a decaying buff when a Form event happens,
# instead of applying a per-ball condition. NONE = a stateless per-ball joker.
enum Trigger { NONE, FORM_BAT, FORM_BOWL, FORM_DOUBLE_BAT }

var id: String = ""
var jname: String = ""        # display name; `name` collides with Godot built-ins
var rarity: String = "Common"
# side/target stored as int (enum values) to avoid GDScript cross-class enum-type
# unification errors when callers pass JokerEffect.Side.* / JokerEffect.Target.*.
var side: int = Side.BATTING
var target: int = Target.WICKET
var mult: float = 1.0
var intent_req: int = -1      # -1 = any; else the BATSMAN's BallResolver.Intent
var ball_min: int = 1         # inclusive innings-ball window
var ball_max: int = 120
var field_req: int = -1       # -1 = any; else a FieldPlan.Mode value
# C2b — the bowling captain's own intent (distinct from intent_req, which reads
# the batsman). -1 = any; else a BallResolver.Intent value. Stored as int (not
# enum-typed) for the same cross-class reason as side/target.
var bowl_intent_req: int = -1
# C2b — a FieldPlan.Mode this joker *forces* when its conditions hold (an enabler
# like Defensive Captain), not a roll modifier. -1 = sets nothing.
var sets_field: int = -1
# C2c — windowed-trigger fields. trigger != NONE makes this joker fire a buff of
# (target, mult) lasting window_n balls when its Form event happens; such jokers
# are owned by JokerRuntime and ignored by the stateless matches().
var trigger: int = Trigger.NONE
var window_n: int = 0

# Convenience constructor so the catalog reads as one line per joker.
static func make(p_id: String, p_jname: String, p_rarity: String,
		p_side: int, p_target: int, p_mult: float,
		p_intent_req: int = -1, p_ball_min: int = 1, p_ball_max: int = 120,
		p_field_req: int = -1, p_bowl_intent_req: int = -1, p_sets_field: int = -1,
		p_trigger: int = Trigger.NONE, p_window_n: int = 0) -> JokerEffect:
	var j := JokerEffect.new()
	j.id = p_id
	j.jname = p_jname
	j.rarity = p_rarity
	j.side = p_side
	j.target = p_target
	j.mult = p_mult
	j.intent_req = p_intent_req
	j.ball_min = p_ball_min
	j.ball_max = p_ball_max
	j.field_req = p_field_req
	j.bowl_intent_req = p_bowl_intent_req
	j.sets_field = p_sets_field
	j.trigger = p_trigger
	j.window_n = p_window_n
	return j

# Does this joker fire on this ball? Side must match the innings, the intent
# requirement (if any) must hold, the innings ball must be in [ball_min, ball_max],
# and the field requirement (if any) must match. field_mode defaults to NEUTRAL (0)
# so existing callers that omit it leave field-agnostic jokers (field_req -1) unchanged.
func matches(player_is_batting: bool, intent: int, ball: int, field_mode: int = FieldPlan.Mode.NEUTRAL, bowl_intent: int = -1) -> bool:
	if trigger != Trigger.NONE:
		return false  # windowed-trigger joker — owned by JokerRuntime, not the per-ball seam
	var side_ok := (side == Side.BATTING) == player_is_batting
	var intent_ok := intent_req == -1 or intent == intent_req
	var ball_ok := ball >= ball_min and ball <= ball_max
	var field_ok := field_req == -1 or field_mode == field_req
	var bowl_intent_ok := bowl_intent_req == -1 or bowl_intent == bowl_intent_req
	return side_ok and intent_ok and ball_ok and field_ok and bowl_intent_ok
