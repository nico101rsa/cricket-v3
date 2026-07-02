class_name LadderMap
extends Control

# The career map (nav-shell spec 2026-07-03, Slice 3; mockup section 6, Q3
# reco): 3 Levels × 8 Tours as rising diagonals — each Level a bottom-left →
# up-right row, the next Level starting at the left at the height the previous
# topped out. Node states from CareerState.cell_status; the current cell rings
# in the accent. Pure presentation — reads, never mutates (RunRateChart
# precedent for custom _draw widgets).

const LEVELS := 3
const TOURS := 8
const R := 9.0            # node radius
const PAD := Vector2(26, 20)

var _status: Array = []
var _level_won: Array = []
var _current := {}
var _accent: Color = Palette.GOLD

func set_state(cell_status: Array, level_won: Array, current: Dictionary,
		accent: Color = Palette.GOLD) -> void:
	_status = cell_status.duplicate()
	_level_won = level_won.duplicate()
	_current = current
	_accent = accent
	queue_redraw()

func current_cell() -> Dictionary:
	return _current

# Geometry: the full climb spans the widget height; each Level's diagonal
# rises one third of it, and level L's row starts at the height L-1 ended.
func node_center(level: int, tour: int) -> Vector2:
	var w := size.x - PAD.x * 2.0
	var h := size.y - PAD.y * 2.0
	var rise_per_level := h / float(LEVELS)
	var x := PAD.x + w * float(tour) / float(TOURS - 1)
	var base_y := size.y - PAD.y - rise_per_level * float(level)
	var y := base_y - rise_per_level * float(tour) / float(TOURS - 1)
	return Vector2(x, y)

func _draw() -> void:
	if _status.is_empty():
		return
	for lvl in range(LEVELS):
		for t in range(TOURS - 1):
			draw_line(node_center(lvl, t), node_center(lvl, t + 1),
				Color(Palette.WHITE_DIM, 0.35), 2.0)
		if lvl < LEVELS - 1:   # promotion link: level top → next level start
			draw_line(node_center(lvl, TOURS - 1), node_center(lvl + 1, 0),
				Color(_accent, 0.5), 2.0)
	for lvl in range(LEVELS):
		for t in range(TOURS):
			_draw_node(lvl, t)

func _draw_node(lvl: int, t: int) -> void:
	var c := node_center(lvl, t)
	var status: int = _status[lvl * TOURS + t]
	var here: bool = (not _current.is_empty()
		and int(_current.get("level", -1)) == lvl and int(_current.get("tour", -1)) == t)
	if here:
		draw_circle(c, R + 3.0, Color(_accent, 0.35))
		draw_circle(c, R, _accent)
	elif t == TOURS - 1 and lvl < _level_won.size() and _level_won[lvl]:
		draw_circle(c, R, Palette.GOLD)          # Premier won: gold
	elif status == CareerState.CellStatus.BEATEN:
		draw_circle(c, R, Palette.GREEN_DARK)
		_draw_check(c)
	elif status == CareerState.CellStatus.UNLOCKED:
		draw_arc(c, R, 0.0, TAU, 24, Palette.WHITE, 2.0)
	else:
		draw_circle(c, R * 0.55, Color(Palette.WHITE_DIM, 0.3))

func _draw_check(c: Vector2) -> void:
	var col := Palette.WHITE
	draw_line(c + Vector2(-4, 0), c + Vector2(-1, 3), col, 2.0)
	draw_line(c + Vector2(-1, 3), c + Vector2(4, -3), col, 2.0)
