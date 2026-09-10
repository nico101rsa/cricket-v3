'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const Game = require('../src/game/game.js');
const G = require('../src/game/generator.js');
const L = require('../src/game/league.js');
const S = require('../src/game/stats.js');
const { mean } = require('./helpers.js');

function fresh(seed = 1, teamId = 1) { return Game.chooseTeam(Game.newLeague(seed), teamId); }

test('generator: 10 teams, 5 per city, 15 players each, unique ids and surnames', () => {
  for (let seed = 1; seed <= 20; seed++) {
    const lg = G.generateLeague(seed);
    assert.equal(lg.teams.length, 10);
    assert.equal(lg.teams.filter((t) => t.city === 'Pretoria').length, 5);
    assert.equal(lg.teams.filter((t) => t.city === 'Sydney').length, 5);
    assert.equal(new Set(lg.teams.map((t) => t.name)).size, 10);
    const ids = new Set();
    for (const t of lg.teams) {
      assert.equal(t.squadIds.length, 15);
      const squad = t.squadIds.map((id) => lg.players[id]);
      assert.equal(new Set(squad.map((p) => p.surname)).size, 15, 'unique surnames in a squad');
      for (const id of t.squadIds) { assert.ok(!ids.has(id)); ids.add(id); }
      const bowlers = squad.filter((p) => p.role === 'BOWLER');
      assert.ok(bowlers.filter((p) => p.kind === 'PACE').length >= 2 && bowlers.filter((p) => p.kind === 'SPIN').length >= 2);
      assert.ok(squad.filter((p) => p.role === 'BATTER').length >= 6);
      assert.ok(squad.filter((p) => p.role === 'ALLROUNDER').length >= 1);
      assert.ok(t.blurb.length > 20 && t.blurb.length <= 110, t.blurb);
      for (const p of squad) { assert.ok(p.age >= 18 && p.age <= 38); for (const v of Object.values(p.attrs)) assert.ok(v >= 3 && v <= 95); }
    }
    assert.deepEqual(JSON.parse(JSON.stringify(G.generateLeague(seed))), JSON.parse(JSON.stringify(lg)), 'deterministic');
  }
});

test('generator: stars, passengers and tiers exist', () => {
  const lg = G.generateLeague(3);
  const ps = Object.values(lg.players);
  assert.ok(ps.filter((p) => p.q >= G.STAR_Q).length >= 5);
  assert.ok(ps.filter((p) => p.q <= G.PASSENGER_Q).length >= 5);
  assert.ok(Math.max(...lg.teams.map((t) => t.tier)) - Math.min(...lg.teams.map((t) => t.tier)) >= 0.25);
});

test('fixtures: 45 matches, each team 9, one per round, home/away balanced-ish', () => {
  const st = fresh(2, 3);
  const fx = st.season.fixtures;
  assert.equal(fx.length, 45);
  for (const t of st.teams) {
    const mine = fx.filter((f) => f.homeId === t.id || f.awayId === t.id);
    assert.equal(mine.length, 9);
    assert.equal(new Set(mine.map((f) => f.round)).size, 9);
    const home = mine.filter((f) => f.homeId === t.id).length;
    assert.ok(home >= 3 && home <= 6);
  }
  for (let r = 1; r <= 9; r++) assert.equal(fx.filter((f) => f.round === r).length, 5);
});

test('a full season: table, stats reconcile, playoffs, champion, next season', () => {
  const st = fresh(5, 4);
  Game.simToEndOfSeason(st);
  assert.equal(st.season.stage, 'done');
  assert.equal(st.season.fixtures.length, 48);
  const rows = L.table(st.teams, st.season.fixtures);
  assert.equal(rows.length, 10);
  assert.equal(rows.reduce((a, r) => a + r.pts, 0), 90);
  for (const r of rows) assert.equal(r.p, 9);
  assert.ok(st.season.champion);
  assert.equal(st.honours.length, 1);
  // Stats reconcile with scorecards.
  let runs = 0, wkts = 0;
  for (const f of st.season.fixtures) for (const inn of f.result.innings) { runs += inn.total; wkts += inn.wickets; }
  let sr = 0, sw = 0;
  for (const [id, seasons] of Object.entries(st.stats)) { const s = seasons[1]; sr += s.bat.runs; sw += s.bowl.wkts; assert.ok(s.matches <= 11, `${id} played ${s.matches}`); }
  assert.equal(sr, runs); assert.equal(sw, wkts);
  // Every XI member of every match counted as playing.
  const played = st.teams.map((t) => t.squadIds.reduce((a, id) => a + S.seasonOf(st.stats, id, 1).matches, 0));
  for (const p of played) assert.ok(p >= 11 * 9 && p <= 11 * 11);
  // Rollover.
  const age0 = st.players[st.teams[0].squadIds[0]].age;
  Game.nextSeason(st);
  assert.equal(st.season.no, 2);
  assert.equal(st.players[st.teams[0].squadIds[0]].age, age0 + 1);
  assert.equal(st.season.fixtures.length, 45);
  assert.equal(S.careerOf(st.stats, st.teams[0].squadIds[0]).matches, S.seasonOf(st.stats, st.teams[0].squadIds[0], 1).matches);
});

