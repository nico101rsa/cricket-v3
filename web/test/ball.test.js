'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { R, tuning } = require('./helpers.js');
const B = require('../src/engine/ball.js');
const { RUN_VALUES } = require('../src/engine/tuning.js');
const { Intent } = B;
const EVEN = 31.25;

function wicketRate(power, comp, attack, control, intent, seed, n, kind) {
  const rng = R.makeRng(seed);
  let w = 0;
  for (let i = 0; i < n; i++) if (B.resolveBall(power, comp, attack, control, intent, tuning(), rng, kind).wicket) w++;
  return w / n;
}
function meanRuns(power, comp, attack, control, intent, seed, n) {
  const rng = R.makeRng(seed);
  let total = 0, balls = 0;
  for (let i = 0; i < n; i++) {
    const o = B.resolveBall(power, comp, attack, control, intent, tuning(), rng);
    if (!o.wicket) { total += o.runs; balls++; }
  }
  return total / balls;
}

test('blended distribution sums to one', () => {
  for (const s of [0, 0.25, 0.5, 0.75, 1]) assert.ok(Math.abs(B.blendedDistribution(s, tuning()).reduce((a, b) => a + b) - 1) < 1e-9);
});
test('blend endpoints match anchor shapes', () => {
  const d = B.blendedDistribution(0, tuning()), a = B.blendedDistribution(1, tuning());
  assert.ok(a[4] > d[4]); assert.ok(d[0] > a[0]);
});
test('higher s raises expected runs', () => {
  const ev = (p) => p.reduce((acc, x, i) => acc + x * RUN_VALUES[i], 0);
  assert.ok(ev(B.blendedDistribution(0.8, tuning())) > ev(B.blendedDistribution(0.2, tuning())));
});
test('same seed gives identical sequence', () => {
  const a = R.makeRng(12345), b = R.makeRng(12345);
  for (let i = 0; i < 200; i++) assert.deepEqual(B.resolveBall(EVEN, EVEN, EVEN, EVEN, Intent.BALANCED, tuning(), a), B.resolveBall(EVEN, EVEN, EVEN, EVEN, Intent.BALANCED, tuning(), b));
});
test('runs in alphabet and a wicket scores zero', () => {
  const rng = R.makeRng(999);
  for (let i = 0; i < 500; i++) {
    const o = B.resolveBall(37.5, 37.5, 37.5, 37.5, Intent.BALANCED, tuning(), rng);
    assert.ok(RUN_VALUES.includes(o.runs));
    if (o.wicket) assert.equal(o.runs, 0);
  }
});
test('even contest wicket rate near 3.5% per ball', () => {
  assert.ok(Math.abs(wicketRate(EVEN, EVEN, EVEN, EVEN, Intent.BALANCED, 2024, 20000) - 0.035) < 0.008);
  assert.ok(Math.abs(B.wicketProbability(EVEN, EVEN, Intent.BALANCED, tuning()) - 0.035) < 1e-4);
});
test('higher attack raises wicket rate', () => {
  assert.ok(wicketRate(EVEN, EVEN, 56.25, EVEN, Intent.BALANCED, 77, 20000) > wicketRate(EVEN, EVEN, 25, EVEN, Intent.BALANCED, 77, 20000));
});
test('higher power raises mean runs', () => {
  assert.ok(meanRuns(56.25, EVEN, EVEN, EVEN, Intent.BALANCED, 88, 20000) > meanRuns(25, EVEN, EVEN, EVEN, Intent.BALANCED, 88, 20000));
});
test('aggressive intent raises both wickets and runs', () => {
  assert.ok(wicketRate(EVEN, EVEN, EVEN, EVEN, Intent.AGGRESSIVE, 55, 20000) > wicketRate(EVEN, EVEN, EVEN, EVEN, Intent.DEFENSIVE, 55, 20000));
  assert.ok(meanRuns(EVEN, EVEN, EVEN, EVEN, Intent.AGGRESSIVE, 66, 20000) > meanRuns(EVEN, EVEN, EVEN, EVEN, Intent.DEFENSIVE, 66, 20000));
});
test('extreme mismatch stays valid', () => {
  const r1 = R.makeRng(3), r2 = R.makeRng(4);
  for (let i = 0; i < 200; i++) {
    assert.ok(RUN_VALUES.includes(B.resolveBall(618.75, 618.75, 6.25, 6.25, Intent.AGGRESSIVE, tuning(), r1).runs));
    assert.ok(RUN_VALUES.includes(B.resolveBall(6.25, 6.25, 618.75, 618.75, Intent.DEFENSIVE, tuning(), r2).runs));
  }
});
test('slogging spin is riskier than slogging pace', () => {
  const t = tuning();
  assert.ok(B.wicketProbability(EVEN, EVEN, Intent.AGGRESSIVE, t, 'SPIN') > B.wicketProbability(EVEN, EVEN, Intent.AGGRESSIVE, t, 'PACE'));
  assert.equal(B.wicketProbability(EVEN, EVEN, Intent.AGGRESSIVE, t, 'PACE'), B.wicketProbability(EVEN, EVEN, Intent.AGGRESSIVE, t, undefined));
});
