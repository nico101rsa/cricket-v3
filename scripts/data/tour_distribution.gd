class_name TourDistribution
extends Resource

# A Tour's strength band. percentile(frac) maps a 0..1 fraction (a Team's
# strength fraction) into a strength number on the /100 card scale (card-rescale
# 2026-06-11). The harness sweeps these. See spec
# 2026-06-07-season-wrapper-7b1-design.md §2 and ADR 0009.

@export var tour_name: String = ""   # flavour only, not load-bearing
@export var mean: float = 31.25      # mid-Tour even-contest centre (5 legacy × SCALE)
@export var spread: float = 9.375    # half-width of the strength band (1.5 legacy × SCALE)
# World-scale v2 (2026-06-14, Nico's ruling): per-Season strength jitter is now
# PROPORTIONAL — continuous ± (noise_frac × spread). The old fixed ±6.25 swamped
# the small star spread at weak tours (Club Flat&Warm star→finish r was 0.07,
# the underdog won 22%); scaling with spread keeps the noise/spread ratio — and
# so the star→finish correlation — consistent across the whole grid. (Supersedes
# the card-rescale DR7 fixed `noise`/`noise_step`.)
@export var noise_frac: float = 0.7  # jitter amplitude as a fraction of spread (≈ the star half-range, so stars correlate with finish but the odd upset still happens)

# frac 0.0 -> mean - spread, 0.5 -> mean, 1.0 -> mean + spread. Continuous
# (card-rescale DR5: the legacy integer-grid snap is gone — league strength is
# a real number on the /100 card axis).
func percentile(frac: float) -> float:
	var f := clampf(frac, 0.0, 1.0)
	return mean + (f - 0.5) * 2.0 * spread
