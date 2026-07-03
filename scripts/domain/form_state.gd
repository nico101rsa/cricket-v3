class_name FormState
extends RefCounted

# The Player's transient Form (CONTEXT.md §Form) + the Affinity bonus carrier
# (spec 2026-07-03 DF2/DF3/DF4/DF7). Pure state -- no RNG, no clock. One instance
# per sim run, constructed from the match-start points; the sim reads mult() at the
# Player's roll touchpoints and calls the tick methods as outcomes land.
# Tuning dials (DF3/DF12) -- first sweep targets, adjust via DF10 if the ledger moves:

const TICK_BOUNDARY := 0.25        # batting: hit a 4 or 6
const TICK_DISMISSED := -1.0       # batting: the Player is out
const TICK_DOT_STREAK := -0.25     # batting: every DOT_STREAK_N consecutive dots on strike
const DOT_STREAK_N := 6
const TICK_BOWL_WICKET := 0.5      # bowling: wicket in the Player's over
const TICK_BOWL_BOUNDARY := -0.25  # bowling: boundary conceded in the Player's over
const POINTS_CLAMP := 3.0          # points live in [-3, +3] (DF1)
const AFFINITY_PCT := 0.01         # +1% attrs per affinity year... (DF7)
const AFFINITY_CAP := 5            # ...capped at the hub's AFF_FULL display cap

var points: float = 0.0
var base_mult: float = 1.0         # static within a match (the Affinity bonus)
var _dot_streak: int = 0

static func make(start_points: float, p_base_mult: float = 1.0) -> FormState:
	var f := FormState.new()
	f.points = clampf(start_points, -POINTS_CLAMP, POINTS_CLAMP)
	f.base_mult = p_base_mult
	return f

# DF2 -- piecewise linear, hits CONTEXT's x0.8 / x1.15 anchors at the clamps.
static func form_mult(p: float) -> float:
	if p >= 0.0:
		return 1.0 + 0.05 * p
	return 1.0 + (0.2 / 3.0) * p

# DF7 -- the Affinity temporary performance bonus.
static func affinity_mult(affinity: int) -> float:
	return 1.0 + AFFINITY_PCT * mini(maxi(affinity, 0), AFFINITY_CAP)

func mult() -> float:
	return base_mult * form_mult(points)

func _bump(delta: float) -> void:
	points = clampf(points + delta, -POINTS_CLAMP, POINTS_CLAMP)

func on_player_boundary() -> void:
	_dot_streak = 0
	_bump(TICK_BOUNDARY)

func on_player_run() -> void:
	_dot_streak = 0

func on_player_dot() -> void:
	_dot_streak += 1
	if _dot_streak >= DOT_STREAK_N:
		_dot_streak = 0
		_bump(TICK_DOT_STREAK)

func on_player_dismissed() -> void:
	_dot_streak = 0
	_bump(TICK_DISMISSED)

func on_player_wicket() -> void:
	_bump(TICK_BOWL_WICKET)

func on_player_conceded_boundary() -> void:
	_bump(TICK_BOWL_BOUNDARY)
