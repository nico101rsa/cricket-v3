class_name LeagueResult
extends RefCounted

# Outcome of a Season's league phase. standings is ranked best -> worst. See
# spec 2026-06-07-season-league-7b2a-design.md §7.

var standings: Array = []        # Array[StandingsRow], ranked
var player_position: int = 0     # 1..8 (the Player team, index 0, after ranking)
var made_playoffs: bool = false  # player_position <= 4
var player_matches: Array = []   # Array[MatchResult] for the Player team's 7 games
var team_bat: Array = []         # team_bat[team_index] = per-Season batting strength
var team_bowl: Array = []        # team_bowl[team_index] = per-Season bowling strength
