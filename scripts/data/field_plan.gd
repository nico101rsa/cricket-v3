class_name FieldPlan
extends RefCounted

# Caller-supplied field setting, one mode per match phase — the field mirror of
# IntentPlan / BowlingPlan and the fieldMode verb of ADR 0006. A transient
# per-match decision input the captain sets while their team is bowling.
# See spec 2026-06-08-jokers-in-sim-7cC2a-field-design.md.
#
# C2a scope: field mode is a *readable condition* jokers gate on; it has no
# intrinsic roll EV of its own yet (deferred — a future "field as a real lever"
# rung). NEUTRAL = 0 so it is also the matches() default (no field set).

enum Mode { NEUTRAL, CATCHING, DEFENSIVE }

const POWERPLAY_OVERS := 6     # aligns with IntentPlan / T20 powerplay
const DEATH_START_OVER := 16   # aligns with IntentPlan death overs

var powerplay: int = Mode.NEUTRAL  # overs 1..6
var middle: int = Mode.NEUTRAL     # overs 7..15
var death: int = Mode.NEUTRAL      # overs 16..20

# 1-based over number -> field Mode for that over.
func for_over(over: int) -> int:
	if over <= POWERPLAY_OVERS:
		return powerplay
	if over < DEATH_START_OVER:
		return middle
	return death

# No field set anywhere (== the default; field jokers inert).
static func neutral() -> FieldPlan:
	return FieldPlan.new()

# Catching field every phase.
static func catching() -> FieldPlan:
	var p := FieldPlan.new()
	p.powerplay = Mode.CATCHING
	p.middle = Mode.CATCHING
	p.death = Mode.CATCHING
	return p

# Defensive field every phase.
static func defensive() -> FieldPlan:
	var p := FieldPlan.new()
	p.powerplay = Mode.DEFENSIVE
	p.middle = Mode.DEFENSIVE
	p.death = Mode.DEFENSIVE
	return p
