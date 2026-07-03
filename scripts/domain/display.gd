class_name Display
extends RefCounted

# Pure DISPLAY transform (world-scale v2, spec 2026-06-13-world-scale-v2-design.md
# WS2). Maps an INTERNAL card/strength value (the units the sim runs on: Club
# average ~12.5, Province Premier best ~46.5, attribute cap 60) to the /100 scale
# Nico wants to SEE (Club ~13, Province Premier average 85 / best 90, cap 100).
# Monotonic, piecewise-linear through Nico's anchors (2026-06-13). DISPLAY ONLY —
# the result is never fed back into the sim, saves, or economy.

const _IN: Array[float] = [0.0, 12.5, 37.5, 46.5, 60.0]      # internal anchors
const _OUT: Array[float] = [0.0, 13.0, 85.0, 90.0, 100.0]    # /100 display anchors


static func to_card(internal: float) -> float:
	if internal <= _IN[0]:
		return _OUT[0]
	for i in range(1, _IN.size()):
		if internal <= _IN[i]:
			var t: float = (internal - _IN[i - 1]) / (_IN[i] - _IN[i - 1])
			return _OUT[i - 1] + t * (_OUT[i] - _OUT[i - 1])
	# Above the top anchor: extrapolate with the last segment's slope.
	var n := _IN.size()
	var slope: float = (_OUT[n - 1] - _OUT[n - 2]) / (_IN[n - 1] - _IN[n - 2])
	return _OUT[n - 1] + (internal - _IN[n - 1]) * slope


static func to_card_round(internal: float) -> int:
	return int(round(to_card(internal)))

# Star-rating glyph string -- half-stars render as the half glyph, NEVER rounded up
# (playtest T2: a 1.5-star team read as two stars on Pre-Match). Shared by every
# screen that prints stars.
static func stars_str(stars: float) -> String:
	var full := int(floor(stars))
	var out := "★".repeat(full)
	if (stars - full) >= 0.5:
		out += "½"
	return out if not out.is_empty() else "½"
