extends SceneTree

# Dev preview for the Offers screen (spec 2026-07-02): renders the season-end
# offer pick with a real drawn offer set. Run WITH rendering (not --headless):
#   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/preview_offers.gd
# Output: docs/mockups/offers-v1.png

var _frames := 0

func _initialize() -> void:
	var career := CareerResolver.start_career(0)
	# Beat every Club climb tour -> the drawn set holds a guaranteed cross-up row.
	for t in range(CareerState.READINESS_TOUR):
		career.mark_beaten(0, t)
	var sr := SeasonResult.new()
	sr.beat = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260702 + 7
	var begin := CareerResolver.begin_live_advance(
		career, sr, 0, CareerState.READINESS_TOUR, rng)
	root.size = Vector2i(390, 844)
	var screen = load("res://scenes/offers/offers.tscn").instantiate()
	root.add_child(screen)
	screen.set_offers(career, begin["offers"])
	print("OFFERS: ", begin["offers"].size())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 8:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://docs/mockups/offers-v1.png"))
		print("SAVED docs/mockups/offers-v1.png")
		return true
	return false
