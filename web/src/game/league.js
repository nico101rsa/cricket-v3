// Fixtures, the points table with net run rate, and the playoffs.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}));
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket) {
  // Circle-method single round robin: n teams -> n-1 rounds of n/2 matches,
  // every team plays once per round. Home advantage is handed out greedily
  // so every team ends up with 4 or 5 home games.
  function roundRobin(teamIds) {
    const ids = teamIds.slice();
    if (ids.length % 2) ids.push(null);
    const n = ids.length, rounds = [];
    const homes = new Map(ids.map((id) => [id, 0]));
    const last = new Map(ids.map((id) => [id, null]));
    let ring = ids.slice(1);
    for (let r = 0; r < n - 1; r++) {
      const left = [ids[0]].concat(ring.slice(0, n / 2 - 1));
      const right = ring.slice(n / 2 - 1).reverse();
      const matches = [];
      for (let i = 0; i < n / 2; i++) {
        const a = left[i], b = right[i];
        if (a === null || b === null) continue;
        let home = a, away = b;
        const da = homes.get(a), db = homes.get(b);
        if (db < da || (db === da && last.get(b) === 'A' && last.get(a) !== 'A')) { home = b; away = a; }
        homes.set(home, homes.get(home) + 1);
        last.set(home, 'H'); last.set(away, 'A');
        matches.push({ homeId: home, awayId: away });
      }
      rounds.push(matches);
      ring = [ring[ring.length - 1]].concat(ring.slice(0, -1));
    }
    return rounds;
  }

  function makeFixtures(teamIds) {
    const fixtures = [];
    roundRobin(teamIds).forEach((matches, r) => {
      matches.forEach((m) => fixtures.push({ id: fixtures.length + 1, round: r + 1, stage: 'league', homeId: m.homeId, awayId: m.awayId, result: null }));
    });
    return fixtures;
  }

  // Points table. An all-out innings counts as the full quota for NRR.
  function table(teams, fixtures, overLimit = 20) {
    const rows = new Map(teams.map((t) => [t.id, { teamId: t.id, name: t.name, p: 0, w: 0, l: 0, t: 0, pts: 0, rf: 0, bf: 0, ra: 0, ba: 0, nrr: 0 }]));
    for (const f of fixtures) {
      if (!f.result || f.stage !== 'league') continue;
      const r = f.result;
      for (const inn of r.innings) {
        const bat = rows.get(inn.teamId), bowl = rows.get(inn.teamId === r.homeId ? r.awayId : r.homeId);
        const balls = inn.wickets >= 10 ? overLimit * 6 : inn.balls;
        bat.rf += inn.total; bat.bf += balls; bowl.ra += inn.total; bowl.ba += balls;
      }
      const h = rows.get(r.homeId), a = rows.get(r.awayId);
      h.p += 1; a.p += 1;
      if (r.outcome === 'HOME_WIN') { h.w += 1; a.l += 1; h.pts += 2; }
      else if (r.outcome === 'AWAY_WIN') { a.w += 1; h.l += 1; a.pts += 2; }
      else { h.t += 1; a.t += 1; h.pts += 1; a.pts += 1; }
    }
    const out = [...rows.values()];
    for (const row of out) row.nrr = (row.bf ? 6 * row.rf / row.bf : 0) - (row.ba ? 6 * row.ra / row.ba : 0);
    out.sort((x, y) => (y.pts - x.pts) || (y.nrr - x.nrr) || (y.w - x.w) || x.name.localeCompare(y.name));
    out.forEach((row, i) => { row.pos = i + 1; });
    return out;
  }

  // Playoffs: 1 v 4, 2 v 3, then the final. Higher seed is home.
  function makeSemis(tableRows, nextId) {
    const s = tableRows;
    return [
      { id: nextId, round: 10, stage: 'semi', label: 'Semi-final 1', homeId: s[0].teamId, awayId: s[3].teamId, result: null },
      { id: nextId + 1, round: 10, stage: 'semi', label: 'Semi-final 2', homeId: s[1].teamId, awayId: s[2].teamId, result: null },
    ];
  }
  // A tied playoff goes to the higher seed (the home side).
  const playoffWinner = (f) => (f.result.outcome === 'AWAY_WIN' ? f.awayId : f.homeId);
  function makeFinal(semis, nextId) {
    return { id: nextId, round: 11, stage: 'final', label: 'Final', homeId: playoffWinner(semis[0]), awayId: playoffWinner(semis[1]), result: null };
  }

  return (Cricket.league = { roundRobin, makeFixtures, table, makeSemis, makeFinal, playoffWinner });
});