test('user XI suggestion never reads hidden attributes', () => {
  const st = fresh(7, 2);
  const a = Game.suggestXI(st, 2);
  for (const id of st.teams[1].squadIds) { const p = st.players[id]; p.attrs = { power: 3, composure: 95, attack: 50, control: 3 }; }
  const b = Game.suggestXI(st, 2);
  assert.deepEqual(a, b);
  assert.equal(Game.validateUserXI(st, a), null);
  assert.equal(new Set(a.order).size, 11);
  assert.equal(a.bowlers.length, 5);
});

test('user XI validation messages', () => {
  const st = fresh(8, 1);
  const xi = Game.suggestXI(st, 1);
  assert.equal(Game.validateUserXI(st, { ...xi, order: xi.order.slice(0, 10) }), 'Pick exactly 11 players.');
  assert.equal(Game.validateUserXI(st, { ...xi, bowlers: xi.bowlers.slice(0, 4) }), 'Choose exactly 5 bowlers.');
  assert.equal(Game.validateUserXI(st, { ...xi, bowlers: [999].concat(xi.bowlers.slice(1)) }), 'A bowler is not in the XI.');
  assert.equal(Game.validateUserXI(st, { ...xi, preset: 'yolo' }), 'Choose a game plan.');
});

test('live match: replay regenerates the same match and commits once', () => {
  const st = fresh(9, 5);
  const f = Game.nextUserFixture(st);
  const sim1 = Game.startLive(st, f);
  assert.ok(st.live && st.live.fixtureId === f.id);
  const round = Game.roundOf(st, f);
  assert.equal(round.filter((g) => g.result).length, 4, 'other 4 fixtures in the round played first');
  assert.equal(f.result, null);
  const saved = Game.deserialize(Game.serialize(st));
  const sim2 = Game.liveMatch(saved);
  assert.deepEqual(sim2.summary, sim1.summary);
  assert.deepEqual(sim2.match.innings1.events, sim1.match.innings1.events);
  Game.finishLive(saved, sim2);
  assert.ok(Game.fixtureById(saved, f.id).result);
  assert.equal(saved.live, null);
});

test('save roundtrip gives an identical future', () => {
  const st = fresh(11, 6);
  Game.playRound(st); Game.playRound(st);
  const copy = Game.deserialize(Game.serialize(st));
  Game.simToEndOfSeason(st); Game.simToEndOfSeason(copy);
  assert.deepEqual(L.table(copy.teams, copy.season.fixtures), L.table(st.teams, st.season.fixtures));
  assert.throws(() => Game.deserialize('{"nope":1}'));
  assert.throws(() => Game.deserialize(JSON.stringify({ version: 99 })));
  assert.ok(Game.serialize(st).length < 400000, `save is ${Game.serialize(st).length} bytes`);
});

test('league scoring environment stays in the tuned band', () => {
  const totals = [], home = [];
  for (let seed = 1; seed <= 6; seed++) {
    const st = fresh(seed, 1); Game.simToEndOfSeason(st);
    for (const f of st.season.fixtures) { totals.push(f.result.innings[0].total); home.push(f.result.outcome === 'HOME_WIN' ? 1 : 0); }
  }
  const m = mean(totals);
  assert.ok(m >= 130 && m <= 185, `mean first-innings total ${m}`);
  assert.ok(mean(home) > 0.35 && mean(home) < 0.65);
});

// The design premise: a season of visible stats must track hidden quality.
function pearson(xs, ys) {
  const mx = mean(xs), my = mean(ys);
  let num = 0, dx = 0, dy = 0;
  for (let i = 0; i < xs.length; i++) { num += (xs[i] - mx) * (ys[i] - my); dx += (xs[i] - mx) ** 2; dy += (ys[i] - my) ** 2; }
  return num / Math.sqrt(dx * dy);
}
test('stats reveal hidden quality: batting average and economy correlate with attributes', () => {
  const bx = [], by = [], wx = [], wy = [];
  for (let seed = 1; seed <= 6; seed++) {
    const st = fresh(seed, 1); Game.simToEndOfSeason(st);
    for (const p of Object.values(st.players)) {
      const s = S.seasonOf(st.stats, p.id, 1);
      if (p.role === 'BATTER' && s.bat.balls >= 60 && s.bat.inns - s.bat.no >= 3) { bx.push(p.attrs.power + p.attrs.composure); by.push(S.batAvg(s)); }
      if (p.role === 'BOWLER' && s.bowl.balls >= 90) { wx.push(p.attrs.attack + p.attrs.control); wy.push(S.econ(s)); }
    }
  }
  const rb = pearson(bx, by), rw = pearson(wx, wy);
  assert.ok(rb >= 0.6, `batting r=${rb.toFixed(2)} over ${bx.length} batters`);
  assert.ok(rw <= -0.5, `bowling r=${rw.toFixed(2)} over ${wx.length} bowlers`);
});
