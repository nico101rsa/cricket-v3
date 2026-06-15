extends Node

# Entry point. Picks the right scene based on save state, then drives transitions.

const IDENTITY := preload("res://scenes/player_creation/identity.tscn")
const BUILD := preload("res://scenes/player_creation/build.tscn")
const STARTING_TEAM := preload("res://scenes/stubs/starting_team_picker_stub.tscn")
const SEASON_HUB := preload("res://scenes/season_hub/season_hub.tscn")
const HALL_OF_FAME := preload("res://scenes/hall_of_fame/hall_of_fame.tscn")
const MATCH_VIEW := preload("res://scenes/match_view/match_view.tscn")

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
	_push(hub)
	hub.boot()

# Tap a played fixture → watch that match's ball-by-ball replay. Pulls the
# captured match + opponent/team names off the live hub (via its public getters)
# and pushes the watch-only match scene. back returns to the hub.
func _push_match(match_index: int) -> void:
	var player := SaveManager.load_player()
	var hub = _slot.get_child(0)   # the live Season Hub
	var view: SeasonView = hub.current_view()
	var mr: MatchResult = hub.season().league.player_matches[match_index]
	var opp: String = view.fixtures[match_index]["opponent_name"]
	var screen := MATCH_VIEW.instantiate()
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
