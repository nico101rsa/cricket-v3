class_name RunRateChart
extends Control

# The hi-fi in-match run-rate chart (design: docs/mockups/in-match-hi-fi-v1.html
# .chart). Pure renderer: set_data(chart) where `chart` is MatchViewBuilder's
# read-model. Paints back-to-front in _draw(): stadium backdrop → per-over bars →
# CRR worm → target/par line → axis + legend. Gently pulses the current over.

const SKY_TOP := Color("1a2740")
const SKY_BOT := Color("24492f")     # horizon → grass
const GRASS := Color("16321f")
const MOON := Color(1, 1, 1, 0.85)
const PAD := 12.0                    # plot inset
const TOP_PAD := 22.0                # headroom above the tallest bar
const BOT_PAD := 18.0                # axis strip

var _chart: Dictionary = {}
var _accent: Color = Palette.GOLD
var _pulse := 0.0

func set_data(chart: Dictionary, accent: Color = Palette.GOLD) -> void:
	_chart = chart
	_accent = accent
	queue_redraw()

func _process(delta: float) -> void:
	# Only animate while a current over is on screen.
	if _chart.get("overs", []).is_empty():
		return
	_pulse += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	_draw_backdrop(w, h)
	var plot := Rect2(PAD, TOP_PAD, w - PAD * 2.0, h - TOP_PAD - BOT_PAD)
	var y_max: float = _chart.get("y_max", 12.0)
	if y_max <= 0.0:
		y_max = 12.0
	_draw_target(plot, y_max)
	var overs: Array = _chart.get("overs", [])
	if not overs.is_empty():
		_draw_bars(plot, overs, y_max)
		_draw_worm(plot, overs, y_max)
	_draw_axis_legend(plot)

func _y(plot: Rect2, rr: float, y_max: float) -> float:
	return plot.position.y + plot.size.y * (1.0 - clampf(rr / y_max, 0.0, 1.0))

# x-centre of over slot `over` (1..20) across the plot width.
func _x(plot: Rect2, over: int) -> float:
	var slots := 20.0
	var slot_w := plot.size.x / slots
	return plot.position.x + (over - 0.5) * slot_w

func _draw_backdrop(w: float, h: float) -> void:
	var horizon := h * 0.62
	# Smooth sky gradient (SKY_TOP → SKY_BOT) as thin strips — avoids visible banding.
	var strips := 24
	for i in range(strips):
		var t := float(i) / float(strips - 1)
		var y0 := horizon * (float(i) / strips)
		var y1 := horizon * (float(i + 1) / strips)
		draw_rect(Rect2(0, y0, w, y1 - y0 + 1.0), SKY_TOP.lerp(SKY_BOT, t))
	# Grass (slight darkening toward the foot).
	for i in range(8):
		var t := float(i) / 7.0
		var y0 := horizon + (h - horizon) * (float(i) / 8.0)
		var y1 := horizon + (h - horizon) * (float(i + 1) / 8.0)
		draw_rect(Rect2(0, y0, w, y1 - y0 + 1.0), GRASS.lerp(GRASS.darkened(0.4), t))
	# moon, upper-right
	draw_circle(Vector2(w * 0.72, h * 0.20), 8.0, MOON)
	draw_circle(Vector2(w * 0.72, h * 0.20), 13.0, Color(1, 1, 1, 0.08))
	# two floodlight poles + lamp glow
	for fx in [w * 0.10, w * 0.90]:
		draw_line(Vector2(fx, horizon), Vector2(fx, h * 0.10), Color(1, 1, 1, 0.14), 1.5)
		draw_rect(Rect2(fx - 5, h * 0.06, 10, 4), Color(1, 1, 1, 0.30))
		draw_circle(Vector2(fx, h * 0.08), 9.0, Color(1, 1, 0.85, 0.07))
	# Stand/crowd: a slim dark band hugging the horizon (reads as the far stand, not
	# a gridline) with a few subtle lighter speckles for texture.
	draw_rect(Rect2(0, horizon - 5.0, w, 5.0), Color(0, 0, 0, 0.30))
	var x := 5.0
	while x < w - 4.0:
		draw_rect(Rect2(x, horizon - 4.0, 1.0, 2.0), Color(1, 1, 1, 0.05))
		x += 7.0

func _draw_bars(plot: Rect2, overs: Array, y_max: float) -> void:
	var slot_w := plot.size.x / 20.0
	var bw := slot_w * 0.6
	for o in overs:
		var cx := _x(plot, o["over"])
		var top := _y(plot, o["bar_rr"], y_max)
		var rect := Rect2(cx - bw * 0.5, top, bw, plot.position.y + plot.size.y - top)
		var col := Palette.BLUE
		if o["has_wicket"]:
			col = Palette.RED
		elif o["has_boundary"]:
			col = Palette.GOLD
		if o["now"]:
			col = col.lerp(Color.WHITE, 0.35 + 0.25 * sin(_pulse * 4.0))
		draw_rect(rect, col)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color(1, 1, 1, 0.25))  # top sheen

func _draw_worm(plot: Rect2, overs: Array, y_max: float) -> void:
	var pts: PackedVector2Array = []
	for o in overs:
		pts.append(Vector2(_x(plot, o["over"]), _y(plot, o["crr"], y_max)))
	if pts.size() >= 2:
		draw_polyline(pts, Color.WHITE, 2.0, true)
	for i in range(pts.size()):
		var is_last := i == pts.size() - 1
		if is_last:
			draw_circle(pts[i], 5.0 + sin(_pulse * 4.0), Color(_accent.r, _accent.g, _accent.b, 0.4))
			draw_circle(pts[i], 4.0, _accent)
		else:
			draw_circle(pts[i], 2.5, Color.WHITE)

func _draw_target(plot: Rect2, y_max: float) -> void:
	var ty := _y(plot, _chart.get("target_rr", 8.0), y_max)
	draw_dashed_line(Vector2(plot.position.x, ty), Vector2(plot.position.x + plot.size.x, ty),
		Color(Palette.RED.r, Palette.RED.g, Palette.RED.b, 0.6), 1.2, 4.0)
	var font := ThemeDB.fallback_font
	var label := ("par %.1f" if _chart.get("innings", 1) == 1 else "target %.1f") % _chart.get("target_rr", 8.0)
	draw_string(font, Vector2(plot.position.x + plot.size.x - 56, ty - 3), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.RED)

func _draw_axis_legend(plot: Rect2) -> void:
	var font := ThemeDB.fallback_font
	for ov in [1, 5, 10, 15, 20]:
		draw_string(font, Vector2(_x(plot, ov) - 4, plot.position.y + plot.size.y + 12),
			str(ov), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.WHITE_DIM)
	# legend bottom-left
	var ly := plot.position.y + plot.size.y + 12
	draw_line(Vector2(plot.position.x, ly - 3), Vector2(plot.position.x + 10, ly - 3), Color.WHITE, 2.0)
	draw_string(font, Vector2(plot.position.x + 13, ly), "CRR", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.WHITE_MID)
