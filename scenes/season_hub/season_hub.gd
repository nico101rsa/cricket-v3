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

# Tapping a PLAYED fixture row opens that match's ball-by-ball replay. main.gd
# wires this to _push_match. Unplayed rows keep scrubbing the season head.
signal open_match(match_index: int)

# Emitted when the player taps PLAY on their next fixture (live forward-play path).
# main.gd pushes the Interactive Match scene; on return it commits the result.
signal play_next(team_index: int)

@onready var _root: VBoxContainer = $Scroll/Margin/Root

var _view: SeasonView
var _player: Player
var _career: CareerState
var _season: SeasonResult
var _play: SeasonPlay   # live forward-play driver (null on the scrub-replay/test path)

func _ready() -> void:
	_root.get_node("ScrubBar/PrevBtn").pressed.connect(func(): step(-1))
	_root.get_node("ScrubBar/NextBtn").pressed.connect(func(): step(1))

# --- Production boot: simulate the saved Player's current cell once. ---

func boot() -> void:
	if _view != null or _play != null:
		return   # a test (or caller) already injected a view/source/play
	if not SaveManager.has_player():
		return
	var player := SaveManager.load_player()
	var career: CareerState = SaveManager.load_career() if SaveManager.has_career() \
		else CareerResolver.start_career(0)
	var spec := DifficultyLadder.spec_for(career.current_level(), 0)
	var team: Team = career.teams[career.current_team_index]
	# Forward-play: a live SeasonPlay you advance fixture-by-fixture, not a
	# pre-simmed season you scrub (spec D6).
	var play := SeasonPlay.start(
		player.attributes, team, career.opponents_of_current(),
		spec.make_tour(), BallTuning.new(), InningsTuning.new(), BOOT_SEED)
	set_play(player, career, play)

# --- Source + scrub ---

func set_source(player: Player, career: CareerState, season: SeasonResult) -> void:
	_player = player
	_career = career
	_season = season
	_rebuild(0)

# --- Live forward-play source (spec D5/D6) ---

# Render the growing league via the existing SeasonViewBuilder, with the scrub
# head pinned to how many games you've played.
func set_play(player: Player, career: CareerState, play: SeasonPlay) -> void:
	_player = player
	_career = career
	_play = play
	_rebuild_live()

func _rebuild_live() -> void:
	if _play == null:
		return
	set_view(SeasonViewBuilder.build(_player, _career, _play.live_season(), _play.played_count()))

func live_play() -> SeasonPlay:
	return _play

func current_career() -> CareerState:
	return _career

func has_play_control() -> bool:
	return _play != null and not _play.league_done() \
		and _root.get_node_or_null("PlayNextBtn") != null

func _rebuild(index: int) -> void:
	if _player == null or _career == null or _season == null:
		return
	set_view(SeasonViewBuilder.build(_player, _career, _season, index))

func scrub_index() -> int:
	return _view.scrub_index if _view != null else 0

# Public getters so main.gd's _push_match can read the captured season + names
# without reaching into the hub's private fields (cleaner coupling, plan §6 note).
func season() -> SeasonResult:
	return _season

func current_view() -> SeasonView:
	return _view

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
	_render_play_next(accent)
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
		if f["played"]:
			row.pressed.connect(func(): open_match.emit(idx))
		else:
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

# The next-fixture PLAY button (live forward-play path only). A solid
# StyleBoxFlat tile — NOT a flat button — because flat+modulate renders
# invisibly (CLAUDE.md). Hidden once the league is done or on the scrub path.
func _render_play_next(accent: Color) -> void:
	var existing := _root.get_node_or_null("PlayNextBtn")
	if existing != null:
		existing.queue_free()
	if _play == null or _play.league_done():
		return
	var nxt := _play.next_player_opponent()
	var btn := Button.new()
	btn.name = "PlayNextBtn"
	btn.text = "▶ PLAY  —  v %s" % nxt["name"]
	btn.size_flags_horizontal = Control.SIZE_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var idx: int = nxt["team_index"]
	btn.pressed.connect(func(): play_next.emit(idx))
	var fixtures := _root.get_node("FixturesBox")
	_root.add_child(btn)
	_root.move_child(btn, fixtures.get_index() + 1)

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
	head.text = "FINAL TABLE" if _play == null else "LEAGUE TABLE · your matches %d/7" % _play.played_count()
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
