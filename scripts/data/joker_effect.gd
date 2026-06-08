class_name JokerEffect
extends RefCounted

# One Joker as a per-ball conditional roll modifier — a pure data tuple.
# See spec 2026-06-08-jokers-in-sim-7cC-slice-design.md §5.1 and ADR 0007.

enum Target { WICKET, RUNS }
enum Side { BATTING, BOWLING }

var id: String = ""
var jname: String = ""        # display name; `name` collides with Godot built-ins
var rarity: String = "Common"
# side/target stored as int (enum values) to avoid GDScript cross-class enum-type
# unification errors when callers pass JokerEffect.Side.* / JokerEffect.Target.*.
var side: int = Side.BATTING
var target: int = Target.WICKET
var mult: float = 1.0
var intent_req: int = -1      # -1 = any; else a BallResolver.Intent value
var ball_min: int = 1         # inclusive innings-ball window
var ball_max: int = 120

# Convenience constructor so the catalog reads as one line per joker.
static func make(p_id: String, p_jname: String, p_rarity: String,
		p_side: int, p_target: int, p_mult: float,
		p_intent_req: int = -1, p_ball_min: int = 1, p_ball_max: int = 120) -> JokerEffect:
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
	return j

# Does this joker fire on this ball? Side must match the innings, the intent
# requirement (if any) must hold, and the innings ball must be in [ball_min, ball_max].
func matches(player_is_batting: bool, intent: int, ball: int) -> bool:
	var side_ok := (side == Side.BATTING) == player_is_batting
	var intent_ok := intent_req == -1 or intent == intent_req
	var ball_ok := ball >= ball_min and ball <= ball_max
	return side_ok and intent_ok and ball_ok
