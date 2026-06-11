class_name OpponentBrain
extends RefCounted

# E3 (spec §3.3): turns a TourSpec brain tier + blend into the opponent's
# IntentPlan/BowlingPlan via the existing opp_* seams. Tier literals are the
# measured self-play equilibria (E1 PR #42, E2 PR #45, re-anchored full-N
# post-rescale 2026-06-12 — see the E3 spec §10). Game code: independent of
# scripts/harness (DL6). NAIVE re-draws the E1 216-space uniformly.

static func textbook_plans() -> Array:
	return [IntentPlan.textbook(), BowlingPlan.textbook()]

# B/A/B·P/S/P — the static equilibrium (bowling-balance + E1).
static func static_eq_plans() -> Array:
	var ip := IntentPlan.new()
	ip.powerplay = BallResolver.Intent.BALANCED
	ip.middle = BallResolver.Intent.AGGRESSIVE
	ip.death = BallResolver.Intent.BALANCED
	return [ip, BowlingPlan.textbook()]

# B/A/B·P/S/P+u10d5c5 — the adaptive equilibrium, re-anchored at full N on the
# /100 card scale (2026-06-12 oracle run, side-A profile; E3 spec §10). The
# death band reads Balanced because the chase rule (u10) supplies the slog when
# the match asks for it. E2's pre-rescale literal was B/A/A·P/S/P+u11d6c4.
static func adaptive_eq_plans() -> Array:
	var ip := IntentPlan.new()
	ip.powerplay = BallResolver.Intent.BALANCED
	ip.middle = BallResolver.Intent.AGGRESSIVE
	ip.death = BallResolver.Intent.BALANCED
	ip.chase_up_rr = 10.0
	ip.chase_down_rr = 5.0
	ip.collapse_wkts = 5
	return [ip, BowlingPlan.textbook()]

# A uniform draw over the E1 static space (3 intents x 2 kinds per phase).
# Draw order fixed: pp/mid/death intent, then pp/mid/death kind.
static func naive_plans(rng: RandomNumberGenerator) -> Array:
	var intents := [BallResolver.Intent.DEFENSIVE, BallResolver.Intent.BALANCED, BallResolver.Intent.AGGRESSIVE]
	var kinds := [BowlingPlan.Kind.PACE, BowlingPlan.Kind.SPIN]
	var ip := IntentPlan.new()
	ip.powerplay = intents[rng.randi_range(0, 2)]
	ip.middle = intents[rng.randi_range(0, 2)]
	ip.death = intents[rng.randi_range(0, 2)]
	var bp := BowlingPlan.new()
	bp.powerplay = kinds[rng.randi_range(0, 1)]
	bp.middle = kinds[rng.randi_range(0, 1)]
	bp.death = kinds[rng.randi_range(0, 1)]
	return [ip, bp]

# The cell's draw: the tier with P(blend), else one tier lower (DL4).
# blend 1.0 on a fixed tier consumes no RNG. rng may be null only when the
# outcome cannot need it (fixed tier, blend 1.0).
static func draw_plans(tier: int, blend: float, rng: RandomNumberGenerator) -> Array:
	var t := tier
	if blend < 1.0 and rng.randf() >= blend:
		t = maxi(t - 1, TourSpec.Tier.NAIVE)
	if t == TourSpec.Tier.NAIVE:
		return naive_plans(rng)
	if t == TourSpec.Tier.TEXTBOOK:
		return textbook_plans()
	if t == TourSpec.Tier.STATIC_EQ:
		return static_eq_plans()
	return adaptive_eq_plans()
