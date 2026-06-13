extends SceneTree

# Full season as a spreadsheet-style HTML table (Nico 2026-06-13). Runs one
# Season of a seeded career and writes docs/mockups/season-table-v1.html — one
# row per Player match, in his column layout: teams + level, both scores, his
# bat/bowl line, his FOUR attributes (Power/Composure = batting, Attack/Control =
# bowling), batting position + overs bowled + style label, the jokers in the bag
# (+ any held), and the running ₸ bank. State columns step at Kit Room visits.
#
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/season_table.gd
# Env: NARRATE_SEED (default 9001) · NARRATE_POLICY (default balanced) · SEASON_NO (default 1)

const SEASON_CAP := 120


func _choose_tour(state: CareerState) -> int:
	var lvl := state.current_level()
	for t in state.playable_cells():
		if state.status_of(lvl, t) != CareerState.CellStatus.BEATEN:
			return t
	return state.playable_cells().back()


func _jname(id: String) -> String:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return g["jname"]
	return id


func _attrs_of(snap: Dictionary) -> Attributes:
	var a := Attributes.new()
	a.power = snap["power"]
	a.composure = snap["composure"]
	a.attack = snap["attack"]
	a.control = snap["control"]
	return a


# Our innings = the one carrying the Player; the other is the opponent's.
func _our_their(m: MatchResult) -> Array:
	if not m.innings1.player_line().is_empty():
		return [m.innings1, m.innings2]
	return [m.innings2, m.innings1]


func _verdict(m: MatchResult) -> String:
	if m.outcome == MatchResult.Outcome.PLAYER_WIN:
		return ("Won by %d runs" % m.margin_runs) if m.margin_runs > 0 \
			else "Won by %d wkts" % m.margin_wickets
	if m.outcome == MatchResult.Outcome.OPPONENT_WIN:
		return ("Lost by %d runs" % m.margin_runs) if m.margin_runs > 0 \
			else "Lost by %d wkts" % m.margin_wickets
	return "Tied"


func _bat_cell(inn: InningsResult) -> String:
	var l: Dictionary = inn.player_line()
	if l.is_empty():
		return "—"
	var sr := (100.0 * int(l.get("runs", 0)) / int(l.get("balls", 1))) if int(l.get("balls", 0)) > 0 else 0.0
	return "%d (%d)%s · SR %.0f" % [int(l.get("runs", 0)), int(l.get("balls", 0)),
		"" if l.get("out", false) else "*", sr]


func _bowl_cell(inn: InningsResult) -> String:
	if inn.player_bowl_balls <= 0:
		return "—"
	var econ := 6.0 * inn.player_bowl_runs / inn.player_bowl_balls
	return "%d/%d · econ %.1f" % [inn.player_bowl_wickets, inn.player_bowl_runs, econ]


func _row(tag: String, opp: String, opp_stars: String, my_stars: float,
		m: MatchResult, snap: Dictionary, itun: InningsTuning) -> String:
	var ot := _our_their(m)
	var our_inn: InningsResult = ot[0]
	var their_inn: InningsResult = ot[1]
	var a := _attrs_of(snap)
	var pos := InningsResolver.player_position(a, itun)
	var overs := their_inn.player_bowl_balls / 6.0
	var style := ClassifierLabel.display_name(Classifier.classify(a))
	var won := m.outcome == MatchResult.Outcome.PLAYER_WIN
	var lost := m.outcome == MatchResult.Outcome.OPPONENT_WIN
	# Joker slots (cap 4) + the held carry/offer.
	var jcells := ""
	var owned: Array = snap["jokers"]
	for i in range(4):
		var nm := _jname(owned[i]) if i < owned.size() else ""
		jcells += "<td class='jk'>%s</td>" % nm
	var held: String = _jname(snap["held"]) if snap.get("held", "") != "" else ""

	var rcls := "win" if won else ("loss" if lost else "")
	return ("<tr class='%s'>" % rcls) + "".join([
		"<td class='m'>%s</td>" % tag,
		"<td>%s</td>" % opp,
		"<td class='c'>%.1f★ v %s</td>" % [my_stars, opp_stars],
		"<td class='v'>%s</td>" % _verdict(m),
		"<td class='c'>%d/%d</td>" % [our_inn.total, our_inn.wickets],
		"<td class='c'>%d/%d</td>" % [their_inn.total, their_inn.wickets],
		"<td class='c'>%s</td>" % _bat_cell(our_inn),
		"<td class='c'>%s</td>" % _bowl_cell(their_inn),
		"<td class='c'>%.0f</td>" % overs,
		"<td class='c'>%d</td>" % (pos + 1),
		"<td class='st'>%s</td>" % style,
		"<td class='c at'>%d</td>" % Display.to_card_round(a.power),
		"<td class='c at'>%d</td>" % Display.to_card_round(a.composure),
		"<td class='c ab'>%d</td>" % Display.to_card_round(a.attack),
		"<td class='c ab'>%d</td>" % Display.to_card_round(a.control),
		jcells,
		"<td class='jk hold'>%s</td>" % held,
		"<td class='c bank'>₸%d</td>" % int(snap["bank"]),
	]) + "</tr>"


