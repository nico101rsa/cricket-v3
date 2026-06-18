class_name MatchResult
extends RefCounted

# Outcome of one full match, from the Player's perspective. Decision logic lives
# in MatchResolver; this is a plain holder + display accessors. Spec §6.

enum Outcome { PLAYER_WIN, OPPONENT_WIN, TIE }

var innings1: InningsResult        # whoever batted first
var innings2: InningsResult        # whoever batted second (the chase)
var player_bats_first: bool = true
var outcome: int = Outcome.TIE
var margin_runs: int = 0           # set when a side wins batting first
var margin_wickets: int = 0        # set when a side wins chasing
var balls_remaining: int = 0       # set when a side wins chasing

# Opt-in per-ball replay logs (Play → Match screen, spec §6). Empty unless the
# match was simulated with capture on. innings1/innings2 follow bat order (same as
# the InningsResult fields); each entry is the per-ball dict InningsResolver records.
var ball_log_innings1: Array = []
var ball_log_innings2: Array = []

func player_won() -> bool:
	return outcome == Outcome.PLAYER_WIN

func is_tie() -> bool:
	return outcome == Outcome.TIE

# Neutral winning-margin phrasing for the Result screen ("won by ..." / "match tied").
func margin_text() -> String:
	if outcome == Outcome.TIE:
		return "match tied"
	if margin_runs > 0:
		return "won by %d runs" % margin_runs
	return "won by %d wickets (%d balls left)" % [margin_wickets, balls_remaining]

# Result line from the PLAYER's perspective — NAMES the winner so a side defending a
# total doesn't read the neutral margin_text ("won by 1 wickets") as its own win
# (the 2026-06-18 confusing-result bug). Used by the match screens; margin_text stays
# neutral for the season-table rows that show won/lost separately.
func result_line_for_player() -> String:
	if is_tie():
		return "Match tied"
	var who := "You" if player_won() else "Opponent"
	if margin_runs > 0:
		return "%s won by %d run%s" % [who, margin_runs, "" if margin_runs == 1 else "s"]
	return "%s won by %d wicket%s (%d balls left)" % [
		who, margin_wickets, "" if margin_wickets == 1 else "s", balls_remaining]
