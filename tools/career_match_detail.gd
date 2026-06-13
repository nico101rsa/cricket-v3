extends SceneTree

# Narrate the START of one Season + its first match in full detail (Nico's
# 2026-06-12 ask): the team, the Kit Room decisions WITH the options that were
# on the table (starter choices, offers + shelf prices), the full scorecard of
# Match 1, and a mechanical note on every joker encountered. Replays the same
# seeded career as career_narrate.gd (identical RNG consumption).
#
# Run:  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/career_match_detail.gd
# Env:  NARRATE_SEED (default 9001) · NARRATE_POLICY (default balanced) · SEASON_NO (default 2)

const SEASON_CAP := 120


func _choose_tour(state: CareerState) -> int:
	var lvl := state.current_level()
	for t in state.playable_cells():
		if state.status_of(lvl, t) != CareerState.CellStatus.BEATEN:
			return t
	return state.playable_cells().back()


var _desc_by_name := {}


func _group_of(id: String) -> Dictionary:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return g
	return {}


func _jname(id: String) -> String:
	var g := _group_of(id)
	return g.get("jname", id)


# Plain-English joker descriptions, parsed from the canonical pool doc
# (docs/joker-pool-v1.md) — its 5th table column, the *italic* effect line.
# Source of truth so the narration never drifts from the authored intent.
func _load_descriptions() -> void:
	var f := FileAccess.open("res://docs/joker-pool-v1.md", FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line()
		if not line.begins_with("|"):
			continue
		var cols := line.split("|")
		if cols.size() < 7:
			continue
		var name := cols[2].strip_edges()
		var desc := cols[5].strip_edges()
		if desc.begins_with("*") and desc.ends_with("*"):
			desc = desc.substr(1, desc.length() - 2).strip_edges()
			_desc_by_name[name] = desc
	f.close()


func _mechanics(id: String) -> String:
	return _desc_by_name.get(_jname(id), "(see joker pool doc)")


func _scorecard(inn: InningsResult, label: String) -> Array:
	var lines: Array = []
	lines.append("**%s — %d/%d off %.1f overs** (Powerplay %d · middle %d · death %d)" % [
		label, inn.total, inn.wickets, inn.balls / 6.0,
		inn.phase_runs[0], inn.phase_runs[1], inn.phase_runs[2]])
	for b in inn.batters:
		if int(b.get("balls", 0)) == 0 and not b.get("out", false):
			continue
		var who := "YOU" if b.get("is_player", false) else "No.%d" % (int(b.get("position", 0)) + 1)
		lines.append("- %s: %d (%d)%s" % [who, int(b.get("runs", 0)), int(b.get("balls", 0)),
			"" if b.get("out", false) else " not out"])
	if inn.player_bowl_balls > 0:
		lines.append("- YOUR bowling in this innings: %d/%d off %.1f overs" % [
			inn.player_bowl_wickets, inn.player_bowl_runs, inn.player_bowl_balls / 6.0])
	if not inn.fall_of_wickets.is_empty():
		var fow: Array = []
		for f in inn.fall_of_wickets:
			fow.append(str(f.get("total", f)) if f is Dictionary else str(f))
		lines.append("- Fall of wickets: %s" % ", ".join(fow))
	return lines


func _init() -> void:
	_load_descriptions()
	var seed_env := OS.get_environment("NARRATE_SEED")
	var seed_v := int(seed_env) if seed_env != "" else 9001
	var policy_kind := OS.get_environment("NARRATE_POLICY")
	if policy_kind == "":
		policy_kind = "balanced"
	var target_env := OS.get_environment("SEASON_NO")
	var target_season := int(target_env) if target_env != "" else 2

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var etun := EconomyTuning.new()
	var player := Player.new()
	var a := Attributes.new()
	a.power = 35.0
	a.composure = 30.0
	a.attack = 30.0
	a.control = 30.0
	player.attributes = a
	var state := CareerResolver.start_career(0)
	var inner := ShopPolicy.preset(policy_kind)
	var seen: Array = []   # recorded shop ctxs for the target season
	var recording := [false]
	var policy := func(ctx: Dictionary) -> Dictionary:
		var decision: Dictionary = inner.call(ctx)
		if recording[0]:
			seen.append({"ctx": {
				"kind": ctx["kind"],
				"offer": ctx.get("offer"),
				"owned": ctx["shop"].owned_ids.duplicate() if ctx.has("shop") else [],
				"bank": ctx["player"].tons_balance if ctx.has("player") else 0,
			}, "decision": decision})
		return decision
	var plans := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, rng)

	var lines: Array = []
	while not state.complete and state.seasons_played < SEASON_CAP:
		var lvl := state.current_level()
		var tour := _choose_tour(state)
		var my_team: Team = state.teams[state.current_team_index]
		var my_label: String = my_team.team_name
		recording[0] = (state.seasons_played + 1) == target_season
		var attrs_before: Attributes = player.attributes.duplicate_typed()
		var bank_before: int = player.tons_balance
		var stars_at_play: float = my_team.stars
		var out := CareerResolver.play_season(
			state, player, tour, tuning, itun, etun, rng, plans[0], plans[1], policy)
		var s_no := state.seasons_played

		if s_no == target_season:
			var season: SeasonResult = out["season"]
			var jokers_seen: Array = []
			lines.append("# Season %d, opened up: the Kit Room and Match 1" % s_no)
			lines.append("")
			lines.append("Same career as career-narrative-v1.md (seed %d, '%s' spending). Team: **%s** (%.1f★), %s %s." % [
				seed_v, policy_kind, my_label, my_team.stars,
				DifficultyLadder.LEVEL_NAMES[lvl], DifficultyLadder.TOUR_NAMES[tour]])
			lines.append("")
			lines.append("## Your Player going into this Season")
			lines.append("")
			lines.append("The harness build (real careers start from the Player Creation screen; the bot has no name): created at Power 35 / Composure 30 / Attack 30 / Control 30 on the /100 card scale (creation budget 125, sliders 5-50).")
			lines.append("- Attributes now (after %d Season(s) of Kit Room training): **Power %.0f / Composure %.0f / Attack %.0f / Control %.0f** (cap 60 each)" % [
				s_no - 1, attrs_before.power, attrs_before.composure, attrs_before.attack, attrs_before.control])
			lines.append("- The build bats at **No.%d** (higher batting share bats higher up) and bowls a **%d-over quota**" % [
				InningsResolver.player_position(attrs_before, itun),
				InningsResolver.player_overs(attrs_before, itun)])
			lines.append("- Bank coming in: ₸%d · Affinity %d" % [bank_before, player.affinity])
			# Split the season's Kit Room events: ONLY the free starter happens
			# before any cricket; the buy/train visits are spread through the
			# season (after Player matches 3 & 5, before the semi, before the
			# championship). They are printed in their real slots, not lumped here.
			var visit_recs: Array = []
			lines.append("")
			lines.append("## Season start — the free starter pick (before any cricket)")
			lines.append("")
			lines.append("The ONLY Kit Room moment before the season begins: pick one free Common. The paid visits come later, between matches.")
			for rec in seen:
				if rec["ctx"]["kind"] != "starter":
					if rec["ctx"]["kind"] == "visit":
						visit_recs.append(rec)
					continue
				var ctx: Dictionary = rec["ctx"]
				var dec: Dictionary = rec["decision"]
				lines.append("")
				lines.append("Owned coming in: %s. Bank ₸%d." % [
					("none" if ctx["owned"].is_empty() else ", ".join(ctx["owned"].map(_jname))), ctx["bank"]])
				lines.append("**Free starter — pick one of three Commons:**")
				for id in ctx["offer"]:
					lines.append("- %s%s — %s" % [_jname(id),
						" ← PICKED" if dec.get("pick", "") == id else "", _mechanics(id)])
					jokers_seen.append(id)
			# Match 1 detail.
			var m: MatchResult = season.league.player_matches[0]
			var opp_team: Team = state.opponents_of_current()[0]
			var opp_name: String = opp_team.team_name
			lines.append("")
			lines.append("## The two teams (this Season's drawn strengths)")
			lines.append("")
			lines.append("Each team's batting/bowling strength is drawn once per Season from the tour's distribution at its ★ percentile (tour mean card %.2f on the /100 scale). The XI around you is derived from these numbers; only YOU have a personal card." % (TourSpec.mean_frac(DifficultyLadder.spec_for(lvl, tour).d) * TourSpec.MID_MEAN))
			lines.append("- **%s (us, %.1f★)** — batting strength %.2f · bowling strength %.2f" % [
				my_label, stars_at_play, season.league.team_bat[0], season.league.team_bowl[0]])
			lines.append("- **%s (them, %.1f★)** — batting strength %.2f · bowling strength %.2f" % [
				opp_name, opp_team.stars, season.league.team_bat[1], season.league.team_bowl[1]])
			lines.append("- Opponent brain at this cell: tier %s (how smart their captain's plans are)" % str(DifficultyLadder.spec_for(lvl, tour).brain_tier))
			lines.append("")
			lines.append("## Match 1 vs %s — ball-for-ball summary" % opp_name)
			lines.append("")
			lines.append("Toss: %s bat first." % ("we" if m.player_bats_first else "they"))
			var our_first := m.player_bats_first
			lines.append("")
			lines.append_array(_scorecard(m.innings1, ("Our innings" if our_first else "Their innings") + " (batting first)"))
			lines.append("")
			lines.append_array(_scorecard(m.innings2, ("Their chase" if our_first else "Our chase")))
			lines.append("")
			var verdict := "tie"
			if m.outcome == MatchResult.Outcome.PLAYER_WIN:
				verdict = ("won by %d runs" % m.margin_runs) if m.margin_runs > 0 else ("won by %d wickets with %d balls to spare" % [m.margin_wickets, m.balls_remaining])
			elif m.outcome == MatchResult.Outcome.OPPONENT_WIN:
				verdict = ("lost by %d runs" % m.margin_runs) if m.margin_runs > 0 else ("lost by %d wickets with %d balls left" % [m.margin_wickets, m.balls_remaining])
			lines.append("**Result: we %s.** Jokers active in this match: %s." % [verdict,
				", ".join(out["shop_owned"].map(_jname)) if not out["shop_owned"].is_empty() else "from the season log"])
			# The money, term by term (mirrors Economy.match_pay + match_win_prize).
			var bat_inn2: InningsResult = m.innings1 if not m.innings1.player_line().is_empty() else m.innings2
			var bowl_inn2: InningsResult = m.innings2 if bat_inn2 == m.innings1 else m.innings1
			var pline: Dictionary = bat_inn2.player_line()
			var p_runs := int(pline.get("runs", 0))
			var p_balls := int(pline.get("balls", 0))
			var pay_dict := Economy.match_pay(m, stars_at_play, etun)
			lines.append("")
			lines.append("## What this match paid, term by term")
			lines.append("")
			lines.append("- Game fee: ₸%d — base ₸%.0f minus ₸%.0f per ★ above 3.0 (you are on a %.1f★ side; weaker teams pay MORE)" % [
				pay_dict["base"], etun.base_pay, etun.star_pay_slope, stars_at_play])
			lines.append("- Runs: %d × ₸%.2f = ₸%.1f" % [p_runs, etun.runs_rate, etun.runs_rate * p_runs])
			var tempo := maxf(0.0, p_runs - etun.sr_par_pay / 100.0 * p_balls)
			lines.append("- Tempo: runs above a strike-rate-%d baseline off %d balls = %.1f extra runs × ₸%.1f = ₸%.1f" % [
				int(etun.sr_par_pay), p_balls, tempo, etun.sr_rate, etun.sr_rate * tempo])
			if p_runs >= 50:
				lines.append("- Milestone: fifty bonus ₸%.0f%s" % [etun.fifty_bonus,
					(" + Ton bonus ₸%.0f" % etun.ton_bonus) if p_runs >= 100 else ""])
			lines.append("- Wickets: %d × ₸%.0f = ₸%.0f" % [bowl_inn2.player_bowl_wickets,
				etun.wicket_rate, etun.wicket_rate * bowl_inn2.player_bowl_wickets])
			var econ_saved := maxf(0.0, etun.rr_par_pay / 6.0 * bowl_inn2.player_bowl_balls - bowl_inn2.player_bowl_runs)
			lines.append("- Economy: runs kept below club-par RR %.0f over %.1f overs = %.1f × ₸%.1f = ₸%.1f" % [
				etun.rr_par_pay, bowl_inn2.player_bowl_balls / 6.0, econ_saved, etun.econ_rate, etun.econ_rate * econ_saved])
			var vers := etun.versatility_rate * minf(minf(1.0, p_balls / etun.bat_ref_balls), minf(1.0, bowl_inn2.player_bowl_balls / etun.bowl_ref_balls))
			lines.append("- Versatility (both jobs done, scaled by the smaller one): ₸%.1f" % vers)
			lines.append("- **Match pay total: ₸%d** (fee %d + performance %d)" % [pay_dict["total"], pay_dict["base"], pay_dict["perf"]])
			if m.outcome == MatchResult.Outcome.PLAYER_WIN:
				lines.append("- **Team-win prize: ₸%d** — (₸%.0f base + ₸%.0f × Level %d) × tour escalation ×%.1f" % [
					Economy.match_win_prize(lvl, tour, etun), etun.win_bonus_base, etun.win_bonus_level_step, lvl,
					etun.prize_escalation[tour]])
			# The paid Kit Room visits, in their real season slots (not pre-game).
			lines.append("")
			lines.append("## The Kit Room through the rest of the Season (%d visits)" % visit_recs.size())
			lines.append("")
			lines.append("These happen BETWEEN matches, not before Match 1: after Player match 3, after match 5, before the semi-final (if top 4), before the championship match (if you made the semi).")
			var visit_when := ["After Match 3", "After Match 5", "Before the semi-final", "Before the championship match"]
			for vi in range(visit_recs.size()):
				var ctx: Dictionary = visit_recs[vi]["ctx"]
				var dec: Dictionary = visit_recs[vi]["decision"]
				var offer: Dictionary = ctx["offer"]
				lines.append("")
				lines.append("**%s** (bank ₸%d, owned: %s):" % [
					visit_when[vi] if vi < visit_when.size() else "Visit %d" % (vi + 1),
					ctx["bank"], ", ".join(ctx["owned"].map(_jname))])
				for r in ["common", "rare", "legendary"]:
					var id2: String = offer[r]
					var tagbits: Array = []
					if dec.get("buy", "") == id2:
						tagbits.append("BOUGHT")
					if dec.get("hold", "") == id2:
						tagbits.append("HELD")
					lines.append("- %s %s — ₸%d%s — %s" % [r.capitalize(), _jname(id2),
						offer["prices"][id2],
						(" ← " + " + ".join(tagbits)) if not tagbits.is_empty() else "",
						_mechanics(id2)])
					jokers_seen.append(id2)
				if dec.get("upgrade", "") != "":
					lines.append("- Also trained **%s** +1." % dec["upgrade"])
			lines.append("")
			lines.append("## Joker reference (everything encountered above)")
			lines.append("")
			var listed: Array = []
			for id3 in jokers_seen:
				if id3 in listed:
					continue
				listed.append(id3)
				var g := _group_of(id3)
				lines.append("- **%s** (%s, catalog ₸%d) — %s" % [_jname(id3), g.get("rarity", "?"),
					JokerCatalog.price(id3), _mechanics(id3)])
			break

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

	var path := "res://docs/mockups/career-match-detail-v1.md"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("\n".join(lines))
	quit()
