class_name InningsTuning
extends Resource

# All innings-level coefficients as DATA, never hardcoded in the resolver —
# the balance harness (Theme 7c) sweeps these. Strawman defaults; see spec
# 2026-06-07-innings-sim-design.md §7.

@export var over_limit: int = 20      # -> over_limit * 6 = 120 balls

# build -> batting position map: pos = clamp(round(pos_base - pos_span*share*competence), 1, 9)
@export var pos_base: float = 9.0
@export var pos_span: float = 8.0

# Position promotion is gated by absolute batting competence (fresh-build-equality
# 2026-06-15): competence = clamp((power+composure) / pos_ref_batting, 0, 1). At/above
# pos_ref the formula is the original share-only promotion (strong builds unchanged);
# below it a weak fresh player bats lower and climbs the order as it levels up.
# Tuned by tools/build_spectrum_sweep.gd to flatten fresh-end build win-equality.
@export var pos_ref_batting: float = 60.0

# weakening-tail curve: factor(p) = max(tail_floor, 1 - (p-1)*tail_slope)
@export var tail_floor: float = 0.45
@export var tail_slope: float = 0.07

# build -> bowling overs (0..bowl_max_overs): overs = clamp(round(gain*share + base), 0, max)
# where share = (attack+control)/(power+composure+attack+control). Strawman; harness-tunable.
@export var bowl_max_overs: int = 4
@export var bowl_overs_gain: float = 13.0
@export var bowl_overs_base: float = -2.6

# Bowling budget conservation (Slice 3, D12): extra charge for a concentrated strong
# Player spell (n overs above team-average attack take convexly more wickets than the
# linear budget assumes). 0 = pure linear conservation. Calibrated to flatten the
# bowling-build win edge (spec §9.5.3). See MatchResolver._conserved_bowling.
@export var bowl_concentration_k: float = 0.5

# Per-kind phase effectiveness bonus (BB1, bowling-balance spec), added to BOTH
# attack and control at the profile lookup, indexed by IntentPlan.phase_of
# [PP, middle, death]. Mirrored signs keep the per-phase sum across kinds ~zero.
# Real-T20 shape: pace owns the Powerplay + death, spin owns the middle
# (E1 spec §10.3, Nico's benchmarks).
# ±1.5 (was strawman ±0.7): the base ±2 style tilt is control-dominated, so a
# small swing never flips the per-phase buy — at ±1.5 pace's PP/death economy
# pulls within ~1 control point of spin while keeping a ~7-point attack edge.
# Card-rescale 2026-06-11: ±1.5 legacy × 6.25 = ±9.375 on the /100 scale.
@export var pace_phase_bonus: Array[float] = [9.375, -9.375, 9.375]
@export var spin_phase_bonus: Array[float] = [-9.375, 9.375, -9.375]
