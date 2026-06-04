extends Control

# Player Creation — Screen 1: Identity.
# Owns the in-progress PlayerCreationDraft, hands it to Build on Next.

signal advance_to_build(draft: PlayerCreationDraft)

@onready var _country_sa_btn: Button = $Layout/CountryRow/SaBtn
@onready var _country_aus_btn: Button = $Layout/CountryRow/AusBtn
@onready var _city_dropdown: OptionButton = $Layout/CityRow/CityDropdown
@onready var _portrait_preview: ColorRect = $Layout/PortraitPreview
@onready var _appearance_picker: AppearancePicker = $Layout/AppearancePicker
@onready var _name_label: Label = $Layout/NameRow/NameLabel
@onready var _reroll_btn: Button = $Layout/NameRow/RerollBtn
@onready var _next_btn: Button = $Layout/NextBtn

var _draft: PlayerCreationDraft
var _rng: RandomNumberGenerator

# Called by the router when navigating BACK from Build, so the screen re-hydrates
# from the in-progress draft instead of starting blank (spec §4: Back preserves picks).
# Must be called before the node enters the tree, or it refreshes immediately if already ready.
func set_draft(draft: PlayerCreationDraft) -> void:
	_draft = draft
	if is_node_ready():
		_refresh_all()

func _ready() -> void:
	if _draft == null:
		_draft = PlayerCreationDraft.new()  # fresh cold-start; set_draft() not used
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_wire_signals()
	_refresh_all()  # doubles as hydration — paints whatever the draft currently holds

func _wire_signals() -> void:
	_country_sa_btn.pressed.connect(_on_country_pressed.bind(Country.Code.SA))
	_country_aus_btn.pressed.connect(_on_country_pressed.bind(Country.Code.AUS))
	_city_dropdown.item_selected.connect(_on_city_selected)
	_appearance_picker.appearance_selected.connect(_on_appearance_selected)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	_next_btn.pressed.connect(_on_next_pressed)

func _on_country_pressed(c: int) -> void:
	if _draft.country == c:
		return
	_draft.country = c
	_draft.city = ""                          # spec §4 Screen 1: City resets on Country change
	_reroll_name_if_possible()                # name bank slice changed
	_refresh_country_buttons()
	_refresh_city_dropdown()
	_refresh_appearance_picker()              # picker enables now that a Country exists
	_refresh_portrait_preview()
	_refresh_next_enabled()

func _on_city_selected(idx: int) -> void:
	if idx <= 0:
		_draft.city = ""
	else:
		_draft.city = _city_dropdown.get_item_text(idx)
	_refresh_next_enabled()

func _on_appearance_selected(bucket: int) -> void:
	_draft.appearance = bucket
	_reroll_name_if_possible()                # name bank slice changed
	_refresh_portrait_preview()
	_refresh_next_enabled()

func _on_reroll_pressed() -> void:
	_reroll_name_if_possible()

func _on_next_pressed() -> void:
	if _draft.identity_complete():
		advance_to_build.emit(_draft)

# --- Helpers ---

func _reroll_name_if_possible() -> void:
	if _draft.country < 0 or _draft.appearance < 0:
		_draft.name = null
	else:
		_draft.name = NameGenerator.generate(_draft.country, _draft.appearance, _rng)
	_refresh_name_label()

func _refresh_all() -> void:
	_refresh_country_buttons()
	_refresh_city_dropdown()
	_refresh_appearance_picker()
	_refresh_portrait_preview()
	_refresh_name_label()
	_refresh_next_enabled()

func _refresh_country_buttons() -> void:
	_country_sa_btn.button_pressed = (_draft.country == Country.Code.SA)
	_country_aus_btn.button_pressed = (_draft.country == Country.Code.AUS)

func _refresh_city_dropdown() -> void:
	_city_dropdown.clear()
	_city_dropdown.add_item("— Select a city —", 0)
	_city_dropdown.set_item_disabled(0, true)
	_city_dropdown.disabled = (_draft.country < 0)
	if _draft.country >= 0:
		var city_list := Cities.for_country(_draft.country)
		for c in city_list:
			_city_dropdown.add_item(c)
		# Honour a city already on the draft (hydration on Back); else show placeholder.
		# Cities sit at dropdown index 1..N because the placeholder occupies index 0.
		var idx := city_list.find(_draft.city)
		_city_dropdown.select(idx + 1 if idx >= 0 else 0)

func _refresh_appearance_picker() -> void:
	# Spec §4: Appearance is disabled until a Country is picked.
	_appearance_picker.set_enabled(_draft.country >= 0)
	# Restore the selection ring on hydration without re-rolling the name.
	if _draft.appearance >= 0:
		_appearance_picker.set_selected_silent(_draft.appearance)

func _refresh_portrait_preview() -> void:
	# Placeholder — same tint logic as the picker. Replaced by Theme 6 art.
	if _draft.appearance < 0:
		_portrait_preview.color = Color(0.2, 0.2, 0.2)
	else:
		_portrait_preview.color = AppearancePicker.placeholder_tint(_draft.appearance)

func _refresh_name_label() -> void:
	if _draft.name == null:
		_name_label.text = "—"
		_reroll_btn.disabled = true
	else:
		_name_label.text = _draft.name.display_caps()
		_reroll_btn.disabled = false

func _refresh_next_enabled() -> void:
	_next_btn.disabled = not _draft.identity_complete()
