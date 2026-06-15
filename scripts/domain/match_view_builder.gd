class_name MatchViewBuilder
extends RefCounted

# Pure builder for the Play → Match screen. build_events() transforms the two raw
# per-ball logs (MatchResult.ball_log_innings1/2) into one ordered, player-centric
# playback list; build() folds that list up to a cursor into a MatchView. No sim
# calls, no RNG — same purity contract as SeasonViewBuilder. Spec §3-§4.

# A ball is "player-involved" if the Player faced it (batting) or bowled it.
static func _involved(b: Dictionary) -> bool:
	return b["is_player"] or b["player_bowling"]

# Transform one innings log into events: player balls individual, the rest of each
# over collapsed into a single "over" summary. `innings_no` is 1 or 2.
static func _innings_events(log: Array, innings_no: int) -> Array:
	var out: Array = []
	var over_no := 0
	var residual_runs := 0
	var residual_wkts := 0
	var residual_total := 0
	var residual_wickets := 0
	var have_residual := false
	for b in log:
		if b["over"] != over_no:
			# flush the previous over's residual non-player balls
			if have_residual:
				out.append({"type": "over", "over": over_no, "runs": residual_runs,
					"wkts": residual_wkts, "total": residual_total, "wickets": residual_wickets,
					"innings": innings_no})
			over_no = b["over"]
			residual_runs = 0; residual_wkts = 0; have_residual = false
		if _involved(b):
			out.append({"type": "ball", "over": b["over"], "ball": b["ball_in_over"],
				"player_batting": b["player_batting"], "player_bowling": b["player_bowling"],
				"runs": b["runs"], "wicket": b["wicket"], "boost": b["boost_pressed"],
				"total": b["total"], "wickets": b["wickets"], "innings": innings_no})
		else:
			residual_runs += b["runs"]
			residual_wkts += (1 if b["wicket"] else 0)
			residual_total = b["total"]; residual_wickets = b["wickets"]
			have_residual = true
	if have_residual:
		out.append({"type": "over", "over": over_no, "runs": residual_runs,
			"wkts": residual_wkts, "total": residual_total, "wickets": residual_wickets,
			"innings": 1 if innings_no == 1 else 2})
	return out

static func build_events(mr: MatchResult, _player: Player) -> Array:
	var events: Array = []
	events.append_array(_innings_events(mr.ball_log_innings1, 1))
	# innings break: 1st-innings final + the target the chase needs.
	var first_total: int = mr.innings1.total
	events.append({"type": "innings_break", "first_total": first_total,
		"first_wkts": mr.innings1.wickets, "target": first_total + 1})
	events.append_array(_innings_events(mr.ball_log_innings2, 2))
	events.append({"type": "result", "text": mr.margin_text(),
		"player_won": mr.player_won()})
	return events
