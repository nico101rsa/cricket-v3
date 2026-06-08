class_name JokerEffect
extends RefCounted

# One Joker as a per-ball conditional roll modifier — a pure data tuple.
# See spec 2026-06-08-jokers-in-sim-7cC-slice-design.md §5.1 and ADR 0007.

enum Target { WICKET, RUNS }
enum Side { BATTING, BOWLING }
# C2c — windowed-trigger jokers fire a decaying buff when a Form event happens,
# instead of applying a per-ball condition. NONE = a stateless per-ball joker.
enum Trigger { NONE, FORM_BAT, FORM_BOWL, FORM_DOUBLE_BAT, CHANGE_PACE, CHANGE_SPIN, CHANGE_ANY }
# C2e — Boost Stack jokers (#31–#37) modify a Manager Boost press rather than
# applying per-ball or firing on a Form/change event. NONE = not a Boost joker.
enum BoostRole { NONE, EXTEND, BATTERY, ADRENALINE, PEDAL, AMPLIFY, COMPOUND, COMEBACK }
# C2f — Reviewer jokers (#38–#45) modify a DRS review (accuracy, extra reviews,
# retain-on-fail, success payoffs). NONE = not a DRS joker.
enum DRSRole { NONE, ACCURACY, EXTRA_REVIEW, RETAIN, FORM_ON_SUCCESS, BOWLING_BUFF, MASTER }
# C2g — Form *source* jokers generate a Form event (instead of consuming one) when
# the Player switches batting intent or survives a Defensive over. NONE = not a source.
enum FormSource { NONE, ON_BALANCED, ON_AGGRESSIVE, ON_DEFENSIVE_OVER }

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
# C2d — a stateless per-ball condition on the current bowler's BowlingPlan.Kind
# (-1 = any; else PACE/SPIN). Used by The Trap (#28). Only applies to NONE-trigger
# jokers via matches().
var bowler_type_req: int = -1
# C2e — which Boost-press modification this joker is (NONE = not a Boost joker).
var boost_role: int = BoostRole.NONE
# C2f — which DRS-review modification this joker is, + its P(success) bonus.
var drs_role: int = DRSRole.NONE
var drs_p_bonus: float = 0.0
# C2g — Form-source kind (NONE = not a source) and the intent this joker snaps the
# Player to on a Form event (-1 = no snap; #13 Boundary Hunter snaps to Aggressive).
var form_source: int = FormSource.NONE
var snaps_intent: int = -1

# Convenience constructor so the catalog reads as one line per joker.
static func make(p_id: String, p_jname: String, p_rarity: String,
		p_side: int, p_target: int, p_mult: float,
		p_intent_req: int = -1, p_ball_min: int = 1, p_ball_max: int = 120,
		p_field_req: int = -1, p_bowl_intent_req: int = -1, p_sets_field: int = -1,
		p_trigger: int = Trigger.NONE, p_window_n: int = 0, p_bowler_type_req: int = -1,
		p_boost_role: int = BoostRole.NONE, p_drs_role: int = DRSRole.NONE,
		p_drs_p_bonus: float = 0.0, p_form_source: int = FormSource.NONE,
		p_snaps_intent: int = -1) -> JokerEffect:
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
	j.bowler_type_req = p_bowler_type_req
	j.boost_role = p_boost_role
	j.drs_role = p_drs_role
	j.drs_p_bonus = p_drs_p_bonus
	j.form_source = p_form_source
	j.snaps_intent = p_snaps_intent
	return j

# Does this joker fire on this ball? Side must match the innings, the intent
# requirement (if any) must hold, the innings ball must be in [ball_min, ball_max],
# and the field requirement (if any) must match. field_mode defaults to NEUTRAL (0)
# so existing callers that omit it leave field-agnostic jokers (field_req -1) unchanged.
func matches(player_is_batting: bool, intent: int, ball: int, field_mode: int = FieldPlan.Mode.NEUTRAL, bowl_intent: int = -1, bowler_type: int = -1) -> bool:
	if trigger != Trigger.NONE or boost_role != BoostRole.NONE or drs_role != DRSRole.NONE \
			or form_source != FormSource.NONE or snaps_intent != -1:
		return false  # event-driven joker — owned by JokerRuntime/sim, not the per-ball seam
	var side_ok := (side == Side.BATTING) == player_is_batting
	var intent_ok := intent_req == -1 or intent == intent_req
	var ball_ok := ball >= ball_min and ball <= ball_max
	var field_ok := field_req == -1 or field_mode == field_req
	var bowl_intent_ok := bowl_intent_req == -1 or bowl_intent == bowl_intent_req
	var bowler_type_ok := bowler_type_req == -1 or bowler_type == bowler_type_req
	return side_ok and intent_ok and ball_ok and field_ok and bowl_intent_ok and bowler_type_ok
