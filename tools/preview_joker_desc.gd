extends SceneTree

# Dev preview for T7: the hub joker bench with a tile TAPPED, showing the
# plain-English description line under the bench. Run WITH rendering:
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_joker_desc.gd
# Output: docs/mockups/hub-joker-desc-v1.png

var _hub
var _frames := 0
var _injected := false

func _initialize() -> void:
	root.size = Vector2i(390, 844)
	_hub = load("res://scenes/season_hub/season_hub.tscn").instantiate()
	root.add_child(_hub)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2 and not _injected:
		var p := Player.new()
		var n := NamePair.new()
		n.first_name = "Bongani"; n.surname = "Kgosi"
		p.name = n
		p.city = "Durban"
		p.country = Country.Code.SA
		p.tons_balance = 180
		var a := Attributes.new()
		a.power = 42.0; a.composure = 33.0; a.attack = 18.0; a.control = 12.0
		p.attributes = a
		var career := CareerResolver.start_career(0)
		var sr := SeasonResult.new()
		var lr := LeagueResult.new()
		lr.standings = []; lr.player_matches = []
		sr.league = lr
		var v := SeasonViewBuilder.build(p, career, sr, 0)
		v.jokers = [
			{"id": "powerplay_punch", "name": "Powerplay Punch", "rarity": "Common"},
			{"id": "carry_your_bat", "name": "Carry Your Bat", "rarity": "Rare"},
		]
		_hub.set_view(v)
		_injected = true
	if _frames == 4:
		# Tap the first joker tile -> the description line appears.
		var box: HBoxContainer = _hub.get_node("Margin/Root/JokersPanel/JokersWrap/JokersBox")
		(box.get_child(0) as Button).pressed.emit()
	if _frames >= 8:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://docs/mockups/hub-joker-desc-v1.png")
		print("PREVIEW_SAVED")
		return true
	return false
