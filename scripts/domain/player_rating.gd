class_name PlayerRating
extends RefCounted

# Pure, stateless net-runs rating (spec 2026-06-08-build-balance §3). Scores a
# batter, bowler, or all-rounder on ONE scale: runs added with the bat + runs
# saved with the ball (wickets folded in as run-value). No member state.

# bat_line: the Player's batting row (InningsResult.player_line()), or {} if they
# did not bat. bowl_*: the Player's figures (InningsResult.player_bowl_*).
static func rate(bat_line: Dictionary, bowl_wickets: int, bowl_runs: int, bowl_balls: int,
		rtun: RatingTuning) -> Dictionary:
	var r_bat := int(bat_line.get("runs", 0))
	var b_bat := int(bat_line.get("balls", 0))
	var batting := r_bat - (rtun.sr_par / 100.0) * b_bat
	var bowling := (rtun.rr_par / 6.0) * bowl_balls - bowl_runs + bowl_wickets * rtun.wicket_value
	return {"batting": batting, "bowling": bowling, "rating": batting + bowling}
