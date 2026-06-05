extends Node

# Autoload — single owner of the "end this Career" state transition.
# Manual retire + Win-out both route through end_career() so future auto-drop
# (Theme 9, post-launch) is a third trigger pointing at the same transition.
# See spec §2 + ADR 0012.

signal career_ended(end_reason: String)

# Seasons-played counter. Real Career-state code will own this; for V1 we
# just hand 1 to archive_to_legends as a placeholder.
const _PLACEHOLDER_SEASONS := 1

func manual_retire() -> void:
	end_career(LegendEntry.END_REASON_RETIRED)

func win_out() -> void:
	end_career(LegendEntry.END_REASON_WON)

func end_career(reason: String) -> void:
	var p := SaveManager.load_player()
	if p == null:
		push_warning("LifecycleManager.end_career called with no Player loaded")
		return
	SaveManager.archive_to_legends(p, reason, _PLACEHOLDER_SEASONS)
	SaveManager.clear_player()
	career_ended.emit(reason)
