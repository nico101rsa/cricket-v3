extends Control

# Placeholder. Real Hall of Fame is a sibling spec, owed by Theme 5.
# This stub renders the LegendsArchive as plain text rows + a "Begin new Player" button.

signal begin_new_player()

func _ready() -> void:
	$Layout/BeginBtn.pressed.connect(func(): begin_new_player.emit())
	_render_legends()

func _render_legends() -> void:
	var arc: LegendsArchive = SaveManager.load_legends()
	var list_label: Label = $Layout/LegendsList
	var lines: Array[String] = []
	for entry in arc.entries:
		var arc_text := "%s · %s · %s · %d seasons" % [
			entry.player.name.display_caps(),
			entry.player.city,
			entry.end_reason.to_upper(),
			entry.seasons_played,
		]
		lines.append(arc_text)
	if lines.is_empty():
		list_label.text = "(no Legends yet)"
	else:
		list_label.text = "\n".join(lines)
