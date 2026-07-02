extends SceneTree

# Dev preview for the Career Grid screen (nav-shell spec 2026-07-03, Slice 3):
# renders the between-seasons home at a SHOWCASE mid-career state (Club fully
# won incl. Premier, two City tours beaten — so beaten / won / here / locked
# node states all render; NOT a real save). Run WITH rendering:
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_career_grid.gd
# Output: docs/mockups/career-grid-v1.png

var _frames := 0

func _initialize() -> void:
	var career := CareerResolver.start_career(0)
	for t in range(CareerState.TOURS):
		career.mark_beaten(0, t)          # Club swept (unlocks City per canon)
	career.level_won[0] = true            # Club Premier won -> gold node
	career.mark_beaten(1, 0)
	career.mark_beaten(1, 1)              # two City tours beaten; here = City T2
	career.seasons_played = 11
	career.current_team_index = 9         # a City-level team
	var player := Player.new()
	player.tons_balance = 1520
	player.country = Country.Code.SA
	root.size = Vector2i(390, 844)
	var screen = load("res://scenes/career_grid/career_grid.tscn").instantiate()
	root.add_child(screen)
	screen.set_career(career, player)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 8:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://docs/mockups/career-grid-v1.png"))
		print("SAVED docs/mockups/career-grid-v1.png")
		return true
	return false
