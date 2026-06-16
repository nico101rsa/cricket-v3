extends SceneTree

# One-shot: seed a demo Player + Career save so launching scenes/main.tscn routes
# straight into the live Season Hub (skips player creation). Run headless:
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/seed_demo_save.gd
# Your local game data only (single-player); start a new player anytime in-game.

func _initialize() -> void:
	var p := Player.new()
	var n := NamePair.new(); n.first_name = "Bongani"; n.surname = "Kgosi"
	p.name = n
	p.country = Country.Code.SA
	p.city = "Durban"
	p.tons_balance = 120
	p.affinity = 3
	var a := Attributes.new()
	a.power = 42.0; a.composure = 34.0; a.attack = 30.0; a.control = 24.0
	p.attributes = a
	var sa := Attributes.new()
	sa.power = 42.0; sa.composure = 34.0; sa.attack = 30.0; sa.control = 24.0
	p.starting_attributes = sa
	# SaveManager is an autoload — not initialised in a -s script — so write the
	# same user:// .tres files it would (ResourceSaver, identical paths).
	ResourceSaver.save(p, "user://player.tres")

	var career := CareerResolver.start_career(0)
	ResourceSaver.save(career, "user://career.tres")
	print("SEEDED demo player + career")
	quit()
