class_name MatchViewBuilder
extends RefCounted

# Pure builder for the Play → Match screen. build_events() transforms the two raw
# per-ball logs (MatchResult.ball_log_innings1/2) into one ordered, player-centric
# playback list; build() folds that list up to a cursor into a MatchView. No sim
# calls, no RNG — same purity contract as SeasonViewBuilder. Spec §3-§4.

const PAR_RR := 8.0   # 1st-innings benchmark RR (no chase yet) — anchored to the
                      # sim's real-T20 scoring env (~RR 8.1). 2nd innings uses the
                      # real chase RR instead.

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
	events.append({"type": "result", "text": mr.result_line_for_player(),
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

# --- Rich in-match read-model (hi-fi interactive scene) ----------------------
# Builds the structured scorecard the v4 screen renders by walking the RAW ball
# log of the active innings up to the cursor. Every number is real; player names
# are flavour (PlayerNames). Reuses build() for feed/result/flash. Context: the
# screen's player team name + the opponent name + their star ratings + country codes.
static func build_rich(mr: MatchResult, player: Player, cursor: int,
		p_team: String, opp_team: String,
		my_stars: float = 2.5, opp_stars: float = 2.5,
		my_code: int = 0, opp_code: int = 1) -> MatchView:
	var v := build(mr, player, cursor)
	v.my_code = my_code
	v.opp_code = opp_code

	# Active innings + how many balls into it the cursor sits.
	var events := build_events(mr, player)
	var c: int = clampi(cursor, 0, events.size())
	var innings_no := 1
	for k in range(c):
		if events[k]["type"] == "innings_break":
			innings_no = 2
	var od := _over_dot(events, c)
	var balls_into: int = maxi(0, (od[0] - 1) * 6 + od[1]) if od[0] >= 1 else 0

	# Which side bats this innings (and its flavour palette).
	var player_batting_this := (innings_no == 1) == mr.player_bats_first
	v.bat_team = p_team if player_batting_this else opp_team
	v.bowl_team = opp_team if player_batting_this else p_team
	var bat_code := my_code if player_batting_this else opp_code
	var bat_stars := my_stars if player_batting_this else opp_stars
	var bowl_code := opp_code if player_batting_this else my_code
	var bowl_stars := opp_stars if player_batting_this else my_stars

	var log: Array = mr.ball_log_innings1 if innings_no == 1 else mr.ball_log_innings2
	var n: int = mini(balls_into, log.size())

	# Per-position OVR from the REAL batting card (power+composure on the /100 scale).
	var card_batters: Array = mr.innings1.batters if innings_no == 1 else mr.innings2.batters
	var ovr_by_pos := {}
	for cb in card_batters:
		ovr_by_pos[cb["position"]] = int(round((cb["power"] + cb["composure"]) / 2.0))

	# Walk the innings to the cursor: per-position runs/balls/out, last partnership break.
	var runs := {}
	var faced := {}
	var out := {}
	var player_pos := -1
	var total := 0
	var wkts := 0
	var last_wkt_total := 0
	var last_wkt_ball := 0
	for i in range(n):
		var b: Dictionary = log[i]
		var pos: int = b["striker_pos"]
		if b["is_player"]: player_pos = pos
		faced[pos] = faced.get(pos, 0) + 1
		if b["wicket"]:
			out[pos] = true
			last_wkt_total = b["total"]; last_wkt_ball = i + 1
		else:
			runs[pos] = runs.get(pos, 0) + b["runs"]
		total = b["total"]; wkts = b["wickets"]

	# The two batters currently at the crease (positions 1..wkts+2 that aren't out).
	var pair: Array = []
	for pos in range(1, mini(wkts + 2, 11) + 1):
		if not out.get(pos, false):
			pair.append(pos)
	var on_strike := -1
	if n < log.size():
		on_strike = log[n]["striker_pos"]
	elif not pair.is_empty():
		on_strike = pair[0]

	# Build the two batter chips (flavour names; "YOU" for the player slot).
	var chips: Array = []
	for pos in pair:
		var nm := "YOU" if pos == player_pos else PlayerNames.upper(v.bat_team, bat_code, pos)
		chips.append({
			"name": nm, "position": pos,
			"badge": "YOU" if pos == player_pos else PlayerNames.badge(PlayerNames.for_position(v.bat_team, bat_code, pos)),
			"runs": runs.get(pos, 0), "balls": faced.get(pos, 0),
			"on_strike": pos == on_strike, "stars": bat_stars, "out": false,
			"ovr": ovr_by_pos.get(pos, 0),
		})
	if not chips.is_empty():
		# Batting-order positions, NEVER reordered on strike rotation (playtest T5:
		# flipping rows made batters hard to track). on_strike carries the highlight.
		# Field names stay striker/nonstriker for the UI; read them as chip 1/chip 2.
		v.striker = chips[0]
		if chips.size() > 1: v.nonstriker = chips[1]

	# This-over cells (the balls of the current over so far + pending pads to 6).
	var cur_over: int = od[0] if od[0] >= 1 else 1
	var over_cells: Array = []
	for i in range(n):
		var b: Dictionary = log[i]
		if b["over"] == cur_over:
			over_cells.append(_ball_kind(b["runs"], b["wicket"]))
	while over_cells.size() < 6:
		over_cells.append({"kind": "pending", "label": "?"})
	v.this_over = over_cells.slice(0, 6)

	# Partnership (current pair, runs since the last wicket).
	if v.striker and not v.nonstriker.is_empty():
		var pr := total - last_wkt_total
		var pb := n - last_wkt_ball
		v.partnership = {
			"names": "%s & %s" % [v.striker["name"], v.nonstriker["name"]],
			"runs": pr, "balls": pb, "frac": clampf(float(pr) / maxf(total, 1.0), 0.0, 1.0),
		}

	# The Player's own batting line (DRS actor = the dismissed player).
	if player_pos != -1:
		v.player_bat = {
			"name": "YOU", "badge": "YOU",
			"runs": runs.get(player_pos, 0), "balls": faced.get(player_pos, 0),
			"ovr": ovr_by_pos.get(player_pos, 0), "stars": bat_stars,
		}

	# Run rate (real) + the bowler row (flavour name, real ★/economy).
	var crr_f := (total * 6.0 / n) if n > 0 else 0.0
	v.crr = "%.1f" % crr_f
	v.chart = _build_chart(log, n, innings_no, mr.innings1.total)
	v.bowler = {
		"name": PlayerNames.upper(v.bowl_team, bowl_code, 7 + (cur_over % 5)),
		"badge": PlayerNames.badge(PlayerNames.for_position(v.bowl_team, bowl_code, 7 + (cur_over % 5))),
		"stars": bowl_stars, "econ": "%.1f" % crr_f,
		"ovr": int(round(bowl_stars * 20.0)),   # bowler card not tracked → team-★ derived
	}

	# Scorebar + innings tag + chase/target lines.
	v.score_big = "%d/%d" % [total, wkts]
	v.score_meta = "%s OV · CRR %s" % [_overs(od[0], od[1]), v.crr]
	if v.finished:
		v.innings_tag = "RESULT"
	elif innings_no == 1:
		v.innings_tag = "1ST INNINGS"
		v.req_value = str(total)
	else:
		var target: int = mr.innings1.total + 1
		var need: int = maxi(target - total, 0)
		var balls_left: int = maxi(120 - n, 0)
		v.target_big = str(target)
		v.target_sub = "NEED %d IN %d" % [need, balls_left]
		v.req_value = str(need)
		v.innings_tag = "CHASING" if player_batting_this else "DEFENDING"

	# Commentary (flavour) + locale chip.
	v.lang = "ZU" if bat_code == 0 else "EN"
	v.commentary = v.highlight_text if v.highlight_text != "" else _phase_comment(cur_over, innings_no)

	# Result recap: both innings totals with the batting side's name.
	if v.finished:
		v.won = mr.player_won()
		var first_team := p_team if mr.player_bats_first else opp_team
		var second_team := opp_team if mr.player_bats_first else p_team
		v.innings_lines = [
			{"label": "%s 1st" % first_team.to_upper(),
				"score": "%d/%d (%s)" % [mr.innings1.total, mr.innings1.wickets, _overs_from_balls(mr.innings1.balls)]},
			{"label": "%s 2nd" % second_team.to_upper(),
				"score": "%d/%d (%s)" % [mr.innings2.total, mr.innings2.wickets, _overs_from_balls(mr.innings2.balls)]},
		]
	return v

# --- T10 scorecard moments (spec 2026-07-04 DSC2/DSC3) ------------------------
# Mini-moment strip trigger for the event just applied (index cursor-1). Derived
# from the stream, never injected into it (DSC1). First-crossing per innings per
# kind; precedence you_bat/you_bowl > powerplay > death. {} = no strip.

const DEATH_FROM_OVER := 16
const _MOMENT_KINDS := ["you_bat", "you_bowl", "powerplay", "death"]
const _MOMENT_COPY := {
	"you_bat": ["YOU'RE IN", "Time to bat"],
	"you_bowl": ["YOU'RE ON", "Your spell begins"],
	"powerplay": ["POWERPLAY", "Field up - first 6 overs"],
	"death": ["FINAL 5 OVERS", "Death overs begin"],
}

static func _moment_matches(e: Dictionary, kind: String) -> bool:
	if e["type"] != "ball" and e["type"] != "over":
		return false
	match kind:
		"you_bat": return e["type"] == "ball" and e.get("player_batting", false)
		"you_bowl": return e["type"] == "ball" and e.get("player_bowling", false)
		"powerplay": return e["innings"] == 1   # first innings-1 event = powerplay start (DSC3)
		"death": return e.get("over", 0) >= DEATH_FROM_OVER
	return false

static func moment_at(mr: MatchResult, player: Player, cursor: int) -> Dictionary:
	var events := build_events(mr, player)
	if cursor < 1 or cursor > events.size():
		return {}
	var e: Dictionary = events[cursor - 1]
	if e["type"] != "ball" and e["type"] != "over":
		return {}
	var innings: int = e["innings"]
	for kind in _MOMENT_KINDS:
		if not _moment_matches(e, kind):
			continue
		var seen := false
		for k in range(cursor - 1):
			var p: Dictionary = events[k]
			if (p["type"] == "ball" or p["type"] == "over") \
					and p["innings"] == innings and _moment_matches(p, kind):
				seen = true
				break
		if not seen:
			return {"kind": kind, "title": _MOMENT_COPY[kind][0], "sub": _MOMENT_COPY[kind][1]}
	return {}

# Pure run-rate chart read-model: walk the active innings' ball-log up to `n`
# legal balls into per-over bars + a cumulative-CRR worm + the target/par line.
# innings_no 1 → par line (PAR_RR); 2 → chase RR from first_total. Used by build_rich.
static func _build_chart(log: Array, n: int, innings_no: int, first_total: int) -> Dictionary:
	var overs: Array = []
	var cur_over := 0
	var over_runs := 0
	var over_boundary := false
	var over_wicket := false
	var max_over_rr := 0.0
	var count: int = mini(n, log.size())
	for i in range(count):
		var b: Dictionary = log[i]
		var o: int = b["over"]
		if o != cur_over:
			if cur_over != 0:
				overs.append(_close_over(cur_over, over_runs, over_boundary, over_wicket,
					log[i - 1]["total"], i, false))
				max_over_rr = maxf(max_over_rr, overs[overs.size() - 1]["bar_rr"])
			cur_over = o
			over_runs = 0; over_boundary = false; over_wicket = false
		over_runs += b["runs"]
		if b["runs"] == 4 or b["runs"] == 6: over_boundary = true
		if b["wicket"]: over_wicket = true
	# flush the last over — `now` true iff it's still in progress (last ball isn't ball 6)
	if cur_over != 0:
		var last: Dictionary = log[count - 1]
		var in_progress: bool = last["ball_in_over"] != 6
		overs.append(_close_over(cur_over, over_runs, over_boundary, over_wicket,
			last["total"], count, in_progress))
		max_over_rr = maxf(max_over_rr, overs[overs.size() - 1]["bar_rr"])

	var target_rr: float = (PAR_RR if innings_no == 1
		else (first_total + 1) * 6.0 / 120.0)
	var y_max: float = clampf(maxf(target_rr, max_over_rr) * 1.15, 10.0, 18.0)
	return {"overs": overs, "target_rr": target_rr, "y_max": y_max, "innings": innings_no}

# One over's chart entry. balls_so_far = legal balls bowled in the innings up to and
# including this over's last counted ball → cumulative CRR. bar_rr = this over's RR.
static func _close_over(over: int, runs: int, boundary: bool, wicket: bool,
		cum_total: int, balls_so_far: int, now: bool) -> Dictionary:
	var balls_in_over: int = balls_so_far - (over - 1) * 6
	return {
		"over": over, "runs": runs,
		"crr": (cum_total * 6.0 / balls_so_far) if balls_so_far > 0 else 0.0,
		"bar_rr": (runs * 6.0 / balls_in_over) if balls_in_over > 0 else 0.0,
		"has_boundary": boundary, "has_wicket": wicket, "now": now,
	}

# Ball outcome → {kind, label} for the this-over grid.
static func _ball_kind(runs: int, wicket: bool) -> Dictionary:
	if wicket: return {"kind": "wicket", "label": "W"}
	if runs == 6: return {"kind": "six", "label": "6"}
	if runs == 4: return {"kind": "four", "label": "4"}
	if runs == 0: return {"kind": "dot", "label": "·"}
	return {"kind": "run", "label": str(runs)}

# Flavour commentary line keyed to phase (no data — pure dressing).
static func _phase_comment(over: int, innings_no: int) -> String:
	if innings_no == 2 and over >= 17: return "\"Down to the wire here...\""
	if over <= 6: return "\"Powerplay's on — field's up.\""
	if over >= 17: return "\"Death overs. The coach is up.\""
	return "\"Working it around for now.\""

# Completed-overs notation from a raw legal-ball count (120 -> "20.0", 117 -> "19.3").
static func _overs_from_balls(balls: int) -> String:
	return "%d.%d" % [balls / 6, balls % 6]

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
