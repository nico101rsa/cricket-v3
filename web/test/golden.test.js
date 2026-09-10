'use strict';
// Python parity: replay the recorded rng tape from the Python sim through the
// JS engine and demand the identical scorecard, ball for ball, tape fully
// consumed. Regenerate with `python3 web/tools/make_golden.py > web/test/golden.json`.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { T, M } = require('./helpers.js');
const X = require('../src/engine/match.js');
const I = require('../src/engine/intent.js');

const golden = JSON.parse(fs.readFileSync(path.join(__dirname, 'golden.json'), 'utf8'));
const PLANS = { balanced: I.balanced, textbook: I.textbook, adaptive: I.adaptive };

function tapeRng(tape) {
  let i = 0;
  return { random() { if (i >= tape.length) throw new Error('tape exhausted'); return tape[i++]; }, get used() { return i; } };
}
const inn = (r) => ({
  total: r.total, wickets: r.wickets, balls: r.balls,
  batters: r.batters.map((b) => ({ id: b.player.id, runs: b.runs, balls: b.balls, out: b.out, dismissedById: b.dismissedBy ? b.dismissedBy.id : null, fours: b.fours, sixes: b.sixes })),
  bowlers: r.bowlers.map((c) => ({ id: c.player.id, balls: c.balls, runs: c.runs, wickets: c.wickets, dots: c.dots })),
  fall: r.fall.map((f) => [f.wicket, f.score, f.ball]),
  phaseRuns: r.phaseRuns,
});

test(`golden tape: ${golden.cases.length} Python matches reproduce ball for ball`, () => {
  for (const c of golden.cases) {
    const mk = (t) => ({ team: { id: t.name, name: t.name, city: t.city, country: t.country }, squad: t.squad.map((p) => M.makePlayer(p.id, p.firstName, p.surname, p.age, p.role, p.kind, p.attrs)) });
    const h = mk(c.home), a = mk(c.away);
    const hxi = M.pickXI(h.team, h.squad), axi = M.pickXI(a.team, a.squad);
    assert.deepEqual(hxi.order.map((p) => p.id), c.homeXI.order, `seed ${c.seed} home order`);
    assert.deepEqual(hxi.bowlers.map((p) => p.id), c.homeXI.bowlers, `seed ${c.seed} home bowlers`);
    assert.deepEqual(axi.order.map((p) => p.id), c.awayXI.order, `seed ${c.seed} away order`);
    assert.deepEqual(axi.bowlers.map((p) => p.id), c.awayXI.bowlers, `seed ${c.seed} away bowlers`);
    const rng = tapeRng(c.tape);
    const m = X.simulateMatch(hxi, axi, T.ballTuning(), T.inningsTuning(), rng, PLANS[c.homePlan](), PLANS[c.awayPlan]());
    const e = c.expected;
    assert.equal(m.homeBatsFirst, e.homeBatsFirst, `seed ${c.seed} toss`);
    assert.deepEqual(inn(m.innings1), e.innings1, `seed ${c.seed} innings 1`);
    assert.deepEqual(inn(m.innings2), e.innings2, `seed ${c.seed} innings 2`);
    assert.equal(m.outcome, e.outcome, `seed ${c.seed} outcome`);
    assert.deepEqual([m.marginRuns, m.marginWickets, m.ballsRemaining], [e.marginRuns, e.marginWickets, e.ballsRemaining], `seed ${c.seed} margin`);
    assert.equal(rng.used, c.tape.length, `seed ${c.seed} tape fully consumed`);
  }
});
