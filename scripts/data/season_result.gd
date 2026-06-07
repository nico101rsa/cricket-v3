class_name SeasonResult
extends RefCounted

# Outcome of a full Season (league + playoffs). See spec
# 2026-06-08-season-playoffs-7b2b-design.md §4.

var league: LeagueResult                 # the league phase
var semi1: MatchResult                   # seed1 v seed4
var semi2: MatchResult                   # seed2 v seed3
var final_match: MatchResult             # the two semi winners (1st/2nd)
var third_place: MatchResult             # the two semi losers (3rd/4th)
var final_order: Array = []              # 8 team_index values, finishing 1st..8th
var player_final_position: int = 0       # 1..8 (where team 0 finished)
var beat: bool = false                   # player finished top 3
var won_final: bool = false              # player finished 1st (won The Final)
