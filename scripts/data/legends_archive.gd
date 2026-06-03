class_name LegendsArchive
extends Resource

@export var entries: Array[LegendEntry] = []

func append(entry: LegendEntry) -> void:
	entries.append(entry)

func size() -> int:
	return entries.size()
