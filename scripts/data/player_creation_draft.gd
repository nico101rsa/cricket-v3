class_name PlayerCreationDraft
extends Resource

# Transient — lives across the 2 Creation screens. Discarded if user backs out.
# See spec §6.1.

@export var country: int = -1          # Country.Code or -1 if unset
@export var city: String = ""          # "" if unset
@export var appearance: int = -1       # Appearance.Bucket or -1 if unset
@export var club_slot: int = 0         # starting-club pick, 0-2 (T11 DCC6)
@export var name: NamePair             # null until first name-roll
@export var attributes: Attributes     # always present; defaults to 11/11/11/11

func _init() -> void:
	attributes = Attributes.new()
	# Creation default (world-scale v2, WS3): a fresh hero ≈ a weak Club player —
	# a valid 44-point balanced all-rounder, internal ~11/attr (shows ~11 on the
	# /100 card via Display). You GROW from here toward the cap over a career.
	attributes.power = 11.0
	attributes.composure = 11.0
	attributes.attack = 11.0
	attributes.control = 11.0

func identity_complete() -> bool:
	return country >= 0 \
		and city != "" \
		and appearance >= 0 \
		and name != null
