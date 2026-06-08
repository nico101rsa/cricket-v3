class_name RatingTuning
extends Resource

# Dials for the net-runs Player rating (spec 2026-06-08-build-balance §3). All
# @export so the balance harness can sweep them. sr_par/rr_par are DERIVED from a
# generic 5/5/5/5 ★3 player's neutral output (build-spectrum sweep, 2026-06-08), so
# an average player rates ~0. wicket_value is SOLVED empirically (it's the
# batter-vs-bowler parity knob) — 10.0 is a starting guess pending Slice-3 calibration.

@export var sr_par: float = 111.6       # par strike rate (generic 5/5/5/5 neutral SR)
@export var rr_par: float = 6.4         # par economy (generic 5/5/5/5 neutral econ)
@export var wicket_value: float = 10.0  # run-worth of one wicket (strawman; over-rewards bowlers — see Slice 3)
