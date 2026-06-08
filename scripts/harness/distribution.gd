class_name Distribution
extends RefCounted

# Summary stats + histogram over a list of numbers. Pure, no RNG. The numeric
# workhorse of the balance harness. See spec
# 2026-06-08-balance-harness-platform-7c1-design.md §3.

var values: Array = []

func _init(vals: Array = []) -> void:
	values = vals

func count() -> int:
	return values.size()

func mean() -> float:
	if values.is_empty():
		return 0.0
	var s := 0.0
	for v in values:
		s += v
	return s / values.size()

func sd() -> float:
	if values.size() < 2:
		return 0.0
	var m := mean()
	var ss := 0.0
	for v in values:
		ss += (v - m) * (v - m)
	return sqrt(ss / values.size())

func minimum() -> float:
	if values.is_empty():
		return 0.0
	var lo: float = values[0]
	for v in values:
		lo = minf(lo, v)
	return lo

func maximum() -> float:
	if values.is_empty():
		return 0.0
	var hi: float = values[0]
	for v in values:
		hi = maxf(hi, v)
	return hi

# Array[int] of length `bins`. Each value -> floor((v-lo)/(hi-lo)*bins), clamped
# to [0, bins-1] so out-of-range values fall into the end bins.
func histogram(bins: int, lo: float, hi: float) -> Array:
	var counts: Array = []
	for i in range(bins):
		counts.append(0)
	if bins <= 0 or hi <= lo:
		return counts
	for v in values:
		var idx := int(floor((v - lo) / (hi - lo) * bins))
		idx = clampi(idx, 0, bins - 1)
		counts[idx] += 1
	return counts

func to_dict() -> Dictionary:
	return {"count": count(), "mean": mean(), "sd": sd(), "min": minimum(), "max": maximum()}
