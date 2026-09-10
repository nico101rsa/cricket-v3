'use strict';
const T = require('../src/engine/tuning.js');
const R = require('../src/engine/rng.js');
const M = require('../src/engine/model.js');

// Archetype squads with +-20% jitter (the shape of the old Python mock):
// 7 batters, 2 all-rounders, 6 bowlers alternating pace/spin.
function mockSquad(seed, idOffset = 0) {
  const rng = R.makeRng(seed);
  const j = (v) => v * (1 + rng.uniform(-0.2, 0.2));
  const squad = [];
  let id = idOffset;
  const add = (role, kind, bat, bowl) => {
    const tilt = role === 'BATTER' ? 0 : 12.5;
    const attack = kind === 'PACE' ? bowl + tilt : Math.max(6.25, bowl - tilt);
    const control = kind === 'PACE' ? Math.max(6.25, bowl - tilt) : bowl + tilt;
    squad.push(M.makePlayer(id, 'P', `S${id}`, rng.range(19, 35), role, kind,
      { power: j(bat), composure: j(bat), attack: j(attack), control: j(control) }));
    id += 1;
  };
  for (let i = 0; i < 7; i++) add('BATTER', i % 2 ? 'SPIN' : 'PACE', 50, 12.5);
  for (let i = 0; i < 2; i++) add('ALLROUNDER', i % 2 ? 'SPIN' : 'PACE', 31.25, 31.25);
  for (let i = 0; i < 6; i++) add('BOWLER', i % 2 ? 'SPIN' : 'PACE', 6.25, 31.25);
  return squad;
}

function xis(seed = 1) {
  const home = { id: 1, name: 'Home CC', city: 'Cape Town', country: 'SA' };
  const away = { id: 2, name: 'Away CC', city: 'Sydney', country: 'AUS' };
  return [M.pickXI(home, mockSquad(seed, 0)), M.pickXI(away, mockSquad(seed + 1000, 100))];
}

// Every player identical: handy for directional tests.
function uniformXI(name, bat, bowl, idOffset = 0) {
  const ps = [];
  for (let i = 0; i < 11; i++) {
    ps.push(M.makePlayer(idOffset + i, 'P', `${name}${i}`, 25, 'ALLROUNDER', i % 2 ? 'PACE' : 'SPIN',
      { power: bat, composure: bat, attack: bowl, control: bowl }));
  }
  return M.makeXI({ id: idOffset, name, city: 'Cape Town', country: 'SA' }, ps, ps.slice(0, 5));
}

const mean = (xs) => xs.reduce((a, b) => a + b, 0) / xs.length;

module.exports = { T, R, M, mockSquad, xis, uniformXI, mean, tuning: T.ballTuning, itun: T.inningsTuning };