func _init() -> void:
	var seed_env := OS.get_environment("NARRATE_SEED")
	var seed_v := int(seed_env) if seed_env != "" else 9001
	var policy_kind := OS.get_environment("NARRATE_POLICY")
	if policy_kind == "":
		policy_kind = "balanced"
	var target_env := OS.get_environment("SEASON_NO")
	var target_season := int(target_env) if target_env != "" else 1

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var etun := EconomyTuning.new()
	var player := Player.new()
	var a := Attributes.new()
	a.power = 11.0       # world-scale v2 WS3: fresh hero starts ≈ a weak Club player
	a.composure = 11.0
	a.attack = 11.0
	a.control = 11.0
	player.attributes = a
	var state := CareerResolver.start_career(0)
	var policy := ShopPolicy.preset(policy_kind)
	var plans := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, rng)

	var hdr := {}
	var rows: Array = []
	var shop_log: Array = []
	var owned_end: Array = []
	var pay := 0

	while not state.complete and state.seasons_played < SEASON_CAP:
		var lvl := state.current_level()
		var tour := _choose_tour(state)
		var my_team: Team = state.teams[state.current_team_index]
		var my_label := my_team.team_name
		var my_stars := my_team.stars
		var opponents: Array = state.opponents_of_current()
		var opp_labels: Array = []
		var opp_stars: Array = []
		for i in range(opponents.size()):
			opp_labels.append(opponents[i].team_name)
			opp_stars.append("%.1f★" % opponents[i].stars)

		var snaps: Array = []
		var out := CareerResolver.play_season(
			state, player, tour, tuning, itun, etun, rng, plans[0], plans[1], policy, snaps)
		var season: SeasonResult = out["season"]
		var s_no := state.seasons_played

		if s_no == target_season:
			hdr = {"season": s_no, "lvl": lvl, "tour": tour, "team": my_label, "stars": my_stars,
				"pos": season.player_final_position, "beat": season.beat}
			shop_log = out["shop_log"]
			owned_end = out["shop_owned"]
			pay = out["pay"]
			var pms: Array = CareerResolver._player_matches(season)
			# League fixtures first (k=0..opp), then the knockouts the Player played.
			var ko_tags := {}  # match -> label, for knockouts
			var ko := [["Semi-final", season.semi1], ["Semi-final", season.semi2],
				["Final", season.final_match], ["3rd-place", season.third_place]]
			for pair in ko:
				ko_tags[pair[1]] = pair[0]
			for k in range(pms.size()):
				var m: MatchResult = pms[k]
				var snap: Dictionary = snaps[k] if k < snaps.size() else {}
				if snap.is_empty():
					continue
				var is_league := k < opp_labels.size()
				var tag: String = "Match %d" % (k + 1) if is_league else ko_tags.get(m, "Playoff")
				var opp: String = opp_labels[k] if is_league else "(playoff opponent)"
				var ostar: String = opp_stars[k] if is_league else "—"
				rows.append(_row(tag, opp, ostar, my_stars, m, snap, itun))

		if state.complete:
			break
		var up: Offer = null
		for o in out["offers"]:
			if o.level > lvl and state.level_won[lvl]:
				up = o
				break
		if up != null:
			CareerResolver.accept_offer(state, player, up)
		else:
			CareerResolver.stay(state, player)
		if s_no >= target_season:
			break

	# --- Render the HTML -------------------------------------------------------
	var kit: Array = []
	for e in shop_log:
		match e["action"]:
			"starter": kit.append("Free starter: <b>%s</b>" % _jname(e["id"]))
			"carryover_in": kit.append("Carried in: <b>%s</b>" % _jname(e["id"]))
			"buy": kit.append("Bought <b>%s</b> (₸%d)" % [_jname(e["id"]), e["tons"]])
			"sell": kit.append("Sold <b>%s</b>" % _jname(e["id"]))
			"upgrade": kit.append("Trained <b>%s</b> +1" % e["id"])
			"hold": kit.append("Held <b>%s</b>" % _jname(e["id"]))
	var bag := ", ".join(owned_end.map(_jname)) if owned_end.size() > 0 else "none"

	var html := """<!doctype html><html><head><meta charset="utf-8">
<title>Season %d — full table</title><style>
:root{color-scheme:dark}
body{font:14px/1.45 -apple-system,Segoe UI,Roboto,sans-serif;background:#11161d;color:#e6edf3;margin:0;padding:24px}
h1{font-size:20px;margin:0 0 4px} h2{font-size:15px;color:#9fb0c0;margin:22px 0 8px;font-weight:600}
.sub{color:#9fb0c0;margin:0 0 16px}
table{border-collapse:collapse;width:100%%;font-size:12.5px}
th,td{border:1px solid #263041;padding:4px 7px;text-align:left;white-space:nowrap}
th{position:sticky;top:0;background:#1b2330;color:#cfe0f0;font-weight:600;font-size:11px;text-transform:uppercase;letter-spacing:.03em}
td.c{text-align:center} td.m{font-weight:600} td.v{font-size:11.5px}
tr.win td.v{color:#56d364} tr.loss td.v{color:#f0786e}
td.at{background:#16241c} td.ab{background:#1c1a24}
td.jk{font-size:11px;color:#d7c27a;max-width:120px;overflow:hidden;text-overflow:ellipsis}
td.hold{color:#7aa2d7} td.bank{font-weight:600;color:#9fe6c0} td.st{font-size:11px;color:#9fb0c0}
thead .grp th{background:#222c3b;text-align:center;color:#8fa6bd}
.kit{color:#cdd9e5;line-height:1.8} .kit b{color:#d7c27a}
</style></head><body>
<h1>Season %d in full — %s %s, %s (%.1f★)</h1>
<p class="sub">Seed %d · '%s' spending · finished %s of 8%s. One row per match; <b>Power/Composure</b> are your batting attributes, <b>Attack/Control</b> your bowling. State columns step when you visit the Kit Room mid-season.</p>
<table><thead>
<tr class="grp"><th colspan="6">The match</th><th colspan="5">You in it</th><th colspan="4">Your attributes</th><th colspan="5">Jokers in the bag</th><th>$</th></tr>
<tr><th>Match</th><th>Opponent</th><th>Level</th><th>Result</th><th>Our score</th><th>Opp score</th>
<th>My bat</th><th>My bowl</th><th>Overs</th><th>Bat #</th><th>Style</th>
<th>Power</th><th>Comp</th><th>Att</th><th>Ctrl</th>
<th>J1</th><th>J2</th><th>J3</th><th>J4</th><th>Held</th><th>Bank</th></tr>
</thead><tbody>
%s
</tbody></table>
<h2>The Kit Room this season</h2>
<p class="kit">%s</p>
<p class="kit">In the bag at season end: <b>%s</b> · season pay ₸%d</p>
</body></html>""" % [
		hdr.get("season", 0), hdr.get("season", 0),
		DifficultyLadder.LEVEL_NAMES[hdr.get("lvl", 0)], DifficultyLadder.TOUR_NAMES[hdr.get("tour", 0)],
		hdr.get("team", "?"), hdr.get("stars", 0.0),
		seed_v, policy_kind, hdr.get("pos", 0),
		" — beat the season (top 3)" if hdr.get("beat", false) else "",
		"\n".join(rows),
		" &nbsp;·&nbsp; ".join(kit) if kit.size() > 0 else "no actions",
		bag, pay]

	var f := FileAccess.open("res://docs/mockups/season-table-v1.html", FileAccess.WRITE)
	f.store_string(html)
	f.close()
	print("Wrote docs/mockups/season-table-v1.html — %d match rows, season %d." % [rows.size(), hdr.get("season", 0)])
	quit()
