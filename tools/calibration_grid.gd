extends SceneTree

# Hero / world-scale calibration grid (Nico 2026-06-13 ruling). Sweeps all 24
# career cells and measures, per cell, the diagnostics behind his two rulings:
#   (i)  is a FRESH hero the right size vs the league? -> world band (weakest /
#        average / strongest team strength on the /100 card scale) vs the hero's
#        batting/bowling card; the maxed-hero (cap 60) ceiling for comparison.
#   (ii) do bat and bowl scale down together? -> league mean batting card vs mean
#        bowling card; the typical first-innings score + wickets; and the WEAK
#        side's (the 1.5-star underdog the Player starts on) score + all-out rate
#        (the collapse symptom).
# Writes docs/mockups/calibration-v1.html (the table grid Nico approved) + a DATA
# line. Measurement only — changes no dials.
#
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/calibration_grid.gd
# Env: N_SEASONS (default 40) · ATTRS ("p,c,a,c" fresh build, default 35,30,30,30)

const FRESH := [35.0, 30.0, 30.0, 30.0]
const MAXED := 60.0


func _cell(level: int, tour_i: int, n: int, build: Array) -> Dictionary:
	var tuning := BallTuning.new()
	var itun := InningsTuning.new()
	var spec := DifficultyLadder.spec_for(level, tour_i)
	var pol := OpponentBrain.draw_plans(TourSpec.Tier.TEXTBOOK, 1.0, RandomNumberGenerator.new())

	# World band from the deterministic tour curve (no noise): the career field
	# spans STAR_LADDER 1.5-star .. 4.5-star; avg = the tour mean.
	var probe_tour := spec.make_tour()
	var world_lo := probe_tour.percentile(1.5 / 5.0)
	var world_avg := probe_tour.mean
	var world_hi := probe_tour.percentile(4.5 / 5.0)

	var attrs := Attributes.new()
	attrs.power = build[0]; attrs.composure = build[1]; attrs.attack = build[2]; attrs.control = build[3]

	var league_totals := 0.0; var league_inns := 0
	var league_wkts := 0.0
	var weak_totals := 0.0; var weak_inns := 0; var weak_allout := 0
	var bat_sum := 0.0; var bowl_sum := 0.0; var team_n := 0

	for s in range(n):
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + s
		var teams: Array = []
		for k in range(CareerState.TEAMS_PER_LEVEL):
			var t := Team.new(); t.stars = CareerResolver.STAR_LADDER[k]; teams.append(t)
		var player_team: Team = teams[0]           # slot 0 = the 1.5-star underdog
		var opponents: Array = teams.duplicate(); opponents.remove_at(0)
		var league := LeagueResolver.simulate_league(
			attrs, player_team, opponents, spec.make_tour(), tuning, itun, rng,
			pol[0], pol[1], spec, [])
		for v in league.team_bat:
			bat_sum += v; team_n += 1
		for v in league.team_bowl:
			bowl_sum += v
		for m in league.player_matches:
			# League env = first innings of every Player match.
			league_totals += m.innings1.total; league_wkts += m.innings1.wickets; league_inns += 1
			# Weak side = the Player's own (1.5-star) team innings.
			var our: InningsResult = m.innings1 if not m.innings1.player_line().is_empty() else m.innings2
			weak_totals += our.total; weak_inns += 1
			if our.wickets >= 10:
				weak_allout += 1

	var hero_bat: float = (build[0] + build[1]) / 2.0
	var hero_bowl: float = (build[2] + build[3]) / 2.0
	return {
		"level": level, "tour": tour_i, "d": spec.d,
		"name": "%s · %s" % [DifficultyLadder.LEVEL_NAMES[level], DifficultyLadder.TOUR_NAMES[tour_i]],
		"world_lo": world_lo, "world_avg": world_avg, "world_hi": world_hi,
		"hero_bat": hero_bat, "hero_bowl": hero_bowl, "maxed": MAXED,
		"league_bat": bat_sum / team_n, "league_bowl": bowl_sum / team_n,
		"typical": league_totals / league_inns, "typ_wkts": league_wkts / league_inns,
		"weak": weak_totals / weak_inns, "weak_allout": 100.0 * weak_allout / weak_inns,
	}


func _init() -> void:
	var n := int(OS.get_environment("N_SEASONS")) if OS.get_environment("N_SEASONS") != "" else 40
	var build := FRESH.duplicate()
	if OS.get_environment("ATTRS") != "":
		var p := OS.get_environment("ATTRS").split(",")
		build = [float(p[0]), float(p[1]), float(p[2]), float(p[3])]

	var cells: Array = []
	for level in range(CareerState.LEVELS):
		for tour_i in range(CareerState.TOURS):
			cells.append(_cell(level, tour_i, n, build))
			var c: Dictionary = cells.back()
			print("cell %-22s d=%2.0f | world %4.1f/%4.1f/%4.1f | you bat %.0f (%.1fx) bowl %.0f | league bat %.1f bowl %.1f | typ %.0f (%.1f wkts) | weak %.0f (%.0f%% a.o.)" % [
				c["name"], c["d"], c["world_lo"], c["world_avg"], c["world_hi"],
				c["hero_bat"], c["hero_bat"] / c["world_avg"], c["hero_bowl"],
				c["league_bat"], c["league_bowl"], c["typical"], c["typ_wkts"],
				c["weak"], c["weak_allout"]])

	_write_html(cells, build, n)
	print("DATA ", JSON.stringify({"n": n, "build": build, "cells": cells}))
	quit()


