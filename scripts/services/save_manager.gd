extends Node

# Autoload — registered in project.godot under [autoload] as `SaveManager`.
# Persists current Player and LegendsArchive to user:// via ResourceSaver.
# user:// = Godot's per-user writable save directory (survives app restarts).

@export var player_save_path: String = "user://player.tres"
@export var legends_save_path: String = "user://legends.tres"

# --- Player ---

func has_player() -> bool:
	return FileAccess.file_exists(player_save_path)

func save_player(p: Player) -> void:
	var err := ResourceSaver.save(p, player_save_path)
	if err != OK:
		push_error("SaveManager: failed to save player (err=%d)" % err)

func load_player() -> Player:
	if not has_player():
		return null
	# CACHE_MODE_IGNORE forces a fresh read from disk every time. A save system
	# must return what is ON DISK, not a shared cached instance that some other
	# part of the app might still be mutating. Without this, two load_player()
	# calls could hand back the SAME object (aliasing bug), and a load right
	# after a save could return the in-memory copy instead of the serialized one.
	return ResourceLoader.load(player_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Player

func clear_player() -> void:
	if has_player():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(player_save_path))

# --- Legends ---

func load_legends() -> LegendsArchive:
	if FileAccess.file_exists(legends_save_path):
		var arc := ResourceLoader.load(legends_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as LegendsArchive
		if arc != null:
			return arc
	return LegendsArchive.new()

func archive_to_legends(p: Player, end_reason: String, seasons_played: int) -> void:
	var arc := load_legends()
	var entry := LegendEntry.new()
	# Deep-duplicate so the archived player has NO resource_path. A path-bearing
	# Player (e.g. one returned by load_player()) would be written into legends.tres
	# as an EXTERNAL reference (ext_resource) pointing at user://player.tres — and
	# the caller (end_career) deletes that file immediately after, orphaning the
	# reference. duplicate(true) embeds the whole Player (and its NamePair /
	# Attributes sub-resources) inline instead. See test_archiving_a_loaded_player_…
	entry.player = p.duplicate(true)
	entry.end_reason = end_reason
	entry.ended_at = int(Time.get_unix_time_from_system())
	entry.seasons_played = seasons_played
	arc.append(entry)
	var err := ResourceSaver.save(arc, legends_save_path)
	if err != OK:
		push_error("SaveManager: failed to save legends (err=%d)" % err)

func clear_legends() -> void:
	if FileAccess.file_exists(legends_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(legends_save_path))
