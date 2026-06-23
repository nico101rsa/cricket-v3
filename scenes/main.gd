extends Node

# Entry point. Picks the right scene based on save state, then drives transitions.

const IDENTITY := preload("res://scenes/player_creation/identity.tscn")
const BUILD := preload("res://scenes/player_creation/build.tscn")
const STARTING_TEAM := preload("res://scenes/stubs/starting_team_picker_stub.tscn")
const SEASON_HUB := preload("res://scenes/season_hub/season_hub.tscn")
const HALL_OF_FAME := preload("res://scenes/hall_of_fame/hall_of_fame.tscn")
const MATCH_VIEW := preload("res://scenes/match_view/match_view.tscn")
const INTERACTIVE_MATCH := preload("res://scenes/interactive_match/interactive_match.tscn")
const OUTCOME := preload("res://scenes/outcome/outcome.tscn")

@onready var _slot: Control = $Slot

func _ready() -> void:
	LifecycleManager.career_ended.connect(_on_career_ended)
	if SaveManager.has_player():
		_push_hub()
	else:
		_start_creation()

# draft is null on a fresh cold start / new Player, or the in-progress draft when
# the user taps Back from Build (spec §4: Back preserves picks). Passing it into
# Identity.set_draft re-hydrates the screen instead of starting blank.
func _start_creation(draft: PlayerCreationDraft = null) -> void:
	var identity := IDENTITY.instantiate()
	if draft != null:
		identity.set_draft(draft)
	identity.advance_to_build.connect(_on_identity_advance)
	_push(identity)

func _on_identity_advance(draft: PlayerCreationDraft) -> void:
	var build := BUILD.instantiate()
	build.set_draft(draft)
	build.back_pressed.connect(_start_creation)   # back_pressed emits the draft → _start_creation(draft)
	build.confirmed.connect(_on_build_confirmed)
	_push(build)

func _on_build_confirmed(_player: Player) -> void:
	var picker := STARTING_TEAM.instantiate()
	picker.proceed_to_season.connect(_push_hub)
	_push(picker)

# Instantiate the Season Hub, mount it, then boot a real season. boot() is
# explicit (not auto-run in the hub's _ready) so tests can inject a view without
# triggering a sim — see scenes/season_hub/season_hub.gd.
func _push_hub() -> void:
	var hub := SEASON_HUB.instantiate()
	hub.open_match.connect(_push_match)
	hub.play_next.connect(func(team_index: int): _play_next(team_index))
	_push(hub)
	hub.boot()

# Re-show a hub for an already-live SeasonPlay (after playing/watching a match).
# _push frees the old hub, but `play` is RefCounted and held by the caller's
# closure, so progress survives — we just rebind it onto a fresh hub.
func _show_live_hub(play: SeasonPlay, career: CareerState) -> void:
	var player := SaveManager.load_player()
	var hub := SEASON_HUB.instantiate()
	hub.open_match.connect(_push_match)
	hub.play_next.connect(func(team_index: int): _play_next(team_index))
	_push(hub)
	hub.set_play(player, career, play)

# Tap PLAY on the next fixture → play it interactively (Boost/DRS). The hub owns
# the live SeasonPlay; we pull a MatchSession off it, push the Interactive Match
# scene, and on back commit the result into the SAME SeasonPlay + re-show the hub.
func _play_next(team_index: int) -> void:
	var hub = _slot.get_child(0)
	var play: SeasonPlay = hub.live_play()
	# A match is pending in the league phase OR the playoffs (knockout); bail only
	# when the driver has nothing left to play.
	if play == null or play.next_player_opponent().is_empty():
		return
	var career: CareerState = hub.current_career()
	var team: Team = career.teams[career.current_team_index]
	# team_index is the live driver's _teams index (1..7) for both a league fixture
	# and a playoff opponent → opponents_of_current()[team_index - 1] resolves both.
	var opp: Team = career.opponents_of_current()[team_index - 1]
	var session := play.make_session()
	var screen := INTERACTIVE_MATCH.instantiate()
	screen.back.connect(func(): _commit_and_return(play, session, career))
	_push(screen)
	screen.set_session(session, team.team_name, opp.team_name,
		team.stars, opp.stars, Country.Code.SA, Country.Code.AUS)
	screen.boot()

func _commit_and_return(play: SeasonPlay, session: MatchSession, career: CareerState) -> void:
	play.commit_player_result(session.result())
	# Persist the ₸ banked into the player by this match (enable_pay bound it).
	var player: Player = play.pay_player()
	if player != null:
		SaveManager.save_player(player)
	# Season over (playoffs resolved) → outcome screen; otherwise back to the hub.
	if play.season_done():
		_show_outcome(play, career)
	else:
		_show_live_hub(play, career)

# The end-of-season outcome (where you finished + ₸ banked). Continue starts a
# fresh season hub. A hi-fi outcome / offers screen is a later presentation rung.
func _show_outcome(play: SeasonPlay, _career: CareerState) -> void:
	var screen := OUTCOME.instantiate()
	screen.continue_pressed.connect(_push_hub)
	_push(screen)
	screen.set_outcome(play.season_result(), play.pay_so_far(), play.season_wins())

# Tap a played fixture → watch that match's ball-by-ball replay (watch-only). On
# the live path the played matches live in the SeasonPlay; back returns to the
# live hub (NOT a fresh boot — that would wipe your league progress).
func _push_match(match_index: int) -> void:
	var player := SaveManager.load_player()
	var hub = _slot.get_child(0)   # the live Season Hub
	var view: SeasonView = hub.current_view()
	var play: SeasonPlay = hub.live_play()
	var career: CareerState = hub.current_career()
	var mr: MatchResult
	if play != null:
		mr = play.live_league().player_matches[match_index]
	else:
		mr = hub.season().league.player_matches[match_index]
	var opp: String = view.fixtures[match_index]["opponent_name"]
	var screen := MATCH_VIEW.instantiate()
	if play != null:
		screen.back.connect(func(): _show_live_hub(play, career))
	else:
		screen.back.connect(_push_hub)
	_push(screen)
	screen.set_match(mr, player, view.team_name, opp)
	screen.boot()

func _on_career_ended(_reason: String) -> void:
	var hof := HALL_OF_FAME.instantiate()
	# Wrap in a 0-arg lambda: begin_new_player emits no args, and connecting it
	# straight to _start_creation(draft = null) would lean on GDScript filling the
	# default from an arg-less signal. The lambda makes the arity unambiguous —
	# a fresh creation, no draft to re-hydrate.
	hof.begin_new_player.connect(func(): _start_creation())
	_push(hof)

func _push(scene: Control) -> void:
	for c in _slot.get_children():
		c.queue_free()
	_slot.add_child(scene)
