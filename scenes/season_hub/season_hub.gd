extends Control

# The Season Hub — renders a SeasonView (spec 2026-06-15-season-hub-replay §5).
# A faithful, scrubbable replay of one real season. The scene never calls
# resolvers directly: it renders a SeasonView and rebuilds it on scrub. Boot
# (simulate a real season) is an explicit boot() the router calls — NOT auto-run
# in _ready — so tests can inject a view/source without triggering a sim or
# touching the save file.

const RARITY_COLOR := {
	"Common": Color("e8e8e8"),
	"Rare": Color("4f8cff"),
	"Legendary": Color("ffc23c"),
}
# Country accent (ADR 0001): SA green, AUS amber. Keyed by Country.Code.
const COUNTRY_ACCENT := {
	Country.Code.SA: Color("1f7a4d"),
	Country.Code.AUS: Color("e3a008"),
}
const BOOT_SEED := 20260615

@onready var _root: VBoxContainer = $Scroll/Margin/Root

var _view: SeasonView
var _player: Player
var _career: CareerState
var _season: SeasonResult

func _ready() -> void:
	_root.get_node("ScrubBar/PrevBtn").pressed.connect(func(): step(-1))
	_root.get_node("ScrubBar/NextBtn").pressed.connect(func(): step(1))

# --- Production boot: simulate the saved Player's current cell once. ---

func boot() -> void:
	if _view != null:
		return   # a test (or caller) already injected a view/source
	if not SaveManager.has_player():
		return
	var player := SaveManager.load_player()
	var career: CareerState = SaveManager.load_career() if SaveManager.has_career() \
		else CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(career.current_level(), 0)
	var team: Team = career.teams[career.current_team_index]
	var rng := RandomNumberGenerator.new()
	rng.seed = BOOT_SEED
	var season := SeasonResolver.simulate_season(
		player.attributes, team, career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), rng)
	set_source(player, career, season)

# --- Source + scrub ---

func set_source(player: Player, career: CareerState, season: SeasonResult) -> void:
	_player = player
	_career = career
	_season = season
	_rebuild(0)

func _rebuild(index: int) -> void:
	if _player == null or _career == null or _season == null:
		return
	set_view(SeasonViewBuilder.build(_player, _career, _season, index))

func scrub_index() -> int:
	return _view.scrub_index if _view != null else 0

func step(delta: int) -> void:
	if _view == null:
		return
	_rebuild(clampi(_view.scrub_index + delta, 0, _view.match_count))

# --- Render ---

func set_view(view: SeasonView) -> void:
	_view = view
	_render()

func _render() -> void:
	if _view == null:
		return
	var accent: Color = COUNTRY_ACCENT.get(_view.country, Color("1f7a4d"))
	# Team name only; the accent colour signals the country (keeps the ₸ chip from
	# being pushed off the right edge on long team names).
	_root.get_node("Header/TitleLabel").text = _view.team_name
	_root.get_node("Header/TitleLabel").add_theme_color_override("font_color", accent)
	_root.get_node("Header/TonsChip").text = "₸ %d" % _view.tons_balance
	_root.get_node("ContextLabel").text = "%s · %s · %s" % [
		_level_word(_view.level), _view.tour_name, _view.difficulty_label]
	_render_fixtures(accent)
	_render_card()
	_render_jokers()
	_root.get_node("AffinityLabel").text = "Affinity %d" % _view.affinity
	_render_standings()
	_render_scrub()

func _render_fixtures(accent: Color) -> void:
	var box: VBoxContainer = _root.get_node("FixturesBox")
	for c in box.get_children():
		c.queue_free()
	for i in range(_view.fixtures.size()):
		var f: Dictionary = _view.fixtures[i]
		var row := Button.new()   # tappable: jump the scrub head to this fixture
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # never clip on a narrow phone
		row.size_flags_horizontal = Control.SIZE_FILL
		var idx := i
		row.pressed.connect(func(): _rebuild(idx))
		if f["played"]:
			var tag := "WON " if f["player_won"] else "LOST "
			row.text = "%d. v %s — %s%s" % [i + 1, f["opponent_name"], tag, f["score_text"]]
			row.add_theme_color_override("font_color",
				accent if f["player_won"] else Color("a05050"))
		else:
			row.text = "%d. v %s — to play" % [i + 1, f["opponent_name"]]
			row.add_theme_color_override("font_color", Color("808080"))
		if i == _view.scrub_index:
			row.text = "▶ " + row.text   # the scrub head
		box.add_child(row)

func _render_card() -> void:
	_root.get_node("PlayerCard/NameLabel").text = "%s · %s" % [_view.player_name, _view.city]
	_root.get_node("PlayerCard/AttrLabel").text = "PWR %d  COM %d  ATT %d  CON %d" % [
		int(_view.power), int(_view.composure), int(_view.attack), int(_view.control)]
	if _view.card_matches == 0:
		_root.get_node("PlayerCard/CareerLabel").text = "no matches yet — OVR %d" % _view.ovr
	else:
		var avg_txt := "%.1f%s" % [_view.card_batting_avg, ("*" if _view.card_dismissals == 0 else "")]
		_root.get_node("PlayerCard/CareerLabel").text = \
			"%d inns · %s avg · SR %.1f · %d wkts · best %s · OVR %d" % [
				_view.card_matches, avg_txt, _view.card_strike_rate,
				_view.card_wickets, _view.card_best_bowling, _view.ovr]

func _render_jokers() -> void:
	var box: HBoxContainer = _root.get_node("JokersBox")
	for c in box.get_children():
		c.queue_free()
	if _view.jokers.is_empty():
		var empty := Label.new()
		empty.text = "(no jokers)"
		empty.add_theme_color_override("font_color", Color("808080"))
		box.add_child(empty)
		return
	for j in _view.jokers:
		var chip := Label.new()
		chip.text = " %s " % j["name"]
		chip.add_theme_color_override("font_color", RARITY_COLOR.get(j["rarity"], Color.WHITE))
		box.add_child(chip)

func _render_standings() -> void:
	var box: VBoxContainer = _root.get_node("StandingsBox")
	for c in box.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "FINAL TABLE"
	box.add_child(head)
	for i in range(_view.standings.size()):
		var s: Dictionary = _view.standings[i]
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = "%d. %s  %dpts  NRR %+.2f" % [i + 1, s["team_name"], s["points"], s["nrr"]]
		if s["is_player"]:
			row.add_theme_color_override("font_color", Color("ffc23c"))
		box.add_child(row)

func _render_scrub() -> void:
	_root.get_node("ScrubBar/ScrubLabel").text = "Match %d / %d" % [_view.scrub_index, _view.match_count]

func _country_word(code: int) -> String:
	return "Australia" if code == Country.Code.AUS else "South Africa"

func _level_word(level: int) -> String:
	return ["Club", "City", "Province"][clampi(level, 0, 2)]
