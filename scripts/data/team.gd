class_name Team
extends Resource

# A star-rated side. Per-Match batting & bowling strengths derive from
# (stars, tour, small noise) per ADR 0009: tour.percentile(stars/5) + noise,
# two independent draws, floored at 1. The Markov star-mutation rule lives in
# 7b-2. See spec 2026-06-07-season-wrapper-7b1-design.md §3.

const STARS_MIN := 0.5
const STARS_MAX := 5.0

@export var team_name: String = ""
@export var stars: float = 2.5                # on the 0.5..5.0 half-step set
@export var last_season_event: String = ""    # ADR 0009 flavour; unused this rung

func batting_strength(tour: TourDistribution, rng: RandomNumberGenerator) -> int:
	return maxi(1, tour.percentile(stars / STARS_MAX) + rng.randi_range(-tour.noise, tour.noise))

func bowling_strength(tour: TourDistribution, rng: RandomNumberGenerator) -> int:
	return maxi(1, tour.percentile(stars / STARS_MAX) + rng.randi_range(-tour.noise, tour.noise))
