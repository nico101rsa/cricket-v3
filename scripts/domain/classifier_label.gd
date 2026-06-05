class_name ClassifierLabel
extends RefCounted

# Flavour label only — zero impact on auto-sim. See spec §3.5.
# Enum is named `Kind` (not `Label`) to avoid colliding with Godot's built-in
# Label node class, which breaks `ClassifierLabel.Label.*` resolution.
enum Kind { BATTER = 0, WK_BATTER = 1, BOWLER = 2, ALL_ROUNDER = 3 }

static func display_name(l: int) -> String:
	match l:
		Kind.BATTER:      return "BATTER"
		Kind.WK_BATTER:   return "WICKET-KEEPER BATTER"
		Kind.BOWLER:      return "BOWLER"
		Kind.ALL_ROUNDER: return "ALL-ROUNDER"
		_: return ""
