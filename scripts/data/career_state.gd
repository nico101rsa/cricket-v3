class_name CareerState
extends Resource

# The persistent Career-grid state (career-loop rung, spec
# 2026-06-12-career-loop-design.md §3.1): 24 Teams (8 per Level, level-major),
# 24 cell statuses (level*8 + tour), Level wins, the Seasons-played counter.
# Pure data + read helpers + transitions on its OWN fields (mark_beaten,
# record_outcome); cross-object orchestration lives in CareerResolver.

enum CellStatus { LOCKED, UNLOCKED, BEATEN }

const LEVELS := 3
const TOURS := 8
const TEAMS_PER_LEVEL := 8
const PREMIER_TOUR := 7
const LEAGUE_GATE_TOUR := 3   # Day Mixed — beating it unlocks the next League (v2 DV5)

@export var teams: Array[Team] = []
@export var current_team_index: int = 0
@export var cell_status: Array[int] = []
@export var level_won: Array[bool] = [false, false, false]
@export var seasons_played: int = 0
@export var complete: bool = false


func current_level() -> int:
	return floori(current_team_index / float(TEAMS_PER_LEVEL))


func cell_index(level: int, tour: int) -> int:
	return level * TOURS + tour


func status_of(level: int, tour: int) -> int:
	return cell_status[cell_index(level, tour)]


# Unlocked-and-playable. No Level-win gate (Nico's ruling 2026-06-12,
# career-pacing spec DP1): Province Premier is playable on adjacency alone;
# lower Premier wins are an optional trophy chase (paid via the v2 prize
# objects — grand-final prize + Premier super prize).
func is_unlocked(level: int, tour: int) -> bool:
	return status_of(level, tour) != CellStatus.LOCKED


func playable_cells() -> Array:
	var lvl := current_level()
	var out: Array = []
	for t in range(TOURS):
		if is_unlocked(lvl, t):
			out.append(t)
	return out


func roster_of(level: int) -> Array:
	var out: Array = []
	for i in range(level * TEAMS_PER_LEVEL, (level + 1) * TEAMS_PER_LEVEL):
		out.append(teams[i])
	return out


func opponents_of_current() -> Array:
	var lvl := current_level()
	var out: Array = []
	for i in range(lvl * TEAMS_PER_LEVEL, (lvl + 1) * TEAMS_PER_LEVEL):
		if i != current_team_index:
			out.append(teams[i])
	return out


# The 3 lowest-★ Club slots — the legal starting picks (DC7). Ties break by slot.
func lowest_star_club_indices() -> Array:
	var arr: Array = []
	for i in range(TEAMS_PER_LEVEL):
		arr.append(i)
	arr.sort_custom(func(a, b):
		if is_equal_approx(teams[a].stars, teams[b].stars):
			return a < b
		return teams[a].stars < teams[b].stars)
	return arr.slice(0, 3)


func any_unlocked_at(level: int) -> bool:
	for t in range(TOURS):
		if status_of(level, t) != CellStatus.LOCKED:
			return true
	return false


# Beating (L,T) unlocks (L,T+1); beating the League-gate Tour (Day Mixed,
# index 3) also unlocks the next League at its first tour (L+1, 0) —
# difficulty-sheet v2 (spec DV5), replacing v1's "any beat unlocks across".
func mark_beaten(level: int, tour: int) -> void:
	cell_status[cell_index(level, tour)] = CellStatus.BEATEN
	_unlock(level, tour + 1)
	if tour == LEAGUE_GATE_TOUR:
		_unlock(level + 1, 0)


func _unlock(level: int, tour: int) -> void:
	if level >= LEVELS or tour >= TOURS:
		return
	var i := cell_index(level, tour)
	if cell_status[i] == CellStatus.LOCKED:
		cell_status[i] = CellStatus.UNLOCKED


# The full end-of-Season grid transition (unit-testable without forcing a sim
# outcome): beat -> mark+unlock; Premier-Final win -> Level won; Province
# Premier win -> Career complete.
func record_outcome(level: int, tour: int, beat: bool, won_final: bool) -> void:
	if beat:
		mark_beaten(level, tour)
	if tour == PREMIER_TOUR and won_final:
		level_won[level] = true
		if level == LEVELS - 1:
			complete = true
