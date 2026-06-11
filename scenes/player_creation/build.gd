extends Control

# Player Creation — Screen 2: Build.
# Receives a PlayerCreationDraft from Identity, lets the user spend 20 points
# across 4 attributes, then confirms → persists Player + emits confirmed signal.

# back_pressed carries the draft so the router can re-hydrate Identity with the
# user's picks intact (spec §4: Back preserves picks).
signal back_pressed(draft: PlayerCreationDraft)
signal confirmed(player: Player)

@onready var _recap_portrait: ColorRect = $Layout/RecapRow/RecapPortrait
@onready var _recap_label: Label = $Layout/RecapRow/RecapLabel
@onready var _power_slider: HSlider = $Layout/Sliders/PowerRow/PowerSlider
@onready var _power_readout: Label = $Layout/Sliders/PowerRow/PowerReadout
@onready var _composure_slider: HSlider = $Layout/Sliders/ComposureRow/ComposureSlider
@onready var _composure_readout: Label = $Layout/Sliders/ComposureRow/ComposureReadout
@onready var _attack_slider: HSlider = $Layout/Sliders/AttackRow/AttackSlider
@onready var _attack_readout: Label = $Layout/Sliders/AttackRow/AttackReadout
@onready var _control_slider: HSlider = $Layout/Sliders/ControlRow/ControlSlider
@onready var _control_readout: Label = $Layout/Sliders/ControlRow/ControlReadout
@onready var _points_label: Label = $Layout/PointsCounter
@onready var _classifier_label: Label = $Layout/ClassifierLabel
@onready var _back_btn: Button = $Layout/Footer/BackBtn
@onready var _confirm_btn: Button = $Layout/Footer/ConfirmBtn

var _draft: PlayerCreationDraft

func set_draft(draft: PlayerCreationDraft) -> void:
	_draft = draft
	if is_node_ready():
		_push_draft_to_ui()

func _ready() -> void:
	for s in [_power_slider, _composure_slider, _attack_slider, _control_slider]:
		s.min_value = Attributes.CREATION_MIN
		s.max_value = Attributes.CREATION_MAX
		s.step = 5    # card-rescale DR10: the /100 budget is spent in 5-point blocks
		s.value = 30
		s.value_changed.connect(_on_slider_changed)
	_back_btn.pressed.connect(func(): back_pressed.emit(_draft))
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	if _draft == null:
		_draft = PlayerCreationDraft.new()
	_push_draft_to_ui()

func _on_slider_changed(_v: float) -> void:
	_draft.attributes.power     = _power_slider.value
	_draft.attributes.composure = _composure_slider.value
	_draft.attributes.attack    = _attack_slider.value
	_draft.attributes.control   = _control_slider.value
	_refresh_readouts()

func _push_draft_to_ui() -> void:
	# set_value_no_signal: writing a slider value normally emits value_changed,
	# which fires _on_slider_changed mid-update and reads the OTHER (not-yet-pushed)
	# sliders back into the draft — corrupting it. Pushing silently then refreshing
	# once is correct and re-entrancy-safe (matters when Back returns a non-default draft).
	_power_slider.set_value_no_signal(_draft.attributes.power)
	_composure_slider.set_value_no_signal(_draft.attributes.composure)
	_attack_slider.set_value_no_signal(_draft.attributes.attack)
	_control_slider.set_value_no_signal(_draft.attributes.control)
	_refresh_recap()
	_refresh_readouts()

func _refresh_recap() -> void:
	# Spec §4 Screen 2: small identity recap confirming who was built on Screen 1.
	if _draft.appearance >= 0:
		_recap_portrait.color = AppearancePicker.placeholder_tint(_draft.appearance)
	else:
		_recap_portrait.color = Color(0.2, 0.2, 0.2)
	var name_text := _draft.name.display_caps() if _draft.name != null else "—"
	var country_key := Country.to_key(_draft.country) if _draft.country >= 0 else ""
	_recap_label.text = "%s · %s · %s" % [name_text, _draft.city, country_key]

func _refresh_readouts() -> void:
	_power_readout.text     = str(int(round(_draft.attributes.power)))
	_composure_readout.text = str(int(round(_draft.attributes.composure)))
	_attack_readout.text    = str(int(round(_draft.attributes.attack)))
	_control_readout.text   = str(int(round(_draft.attributes.control)))

	var remaining := Attributes.CREATION_TOTAL - _draft.attributes.sum()
	_points_label.text = "POINTS REMAINING: %d / %d" % [int(round(remaining)), int(round(Attributes.CREATION_TOTAL))]
	_points_label.modulate = Color.WHITE if is_zero_approx(remaining) else Color(1, 0.3, 0.3)

	var label := Classifier.classify(_draft.attributes)
	_classifier_label.text = "YOUR PLAYER IS A: %s" % ClassifierLabel.display_name(label)

	_confirm_btn.disabled = not _draft.attributes.is_valid_creation_distribution()

func _on_confirm_pressed() -> void:
	if not _draft.attributes.is_valid_creation_distribution():
		return
	var player := Player.from_draft(_draft)
	SaveManager.save_player(player)
	confirmed.emit(player)
