class_name PlayerCreationDraft
extends Resource

# Transient — lives across the 2 Creation screens. Discarded if user backs out.
# See spec §6.1.

@export var country: int = -1          # Country.Code or -1 if unset
@export var city: String = ""          # "" if unset
@export var appearance: int = -1       # Appearance.Bucket or -1 if unset
@export var name: NamePair             # null until first name-roll
@export var attributes: Attributes     # always present; defaults to 35/30/30/30

func _init() -> void:
	attributes = Attributes.new()
	# Creation default (card-rescale DR10): a valid 125-point all-rounder ON the
	# Build screen's 5-point slider grid (the raw Attributes default 31.25 x4 is
	# valid but off-grid — moving any slider would strand the budget).
	attributes.power = 35.0
	attributes.composure = 30.0
	attributes.attack = 30.0
	attributes.control = 30.0

func identity_complete() -> bool:
	return country >= 0 \
		and city != "" \
		and appearance >= 0 \
		and name != null
