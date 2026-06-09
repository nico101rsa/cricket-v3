class_name Team
extends Resource

# A star-rated side. Per-Match batting & bowling strengths derive from
# (stars, tour, small noise) per ADR 0009: tour.percentile(stars/5) + noise,
# two independent draws, floored at 1. The Markov star-mutation rule lives in
# 7b-2. See spec 2026-06-07-season-wrapper-7b1-design.md §3.

const STARS_MIN := 0.5
const STARS_MAX := 5.0

const MUTATE_CATASTROPHIC := 0.05   # P(+-1.0 swing)
const MUTATE_SWING := 0.35          # cumulative: P(+-0.5) = 0.30; else no change

@export var team_name: String = ""
@export var stars: float = 2.5                # on the 0.5..5.0 half-step set
@export var last_season_event: String = ""    # ADR 0009 flavour; unused this rung

func batting_strength(tour: TourDistribution, rng: RandomNumberGenerator) -> int:
	return maxi(1, tour.percentile(stars / STARS_MAX) + rng.randi_range(-tour.noise, tour.noise))

func bowling_strength(tour: TourDistribution, rng: RandomNumberGenerator) -> int:
	return maxi(1, tour.percentile(stars / STARS_MAX) + rng.randi_range(-tour.noise, tour.noise))

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

static func archetype_batter() -> Attributes:
	var a := Attributes.new()
	a.power = 8; a.composure = 8; a.attack = 2; a.control = 2
	return a

static func archetype_bowler() -> Attributes:
	var a := Attributes.new()
	a.power = 2; a.composure = 2; a.attack = 8; a.control = 8
	return a

static func archetype_allrounder() -> Attributes:
	var a := Attributes.new()
	a.power = 5; a.composure = 5; a.attack = 5; a.control = 5
	return a

# The fixed standard XI, in batting order: 6 BATTER, 1 ALLROUNDER, 4 BOWLER.
# Point split = (122 batting / 98 bowling) per spec §4.2. Used unchanged by the
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
# batting total lands back on 122. Walks the order TOP -> TAIL so the top-up lands
# on the high-leverage top order (where runs actually get scored — tail points
# barely face balls), alternating composure then power per sweep. Floors each stat
# at 1. The Player slot (index ppos-1) is never touched. The top-first distribution
# is a calibration lever (spec §8.6 D14).
static func _apply_batting_gapfill(xi: Array, ppos: int, deficit: int) -> void:
	if deficit == 0:
		return
	var step := 1 if deficit > 0 else -1
	var remaining := absi(deficit)
	var slots: Array[int] = []
	for i in range(0, 11):   # 0 -> 10, top to tail
		if i != ppos - 1:
			slots.append(i)
	var idx := 0
	while remaining > 0:
		var slot: int = slots[idx % slots.size()]
		var a: Attributes = xi[slot]
		if (idx / slots.size()) % 2 == 1:   # sweep 0 = composure, sweep 1 = power, ...
			a.power = maxi(1, a.power + step)
		else:
			a.composure = maxi(1, a.composure + step)
		remaining -= 1
		idx += 1
