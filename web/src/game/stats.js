// Per-player cricket stats: what the manager sees instead of attributes.
// Accumulated per season from scorecards; career = the sum of seasons.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}));
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket) {
  function emptySeason() {
    return {
      matches: 0,
      bat: { inns: 0, no: 0, runs: 0, balls: 0, hs: 0, hsNo: false, fours: 0, sixes: 0, ducks: 0, fifties: 0 },
      bowl: { balls: 0, runs: 0, wkts: 0, bestW: 0, bestR: 0, threes: 0 },
      last5: [], // most recent first: {runs, balls, out}
      last5b: [], // most recent first: {wkts, runs, balls}
    };
  }

  function addBatting(s, line) {
    if (line.balls === 0 && !line.out) return; // did not bat
    s.bat.inns += 1;
    if (!line.out) s.bat.no += 1;
    s.bat.runs += line.runs; s.bat.balls += line.balls;
    s.bat.fours += line.fours || 0; s.bat.sixes += line.sixes || 0;
    if (line.runs === 0 && line.out) s.bat.ducks += 1;
    if (line.runs >= 50) s.bat.fifties += 1;
    if (line.runs > s.bat.hs || (line.runs === s.bat.hs && !line.out && !s.bat.hsNo)) { s.bat.hs = line.runs; s.bat.hsNo = !line.out; }
    s.last5.unshift({ runs: line.runs, balls: line.balls, out: line.out });
    if (s.last5.length > 5) s.last5.length = 5;
  }

  function addBowling(s, line) {
    if (line.balls === 0) return;
    s.bowl.balls += line.balls; s.bowl.runs += line.runs; s.bowl.wkts += line.wkts;
    if (line.wkts > s.bowl.bestW || (line.wkts === s.bowl.bestW && line.runs < s.bowl.bestR)) { s.bowl.bestW = line.wkts; s.bowl.bestR = line.runs; }
    if (line.wkts >= 3) s.bowl.threes += 1;
    s.last5b = s.last5b || [];
    s.last5b.unshift({ wkts: line.wkts, runs: line.runs, balls: line.balls });
    if (s.last5b.length > 5) s.last5b.length = 5;
  }

  // Fold one stored match result into stats[playerId][seasonNo].
  function applyResult(stats, seasonNo, result) {
    const seen = new Set();
    const get = (id) => {
      stats[id] = stats[id] || {};
      stats[id][seasonNo] = stats[id][seasonNo] || emptySeason();
      return stats[id][seasonNo];
    };
    for (const inn of result.innings) {
      for (const b of inn.batters) { const s = get(b.id); if (!seen.has(b.id)) { s.matches += 1; seen.add(b.id); } addBatting(s, b); }
      for (const c of inn.bowlers) { const s = get(c.id); if (!seen.has(c.id)) { s.matches += 1; seen.add(c.id); } addBowling(s, c); }
    }
    // Everyone in both XIs played, even a batter who did not bat or bowl.
    for (const side of ['home', 'away']) for (const id of result.xis[side].order) { const s = get(id); if (!seen.has(id)) { s.matches += 1; seen.add(id); } }
  }

  function merge(a, b) {
    const s = emptySeason();
    for (const x of [a, b]) {
      if (!x) continue;
      s.matches += x.matches;
      for (const k of ['inns', 'no', 'runs', 'balls', 'fours', 'sixes', 'ducks', 'fifties']) s.bat[k] += x.bat[k];
      if (x.bat.hs > s.bat.hs || (x.bat.hs === s.bat.hs && x.bat.hsNo)) { s.bat.hs = x.bat.hs; s.bat.hsNo = x.bat.hsNo; }
      for (const k of ['balls', 'runs', 'wkts', 'threes']) s.bowl[k] += x.bowl[k];
      if (x.bowl.bestW > s.bowl.bestW || (x.bowl.bestW === s.bowl.bestW && x.bowl.bestR < s.bowl.bestR)) { s.bowl.bestW = x.bowl.bestW; s.bowl.bestR = x.bowl.bestR; }
    }
    s.last5 = (b && b.last5.length ? b.last5 : (a ? a.last5 : [])).slice(0, 5);
    const l5b = (x) => (x && x.last5b) || [];
    s.last5b = (l5b(b).length ? l5b(b) : l5b(a)).slice(0, 5);
    return s;
  }

  const seasonOf = (stats, id, seasonNo) => (stats[id] && stats[id][seasonNo]) || emptySeason();
  function careerOf(stats, id) {
    const all = stats[id] || {};
    const nos = Object.keys(all).map(Number).sort((a, b) => a - b);
    let acc = null;
    for (const n of nos) acc = merge(acc, all[n]);
    return acc || emptySeason();
  }

  // Display helpers.
  const oversText = (balls) => (balls % 6 ? `${Math.floor(balls / 6)}.${balls % 6}` : `${Math.floor(balls / 6)}`);
  const fmt1 = (x) => (Number.isFinite(x) ? x.toFixed(1) : '-');
  const fmt2 = (x) => (Number.isFinite(x) ? x.toFixed(2) : '-');
  function batAvg(s) { const outs = s.bat.inns - s.bat.no; return outs > 0 ? s.bat.runs / outs : (s.bat.inns ? Infinity : NaN); }
  function batSR(s) { return s.bat.balls ? 100 * s.bat.runs / s.bat.balls : NaN; }
  function bowlAvg(s) { return s.bowl.wkts ? s.bowl.runs / s.bowl.wkts : NaN; }
  function econ(s) { return s.bowl.balls ? 6 * s.bowl.runs / s.bowl.balls : NaN; }
  function hsText(s) { return s.bat.inns ? `${s.bat.hs}${s.bat.hsNo ? '*' : ''}` : '-'; }
  function bestText(s) { return s.bowl.balls ? `${s.bowl.bestW}/${s.bowl.bestR}` : '-'; }
  function avgText(s) { const a = batAvg(s); return a === Infinity ? `${s.bat.runs}*` : fmt1(a); }
  function last5Text(s) { return s.last5.length ? s.last5.map((x) => `${x.runs}${x.out ? '' : '*'}`).join(' ') : '-'; }
  function last5BowlText(s) { const l = s.last5b || []; return l.length ? l.map((x) => `${x.wkts}/${x.runs}`).join(' ') : '-'; }

  return (Cricket.stats = {
    emptySeason, applyResult, merge, seasonOf, careerOf, oversText, fmt1, fmt2, batAvg, batSR, bowlAvg, econ, hsText, bestText, avgText, last5Text, last5BowlText,
  });
});
