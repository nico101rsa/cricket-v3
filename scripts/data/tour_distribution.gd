class_name TourDistribution
extends Resource

# A Tour's strength band. percentile(frac) maps a 0..1 fraction (a Team's
# stars/5) into a strength number on the ~1-8 attribute scale. All three values
# are V1 strawman — the 7c balance harness sweeps them. See spec
# 2026-06-07-season-wrapper-7b1-design.md §2 and ADR 0009.

@export var tour_name: String = ""   # flavour only, not load-bearing
@export var mean: int = 5            # mid-Tour even-contest centre
@export var spread: int = 3          # half-width of the strength band
@export var noise: int = 1           # +-absolute per-derivation jitter

# frac 0.0 -> mean - spread, 0.5 -> mean, 1.0 -> mean + spread. Clamped + rounded.
func percentile(frac: float) -> int:
	var f := clampf(frac, 0.0, 1.0)
	return roundi(mean + (f - 0.5) * 2.0 * spread)