func _write_html(cells: Array, build: Array, n: int) -> void:
	var data := JSON.stringify(cells)
	var html := """<!doctype html><html><head><meta charset="utf-8"><title>Hero / world scale calibration</title>
<style>
:root{color-scheme:dark}
body{font:14px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;background:#11161d;color:#e6edf3;margin:0;padding:24px}
h1{font-size:20px;margin:0 0 4px} p.sub{color:#9fb0c0;margin:0 0 18px;max-width:70ch}
table{border-collapse:collapse;width:100%;font-size:12.5px}
th,td{padding:7px 9px;border-bottom:0.5px solid #263041;text-align:center;white-space:nowrap}
th{font-size:10.5px;text-transform:uppercase;letter-spacing:.03em;color:#8fa6bd;font-weight:600;vertical-align:bottom}
td.cell{text-align:left;color:#e6edf3;font-weight:600} .lvl td{background:#1b2330;color:#cfe0f0;font-weight:600;text-align:left}
.grp th{border-bottom:none;color:#cfe0f0;font-size:11px;text-transform:none;letter-spacing:0}
.sub2{color:#9fb0c0} .note{margin-top:16px;color:#9fb0c0;font-size:12px;line-height:1.6;max-width:80ch}
.red{color:#f0786e} .amber{color:#e3a949} .green{color:#7ee2a8}
</style></head><body>
<h1>Hero / world scale — calibration grid</h1>
<p class="sub">Measured, N=@@N@@ seasons/cell, fresh build @@BUILD@@, textbook bot line. Each row is one career world. <b>World</b> = team strength (weakest 1.5★ / average / strongest 4.5★) on the /100 card scale. <b>You now</b> = your fresh card vs that average; <b>maxed</b> = after a full career (cap 60). <b>League bat/bowl</b> = are the two sides of the game filed down together? <b>Typical</b> = league first-innings score (wickets). <b>Weak side</b> = what your 1.5★ team scores, and how often it's bowled out.</p>
<div id="t"></div>
<p class="note" id="note"></p>
<script>
const cells = @@CELLS@@;
const LV = ["Club","City","Province"];
const f1 = x => x.toFixed(1), f0 = x => Math.round(x);
function ratioCls(r){ return r>=2 ? "red" : r>=1.4 ? "amber" : "green"; }
let html = `<table><thead>
<tr class="grp"><th></th><th colspan="3">the world (team strength)</th><th colspan="3">you (a card)</th><th colspan="2">bat vs bowl</th><th colspan="2">scores</th><th>weak side</th></tr>
<tr><th style="text-align:left">cell</th>
<th>weak</th><th>avg</th><th>strong</th>
<th>bat now</th><th>bowl now</th><th>maxed</th>
<th>league bat</th><th>league bowl</th>
<th>typical</th><th>wkts</th>
<th>all out</th></tr></thead><tbody>`;
let lastLv = -1;
cells.forEach(c => {
  if (c.level !== lastLv){ html += `<tr class="lvl"><td colspan="12">${LV[c.level]}</td></tr>`; lastLv = c.level; }
  const r = c.hero_bat / c.world_avg;
  const gap = c.league_bowl - c.league_bat;
  const balCls = gap >= 3 ? "red" : gap >= 1.5 ? "amber" : "green";
  const typCls = c.typical < 90 ? "red" : c.typical < 110 ? "amber" : "";
  const aoCls = c.weak_allout >= 40 ? "red" : c.weak_allout >= 20 ? "amber" : "";
  html += `<tr>
   <td class="cell">${c.name.split(" · ")[1]}</td>
   <td class="sub2">${f1(c.world_lo)}</td><td>${f1(c.world_avg)}</td><td class="sub2">${f1(c.world_hi)}</td>
   <td class="${ratioCls(r)}">${f0(c.hero_bat)} <span style="font-size:10.5px">(${f1(r)}×)</span></td>
   <td class="sub2">${f0(c.hero_bowl)}</td><td class="sub2">${f0(c.maxed)}</td>
   <td class="sub2 ${balCls}">${f1(c.league_bat)}</td><td class="sub2 ${balCls}">${f1(c.league_bowl)}</td>
   <td class="${typCls}">${f0(c.typical)}</td><td class="sub2">${f1(c.typ_wkts)}</td>
   <td class="sub2"><span class="${typCls}">${f0(c.weak)}</span> <span class="${aoCls}">(${f0(c.weak_allout)}%)</span></td>
  </tr>`;
});
html += `</tbody></table>`;
document.getElementById("t").innerHTML = html;
const club1 = cells[0];
document.getElementById("note").innerHTML =
  `Read a row: who you face (world), how big you are among them (you now × avg — red = too big), whether bat & bowl are balanced, and what the world (and your weak side) actually scores. ` +
  `At ${club1.name}, a fresh hero's bat card ${f0(club1.hero_bat)} is ${f1(club1.hero_bat/club1.world_avg)}× the average player (${f1(club1.world_avg)}) — the scale gap. Red "all out" = the collapses.`;
</script></body></html>"""
	html = html.replace("@@N@@", str(n)).replace("@@BUILD@@", str(build)).replace("@@CELLS@@", data)
	var f := FileAccess.open("res://docs/mockups/calibration-v1.html", FileAccess.WRITE)
	f.store_string(html)
	f.close()
