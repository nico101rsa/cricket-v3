class_name Attributes
extends Resource

# 4-attribute distribution used at Creation and during Career.
# Creation constraints: sum == 20, each in [1, 8]. See spec §3.5.

const CREATION_TOTAL := 20
const CREATION_MIN := 1
const CREATION_MAX := 8

@export var power: int = 5
@export var composure: int = 5
@export var attack: int = 5
@export var control: int = 5

func sum() -> int:
	return power + composure + attack + control

func is_valid_creation_distribution() -> bool:
	if sum() != CREATION_TOTAL:
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
