class_name LegendEntry
extends Resource

# One archived Player. See spec §6.3.

const END_REASON_WON := "won"
const END_REASON_RETIRED := "retired"

@export var player: Player                 # full snapshot at archive time
@export var end_reason: String = ""        # "won" or "retired"
@export var ended_at: int = 0              # Unix epoch seconds
@export var seasons_played: int = 0
# career_stats deferred — Career Records spec (ADR 0011) owns the schema
