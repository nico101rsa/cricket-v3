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
const KIT_ROOM := preload("res://scenes/kit_room/kit_room.tscn")
const OFFERS := preload("res://scenes/offers/offers.tscn")
const PRE_MATCH := preload("res://scenes/pre_match/pre_match.tscn")
const RESULT := preload("res://scenes/result/result.tscn")
const CAREER_GRID := preload("res://scenes/career_grid/career_grid.tscn")

@onready var _slot: Control = $Slot

func _ready() -> void:
	LifecycleManager.career_ended.connect(_on_career_ended)
	if not SaveManager.has_player():
		_start_creation()
	elif SaveManager.has_live_season():
		_push_hub()            # mid-season resume, unchanged
	else:
		_push_career_grid()    # between seasons: the career map is home (ADR 0010)

# The between-Seasons home (nav-shell spec 2026-07-03, Slice 3). Read-only:
# create-if-absent mirrors hub.boot's career bootstrapping (DN10) so a fresh
# career renders without booting a season; the season itself still only starts
# on hub.boot() when START SEASON is tapped.
func _push_career_grid() -> void:
	var player := SaveManager.load_player()
	var career: CareerState = SaveManager.load_career() if SaveManager.has_career() \
		else CareerResolver.start_career(0)
	SaveManager.save_career(career)
	var screen := CAREER_GRID.instantiate()
	screen.start_season.connect(_push_hub)
	_push(screen)
	screen.set_career(career, player)

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
	picker.proceed_to_season.connect(_push_career_grid)
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
	# A fresh season pends the V0 Kit Room (starter pick) before anything is played
	# (spec 2026-07-02); resumed seasons re-pend an unfinished visit the same way.
	if hub.live_play() != null and not hub.live_play().pending_shop_visit().is_empty():
		_show_kit_room(hub.live_play(), hub.current_career())

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
	# A pending Kit Room visit gates the next match (spec 2026-07-02 — the canon
	# cadence is visit-then-play; the visit screen loops back to the hub).
	if not play.pending_shop_visit().is_empty():
		_show_kit_room(play, career)
		return
	# The versus moment first (nav-shell spec 2026-07-03, Slice 1). The hub is
	# freed by _push, so read everything it holds BEFORE pushing (play/career
	# survive in the closure — the established RefCounted pattern).
	var view: SeasonView = hub.current_view()
	var opp_info: Dictionary = play.next_player_opponent()
	var opp_team: Team = career.opponents_of_current()[team_index - 1]
	var screen := PRE_MATCH.instantiate()
	screen.start_pressed.connect(func(): _start_match(play, career, team_index))
	_push(screen)
	screen.set_matchup(view, opp_info, opp_team.stars, play.played_count() + 1)

# TAP TO START → build the session and push the interactive match (the body
# that used to follow the Kit Room gate, unchanged).
func _start_match(play: SeasonPlay, career: CareerState, team_index: int) -> void:
	var team: Team = career.teams[career.current_team_index]
	# team_index is the live driver's _teams index (1..7) for both a league fixture
	# and a playoff opponent → opponents_of_current()[team_index - 1] resolves both.
	var opp: Team = career.opponents_of_current()[team_index - 1]
	var session := play.make_session()
	var screen := INTERACTIVE_MATCH.instantiate()
	screen.back.connect(func(): _commit_and_return(play, session, career, opp.team_name))
	_push(screen)
	screen.set_session(session, team.team_name, opp.team_name,
		team.stars, opp.stars, Country.Code.SA, Country.Code.AUS)
	screen.boot()

func _commit_and_return(play: SeasonPlay, session: MatchSession, career: CareerState,
		opp_name: String) -> void:
	# Read the fixture context BEFORE committing — commit advances the pointer.
	var stage := str(play.next_player_opponent().get("stage", ""))
	var match_no := play.played_count() + 1
	# Commit WITH the session's decisions so the live season can be replayed after a
	# restart (cross-session save, spec 2026-06-23).
	play.commit_player_result(session.result(), session.export_decisions())
	# Persist the ₸ banked into the player by this match (enable_pay bound it).
	var player: Player = play.pay_player()
	if player == null:
		player = SaveManager.load_player()
	if player != null:
		SaveManager.save_player(player)
	# The Result screen (nav-shell spec 2026-07-03, Slice 2): the payoff moment
	# between the match and the cadence fork. Display-only — the fork itself
	# (kit room / hub / season end) runs on Continue in _after_result.
	var mr := session.result()
	var dest := ""
	if play.season_done():
		dest = "SEASON END"
	elif not play.pending_shop_visit().is_empty():
		dest = "KIT ROOM"
	var champion := {}
	if stage == "final" and mr.player_won():
		# The cell just beaten — the grid only advances in _finish_live_season.
		var won_cell := CareerResolver.next_live_cell(career)
		champion = {"level_word": ["Club", "City", "Province"][int(won_cell["level"])],
			"tour_name": DifficultyLadder.TOUR_NAMES[int(won_cell["tour"])]}
	var team: Team = career.teams[career.current_team_index]
	var screen := RESULT.instantiate()
	screen.continue_pressed.connect(func(): _after_result(play, career))
	_push(screen)
	screen.set_result(mr, team.team_name, opp_name, match_no, stage,
		_display_pay(play, mr), (player.tons_balance if player != null else 0),
		dest, champion)

