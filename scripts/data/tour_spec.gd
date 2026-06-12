class_name TourSpec
extends RefCounted

# One Career-grid cell's difficulty row (E3, spec
# 2026-06-12-difficulty-ladder-7cE3-design.md §3.2). Pure data; DifficultyLadder
# builds the 24 of them, OpponentBrain interprets brain_tier/blend.

enum Tier { NAIVE, TEXTBOOK, STATIC_EQ, ADAPTIVE }

const MID_MEAN := 31.25         # the mid-league card anchor (= MatchResolver.REF_SCALAR)
const SPREAD_RATIO := 0.3       # today's mid-league spread/mean ratio (DL7)

var level: int = 0              # 0 Club, 1 City, 2 Province
var tour_index: int = 0         # 0..7 (Flat & Warm .. Premier)
var d: float = 1.0              # canon difficulty number (DL1)
var cell_name: String = ""
var brain_tier: int = Tier.NAIVE
var blend: float = 1.0          # P(tier); else one tier lower (DL4)
var opp_stars: Array = []       # the 7-opponent ★ field

# mean_frac spans 0.40 (d=1) .. 1.20 (d=20), linear. Career-fidelity rung CF4
# (2026-06-13, Nico's env-span ruling): solved against probe_felt_env on the
# roster-path career sim — felt first-innings env reads ~128 at Club T1 and
# ~155 at Province Premier (his real-T20 top anchor). The bottom is dial-
# insensitive (both sides scale together; floors bind), so frac_lo stays 0.40.
static func mean_frac(p_d: float) -> float:
	return 0.4 + (p_d - 1.0) * 0.8 / 19.0

func make_tour() -> TourDistribution:
	var tour := TourDistribution.new()
	tour.tour_name = cell_name
	tour.mean = TourSpec.mean_frac(d) * MID_MEAN
	tour.spread = SPREAD_RATIO * tour.mean
	return tour
