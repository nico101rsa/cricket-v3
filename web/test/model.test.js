'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { M, mockSquad } = require('./helpers.js');

test('pickXI shape', () => {
  for (let seed = 1; seed < 30; seed++) {
    const squad = mockSquad(seed);
    const xi = M.pickXI({ name: 't' }, squad);
    assert.equal(xi.order.length, 11); assert.equal(new Set(xi.order.map((p) => p.id)).size, 11);
    const roles = xi.order.map((p) => p.role);
    assert.deepEqual(roles.slice(0, 6), Array(6).fill('BATTER')); assert.equal(roles[6], 'ALLROUNDER'); assert.deepEqual(roles.slice(7), Array(4).fill('BOWLER'));
    const kinds = xi.order.slice(7).map((p) => p.kind);
    assert.equal(kinds.filter((k) => k === 'PACE').length, 2); assert.equal(kinds.filter((k) => k === 'SPIN').length, 2);
    assert.equal(xi.bowlers.length, 5);
    const best = xi.order.slice().sort((a, b) => M.bowling(b) - M.bowling(a)).slice(0, 5).map((p) => p.id);
    assert.deepEqual(new Set(xi.bowlers.map((p) => p.id)), new Set(best));
  }
});
test('XI validation', () => {
  const s = mockSquad(1);
  assert.throws(() => M.makeXI({}, s.slice(0, 10), s.slice(0, 5)));
  assert.throws(() => M.makeXI({}, s.slice(0, 11), s.slice(0, 4)));
  assert.throws(() => M.makeXI({}, s.slice(0, 11), s.slice(10, 15)));
  assert.throws(() => M.makeXI({}, s.slice(0, 10).concat([s[0]]), s.slice(0, 5)));
});
test('pickXI needs eleven', () => {
  assert.throws(() => M.pickXI({ name: 'Tiny' }, mockSquad(1).slice(0, 9)));
});
