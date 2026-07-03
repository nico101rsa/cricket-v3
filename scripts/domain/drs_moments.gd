class_name DRSMoments
extends RefCounted

# DRS decision moments (spec 2026-07-04, playtest T8). The single source of truth
# for WHICH wickets are reviewable decision moments and at WHAT shown odds -- both
# the InningsResolver (auto/AI path) and MatchSession (the player's card) consume
# this, so the number on the card is exactly the number the roll uses.
#
# Everything here is HASH-derived from (batting side, over, ball-in-over): stable
# across re-sims and NO RNG consumption, so the ball-outcome cascade is untouched
# (DT1). A wicket's flavour is presentation + review-gate only -- it carries no
# other sim effect.

const SET_BALLS := 10      # a striker who has faced this many balls is "set" (DT2)
const DEATH_OVER := 19     # last-2-overs gate (DT2)
const AI_BURN_P := 0.35    # auto/AI burns a review in a moment iff raw p >= this (DT4)
const P_LO := 0.20         # moment p range [P_LO, P_LO + P_SPAN] (DT3)
const P_SPAN := 0.50

# DT1 flavour weights (percent, sum 100). Reviewable-looking = lbw + caught_behind.
const _FLAVOURS := [
	["caught", 35], ["bowled", 22], ["lbw", 18],
	["caught_behind", 15], ["run_out", 7], ["stumped", 3],
]

static func _h(salt: String, batting_side_is_player: bool, over: int, bio: int) -> int:
	return hash("%s|%s|%d|%d" % [salt, "p" if batting_side_is_player else "o", over, bio])

static func flavour_of(batting_side_is_player: bool, over: int, bio: int) -> String:
	var roll := _h("drsf", batting_side_is_player, over, bio) % 100
	var acc := 0
	for f in _FLAVOURS:
		acc += f[1]
		if roll < acc:
			return f[0]
	return "caught"

static func is_reviewable(flavour: String) -> bool:
	return flavour == "lbw" or flavour == "caught_behind"

# The per-moment success chance, drawn once per ball cell and SHOWN to the player
# (joker accuracy bonuses stack on top at roll/display time).
static func moment_p(batting_side_is_player: bool, over: int, bio: int) -> float:
	var u := float(_h("drsp", batting_side_is_player, over, bio) % 10000) / 9999.0
	return P_LO + P_SPAN * u

# DT2: a wicket is a DRS decision moment iff its flavour looks reviewable AND the
# striker was set (faced >= SET_BALLS before this delivery) OR it's the death overs.
static func is_moment(flavour: String, striker_balls_faced: int, over: int) -> bool:
	if not is_reviewable(flavour):
		return false
	return striker_balls_faced >= SET_BALLS or over >= DEATH_OVER
