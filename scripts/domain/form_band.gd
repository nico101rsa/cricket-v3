class_name FormBand
extends RefCounted

# The single form-banding seam (spec DP3). Display + portrait consumers band the
# RAW form points (float) here -- banding a roundi'd int made one bad game (-0.75)
# read TIRED (playtest T6). STEADY covers everything above -1.0; the negative range
# splits into clean thirds. HOT keeps the old effective boundary (1.5 rounded to 2).
# Fresh players (0.0) are STEADY.
enum Band { COLD = 0, TIRED = 1, STEADY = 2, HOT = 3 }

static func of(points: float) -> int:
	if points >= 1.5: return Band.HOT
	if points > -1.0: return Band.STEADY
	if points > -2.0: return Band.TIRED
	return Band.COLD

static func key(band: int) -> String:
	match band:
		Band.HOT: return "hot"
		Band.STEADY: return "steady"
		Band.TIRED: return "tired"
		_: return "cold"

static func label(band: int) -> String:
	return key(band).to_upper()
