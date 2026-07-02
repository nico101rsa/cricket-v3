class_name SeasonViewBuilder
extends RefCounted

# Pure builder of SeasonView from real game state (spec 2026-06-15 §3/§6).
# No RNG, no UI, no resolver mutation. Folds the Player's real match lines into
# the career card; everything else is passthrough/mapping.

static func build(player: Player, career_state: CareerState,
		season_result: SeasonResult, scrub_index: int,
		owned_ids: Array = []) -> SeasonView:
	var v := SeasonView.new()
	var level := career_state.current_level()
	var tour_index := 0   # this slice boots the current Level's first cell; real
	                      # tour selection arrives with the Career Grid rung.
	var spec := DifficultyLadder.spec_for(level, tour_index)
	var team: Team = career_state.teams[career_state.current_team_index]

	# Context
	v.level = level
	v.tour = tour_index
	v.tour_name = spec.cell_name
	v.difficulty_label = "d %.1f" % spec.d
	v.country = player.country
	v.team_name = team.team_name
	v.team_stars = team.stars

	# Snapshot
	v.player_name = player.name.display_caps()
	v.city = player.city
	v.form = player.form
	v.appearance = player.appearance
	v.power = player.attributes.power
	v.composure = player.attributes.composure
	v.attack = player.attributes.attack
	v.control = player.attributes.control
	v.ovr = int(round((v.power + v.composure + v.attack + v.control) / 4.0))

	# Wallet / loyalty
	v.tons_balance = player.tons_balance
	v.affinity = player.affinity

	# Scrub
	v.match_count = 7
	v.scrub_index = clampi(scrub_index, 0, v.match_count)

	# Fixtures chain — Player league games in order, opponent identity from the
	# current cell's opponent field. simulate_league iterates the Player's games in
	# opponents_of_current() order, so they align by index.
	var opps := career_state.opponents_of_current()
	var pms: Array = season_result.league.player_matches
	for i in range(v.match_count):
		var opp: Team = opps[i] if i < opps.size() else null
		var row := {
			"opponent_name": (opp.team_name if opp != null else "TBD"),
			"opponent_stars": (opp.stars if opp != null else 0.0),
			"played": i < v.scrub_index,
			"player_won": false,
			"margin_text": "",
			"score_text": "",
		}
		if i < v.scrub_index and i < pms.size():
			var m: MatchResult = pms[i]
			row["player_won"] = m.player_won()
			row["margin_text"] = m.margin_text()
			var your := (m.innings1 if m.player_bats_first else m.innings2)
			var their := (m.innings2 if m.player_bats_first else m.innings1)
			row["score_text"] = "%d/%d  v  %d/%d" % [your.total, your.wickets, their.total, their.wickets]
		v.fixtures.append(row)

	# Final standings (labeled "Final" in the UI — provenance honest, §5).
	for r in season_result.league.standings:
		var rr_for: float = (float(r.runs_for) / (r.balls_for / 6.0)) if r.balls_for > 0 else 0.0
		var rr_against: float = (float(r.runs_against) / (r.balls_against / 6.0)) if r.balls_against > 0 else 0.0
		v.standings.append({
			"team_name": career_state.teams[r.team_index].team_name,
			"played": r.played,
			"won": r.points / 2,   # 2 points a win
			"points": r.points,
			"nrr": rr_for - rr_against,
			"is_player": r.team_index == 0,
		})
	v.player_final_position = season_result.player_final_position

	# Career card — fold the Player's real match lines up to the scrub head (§6).
	# Empty at scrub 0 (sentinels, never zeros-as-data).
	var best_w := -1
	var best_r := 0
	for i in range(min(v.scrub_index, pms.size())):
		var m: MatchResult = pms[i]
		var bat_inns := (m.innings1 if m.player_bats_first else m.innings2)
		var line := bat_inns.player_line()
		if not line.is_empty():
			v.card_matches += 1
			v.card_runs += int(line["runs"])
			v.card_balls_faced += int(line["balls"])
			if line["out"]:
				v.card_dismissals += 1
			v.card_high_score = max(v.card_high_score, int(line["runs"]))
		# Bowling: sum across both innings (only the bowling innings is non-zero).
		var mw := m.innings1.player_bowl_wickets + m.innings2.player_bowl_wickets
		var mr := m.innings1.player_bowl_runs + m.innings2.player_bowl_runs
		var mb := m.innings1.player_bowl_balls + m.innings2.player_bowl_balls
		v.card_wickets += mw
		v.card_runs_conceded += mr
		v.card_balls_bowled += mb
		if mb > 0 and (mw > best_w or (mw == best_w and mr < best_r)):
			best_w = mw; best_r = mr
	if v.card_dismissals > 0:
		v.card_batting_avg = float(v.card_runs) / v.card_dismissals
	elif v.card_matches > 0:
		v.card_batting_avg = float(v.card_runs)   # not-out average (flagged * in UI)
	if v.card_balls_faced > 0:
		v.card_strike_rate = 100.0 * v.card_runs / v.card_balls_faced
	if v.card_balls_bowled > 0:
		v.card_economy = float(v.card_runs_conceded) / (v.card_balls_bowled / 6.0)
	if best_w >= 0:
		v.card_best_bowling = "%d/%d" % [best_w, best_r]

	# Jokers on the bench: the live Kit Room's owned loadout when provided (Rung 2,
	# spec 2026-07-02 DK2-10); otherwise the carry-over joker (the pre-shop default,
	# keeps every existing caller untouched).
	if not owned_ids.is_empty():
		for oid in owned_ids:
			var m := _joker_meta(oid)
			if not m.is_empty():
				v.jokers.append(m)
	elif career_state.carryover_joker_id != "":
		var meta := _joker_meta(career_state.carryover_joker_id)
		if not meta.is_empty():
			v.jokers.append(meta)

	return v


static func _joker_meta(id: String) -> Dictionary:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return {"id": id, "name": g["jname"], "rarity": g["rarity"]}
	return {}
