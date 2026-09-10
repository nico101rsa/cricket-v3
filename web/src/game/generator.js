// League generator with real variance. Ten clubs, five each from two cities,
// with hidden team tiers, stars and passengers, varied squad shapes and age
// profiles, so that a season of stats actually says something about players.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}), typeof require === 'function' ? require : null);
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket, require) {
  const R = require ? require('../engine/rng.js') : Cricket.rng;
  const M = require ? require('../engine/model.js') : Cricket.model;
  const N = require ? require('./names.js') : Cricket.names;

  const TIERS = [1.15, 1.10, 1.05, 1.0, 1.0, 1.0, 0.95, 0.95, 0.90, 0.85];
  const AGE_PROFILES = { young: 24, mixed: 27, veteran: 30 };
  const STAR_Q = 1.35;     // hidden quality at or above this = a star
  const PASSENGER_Q = 0.75;
  const QUALITY_SD = 0.28; // lognormal spread of individual quality

  // Form curve by age: peak 25-31, a little green before, fading after.
  function ageFactor(age) {
    if (age <= 21) return 0.90;
    if (age <= 24) return 0.95;
    if (age <= 31) return 1.0;
    if (age <= 33) return 0.96;
    if (age <= 35) return 0.92;
    return 0.87;
  }

  const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
  const round2 = (x) => Math.round(x * 100) / 100;
  const quality = (rng) => clamp(Math.exp(QUALITY_SD * rng.gauss()), 0.5, 1.8);

  function makePlayerFor(rng, id, role, kind, country, tier, meanAge, used) {
    let first, surname, tries = 0;
    do {
      first = rng.pick(N.FIRST_NAMES[country]);
      surname = rng.pick(N.SURNAMES[country]);
      tries += 1;
    } while (used.has(surname) && tries < 50);
    used.add(surname);
    const age = clamp(Math.round(meanAge + 4 * rng.gauss()), 18, 38);
    const af = ageFactor(age);
    const qBat = quality(rng), qBowl = quality(rng);
    const j = () => 1 + 0.08 * rng.gauss();
    let bat, bowl;
    if (role === 'BATTER') { bat = 50; bowl = 12.5; }
    else if (role === 'ALLROUNDER') { bat = 31.25; bowl = 31.25; }
    else { bat = 6.25; bowl = 31.25; }
    const tilt = role === 'BATTER' ? 0 : 12.5;
    const attackBase = kind === 'PACE' ? bowl + tilt : Math.max(6.25, bowl - tilt);
    const controlBase = kind === 'PACE' ? Math.max(6.25, bowl - tilt) : bowl + tilt;
    const B = bat * qBat * tier * af, W = qBowl * tier * af;
    const attrs = {
      power: round2(clamp(B * j(), 3, 95)),
      composure: round2(clamp(B * j(), 3, 95)),
      attack: round2(clamp(attackBase * W * j(), 3, 95)),
      control: round2(clamp(controlBase * W * j(), 3, 95)),
    };
    const p = M.makePlayer(id, first, surname, age, role, kind, attrs);
    p.q = role === 'BOWLER' ? qBowl : role === 'BATTER' ? qBat : (qBat + qBowl) / 2; // hidden: for blurbs/tests only
    return p;
  }

  function squadShape(rng) {
    const batters = rng.range(6, 8);
    const ars = rng.range(1, 3);
    const bowlers = 15 - batters - ars;
    const pace = clamp(Math.round(bowlers * rng.uniform(0.3, 0.7)), 2, bowlers - 2);
    return { batters, ars, bowlers, pace, spin: bowlers - pace };
  }

  function blurbFor(rng, team, squad) {
    const spinners = squad.filter((p) => p.role !== 'BATTER' && p.kind === 'SPIN').length;
    const pacers = squad.filter((p) => p.role !== 'BATTER' && p.kind === 'PACE').length;
    const batters = squad.filter((p) => p.role === 'BATTER').length;
    const ars = squad.filter((p) => p.role === 'ALLROUNDER').length;
    const stars = squad.filter((p) => p.q >= STAR_Q).length;
    const meanAge = squad.reduce((a, p) => a + p.age, 0) / squad.length;
    const ageLine = meanAge < 25.5 ? 'Young legs, thin CVs' : meanAge > 28.5 ? 'Old heads, long memories' : 'A settled, mixed-age group';
    let shape;
    if (batters >= 8) shape = 'Bats a long way down';
    else if (spinners >= 4) shape = 'Spin, spin and more spin';
    else if (pacers >= 5) shape = 'A pace battery';
    else if (ars >= 3) shape = 'All-rounders everywhere';
    else if (batters <= 6) shape = 'Bowling-heavy, batting-light';
    else shape = 'Balanced on paper';
    const starLine = stars === 0 ? 'no household names' : stars === 1 ? 'one name everyone knows' : 'big names, big egos';
    // Tier mood, deliberately fuzzed one step a quarter of the time.
    let mood = team.tier >= 1.05 ? 2 : team.tier <= 0.95 ? 0 : 1;
    if (rng.random() < 0.25) mood = clamp(mood + (rng.random() < 0.5 ? -1 : 1), 0, 2);
    const moodLine = ['a rebuilding year', 'could go either way', 'expected to challenge'][mood];
    return `${ageLine}. ${shape}, ${starLine}. Word is ${moodLine}.`;
  }

  // Three-letter abbreviations, unique within the league.
  function assignAbbrs(teams) {
    const used = new Set();
    for (const t of teams) {
      const words = t.name.replace(/[^A-Za-z ]/g, '').split(' ').filter(Boolean);
      const cands = [words[0].slice(0, 3), words.map((w) => w[0]).join('').slice(0, 3), words[0].slice(0, 2) + (words[1] ? words[1][0] : 'X'), words[0].slice(0, 1) + words[0].slice(-2)];
      let abbr = cands.map((c) => c.toUpperCase()).find((c) => c.length === 3 && !used.has(c));
      if (!abbr) { let i = 1; while (used.has((words[0].slice(0, 2) + i).toUpperCase())) i++; abbr = (words[0].slice(0, 2) + i).toUpperCase(); }
      used.add(abbr); t.abbr = abbr;
    }
  }

  // Build the league. Returns plain data: teams with squadIds, players keyed by id.
  function generateLeague(seed, cityA = 'Pretoria', cityB = 'Sydney') {
    const rng = R.makeRng(R.deriveSeed(seed, 1));
    const tiers = rng.shuffle(TIERS);
    const clubsA = rng.shuffle(N.CLUBS[cityA]).slice(0, 5);
    const clubsB = rng.shuffle(N.CLUBS[cityB]).slice(0, 5);
    const specs = clubsA.map((name) => ({ name, city: cityA })).concat(clubsB.map((name) => ({ name, city: cityB })));
    const teams = [], players = {};
    let nextId = 1;
    specs.forEach((spec, i) => {
      const country = N.countryOfCity(spec.city);
      const tier = tiers[i];
      const profile = rng.pick(['young', 'mixed', 'mixed', 'veteran']);
      const team = { id: i + 1, name: spec.name, city: spec.city, country, tier, ageProfile: profile, blurb: '', squadIds: [] };
      const shape = squadShape(rng);
      const used = new Set();
      const squad = [];
      const add = (role, kind) => {
        const p = makePlayerFor(rng, nextId++, role, kind, country, tier, AGE_PROFILES[profile], used);
        players[p.id] = p; squad.push(p); team.squadIds.push(p.id);
      };
      for (let k = 0; k < shape.batters; k++) add('BATTER', rng.random() < 0.5 ? 'PACE' : 'SPIN');
      for (let k = 0; k < shape.ars; k++) add('ALLROUNDER', rng.random() < 0.5 ? 'PACE' : 'SPIN');
      for (let k = 0; k < shape.pace; k++) add('BOWLER', 'PACE');
      for (let k = 0; k < shape.spin; k++) add('BOWLER', 'SPIN');
      team.blurb = blurbFor(rng, team, squad);
      teams.push(team);
    });
    assignAbbrs(teams);
    return { seed, teams, players };
  }

  return (Cricket.generator = { generateLeague, ageFactor, STAR_Q, PASSENGER_Q, TIERS, blurbFor });
});
