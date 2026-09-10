'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const I = require('../src/engine/intent.js');
const { Intent } = I;

test('phaseOf maps boundaries', () => {
  assert.deepEqual([1, 6, 7, 15, 16, 20].map(I.phaseOf), [0, 0, 1, 1, 2, 2]);
});
test('forOver reads phase bands', () => {
  const p = I.textbook();
  assert.equal(p.forOver(3), Intent.AGGRESSIVE); assert.equal(p.forOver(10), Intent.BALANCED); assert.equal(p.forOver(18), Intent.AGGRESSIVE);
});
test('static plan ignores state', () => {
  assert.equal(I.balanced().forState(10, 20, 8, 60, 200, 120), Intent.BALANCED);
});
test('chase rules escalate and de-escalate', () => {
  const p = I.adaptive();
  assert.equal(p.forState(10, 80, 2, 60, 200, 120), Intent.AGGRESSIVE);
  assert.equal(p.forState(10, 180, 2, 60, 200, 120), Intent.BALANCED);
  assert.equal(p.forState(10, 80, 2, 60, 0, 120), Intent.AGGRESSIVE);
});
test('collapse protection never overrides a chase escalation', () => {
  const p = I.adaptive();
  assert.equal(p.forState(10, 80, 6, 60, 200, 120), Intent.AGGRESSIVE);
  assert.equal(p.forState(10, 80, 6, 60, 0, 120), Intent.BALANCED);
  assert.equal(p.forState(10, 180, 6, 60, 200, 120), Intent.DEFENSIVE);
});
test('bands clamp', () => {
  const p = I.makePlan(Intent.DEFENSIVE, Intent.DEFENSIVE, Intent.DEFENSIVE, { chase_down_rr: 5.0, collapse_wkts: 1 });
  assert.equal(p.forState(10, 180, 6, 60, 200, 120), Intent.DEFENSIVE);
});
test('presets exist and differ', () => {
  const keys = Object.keys(I.PRESETS);
  assert.deepEqual(keys, ['cautious', 'balanced', 'attacking']);
  assert.ok(I.presetPlan('attacking').forOver(1) > I.presetPlan('cautious').forOver(1));
  assert.equal(I.presetPlan('nonsense').forOver(10), I.adaptive().forOver(10));
});
