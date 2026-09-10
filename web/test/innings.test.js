'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { R, xis, uniformXI, mean, tuning, itun } = require('./helpers.js');
const { simulateInnings } = require('../src/engine/innings.js');
const I = require('../src/engine/intent.js');

test('same seed gives identical innings', () => {
  const [h, a] = xis(3);
  const r1 = simulateInnings(h, a, tuning(), itun(), R.makeRng(9));
  const r2 = simulateInnings(h, a, tuning(), itun(), R.makeRng(9));
  assert.deepEqual([r1.total, r1.wickets, r1.balls], [r2.total, r2.wickets, r2.balls]);
  assert.deepEqual(r1.fall.map((f) => f.score), r2.fall.map((f) => f.score));
});
test('termination bounds and accounting', () => {
  for (let seed = 1; seed < 60; seed++) {
    const [h, a] = xis(seed);
    const r = simulateInnings(h, a, tuning(), itun(), R.makeRng(seed), I.adaptive(), 0, { cosmetic: R.makeRng(seed + 7) });
    assert.ok(r.balls <= 120 && r.wickets <= 10);
    assert.equal(r.batters.length, 11);
    const sum = (xs, k) => xs.reduce((acc, x) => acc + x[k], 0);
    assert.equal(sum(r.batters, 'balls'), r.balls); assert.equal(sum(r.bowlers, 'balls'), r.balls);
    assert.equal(sum(r.batters, 'runs'), r.total); assert.equal(sum(r.bowlers, 'runs'), r.total);
    assert.equal(r.batters.filter((b) => b.out).length, r.wickets); assert.equal(sum(r.bowlers, 'wickets'), r.wickets);
    assert.equal(r.phaseRuns.reduce((x, y) => x + y), r.total);
    assert.equal(r.fall.length, r.wickets);
    assert.deepEqual(r.fall.map((f) => f.wicket), r.fall.map((_, i) => i + 1));
    for (const b of r.batters) assert.equal(b.out, b.dismissedBy !== null);
    assert.equal(r.bowlers.length, 5);
    // The event log reduces to the cards.
    assert.equal(r.events.length, r.balls);
    const last = r.events[r.events.length - 1];
    assert.equal(last.total, r.total); assert.equal(last.wickets, r.wickets);
    const perBatter = new Map();
    for (const e of r.events) {
      const c = perBatter.get(e.strikerId) || { runs: 0, balls: 0 };
      c.runs += e.runs; c.balls += 1; perBatter.set(e.strikerId, c);
      if (e.wicket) assert.ok(['b', 'c', 'c&b', 'lbw', 'st'].includes(e.how));
    }
    for (const b of r.batters) if (b.balls) assert.deepEqual(perBatter.get(b.player.id), { runs: b.runs, balls: b.balls });
  }
});
test('all out stops immediately', () => {
  const weak = uniformXI('Weak', 6.25, 6.25), strong = uniformXI('Strong', 60, 60, 50);
  let seen = false;
  for (let seed = 1; seed < 20; seed++) {
    const r = simulateInnings(weak, strong, tuning(), itun(), R.makeRng(seed));
    if (r.wickets === 10) { seen = true; assert.ok(r.balls < 120); }
  }
  assert.ok(seen);
});
test('chase stops at target', () => {
  const [h, a] = xis(2);
  const r = simulateInnings(h, a, tuning(), itun(), R.makeRng(1), I.adaptive(), 60);
  assert.ok(r.total >= 60 && r.total < 66 && r.balls < 120);
});
test('even contest total in a sane T20 band (balanced plan)', () => {
  const totals = [];
  for (let seed = 1; seed < 120; seed++) { const [h, a] = xis(seed); totals.push(simulateInnings(h, a, tuning(), itun(), R.makeRng(seed)).total); }
  const m = mean(totals); assert.ok(m >= 110 && m <= 175, `mean ${m}`);
});
test('textbook mirror scores in the tuned band', () => {
  const totals = [];
  for (let seed = 1; seed < 300; seed++) { const [h, a] = xis(seed); totals.push(simulateInnings(h, a, tuning(), itun(), R.makeRng(seed), I.textbook()).total); }
  const m = mean(totals); assert.ok(m >= 145 && m <= 172, `mean ${m}`);
});
test('stronger bowling concedes less', () => {
  const bat = uniformXI('Bat', 50, 12.5), weak = uniformXI('Weak', 30, 20, 50), strong = uniformXI('Strong', 30, 45, 100);
  const w = mean(Array.from({ length: 40 }, (_, s) => simulateInnings(bat, weak, tuning(), itun(), R.makeRng(s)).total));
  const s = mean(Array.from({ length: 40 }, (_, i) => simulateInnings(bat, strong, tuning(), itun(), R.makeRng(i)).total));
  assert.ok(s < w);
});
test('cosmetic rng never changes the cricket', () => {
  const [h, a] = xis(11);
  const r1 = simulateInnings(h, a, tuning(), itun(), R.makeRng(4), I.adaptive(), 0, { cosmetic: R.makeRng(1) });
  const r2 = simulateInnings(h, a, tuning(), itun(), R.makeRng(4), I.adaptive(), 0, { cosmetic: R.makeRng(2) });
  assert.deepEqual([r1.total, r1.wickets, r1.balls], [r2.total, r2.wickets, r2.balls]);
});
