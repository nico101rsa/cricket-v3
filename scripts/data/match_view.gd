class_name MatchView
extends RefCounted

# Read-model the match_view scene renders at one playback cursor. Built by
# MatchViewBuilder; pure data, no logic. Spec §3.

var innings_label: String = ""     # "Your innings" / "Bowling — chasing 151"
var batting_score: String = ""     # running "84/3 (10.2)" for the active batting side
var target_text: String = ""       # "Target 151" in the 2nd innings, else ""
var current_line: String = ""      # striker "You 40* (28)" or bowling "You 2/26 (4.0)"
var feed: Array = []               # last ~6 event display strings (newest last)
var finished: bool = false         # cursor reached the end
var result_text: String = ""       # "won by 5 wickets" once finished
var player_won: bool = false
var player_summary: String = ""     # "You: 38 (20) bat · 6/18 (3.0) bowl" once finished
var event_count: int = 0           # total events in the stream (for the scrubber)
var highlight_text: String = ""    # your-moment flash for the just-shown ball ("" = none)
