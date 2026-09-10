'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { M, mockSquad, xis, itun } = require('./helpers.js');
const W = require('../src/engine/bowling.js');

test('phase bonus values', () => {
  const t = itun();
  assert.equal(W.phaseBonus('PACE', 1, t), 9.375); assert.equal(W.phaseBonus('SPIN', 1, t), -9.375);
  assert.equal(W.phaseBonus('SPIN', 10, t), 9.375); assert.equal(W.phaseBonus('PACE', 20, t), 9.375);
});
test('preferred kind is textbook', () => {
  assert.deepEqual([1, 6, 7, 15, 16, 20].map(W.preferredKind), ['PACE', 'PACE', 'SPIN', 'SPIN', 'PACE', 'PACE']);
});
test('rotation is legal for many teams', () => {
  for (let seed = 1; seed < 200; seed++) {
    for (const xi of [M.pickXI({ name: 'a' }, mockSquad(seed)), M.pickXI({ name: 'b' }, mockSquad(seed + 5000, 50))]) {
      const plan = W.rotation(xi.bowlers, itun());
      assert.equal(plan.length, 20);
      const ids = new Set(xi.bowlers.map((b) => b.id));
      for (const b of plan) assert.ok(ids.has(b.id));
      for (const b of xi.bowlers) assert.ok(plan.filter((x) => x.id === b.id).length <= 4);
      for (let i = 1; i < plan.length; i++) assert.notEqual(plan[i].id, plan[i - 1].id, 'no consecutive overs');
    }
  }
});
test('rotation prefers pace in powerplay and spin in the middle', () => {
  let hits = 0, total = 0;
  for (let seed = 1; seed < 100; seed++) {
    const [h] = xis(seed);
    W.rotation(h.bowlers, itun()).forEach((b, i) => { total++; if (b.kind === W.preferredKind(i + 1)) hits++; });
  }
  assert.ok(hits / total > 0.8);
});
test('rotation is deterministic', () => {
  const [h] = xis(5);
  assert.deepEqual(W.rotation(h.bowlers, itun()).map((b) => b.id), W.rotation(h.bowlers, itun()).map((b) => b.id));
});
