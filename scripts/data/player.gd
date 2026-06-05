class_name Player
extends Resource

# Persisted Player. New fields added by this spec are flagged below.
# Existing fields (form, affinity, tons_balance) are initialised to neutral
# defaults here; their behaviour belongs to other systems.

@export var name: NamePair                       # immutable post-Creation
@export var country: int = Country.Code.SA       # Country.Code
@export var city: String = ""                    # NEW (spec §6.2)
@export var appearance: int = Appearance.Bucket.WHITE  # NEW (spec §6.2)
@export var attributes: Attributes               # mutable via Tons upgrades
@export var starting_attributes: Attributes      # NEW (spec §6.2) — snapshot at creation, immutable
@export var created_at: int = 0                  # NEW — Unix epoch seconds

# Neutral defaults for fields that other systems own.
@export var form: int = 0          # 0 = "Steady" (neutral); enum will land with the Form system
@export var affinity: int = 0
@export var tons_balance: int = 0

static func from_draft(draft: PlayerCreationDraft) -> Player:
	var p := Player.new()
	p.name = draft.name
	p.country = draft.country
	p.city = draft.city
	p.appearance = draft.appearance
	p.attributes = draft.attributes.duplicate_typed()
	p.starting_attributes = draft.attributes.duplicate_typed()
	p.created_at = int(Time.get_unix_time_from_system())
	return p
