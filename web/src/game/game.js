// The game state machine. One plain-JSON save holds everything; every
// function here takes the state and returns/mutates it. Matches are seeded
// from (league seed, season, fixture id) so a match replays without
// simulating the ones before it.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}), typeof require === 'function' ? require : null);
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket, require) {
  const T = require ? require('../engine/tuning.js') : Cricket.tuning;
  const R = require ? require('../engine/rng.js') : Cricket.rng;
  const M = require ? require('../engine/model.js') : Cricket.model;
  const I = require ? require('../engine/intent.js') : Cricket.intent;
  const X = require ? require('../engine/match.js') : Cricket.match;
  const G = require ? require('./generator.js') : Cricket.generator;
  const S = require ? require('./stats.js') : Cricket.stats;
  const L = require ? require('./league.js') : Cricket.league;

  const SAVE_VERSION = 1;

  // ---- creation -----------------------------------------------------------
  function newLeague(seed) {
    const lg = G.generateLeague(seed);
    return {
      version: SAVE_VERSION, seed, teams: lg.teams, players: lg.players,
      userTeamId: null, season: null, stats: {}, honours: [], userXI: null, live: null,
      settings: { ballMs: 3000 },
    };
  }

  function chooseTeam(state, teamId) {
    state.userTeamId = teamId;
    state.userXI = suggestXI(state, teamId);
    startSeason(state, 1);
    return state;
  }

  function startSeason(state, no) {
    const ids = state.teams.map((t) => t.id);
    const order = R.makeRng(R.deriveSeed(state.seed, 77, no)).shuffle(ids);
    state.season = { no, stage: 'league', fixtures: L.makeFixtures(order), champion: null };
    return state;
  }

  // ---- lookups ------------------------------------------------------------
  const teamById = (state, id) => state.teams.find((t) => t.id === id);
  const squadOf = (state, teamId) => teamById(state, teamId).squadIds.map((id) => state.players[id]);
  const fixtureById = (state, id) => state.season.fixtures.find((f) => f.id === id);
  function userFixtures(state) { return state.season.fixtures.filter((f) => f.homeId === state.userTeamId || f.awayId === state.userTeamId); }
  function nextFixture(state) { return state.season.fixtures.find((f) => !f.result) || null; }
  function nextUserFixture(state) { return userFixtures(state).find((f) => !f.result) || null; }
  function roundOf(state, fixture) { return state.season.fixtures.filter((f) => f.round === fixture.round); }

  // ---- visible view + user XI suggestion ----------------------------------
  // Everything the manager may see about a player: never the attributes.
  function visible(state, p) {
    const season = state.season ? S.seasonOf(state.stats, p.id, state.season.no) : S.emptySeason();
    return { id: p.id, firstName: p.firstName, surname: p.surname, age: p.age, role: p.role, kind: p.kind, season, career: S.careerOf(state.stats, p.id) };
  }
  const visibleSquad = (state, teamId) => squadOf(state, teamId).map((p) => visible(state, p));

  // Rank by what is visible: career runs/wickets weighted by average, with
  // role and age as tie-breaks. A pure function of the visible view.
  function batScore(v) { const c = v.career; if (!c.bat.inns) return 0; const a = S.batAvg(c); return (Number.isFinite(a) ? a : c.bat.runs) * Math.min(1, c.bat.inns / 5) + (Number.isFinite(S.batSR(c)) ? S.batSR(c) / 20 : 0); }
  function bowlScore(v) { const c = v.career; if (!c.bowl.balls) return 0; const e = S.econ(c); return c.bowl.wkts * 3 - (Number.isFinite(e) ? e : 8) * Math.min(1, c.bowl.balls / 60); }
  const expTie = (a, b) => (b.age - a.age) || (a.id - b.id); // experience: older first
  function suggestFrom(vs) {
    const batters = vs.filter((v) => v.role === 'BATTER').sort((a, b) => (batScore(b) - batScore(a)) || expTie(a, b));
    const alls = vs.filter((v) => v.role === 'ALLROUNDER').sort((a, b) => ((bowlScore(b) + batScore(b)) - (bowlScore(a) + batScore(a))) || expTie(a, b));
    const pace = vs.filter((v) => v.role === 'BOWLER' && v.kind === 'PACE').sort((a, b) => (bowlScore(b) - bowlScore(a)) || expTie(a, b));
    const spin = vs.filter((v) => v.role === 'BOWLER' && v.kind === 'SPIN').sort((a, b) => (bowlScore(b) - bowlScore(a)) || expTie(a, b));
    let bowlers = pace.slice(0, 2).concat(spin.slice(0, 2));
    if (bowlers.length < 4) bowlers = bowlers.concat(pace.slice(2).concat(spin.slice(2)).sort((a, b) => (bowlScore(b) - bowlScore(a)) || expTie(a, b)).slice(0, 4 - bowlers.length));
    let chosen = batters.slice(0, 6).concat(alls.slice(0, 1), bowlers);
    if (chosen.length < 11) {
      const ids = new Set(chosen.map((v) => v.id));
      chosen = chosen.concat(vs.filter((v) => !ids.has(v.id)).sort((a, b) => ((batScore(b) + bowlScore(b)) - (batScore(a) + bowlScore(a))) || expTie(a, b)).slice(0, 11 - chosen.length));
    }
    const top = chosen.slice(0, 6), tail = chosen.slice(6);
    const order = top.concat(tail).map((v) => v.id);
    const five = chosen.slice().sort((a, b) => (bowlScore(b) - bowlScore(a)) || (roleBowl(b) - roleBowl(a)) || expTie(a, b)).slice(0, 5).map((v) => v.id);
    return { order, bowlers: five, preset: 'balanced' };
  }
  const roleBowl = (v) => (v.role === 'BOWLER' ? 2 : v.role === 'ALLROUNDER' ? 1 : 0);
  function suggestXI(state, teamId) { return suggestFrom(visibleSquad(state, teamId)); }

  function validateUserXI(state, xi) {
    const squad = new Set(teamById(state, state.userTeamId).squadIds);
    if (!xi || xi.order.length !== 11) return 'Pick exactly 11 players.';
    if (new Set(xi.order).size !== 11) return 'A player is picked twice.';
    for (const id of xi.order) if (!squad.has(id)) return 'A picked player is not in your squad.';
    if (xi.bowlers.length !== 5) return 'Choose exactly 5 bowlers.';
    for (const id of xi.bowlers) if (!xi.order.includes(id)) return 'A bowler is not in the XI.';
    if (!I.PRESETS[xi.preset]) return 'Choose a game plan.';
    return null;
  }

  // ---- simulation ---------------------------------------------------------
  const resolveXI = (state, teamId, spec) => M.makeXI(teamById(state, teamId), spec.order.map((id) => state.players[id]), spec.bowlers.map((id) => state.players[id]));
  function aiXI(state, teamId) { const xi = M.pickXI(teamById(state, teamId), squadOf(state, teamId)); return { order: xi.order.map((p) => p.id), bowlers: xi.bowlers.map((p) => p.id), preset: 'balanced' }; }
  function xiSpecFor(state, teamId) { return teamId === state.userTeamId ? state.userXI : aiXI(state, teamId); }
  const matchSeed = (state, fixture) => R.deriveSeed(state.seed, 1000 + state.season.no, fixture.id);

  // Simulate a fixture (pure: does not touch state). Returns the engine result
  // plus the stored-form summary. xis may be given (replays use the stored ones).
  function simulateFixture(state, fixture, xis) {
    xis = xis || { home: xiSpecFor(state, fixture.homeId), away: xiSpecFor(state, fixture.awayId) };
    const seed = matchSeed(state, fixture);
    const home = resolveXI(state, fixture.homeId, xis.home), away = resolveXI(state, fixture.awayId, xis.away);
    const m = X.simulateMatch(home, away, T.ballTuning(), T.inningsTuning(), R.makeRng(seed), I.presetPlan(xis.home.preset), I.presetPlan(xis.away.preset), { cosmetic: R.makeRng(R.deriveSeed(seed, 9)) });
    return { match: m, summary: summarise(fixture, m, xis, seed) };
  }

  function summarise(fixture, m, xis, seed) {
    const inn = (r) => ({
      teamId: r.xi.team.id, total: r.total, wickets: r.wickets, balls: r.balls, target: r.target, phaseRuns: r.phaseRuns,
      batters: r.batters.map((b) => ({ id: b.player.id, pos: b.position, runs: b.runs, balls: b.balls, fours: b.fours, sixes: b.sixes, out: b.out, how: b.how, bowlerId: b.dismissedBy ? b.dismissedBy.id : null, fielderId: b.fielder ? b.fielder.id : null })),
      bowlers: r.bowlers.map((c) => ({ id: c.player.id, balls: c.balls, runs: c.runs, wkts: c.wickets, dots: c.dots })),
      fall: r.fall.map((f) => ({ w: f.wicket, score: f.score, ball: f.ball, batterId: f.batter.player.id })),
    });
    return {
      fixtureId: fixture.id, homeId: fixture.homeId, awayId: fixture.awayId, seed, xis,
      homeBatsFirst: m.homeBatsFirst, outcome: m.outcome, marginRuns: m.marginRuns, marginWickets: m.marginWickets,
      ballsRemaining: m.ballsRemaining, resultLine: m.resultLine(), innings: [inn(m.innings1), inn(m.innings2)],
    };
  }

  function commitResult(state, fixture, summary) {
    fixture.result = summary;
    S.applyResult(state.stats, state.season.no, summary);
    advanceStage(state);
  }

  // Play a fixture instantly and record it.
  function playFixture(state, fixture) {
    const { summary } = simulateFixture(state, fixture);
    commitResult(state, fixture, summary);
    return summary;
  }

  // Simulate every AI-only fixture in the same round as `fixture` (before the
  // user's match is shown, so the table is current afterwards).
  function playOthersInRound(state, fixture) {
    for (const f of roundOf(state, fixture)) if (!f.result && f.id !== fixture.id && f.homeId !== state.userTeamId && f.awayId !== state.userTeamId) playFixture(state, f);
  }
  function playRound(state) {
    const f = nextFixture(state);
    if (!f) return null;
    for (const g of roundOf(state, f)) if (!g.result) playFixture(state, g);
    return f.round;
  }
  function simToEndOfSeason(state) { let guard = 0; while (state.season.stage !== 'done' && guard++ < 50) playRound(state); }

  function advanceStage(state) {
    const s = state.season;
    if (s.stage === 'league' && s.fixtures.filter((f) => f.stage === 'league').every((f) => f.result)) {
      const rows = L.table(state.teams, s.fixtures);
      s.fixtures.push(...L.makeSemis(rows, s.fixtures.length + 1));
      s.stage = 'semis';
    } else if (s.stage === 'semis') {
      const semis = s.fixtures.filter((f) => f.stage === 'semi');
      if (semis.every((f) => f.result)) { s.fixtures.push(L.makeFinal(semis, s.fixtures.length + 1)); s.stage = 'final'; }
    } else if (s.stage === 'final') {
      const fin = s.fixtures.find((f) => f.stage === 'final');
      if (fin && fin.result) { s.stage = 'done'; s.champion = L.playoffWinner(fin); state.honours.push({ season: s.no, champion: s.champion }); }
    }
  }

  // ---- live match ---------------------------------------------------------
  // Start a live replay of the user's next fixture: AI fixtures of the round
  // are played first, the match is simulated, and only the replay position is
  // stored (events regenerate from seed + XIs).
  function startLive(state, fixture) {
    const err = validateUserXI(state, state.userXI);
    if (err) throw new Error(err);
    playOthersInRound(state, fixture);
    const xis = { home: xiSpecFor(state, fixture.homeId), away: xiSpecFor(state, fixture.awayId) };
    state.live = { fixtureId: fixture.id, xis, cursor: 0, playing: false, anchorMs: null, anchorCursor: 0, speed: 1 };
    return liveMatch(state);
  }
  // Re-simulate the live fixture (deterministic) for the replay.
  function liveMatch(state) {
    const f = fixtureById(state, state.live.fixtureId);
    return simulateFixture(state, f, state.live.xis);
  }
  function finishLive(state, sim) {
    const f = fixtureById(state, state.live.fixtureId);
    commitResult(state, f, sim.summary);
    state.live = null;
    return f;
  }

  // ---- season rollover ----------------------------------------------------
  function nextSeason(state) {
    for (const p of Object.values(state.players)) {
      const before = G.ageFactor(p.age), after = G.ageFactor(p.age + 1);
      p.age += 1;
      const k = after / before;
      for (const a of ['power', 'composure', 'attack', 'control']) p.attrs[a] = Math.round(p.attrs[a] * k * 100) / 100;
    }
    startSeason(state, state.season.no + 1);
    state.live = null;
    return state;
  }

  // ---- save ---------------------------------------------------------------
  function serialize(state) { return JSON.stringify(state); }
  function deserialize(text) {
    const s = JSON.parse(text);
    if (!s || typeof s !== 'object' || !s.version) throw new Error('not a Cricket save');
    return migrate(s);
  }
  function migrate(s) {
    // Add migrations here as the format grows: if (s.version === 1) {...; s.version = 2;}
    if (s.version > SAVE_VERSION) throw new Error(`save is from a newer game (v${s.version})`);
    s.settings = s.settings || { ballMs: 3000 };
    return s;
  }

  return (Cricket.game = {
    SAVE_VERSION, newLeague, chooseTeam, startSeason, teamById, squadOf, fixtureById, userFixtures, nextFixture, nextUserFixture, roundOf,
    visible, visibleSquad, suggestXI, suggestFrom, validateUserXI, aiXI, matchSeed, simulateFixture, playFixture, playOthersInRound, playRound,
    simToEndOfSeason, startLive, liveMatch, finishLive, nextSeason, serialize, deserialize, migrate,
  });
});
