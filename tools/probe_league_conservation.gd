extends SceneTree

# Diagnostic probe (2026-07-04): season-level slice of sweep_form_balance.gd only,
# same builds / seeds (555000+k) / N=300 / 7 even-*3 opponents, so DATA lines are
# directly comparable with /tmp/t8_sweep.log. Used to test whether the missing
# _conserved_bowling in LeagueResolver's Player fixtures explains the bowler
# build's ~+9pp season-level win edge (CF1 deferred gap, career-fidelity spec).

var _tuning := BallTuning.new()
var _itun := InningsTuning.new()

const N_SEASON := 1000

func _tour() -> TourDistribution:
	var t := TourDistribution.new()
	t.mean = 31.25
	t.spread = 9.375
	return t

func _builds() -> Array:
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

func _team() -> Team:
	var t := Team.new(); t.team_name = "My XI"; t.stars = 3.0
	return t

func _opps() -> Array:
	var out: Array = []
	for k in 7:
		var t := Team.new(); t.team_name = "Opp %d" % (k + 1); t.stars = 3.0
		out.append(t)
	return out

func _init() -> void:
	print("=== SEASON LEVEL probe (7 fixtures, N=%d seasons per build x arm) ===" % N_SEASON)
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
