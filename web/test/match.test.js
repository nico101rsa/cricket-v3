'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { R, xis, tuning, itun } = require('./helpers.js');
const X = require('../src/engine/match.js');
const I = require('../src/engine/intent.js');
const inn = (xi, total, wickets, balls) => ({ xi, total, wickets, balls });

test('decide win by runs', () => {
  const [h, a] = xis(1);
  const r = X.decideResult(h, a, true, inn(h, 150, 8, 120), inn(a, 140, 9, 120), 120);
  assert.equal(r.outcome, X.Outcome.HOME_WIN); assert.equal(r.marginRuns, 10); assert.equal(r.marginWickets, 0);
  assert.equal(r.resultLine(), `${h.team.name} won by 10 runs`);
});
test('decide win by wickets', () => {
  const [h, a] = xis(1);
  const r = X.decideResult(h, a, false, inn(a, 140, 10, 120), inn(h, 141, 4, 112), 120);
  assert.equal(r.outcome, X.Outcome.HOME_WIN); assert.equal(r.marginWickets, 6); assert.equal(r.ballsRemaining, 8);
  assert.equal(r.resultLine(), `${h.team.name} won by 6 wickets (8 balls left)`);
});
test('decide tie', () => {
  const [h, a] = xis(1);
  const r = X.decideResult(h, a, true, inn(h, 150, 7, 120), inn(a, 150, 10, 120), 120);
  assert.equal(r.outcome, X.Outcome.TIE); assert.equal(r.winner, null); assert.equal(r.resultLine(), 'Match tied');
});
test('decide perspective away defends', () => {
  const [h, a] = xis(1);
  const r = X.decideResult(h, a, false, inn(a, 150, 8, 120), inn(h, 140, 9, 120), 120);
  assert.equal(r.outcome, X.Outcome.AWAY_WIN); assert.equal(r.marginRuns, 10);
});
test('same seed deterministic', () => {
  const [h, a] = xis(7);
  const r1 = X.simulateMatch(h, a, tuning(), itun(), R.makeRng(2024));
  const r2 = X.simulateMatch(h, a, tuning(), itun(), R.makeRng(2024));
  assert.deepEqual([r1.outcome, r1.innings1.total, r1.innings2.total, r1.marginRuns, r1.marginWickets],
    [r2.outcome, r2.innings1.total, r2.innings2.total, r2.marginRuns, r2.marginWickets]);
});
test('forced toss places sides', () => {
  const [h, a] = xis(7);
  let r = X.simulateMatch(h, a, tuning(), itun(), R.makeRng(1), null, null, { homeBatsFirst: true });
  assert.equal(r.innings1.xi, h); assert.equal(r.innings2.xi, a); assert.equal(r.tossWinner, h.team);
  r = X.simulateMatch(h, a, tuning(), itun(), R.makeRng(1), null, null, { homeBatsFirst: false });
  assert.equal(r.innings1.xi, a); assert.equal(r.innings2.xi, h);
});
test('outcome always valid and consistent', () => {
  for (let seed = 1; seed < 60; seed++) {
    const [h, a] = xis(seed);
    const r = X.simulateMatch(h, a, tuning(), itun(), R.makeRng(seed));
    assert.equal(r.innings2.target, r.innings1.total + 1);
    if (r.outcome === X.Outcome.TIE) assert.equal(r.innings1.total, r.innings2.total);
    else if (r.marginRuns > 0) { assert.equal(r.marginWickets, 0); assert.ok(r.innings1.total > r.innings2.total); }
    else { assert.ok(r.marginWickets > 0); assert.ok(r.innings2.total > r.innings1.total); }
  }
});
test('even contest roughly balanced', () => {
  let wins = 0, decided = 0;
  for (let seed = 1; seed < 200; seed++) {
    const [h, a] = xis(seed);
    const r = X.simulateMatch(h, a, tuning(), itun(), R.makeRng(seed), I.adaptive(), I.adaptive());
    if (r.outcome === X.Outcome.TIE) continue;
    decided++; if (r.outcome === X.Outcome.HOME_WIN) wins++;
  }
  assert.ok(wins / decided >= 0.35 && wins / decided <= 0.65);
});
