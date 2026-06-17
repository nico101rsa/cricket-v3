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

# Fold the event stream up to `cursor` (0..event_count) into the current MatchView.
static func build(mr: MatchResult, player: Player, cursor: int) -> MatchView:
	var events := build_events(mr, player)
	var v := MatchView.new()
	v.event_count = events.size()
	var c: int = clampi(cursor, 0, events.size())

	var bat_total := 0
	var bat_wkts := 0
	var innings_no := 1
	var target := 0
	var feed: Array = []
	var my_runs := 0
	var my_balls := 0
	var my_out := false
	var bw_wkts := 0
	var bw_runs := 0
	var bw_balls := 0

	for k in range(c):
		var e: Dictionary = events[k]
		match e["type"]:
			"ball":
				innings_no = e["innings"]
				bat_total = e["total"]; bat_wkts = e["wickets"]
				var tag := ""
				if e["boost"]: tag = "BOOST · "
				# Every individual "ball" event is a Player delivery (teammates fold into "over"
				# summaries) — label it so participation is legible.
				var who := "You bat " if e["player_batting"] else "You bowl "
				var what := ("WICKET!" if e["wicket"] else "%d run%s" % [e["runs"], "" if e["runs"] == 1 else "s"])
				feed.append("%s  %s%s%s" % [_overs(e["over"], e["ball"]), who, tag, what])
				if e["player_batting"]:
					var runs_before := my_runs
					my_balls += 1
					if e["wicket"]: my_out = true
					else: my_runs += e["runs"]
					v.current_line = "You %d%s (%d)" % [my_runs, "" if my_out else "*", my_balls]
					if k == c - 1:  # flash this ball only if it's the one just shown
						v.highlight_text = _bat_highlight(runs_before, my_runs, my_balls, e["wicket"], e["runs"])
				elif e["player_bowling"]:
					bw_balls += 1
					if e["wicket"]: bw_wkts += 1
					else: bw_runs += e["runs"]
					v.current_line = "You %d/%d (%d.%d)" % [bw_wkts, bw_runs, bw_balls / 6, bw_balls % 6]
					if k == c - 1 and e["wicket"]:
						v.highlight_text = _bowl_highlight(bw_wkts, bw_runs)
			"over":
				innings_no = e["innings"]
				bat_total = e["total"]; bat_wkts = e["wickets"]
				feed.append("Over %d: %d run%s%s" % [e["over"], e["runs"],
					"" if e["runs"] == 1 else "s",
					(", %d wkt" % e["wkts"]) if e["wkts"] > 0 else ""])
			"innings_break":
				target = e["target"]
				innings_no = 2
				bat_total = 0; bat_wkts = 0
				feed.append("Innings break — chasing %d" % target)
			"result":
				v.finished = true
				v.result_text = e["text"]
				v.player_won = e["player_won"]
				feed.append("Result: %s" % e["text"])
				v.player_summary = "You: %d%s (%d) bat  ·  %d/%d (%d.%d) bowl" % [
					my_runs, "" if my_out else "*", my_balls,
					bw_wkts, bw_runs, bw_balls / 6, bw_balls % 6]
				feed.append(v.player_summary)

	# Active innings label + scoreboard.
	var player_bats_this := (innings_no == 1) == mr.player_bats_first
	if innings_no == 2 and target > 0:
		v.innings_label = ("Your chase" if player_bats_this else "Bowling — defending %d" % target)
		v.target_text = "Target %d" % target
	else:
		v.innings_label = ("Your innings" if player_bats_this else "Bowling")
		v.target_text = ""
	var od := _over_dot(events, c)
	var overs := _overs(od[0], od[1])
	v.batting_score = "%d/%d (%s)" % [bat_total, bat_wkts, overs]
	v.feed = feed.slice(maxi(0, feed.size() - 6))
	return v

# The striker/bowler one-liner for the current ball.
static func _line_for(e: Dictionary, total: int, _wkts: int) -> String:
	if e["player_bowling"]:
		return "You bowling — %d.%d" % [e["over"], e["ball"]]
	if e["player_batting"]:
		return "You batting — team %d" % total
	return ""

# Your-moment flash for a Player batting ball (spec 2026-06-17 §4). Milestones win
# over a plain boundary; getting out is also flagged. "" = nothing to flash.
static func _bat_highlight(runs_before: int, runs_after: int, balls: int, wicket: bool, runs: int) -> String:
	if wicket:
		return "OUT! %d (%d)" % [runs_after, balls]
	if runs_before < 100 and runs_after >= 100:
		return "HUNDRED! %d (%d)" % [runs_after, balls]
	if runs_before < 50 and runs_after >= 50:
		return "FIFTY! %d (%d)" % [runs_after, balls]
	if runs == 6:
		return "SIX!"
	if runs == 4:
		return "FOUR!"
	return ""

# Your-moment flash for a Player bowling wicket (3-for / 5-for win over a plain wicket).
static func _bowl_highlight(wkts: int, runs: int) -> String:
	if wkts == 5:
		return "FIVE-FOR! %d/%d" % [wkts, runs]
	if wkts == 3:
		return "THREE-FOR! %d/%d" % [wkts, runs]
	return "WICKET! %d/%d" % [wkts, runs]

# Cricket overs notation from a 1-based over + 1-6 ball: completed-overs.balls.
# The 6th ball of an over ticks the over count over (over 1 ball 6 -> "1.0", over 20
# ball 5 -> "19.5", ball 6 -> "20.0") — not the raw "20.6" the ball-log stores.
static func _overs(over: int, ball: int) -> String:
	if over < 1:
		return "0.0"
	var total := (over - 1) * 6 + ball
	return "%d.%d" % [total / 6, total % 6]

# Best-effort current over.ball from the last applied event (display only).
static func _over_dot(events: Array, c: int) -> Array:
	for k in range(c - 1, -1, -1):
		var e: Dictionary = events[k]
		if e["type"] == "ball":
			return [e["over"], e["ball"]]
		if e["type"] == "over":
			return [e["over"], 6]
	return [0, 0]
