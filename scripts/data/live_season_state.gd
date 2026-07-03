class_name LiveSeasonState
extends Resource

# The serialisable save payload for an in-progress live season (cross-session save,
# spec 2026-06-23-live-season-cross-session-save). We do NOT persist match results
# (RefCounted, non-@export) — instead we persist the seed + the small per-match
# player DECISIONS and replay them deterministically on resume (SeasonPlay.replay).
#
# Player + CareerState are NOT duplicated here — they have their own save files
# (player.tres / career.tres); SeasonPlay.from_state takes them as args (SL3).

@export var version: int = 2            # schema version (v2 = the Kit Room fields below)
@export var seed: int = 0               # the season's base seed (SeasonPlay._seed)
@export var level: int = 0              # career cell coordinates — pins the difficulty
@export var tour_index: int = 0         # spec + pay context (SL2), so the save is self-describing
@export var pay_total: int = 0          # running ₸ banked this season (for the outcome screen)
@export var wins: int = 0               # player wins this season
# One Dictionary per committed player match, in commit order:
# {presses, review_balls, km, bowl_km} (MatchSession.export_decisions()) plus the
# REPLAY CONTEXT (spec 2026-07-02 DK2-4): {jokers, attrs} — the loadout + attributes
# this match was played with, so mid-season shopping replays losslessly.
@export var decisions: Array = []

# --- v2: the live Kit Room (spec 2026-07-02). ShopState is tiny + serialisable. ---
@export var form_enabled: bool = false  # Form was live on the saved driver (spec 2026-07-03 DF6)
@export var shop_enabled: bool = false
@export var shop_owned: Array = []
@export var shop_paid: Dictionary = {}
@export var shop_held: String = ""
@export var shop_visits_mask: int = 0
@export var shop_paid_mask: int = 0
