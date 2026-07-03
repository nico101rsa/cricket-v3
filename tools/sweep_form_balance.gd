extends SceneTree

# DF10 -- the Form+Affinity shared balance re-sweep (spec 2026-07-03).
# Two levels, each form-OFF vs form-ON (start 0, affinity 0 -- the honest floor):
#   1. MATCH level (Sweep harness, paired seeds, N per arm): the 4 reference builds
#      at even *3 -- win% / pay / team+opp totals (the env at player matches) / form_end.
#   2. SEASON level (LeagueResolver, N seasons): season win% of the player's 7
#      fixtures with form CHAINING across the season + end-of-season form.
# Tolerances (DF10): ON-arm build win spread <= ~2pp match / pay spread <= ~T1 /
# env drift small vs OFF. Prints DATA lines; run detached if slow:
#   nohup /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/sweep_form_balance.gd > /tmp/form_sweep.log 2>&1 &

var _tuning := BallTuning.new()
var _itun := InningsTuning.new()
var _etun := EconomyTuning.new()

const N_MATCH := 2000
const N_SEASON := 300

func _tour() -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = 31.25
	t.spread = 9.375
	return t

func _builds() -> Array:
	# total 125 (creation budget), power==composure=bs, attack==control=ws, bs+ws=62.5
	return [
		{"name": "batter    ", "bs": 50.0, "ws": 12.5},
		{"name": "bat-AR    ", "bs": 40.0, "ws": 22.5},
		{"name": "allround  ", "bs": 31.25, "ws": 31.25},
		{"name": "bowler    ", "bs": 12.5, "ws": 50.0},
	]

func _attrs(b: Dictionary) -> Attributes:
	var a := Attributes.new()
	a.power = b["bs"]; a.composure = b["bs"]
	a.attack = b["ws"]; a.control = b["ws"]
	return a

func _init() -> void:
	print("=== MATCH LEVEL (even *3, N=%d paired seeds per build x arm) ===" % N_MATCH)
	print("build       arm   win%   pay    team   opp    form_end")
	for b in _builds():
		for arm in ["off", "on"]:
			var arms := [{"name": b["name"], "config": {"b": b, "form": arm == "on"}}]
			var swept := Sweep.run(arms, N_MATCH, _match_scenario)
			var recs: Array = swept[0]["records"]
			var wins := 0
			var pay := 0.0
			var team := 0.0
			var opp := 0.0
			var fend := 0.0
			for r in recs:
				wins += r["won"]; pay += r["pay"]; team += r["team"]; opp += r["opp"]; fend += r["form_end"]
			var n := float(recs.size())
			print("DATA match %s %s  %5.1f  %6.2f  %5.1f  %5.1f  %+.2f" % [
				b["name"], arm, 100.0 * wins / n, pay / n, team / n, opp / n, fend / n])
	print("=== SEASON LEVEL (7 fixtures, form chains, N=%d seasons per build x arm) ===" % N_SEASON)
	print("build       arm   fixture-win%   season-end-form")
	for b in _builds():
		for arm in ["off", "on"]:
			var wins := 0
			var played := 0
			var fend := 0.0
			for k in N_SEASON:
				var rng := RandomNumberGenerator.new()
				rng.seed = 555000 + k
				var fs: FormState = FormState.make(0.0) if arm == "on" else null
				var lg := LeagueResolver.simulate_league(_attrs(b), _team(), _opps(),
					_tour(), _tuning, _itun, rng, null, null, null, [], Callable(), false, fs)
				for m in lg.player_matches:
					played += 1
					if m.outcome == MatchResult.Outcome.PLAYER_WIN:
						wins += 1
				if fs != null:
					fend += fs.points
			print("DATA season %s %s  %5.1f  %+.2f" % [
				b["name"], arm, 100.0 * wins / played, fend / N_SEASON])
	print("DATA done")
	quit()

func _team() -> Team:
	var t := Team.new(); t.team_name = "My XI"; t.stars = 3.0
	return t

func _opps() -> Array:
	var out: Array = []
	for k in 7:
		var t := Team.new(); t.team_name = "Opp %d" % (k + 1); t.stars = 3.0
		out.append(t)
	return out

func _match_scenario(config, rng: RandomNumberGenerator) -> Dictionary:
	var b: Dictionary = config["b"]
	var fs: FormState = FormState.make(0.0) if config["form"] else null
	var pt := Team.new(); pt.stars = 3.0
	var ot := Team.new(); ot.stars = 3.0
	var m := MatchResolver.simulate_match_teams(_attrs(b), pt, ot, _tour(), _tuning, _itun, rng,
		null, null, [], null, null, null, null, null, null, null, null,
		-1, null, null, null, fs)
	var bat_inn := m.innings1
	var bowl_inn := m.innings2
	if m.innings1.player_line().is_empty():
		bat_inn = m.innings2
		bowl_inn = m.innings1
	var pay: Dictionary = Economy.match_pay(m, 3.0, _etun)
	return {
		"won": 1 if m.outcome == MatchResult.Outcome.PLAYER_WIN else 0,
		"pay": float(pay.get("total", 0)),
		"team": float(bat_inn.total),
		"opp": float(bowl_inn.total),
		"form_end": m.form_end,
	}
