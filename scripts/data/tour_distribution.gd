class_name TourDistribution
extends Resource

# A Tour's strength band. percentile(frac) maps a 0..1 fraction (a Team's
# strength fraction) into a strength number on the /100 card scale (card-rescale
# 2026-06-11). The harness sweeps these. See spec
# 2026-06-07-season-wrapper-7b1-design.md §2 and ADR 0009.

@export var tour_name: String = ""   # flavour only, not load-bearing
@export var mean: float = 31.25      # mid-Tour even-contest centre (5 legacy × SCALE)
@export var spread: float = 9.375    # half-width of the strength band (1.5 legacy × SCALE)
@export var noise: int = 1           # +- per-derivation jitter, in noise_step units
@export var noise_step: float = 6.25 # one legacy attribute point (DR7: noise model
                                     # unchanged by the rescale, just scaled — continuous
                                     # noise is a separate tuning question)

# frac 0.0 -> mean - spread, 0.5 -> mean, 1.0 -> mean + spread.
# STAGE A: snapped to the legacy 6.25 grid (roundi-equivalent) so the rescale is
# byte-identical — Stage B (card-rescale DR5) removes the snap.
func percentile(frac: float) -> float:
	var f := clampf(frac, 0.0, 1.0)
	var raw := mean + (f - 0.5) * 2.0 * spread
	return roundi(raw / Attributes.SCALE) * Attributes.SCALE
