class_name RatingTuning
extends Resource

# Dials for the net-runs Player rating (spec 2026-06-08-build-balance §3). All
# @export so the balance harness can sweep them. sr_par/rr_par are DERIVED from a
# generic 5/5/5/5 ★3 player's neutral output (build-spectrum sweep, 2026-06-08), so
# an average player rates ~0. wicket_value is SOLVED empirically (it's the
# batter-vs-bowler parity knob) — 10.0 is a starting guess pending Slice-3 calibration.

@export var sr_par: float = 107.4       # par strike rate — re-derived from the 5/5/5/5 build's
                                        # neutral output in the conserved-roster world (Slice 3)
@export var rr_par: float = 9.0         # par economy — re-derived likewise (≈ the going run-rate
                                        # an average part-time bowler concedes; Slice 3)
@export var wicket_value: float = 2.0   # SOLVED Slice 3 (2026-06-09): the value at which a pure
                                        # bowler's mean rating equals a pure batter's at derived par.
                                        # Low because the rating's bowling value is dominated by
                                        # runs-saved (economy), not wickets. See spec §9.5.3.
