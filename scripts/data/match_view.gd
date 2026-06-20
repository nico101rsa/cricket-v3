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

# --- rich in-match fields (hi-fi interactive scene, docs/design-inbox/in-match.md) ---
# Computed by build_rich(). All NUMBERS are real (from the model); player NAMES are
# flavour (PlayerNames) — never mistaken for a named-player sim.
var bat_team: String = ""          # batting side's name THIS innings
var bowl_team: String = ""         # bowling side's name THIS innings
var my_code: int = 0               # player team Country.Code (header gradient)
var opp_code: int = 1              # opponent Country.Code (accent contrast)
var score_big: String = ""         # "72/2"
var score_meta: String = ""        # "9.4 OV · CRR 7.6"
var innings_tag: String = ""       # "1ST INNINGS" / "CHASING" / "DEFENDING" / "RESULT"
var target_big: String = ""        # "" or the chase target/total
var target_sub: String = ""        # "" / "NEED 53 IN 34" / "4 OV LEFT"
var striker: Dictionary = {}       # {name, badge, runs, balls, on_strike, stars} or {}
var nonstriker: Dictionary = {}    # same shape, on_strike=false
var bowler: Dictionary = {}        # {name, badge, stars, econ, spell} flavour name, real ★/econ
var this_over: Array = []          # up to 6 {kind, label}
var partnership: Dictionary = {}   # {names, runs, balls, frac} or {}
var crr: String = ""               # current run rate "7.6"
var req_value: String = ""         # right-side urgency value (required runs) or runs scored
var commentary: String = ""        # flavour commentary line
var lang: String = "ZU"            # locale tag chip
var innings_lines: Array = []      # Result: ["KAROO KINGS 1st", "162/5 (20)"] pairs
var won: bool = false              # Result: player won
var player_bat: Dictionary = {}    # the Player's own batting line {name,badge,runs,balls,ovr,stars} (DRS actor)
