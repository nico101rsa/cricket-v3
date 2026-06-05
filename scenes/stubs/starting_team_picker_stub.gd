extends Control

# Placeholder. Real Starting Team picker lives in around-the-match-v1.html mockup
# and is part of Theme 5's broader Season hub work — not in scope here.

signal proceed_to_season()

func _ready() -> void:
	$Layout/ContinueBtn.pressed.connect(func(): proceed_to_season.emit())
