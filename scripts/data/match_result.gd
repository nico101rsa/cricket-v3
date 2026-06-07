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
