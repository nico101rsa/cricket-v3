class_name RatingTuning
extends Resource

# Dials for the net-runs Player rating (spec 2026-06-08-build-balance §3). All
# @export so the balance harness can sweep them. sr_par/rr_par are DERIVED from a
# generic ★3 player's neutral output (Slice-1 Task 4); wicket_value is SOLVED
# empirically (it's the batter-vs-bowler parity knob) — 10.0 is a starting guess.

@export var sr_par: float = 120.0       # par strike rate (runs per 100 balls)
@export var rr_par: float = 7.5         # par economy (runs per over conceded)
@export var wicket_value: float = 10.0  # run-worth of one wicket (strawman)
