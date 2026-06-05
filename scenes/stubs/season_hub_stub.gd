extends Control

# Placeholder. The real Season hub is the Theme 5 hi-fi spec
# (docs/mockups/around-the-match-v1.html §1). This stub exists so the
# Manual-retire button has a home + so the dev win-out cheat has a trigger.

func _ready() -> void:
	$Layout/RetireBtn.pressed.connect(_on_retire_pressed)
	$Layout/DevWinBtn.pressed.connect(_on_dev_win_pressed)
	_refresh_player_display()

func _refresh_player_display() -> void:
	var p := SaveManager.load_player()
	if p == null:
		$Layout/PlayerLabel.text = "(no player)"
	else:
		$Layout/PlayerLabel.text = "%s · %s · %s" % [
			p.name.display_caps(),
			p.city,
			Country.to_key(p.country),
		]

func _on_retire_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "End this Player's career? They will be archived to the Hall of Fame."
	dialog.title = "Retire Player"
	dialog.confirmed.connect(func(): LifecycleManager.manual_retire())
	add_child(dialog)
	dialog.popup_centered()

func _on_dev_win_pressed() -> void:
	# Dev-only — wired here until the real Match scene exists to trigger it.
	LifecycleManager.win_out()