# Display-only recompute of what _settle banked (same pure functions, same ints).
func _display_pay(play: SeasonPlay, mr: MatchResult) -> Dictionary:
	var ctx := play.pay_context()
	if ctx.is_empty():
		return {"base": 0, "perf": 0, "prize": 0, "total": 0}
	var p: Dictionary = Economy.match_pay(mr, ctx["stars"], ctx["etun"])
	var prize := 0
	if mr.player_won():
		prize = Economy.match_win_prize(ctx["level"], ctx["tour"], ctx["etun"])
	return {"base": p["base"], "perf": p["perf"], "prize": prize,
		"total": int(p["total"]) + prize}

# Continue on the Result screen → the cadence fork (the old post-commit body).
func _after_result(play: SeasonPlay, career: CareerState) -> void:
	# The career cell this Season was played at (the grid hasn't advanced yet — the
	# hub is already freed here, so re-derive from the career, not hub.current_cell()).
	var cell := CareerResolver.next_live_cell(career)
	if play.season_done():
		# Carry-over election first (spec 2026-07-02 DK2-6): pick the one joker that
		# survives into next season, then run the season-end advance.
		if play.shop_enabled() and not play.shop_owned().is_empty():
			var screen := KIT_ROOM.instantiate()
			screen.carryover_elected.connect(func(id: String):
				career.carryover_joker_id = id
				_finish_live_season(play, career))
			_push(screen)
			screen.set_carryover(play)
		else:
			if play.shop_enabled():
				career.carryover_joker_id = ""   # owned nothing: no carry-over
			_finish_live_season(play, career)
	else:
		SaveManager.save_live_season(play.to_state(cell["level"], cell["tour"]))
		# A mid-season Kit Room visit (V1/V2 post-match, V3/V4 pre-knockout) gates
		# the way back to the hub.
		if play.pending_shop_visit().is_empty():
			_show_live_hub(play, career)
		else:
			_show_kit_room(play, career)

# The season-end advance, now two-phase around the Offers screen (offers spec
# 2026-07-02, DO1): record the season + draw offers (begin), let the player
# pick a team or stay, then apply + persist (finish). Derives the played cell
# FIRST (the grid must not have advanced yet). Career complete -> no offers,
# straight to the Outcome (DO2). Nothing is saved until the pick lands (DO5),
# so a quit on the Offers screen resumes from the last live-season save and
# re-draws the same offers (rng is seeded, offers are its only consumer).
func _finish_live_season(play: SeasonPlay, career: CareerState) -> void:
	var cell := CareerResolver.next_live_cell(career)
	var player: Player = play.pay_player()
	if player == null:
		player = SaveManager.load_player()
	var rng := RandomNumberGenerator.new()
	rng.seed = play.seed() + 7   # distinct from strength (_seed) / AI (+1) / playoff (+2)
	var begin := CareerResolver.begin_live_advance(
		career, play.season_result(), cell["level"], cell["tour"], rng)
	if begin["offers"].is_empty():
		_apply_offer_pick(play, career, player, begin, null)
		return
	var screen := OFFERS.instantiate()
	screen.offer_picked.connect(func(offer):
		_apply_offer_pick(play, career, player, begin, offer))
	_push(screen)
	screen.set_offers(career, begin["offers"])

# The pick lands: apply it, persist atomically (career + player + the cleared
# live season), then show the Outcome.
func _apply_offer_pick(play: SeasonPlay, career: CareerState, player: Player,
		begin: Dictionary, offer) -> void:
	var transition := CareerResolver.finish_live_advance(career, player, begin, offer)
	SaveManager.save_career(career)
	SaveManager.clear_live_season()
	if player != null:
		SaveManager.save_player(player)   # affinity moved on stay AND accept
	_show_outcome(play, career, transition, player)

# A pending Kit Room visit: show the screen; when the visit closes, save progress
# and loop (another visit may pend) until none — then fall through to the hub.
func _show_kit_room(play: SeasonPlay, career: CareerState) -> void:
	var visit: Dictionary = play.pending_shop_visit()
	if visit.is_empty():
		_show_live_hub(play, career)
		return
	var screen := KIT_ROOM.instantiate()
	screen.done.connect(func():
		_save_shop_progress(play, career)
		_show_kit_room(play, career))
	_push(screen)
	screen.set_visit(play, visit)

# Shop actions move ₸/attrs (persisted on the Player) and the shop state (in the
# live-season save) — write both after each closed visit.
func _save_shop_progress(play: SeasonPlay, career: CareerState) -> void:
	var player: Player = play.pay_player()
	if player != null:
		SaveManager.save_player(player)
	var cell := CareerResolver.next_live_cell(career)
	SaveManager.save_live_season(play.to_state(cell["level"], cell["tour"]))

# The end-of-season Outcome (finish + ₸ banked + the career transition). Continue
# starts the next Season at the new cell, or — when the Career is complete (won the
# Province Premier) — routes through the Hall of Fame.
func _show_outcome(play: SeasonPlay, career: CareerState, transition: Dictionary,
		player: Player = null) -> void:
	var screen := OUTCOME.instantiate()
	if transition.get("complete", false):
		screen.continue_pressed.connect(func(): LifecycleManager.win_out())
	else:
		# Between seasons the Career Grid is home (ADR 0010) — the next season
		# only starts from its START SEASON.
		screen.continue_pressed.connect(_push_career_grid)
	_push(screen)
	screen.set_outcome(play.season_result(), play.pay_so_far(), play.season_wins(),
		career, transition,
		player.country if player != null else Country.Code.SA)

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
