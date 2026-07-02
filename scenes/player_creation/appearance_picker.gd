class_name AppearancePicker
extends HBoxContainer

# Emits the selected bucket when the user taps a thumbnail.
signal appearance_selected(bucket: int)

var _selected: int = -1
var _buttons: Dictionary = {}  # bucket -> Button

# Hi-fi restyle knobs (set by apply_hifi from the Identity screen). Default to the
# original look (square tiles, brand-gold ring) so the low-fi/test paths are unchanged.
var _ring_color: Color = Color(0.66, 0.43, 0.0)  # brand gold
var _corner_radius: int = 0

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	for bucket in Appearance.all():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 80)
		btn.toggle_mode = true
		# Placeholder appearance — a flat skin-tone tile drawn via StyleBoxFlat so the
		# colour is actually visible (a flat Button + modulate draws nothing). Theme 6
		# commissions real portrait art. The selected tile gets a gold ring; disabled dims.
		var tint := placeholder_tint(bucket)
		btn.add_theme_stylebox_override("normal", _make_tile_style(tint, false, false))
		btn.add_theme_stylebox_override("hover", _make_tile_style(tint, false, false))
		btn.add_theme_stylebox_override("pressed", _make_tile_style(tint, true, false))
		btn.add_theme_stylebox_override("focus", _make_tile_style(tint, true, false))
		btn.add_theme_stylebox_override("disabled", _make_tile_style(tint, false, true))
		# Real face thumbnail (portrait pipeline, DP6) -- the tint stylebox stays
		# underneath as the selection-ring frame around the opaque face tile.
		btn.icon = PortraitLibrary.texture_for(bucket, 0)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.pressed.connect(_on_pressed.bind(bucket))
		add_child(btn)
		_buttons[bucket] = btn

# Builds a flat colour tile for one thumbnail. `selected` adds a gold ring (used by
# the "pressed"/"focus" states since these are toggle buttons); `dim` darkens it for
# the disabled state so the picker reads as inactive before a Country is chosen.
func _make_tile_style(tint: Color, selected: bool, dim: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = (tint.darkened(0.55) if dim else tint)
	sb.set_corner_radius_all(_corner_radius)
	# content margin keeps the ring visible around the opaque face thumbnail
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if selected:
		sb.set_border_width_all(4)
		sb.border_color = _ring_color
	return sb

# Hi-fi restyle (Identity screen): rounded tiles + a country-accent selection ring.
# Visuals only — selection/enable behaviour is untouched. Safe to call before or
# after _ready (re-applies the styleboxes on whatever buttons exist).
func apply_hifi(accent: Color) -> void:
	_ring_color = accent
	_corner_radius = 9
	for bucket in _buttons.keys():
		var btn := _buttons[bucket] as Button
		var tint := placeholder_tint(bucket)
		btn.add_theme_stylebox_override("normal", _make_tile_style(tint, false, false))
		btn.add_theme_stylebox_override("hover", _make_tile_style(tint, false, false))
		btn.add_theme_stylebox_override("pressed", _make_tile_style(tint, true, false))
		btn.add_theme_stylebox_override("focus", _make_tile_style(tint, true, false))
		btn.add_theme_stylebox_override("disabled", _make_tile_style(tint, false, true))

func selected_bucket() -> int:
	return _selected

# Scene tests + previews reach a tile by bucket.
func button_for(bucket: int) -> Button:
	return _buttons.get(bucket)

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
