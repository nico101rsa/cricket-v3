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

# E2 state rules (spec 2026-06-11-stateaware-policy-7cE2-design.md §3). All
# disabled by default; for_state() == for_over() when off, so static plans and
# every pre-E2 caller are byte-identical. req RR = runs still needed per over.
var chase_up_rr: float = -1.0    # chasing & req RR >= this -> escalate one band
var chase_down_rr: float = -1.0  # chasing & req RR <= this -> de-escalate one band
var collapse_wkts: int = -1      # wickets fallen >= this -> de-escalate one band

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

# State-aware band for the ball about to be bowled. balls = balls bowled so far
# this innings; target/max_balls as in simulate_innings. No RNG draws. DS2a:
# collapse protection never overrides a chase escalation (a side chasing
# 11-an-over keeps attacking even 5 down).
func for_state(over: int, total: int, wickets: int, balls: int, target: int, max_balls: int) -> int:
	var band := for_over(over)
	var delta := 0
	if target > 0 and balls < max_balls:
		var req_rr := float(target - total) * 6.0 / float(max_balls - balls)
		if chase_up_rr >= 0.0 and req_rr >= chase_up_rr:
			delta = 1
		elif chase_down_rr >= 0.0 and req_rr <= chase_down_rr:
			delta = -1
	if collapse_wkts >= 0 and wickets >= collapse_wkts and delta <= 0:
		delta -= 1
	return clampi(band + delta, BallResolver.Intent.DEFENSIVE, BallResolver.Intent.AGGRESSIVE)

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
