class_name InningsTuning
extends Resource

# All innings-level coefficients as DATA, never hardcoded in the resolver —
# the balance harness (Theme 7c) sweeps these. Strawman defaults; see spec
# 2026-06-07-innings-sim-design.md §7.

@export var over_limit: int = 20      # -> over_limit * 6 = 120 balls

# build -> batting position map: pos = clamp(round(pos_base - pos_span*share), 1, 9)
@export var pos_base: float = 9.0
@export var pos_span: float = 8.0

# weakening-tail curve: factor(p) = max(tail_floor, 1 - (p-1)*tail_slope)
@export var tail_floor: float = 0.45
@export var tail_slope: float = 0.07

# build -> bowling overs (0..bowl_max_overs): overs = clamp(round(gain*share + base), 0, max)
# where share = (attack+control)/(power+composure+attack+control). Strawman; harness-tunable.
@export var bowl_max_overs: int = 4
@export var bowl_overs_gain: float = 8.0
@export var bowl_overs_base: float = -2.5

# Bowling budget conservation (Slice 3, D12): extra charge for a concentrated strong
# Player spell (n overs above team-average attack take convexly more wickets than the
# linear budget assumes). 0 = pure linear conservation. Calibrated to flatten the
# bowling-build win edge (spec §9.5.3). See MatchResolver._conserved_bowling.
@export var bowl_concentration_k: float = 1.0
