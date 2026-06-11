class_name IntentPlan
extends RefCounted

# Caller-supplied batting Intent, one band per match phase. A transient
# per-match decision input (not saved tuning) — see spec
# 2026-06-07-intent-plan-design.md and the setIntent verb of ADR 0006.
# Band values are BallResolver.Intent (DEFENSIVE / BALANCED / AGGRESSIVE).

const POWERPLAY_OVERS := 6     # fixed by T20 law (6-over powerplay)
const DEATH_START_OVER := 16   # tunable default (last 5 overs)

var powerplay: int = BallResolver.Intent.BALANCED  # overs 1..6
var middle: int = BallResolver.Intent.BALANCED     # overs 7..15
var death: int = BallResolver.Intent.BALANCED      # overs 16..20

# Phase index for a 1-based over: 0 = Powerplay, 1 = middle, 2 = death.
# Single source of truth for phase boundaries (BB2, bowling-balance spec).
static func phase_of(over: int) -> int:
	if over <= POWERPLAY_OVERS:
		return 0
	if over < DEATH_START_OVER:
		return 1
	return 2

# 1-based over number -> Intent band for that over.
func for_over(over: int) -> int:
	match IntentPlan.phase_of(over):
		0:
			return powerplay
		1:
			return middle
		_:
			return death

# Neutral baseline: BALANCED in every phase (== the pre-rung-4a hardcode).
static func balanced() -> IntentPlan:
	return IntentPlan.new()

# Textbook plan: attack the powerplay, build the middle, slog the death.
static func textbook() -> IntentPlan:
	var plan := IntentPlan.new()
	plan.powerplay = BallResolver.Intent.AGGRESSIVE
	plan.middle = BallResolver.Intent.BALANCED
	plan.death = BallResolver.Intent.AGGRESSIVE
	return plan
