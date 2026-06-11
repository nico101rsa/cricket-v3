class_name Attributes
extends Resource

# 4-attribute distribution used at Creation and during Career, on the /100 card
# scale (card-rescale spec 2026-06-11, DR1/DR3). SCALE converts one classic
# 1-8-era attribute point to /100 units; the save migration uses it too.
# Creation constraints: sum == 125, each in [5, 50]. NPC archetypes are exempt
# from the per-attribute cap (prior ruling; the bowler card carries 56.25).

const SCALE := 6.25            # /100 units per legacy attribute point (= 50/8)
const CREATION_TOTAL := 125.0
const CREATION_MIN := 5.0
const CREATION_MAX := 50.0

@export var power: float = 31.25
@export var composure: float = 31.25
@export var attack: float = 31.25
@export var control: float = 31.25

func sum() -> float:
	return power + composure + attack + control

func is_valid_creation_distribution() -> bool:
	if not is_equal_approx(sum(), CREATION_TOTAL):
		return false
	for v in [power, composure, attack, control]:
		if v < CREATION_MIN or v > CREATION_MAX:
			return false
	return true

func duplicate_typed() -> Attributes:
	var copy := Attributes.new()
	copy.power = power
	copy.composure = composure
	copy.attack = attack
	copy.control = control
	return copy
