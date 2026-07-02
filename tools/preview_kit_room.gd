extends SceneTree

# Dev preview for the live Kit Room (spec 2026-07-02, Rung 2). Renders the three
# modes for eyeballing the in-house skin:
#   1. starter   — V0 season start, pick 1 of 3 free Commons
#   2. visit     — V1 after match 3 (shelf + bench + training), ₸ to spend
#   3. carryover — season end, elect the joker that survives
# Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_kit_room.gd
# Output: docs/mockups/kit-room-{starter,visit,carryover}-v1.png

const KitRoomScene = preload("res://scenes/kit_room/kit_room.tscn")

var _frames := 0
var _stage := 0
var _screen
var _states: Array = []

func _initialize() -> void:
	root.size = Vector2i(390, 844)
	# One rich player + one live driver per mode (mirrors the scene tests).
	_states = [
		{"name": "starter", "mode": "starter"},
		{"name": "visit", "mode": "visit"},
		{"name": "carryover", "mode": "carryover"},
	]
	_mount(0)

func _make_play(mode: String) -> SeasonPlay:
	var p := Player.new()
	var a := Attributes.new()
	a.power = 55.0; a.composure = 45.0; a.attack = 35.0; a.control = 30.0
	p.attributes = a
	p.tons_balance = 420
	var career := CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(0, 0)
	var sp := SeasonPlay.start(p.attributes, career.teams[0], career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), 20260702, spec)
	sp.enable_shop(p, EconomyTuning.new(), 0, 0)
	match mode:
		"visit":
			sp.apply_shop_action({"kind": "pick", "id": sp.pending_shop_visit()["offer"][0]})
			for i in range(3):
				sp.commit_player_result(sp.make_session().result())
		"carryover":
			sp.apply_shop_action({"kind": "pick", "id": sp.pending_shop_visit()["offer"][0]})
	return sp

func _mount(i: int) -> void:
	var st: Dictionary = _states[i]
	_screen = KitRoomScene.instantiate()
	root.add_child(_screen)
	var sp := _make_play(st["mode"])
	if st["mode"] == "carryover":
		_screen.set_carryover(sp)
	else:
		_screen.set_visit(sp, sp.pending_shop_visit())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 6:
		var st: Dictionary = _states[_stage]
		var path := "res://docs/mockups/kit-room-%s-v1.png" % st["name"]
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(path)
		print("SAVED ", path)
		_screen.queue_free()
		_stage += 1
		_frames = 0
		if _stage >= _states.size():
			print("PREVIEW_SAVED")
			return true
		call_deferred("_mount", _stage)
	return false
