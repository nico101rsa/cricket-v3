class_name FormBand
extends RefCounted

# The single form-banding seam (spec DP3). Display + portrait consumers band a raw
# Player.form int here; the future Form-mechanic rung re-tunes ticks against this.
# Fresh players (form 0) are STEADY -- 0 used to read TIRED in the hub chip.
enum Band { COLD = 0, TIRED = 1, STEADY = 2, HOT = 3 }

static func of(form: int) -> int:
	if form >= 2: return Band.HOT
	if form >= 0: return Band.STEADY
	if form == -1: return Band.TIRED
	return Band.COLD

static func key(band: int) -> String:
	match band:
		Band.HOT: return "hot"
		Band.STEADY: return "steady"
		Band.TIRED: return "tired"
		_: return "cold"

static func label(band: int) -> String:
	return key(band).to_upper()
