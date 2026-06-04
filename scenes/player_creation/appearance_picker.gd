class_name AppearancePicker
extends HBoxContainer

# Emits the selected bucket when the user taps a thumbnail.
signal appearance_selected(bucket: int)

var _selected: int = -1
var _buttons: Dictionary = {}  # bucket -> Button

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	for bucket in Appearance.all():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 80)
		btn.toggle_mode = true
		btn.flat = true
		# Placeholder appearance — a skin-tone gradient. Theme 6 commissions real portrait art.
		btn.modulate = placeholder_tint(bucket)
		btn.pressed.connect(_on_pressed.bind(bucket))
		add_child(btn)
		_buttons[bucket] = btn

func selected_bucket() -> int:
	return _selected

# Programmatically reflect a selection WITHOUT emitting appearance_selected.
# Used when re-hydrating the screen from an existing draft (Back navigation) —
# we want the visual ring restored but must NOT trigger a name re-roll.
func set_selected_silent(bucket: int) -> void:
	_selected = bucket
	for b in _buttons.keys():
		(_buttons[b] as Button).button_pressed = (b == bucket)

# Enable/disable the whole picker (spec §4: Appearance is disabled until Country is picked).
func set_enabled(enabled: bool) -> void:
	for b in _buttons.keys():
		(_buttons[b] as Button).disabled = not enabled

func _on_pressed(bucket: int) -> void:
	_selected = bucket
	for b in _buttons.keys():
		(_buttons[b] as Button).button_pressed = (b == bucket)
	appearance_selected.emit(bucket)

# Static so callers (the portrait preview on Identity, the recap on Build) can
# get the same placeholder tint without holding a picker instance.
# Placeholder until Theme 6 art lands.
static func placeholder_tint(bucket: int) -> Color:
	match bucket:
		Appearance.Bucket.WHITE:  return Color(0.95, 0.86, 0.76)
		Appearance.Bucket.MIXED:  return Color(0.78, 0.62, 0.48)
		Appearance.Bucket.INDIAN: return Color(0.62, 0.45, 0.33)
		Appearance.Bucket.BLACK:  return Color(0.36, 0.24, 0.18)
		_: return Color.WHITE
