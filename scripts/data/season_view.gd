class_name SeasonView
extends RefCounted

# Transient read-model for the Season Hub (spec 2026-06-15-season-hub-replay §4).
# Pure data — no node or resolver dependencies. Built by SeasonViewBuilder.

# --- Context ---
var level: int = 0
var tour: int = 0
var tour_name: String = ""
var difficulty_label: String = ""
var country: int = 0
var team_name: String = ""
var team_stars: float = 0.0

# --- Player snapshot ---
var player_name: String = ""
var city: String = ""
var form: float = 0.0  # raw form points -- FormBand bands the float (T6)
var appearance: int = 0
var power: float = 0.0
var composure: float = 0.0
var attack: float = 0.0
var control: float = 0.0
var ovr: int = 0

# --- Wallet / loyalty ---
var tons_balance: int = 0
var affinity: int = 0

# --- Fixtures chain (one dict per league game, in order) ---
# {opponent_name, opponent_stars, played, player_won, margin_text, score_text}
var fixtures: Array = []

# --- Final standings (ranked) ---
# {team_name, played, won, points, nrr, is_player}
var standings: Array = []
var player_final_position: int = 0

# --- Jokers owned ({id, name, rarity}) ---
var jokers: Array = []

# --- Scrub ---
var scrub_index: int = 0
var match_count: int = 7

# --- Career card (folded over player_matches[0 .. scrub_index-1]) ---
var card_matches: int = 0
var card_runs: int = 0
var card_balls_faced: int = 0
var card_dismissals: int = 0
var card_high_score: int = 0
var card_strike_rate: float = 0.0
var card_batting_avg: float = 0.0
var card_wickets: int = 0
var card_runs_conceded: int = 0
var card_balls_bowled: int = 0
var card_economy: float = 0.0
var card_best_bowling: String = "—"
