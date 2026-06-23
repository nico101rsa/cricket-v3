extends SceneTree

# Dev preview for the in-match run-rate chart. Renders four states to PNGs.
# Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_run_rate_chart.gd

var _chart
var _frames := 0
var _shot := 0
var _cases: Array = []

const CHART_RECT := Rect2i(12, 12, 366, 180)   # real in-match panel proportion

func _initialize() -> void:
	_chart = RunRateChart.new()
	_chart.position = CHART_RECT.position
	_chart.size = CHART_RECT.size
	root.add_child(_chart)
	_cases = [
		["res://docs/mockups/in-match-chart-1st-innings-v1.png", _first_innings()],
		["res://docs/mockups/in-match-chart-chase-v1.png", _chase()],
		["res://docs/mockups/in-match-chart-boundary-over-v1.png", _boundary()],
		["res://docs/mockups/in-match-chart-wicket-over-v1.png", _wicket()],
	]

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_chart.set_data(_cases[_shot][1])
	if _frames >= 8:
		var img := root.get_viewport().get_texture().get_image().get_region(CHART_RECT)
		img.save_png(_cases[_shot][0])
		print("SAVED ", _cases[_shot][0])
		_shot += 1
		_frames = 0
		if _shot >= _cases.size():
			print("PREVIEW_SAVED")
			return true
	return false

func _ov(over: int, runs: int, crr: float, bar_rr: float, b := false, w := false, now := false) -> Dictionary:
	return {"over": over, "runs": runs, "crr": crr, "bar_rr": bar_rr,
		"has_boundary": b, "has_wicket": w, "now": now}

func _first_innings() -> Dictionary:
	return {"overs": [_ov(1, 8, 8.0, 8.0, true), _ov(2, 5, 6.5, 5.0), _ov(3, 9, 7.3, 9.0, true),
		_ov(4, 6, 7.0, 6.0, false, false, true)], "target_rr": 8.0, "y_max": 12.0, "innings": 1}

func _chase() -> Dictionary:
	return {"overs": [_ov(1, 10, 10.0, 10.0, true), _ov(2, 4, 7.0, 4.0), _ov(3, 12, 8.7, 12.0, true),
		_ov(4, 5, 7.75, 5.0), _ov(5, 8, 7.8, 8.0, true, false, true)],
		"target_rr": 8.6, "y_max": 13.0, "innings": 2}

func _boundary() -> Dictionary:
	return {"overs": [_ov(1, 6, 6.0, 6.0), _ov(2, 18, 12.0, 18.0, true, false, true)],
		"target_rr": 8.0, "y_max": 18.0, "innings": 1}

func _wicket() -> Dictionary:
	return {"overs": [_ov(1, 7, 7.0, 7.0), _ov(2, 1, 4.0, 1.0, false, true, true)],
		"target_rr": 8.0, "y_max": 12.0, "innings": 1}
