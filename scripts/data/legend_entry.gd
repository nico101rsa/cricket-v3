class_name LegendEntry
extends Resource

# One archived Player. See spec §6.3.

const END_REASON_WON := "won"
const END_REASON_RETIRED := "retired"

@export var player: Player                 # full snapshot at archive time
@export var end_reason: String = ""        # "won" or "retired"
@export var ended_at: int = 0              # Unix epoch seconds
@export var seasons_played: int = 0
@export var levels_won: int = 0            # NEW (HoF spec §2.1) — stub until the Season loop
@export var retired_season: int = 0        # NEW (HoF spec §2.1) — stub until the Season loop
@export var immortalised: bool = true      # NEW (HoF spec §2.1) — V1 always gold
# career_stats deferred — Career Records spec (ADR 0011) owns the schema

# Arc roles are DERIVED from the snapshot, never stored: the Player already holds
# both starting_attributes and (final) attributes, so storing the labels would
# duplicate derivable data and risk drift. Single source of truth = the snapshot.
func start_role() -> int:    # ClassifierLabel.Kind
	return Classifier.classify(player.starting_attributes)

func end_role() -> int:      # ClassifierLabel.Kind
	return Classifier.classify(player.attributes)
