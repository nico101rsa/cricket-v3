class_name PlayerCreationDraft
extends Resource

# Transient — lives across the 2 Creation screens. Discarded if user backs out.
# See spec §6.1.

@export var country: int = -1          # Country.Code or -1 if unset
@export var city: String = ""          # "" if unset
@export var appearance: int = -1       # Appearance.Bucket or -1 if unset
@export var name: NamePair             # null until first name-roll
@export var attributes: Attributes     # always present; defaults to 5/5/5/5

func _init() -> void:
	attributes = Attributes.new()

func identity_complete() -> bool:
	return country >= 0 \
		and city != "" \
		and appearance >= 0 \
		and name != null
