class_name Team
extends Resource

# A star-rated side. Per-Match batting & bowling strengths derive from
# (stars, tour, small noise) per ADR 0009: tour.percentile(stars/5) + noise,
# two independent draws, floored at one legacy point (SCALE). The Markov
# star-mutation rule lives in 7b-2. See spec 2026-06-07-season-wrapper-7b1-design.md §3.

const STARS_MIN := 0.5
const STARS_MAX := 5.0

const MUTATE_CATASTROPHIC := 0.05   # P(+-1.0 swing)
const MUTATE_SWING := 0.35          # cumulative: P(+-0.5) = 0.30; else no change

@export var team_name: String = ""
@export var stars: float = 2.5                # on the 0.5..5.0 half-step set
@export var last_season_event: String = ""    # ADR 0009 flavour; unused this rung

# The star -> band-fraction map, centred on ★3 (card-rescale DR5): ★3 is the
# even-contest balance baseline, so it sits exactly ON the tour mean — a ★3
# mid-tour team plays its cards at face value (factor 1.0). ★0.5 -> 0.0,
# ★5 -> 0.9 (the top half-star band sits inside the spread). The legacy
# stars/5 map centred on ★2.75 and the old integer snap blurred it.
func strength_frac() -> float:
	return clampf((stars - 3.0) / 5.0 + 0.5, 0.0, 1.0)

func batting_strength(tour: TourDistribution, rng: RandomNumberGenerator) -> float:
	return maxf(Attributes.SCALE, tour.percentile(strength_frac()) + rng.randf_range(-1.0, 1.0) * tour.noise_frac * tour.spread)

func bowling_strength(tour: TourDistribution, rng: RandomNumberGenerator) -> float:
	return maxf(Attributes.SCALE, tour.percentile(strength_frac()) + rng.randf_range(-1.0, 1.0) * tour.noise_frac * tour.spread)

# Mutate stars Markov-style at a Season rollover (ADR 0009). Two RNG draws
# (magnitude, then direction), clamped to [0.5, 5.0]. Catastrophic flavour string
# deferred. See spec 2026-06-08-season-playoffs-7b2b-design.md §6.
func mutate_stars(rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	var delta := 0.0
	if roll < MUTATE_CATASTROPHIC:
		delta = 1.0 * dir
	elif roll < MUTATE_SWING:
		delta = 0.5 * dir
	stars = clampf(stars + delta, STARS_MIN, STARS_MAX)

# --- Slice 2: discrete roster (spec §4) ---------------------------------------
# Archetypes are strawman 20-point builds (harness-tunable). Each call returns a
# FRESH Attributes so callers never share mutable state.

# Tail-steepened split (bowling-balance BB5, Nico's lever 2026-06-11): the
# BOWLER's batting drops 2/2 -> 1/1 (legacy units) so the card falls off a cliff
# after the all-rounder — each top-order wicket walks the innings toward a
# near-useless tail, making wickets more expensive. The BATTER stays 8/8/2/2: a
# fully sharpened 9/9 top order saturated the scoring curve and blew the build-
# equality spread to 4.6 pts (measured 2026-06-11), so only the tail half of
# the lever ships. Card-rescale 2026-06-11: all values ×6.25 on the /100 scale —
# every archetype is exactly a 125-point build (the BB5 asymmetry preserved,
# spec DR2: bowler bowling reads 56.25, not a round 50).
static func archetype_batter() -> Attributes:
	var a := Attributes.new()
	a.power = 50.0; a.composure = 50.0; a.attack = 12.5; a.control = 12.5
	return a

static func archetype_bowler() -> Attributes:
	var a := Attributes.new()
	a.power = 6.25; a.composure = 6.25; a.attack = 56.25; a.control = 56.25
	return a

static func archetype_allrounder() -> Attributes:
	var a := Attributes.new()
	a.power = 31.25; a.composure = 31.25; a.attack = 31.25; a.control = 31.25
	return a

# The fixed standard XI, in batting order: 6 BATTER, 1 ALLROUNDER, 4 BOWLER.
# Point split = (712.5 batting / 662.5 bowling, legacy 114/106 × SCALE, BB5
# steep-tail split). Used unchanged by the
# opponent, and as the template the Player slots into (build_xi).
static func standard_xi() -> Array:
	var xi: Array = []
	for i in range(6):
		xi.append(archetype_batter())
	xi.append(archetype_allrounder())
	for i in range(4):
		xi.append(archetype_bowler())
	return xi

# The Player's team order: the standard XI with the archetype at the Player's
# 1-based batting position `ppos` replaced by the Player, then the 10 teammates
# topped up / docked so the team's batting points return to the standard 122 —
# build-adaptive gap-fill (Slice 3, D11). ppos is 1..9 (< 11), safe.
static func build_xi(player_attrs: Attributes, ppos: int) -> Array:
	var xi := standard_xi()
	var displaced: Attributes = xi[ppos - 1]
	var deficit := (displaced.power + displaced.composure) - (player_attrs.power + player_attrs.composure)
	xi[ppos - 1] = player_attrs
	_apply_batting_gapfill(xi, ppos, deficit)
	return xi

# Spread `deficit` batting points across the 10 non-Player slots so the team
# batting total lands back on the standard 712.5 (= legacy 114 × SCALE, BB5 split). Walks the
# order TOP -> TAIL so the top-up lands on the high-leverage top order (where runs
# actually get scored — tail points barely face balls), alternating composure then
# power per sweep, in one-legacy-point (SCALE) chunks with a fractional final
# chunk so any float deficit conserves exactly (card-rescale DR9). Floors each
# stat at SCALE while docking (can strand deficit, same as the integer era). The
# Player slot (index ppos-1) is never touched. The top-first distribution is a
# calibration lever (spec §8.6 D14).
static func _apply_batting_gapfill(xi: Array, ppos: int, deficit: float) -> void:
	if is_zero_approx(deficit):
		return
	var dir := 1.0 if deficit > 0.0 else -1.0
	var remaining := absf(deficit)
	var slots: Array[int] = []
	for i in range(0, 11):   # 0 -> 10, top to tail
		if i != ppos - 1:
			slots.append(i)
	var idx := 0
	while remaining > 0.0:
		var step := minf(Attributes.SCALE, remaining)   # final chunk is fractional (DR9)
		var slot: int = slots[idx % slots.size()]
		var a: Attributes = xi[slot]
		if (idx / slots.size()) % 2 == 1:   # sweep 0 = composure, sweep 1 = power, ...
			a.power = maxf(Attributes.SCALE, a.power + step * dir)
		else:
			a.composure = maxf(Attributes.SCALE, a.composure + step * dir)
		remaining -= step
		idx += 1
