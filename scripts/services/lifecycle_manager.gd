extends Node

# Autoload — single owner of the "end this Career" state transition.
# Manual retire + Win-out both route through end_career() so future auto-drop
# (Theme 9, post-launch) is a third trigger pointing at the same transition.
# See spec §2 + ADR 0012.

signal career_ended(end_reason: String)

func _ready() -> void:
	# Desktop must let the OS lock/sleep the screen (a security finding, 2026-07-03:
	# Godot's keep_screen_on default held a macOS power assertion, so the Mac never
	# locked while the game ran). The project setting is off; phones re-enable it at
	# runtime -- a match should not dim mid-over on the iOS build.
	DisplayServer.screen_set_keep_on(OS.has_feature("mobile"))

func manual_retire() -> void:
	end_career(LegendEntry.END_REASON_RETIRED)

func win_out() -> void:
	end_career(LegendEntry.END_REASON_WON)

func end_career(reason: String) -> void:
	var p := SaveManager.load_player()
	if p == null:
		push_warning("LifecycleManager.end_career called with no Player loaded")
		return
	# Real Seasons-played from the Career save (career-loop DC14); a Career-less
	# save (pre-rung or test fixture) archives the old placeholder 1.
	var seasons := 1
	var c := SaveManager.load_career()
	if c != null:
		seasons = c.seasons_played
	SaveManager.archive_to_legends(p, reason, seasons)
	SaveManager.clear_player()
	SaveManager.clear_career()
	career_ended.emit(reason)
