// One T20 innings, ball by ball, with named batters and named bowlers.
// Every ball: the striker's power/composure against the over's bowler
// (attack/control + that kind's phase bonus) at the batting side's intent for
// the match state. Strike rotates on odd runs and at the end of each over.
// Returns cards plus a ball-by-ball event log the UI replays.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}), typeof require === 'function' ? require : null);
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket, require) {
  const { resolveBall } = require ? require('./ball.js') : Cricket.ball;
  const { phaseOf, balanced } = require ? require('./intent.js') : Cricket.intent;
  const { phaseBonus, rotation } = require ? require('./bowling.js') : Cricket.bowling;

  const oversText = (balls) => (balls % 6 ? `${Math.floor(balls / 6)}.${balls % 6}` : `${Math.floor(balls / 6)}`);

  function batterCard(player, position) {
    return { player, position, runs: 0, balls: 0, fours: 0, sixes: 0, out: false, dismissedBy: null, how: null, fielder: null };
  }
  function bowlerCard(player) {
    return { player, balls: 0, runs: 0, wickets: 0, dots: 0 };
  }

  // Cosmetic dismissal mode and fielder. Uses its own rng (never the sim's) so
  // the flavour cannot change the cricket. The keeper is whoever bats at 6.
  function dismissal(bowler, fieldingXI, cosmetic) {
    if (!cosmetic) return { how: 'b', fielder: null };
    const r = cosmetic.random();
    const isSpin = bowler.kind === 'SPIN';
    if (r < 0.10) return { how: 'c&b', fielder: null };
    if (r < 0.55) {
      const others = fieldingXI.order.filter((p) => p.id !== bowler.id);
      return { how: 'c', fielder: cosmetic.pick(others) };
    }
    if (r < 0.80) return { how: 'b', fielder: null };
    if (isSpin && r < 0.90) return { how: 'st', fielder: fieldingXI.order[5] };
    return { how: 'lbw', fielder: null };
  }

  // Simulate one innings. target > 0 stops the innings the instant the total
  // reaches it (a chase). opts.cosmetic is an optional rng for dismissal flavour.
  function simulateInnings(batting, bowlingXI, tuning, itun, rng, plan, target = 0, opts = {}) {
    plan = plan || balanced();
    const batters = batting.order.map((p, i) => batterCard(p, i + 1));
    const overPlan = rotation(bowlingXI.bowlers, itun);
    const cards = new Map();
    const bowlerOrder = [];
    for (const b of overPlan) {
      if (!cards.has(b.id)) { cards.set(b.id, bowlerCard(b)); bowlerOrder.push(cards.get(b.id)); }
    }
    const maxBalls = itun.over_limit * 6;
    let striker = 0, nonStriker = 1, nextIn = 2;
    let wickets = 0, balls = 0, total = 0;
    const fall = [];
    const phaseRuns = [0, 0, 0];
    const events = [];

    while (balls < maxBalls && wickets < 10 && (target === 0 || total < target)) {
      const s = batters[striker];
      const over = Math.floor(balls / 6) + 1;
      const intent = plan.forState(over, total, wickets, balls, target, maxBalls);
      const bowler = overPlan[over - 1];
      const card = cards.get(bowler.id);
      const bonus = phaseBonus(bowler.kind, over, itun);
      const attack = Math.max(itun.attr_floor, bowler.attrs.attack + bonus);
      const control = Math.max(itun.attr_floor, bowler.attrs.control + bonus);
      const o = resolveBall(
        Math.max(itun.attr_floor, s.player.attrs.power),
        Math.max(itun.attr_floor, s.player.attrs.composure),
        attack, control, intent, tuning, rng, bowler.kind);
      balls += 1;
      s.balls += 1;
      card.balls += 1;
      const ev = {
        over, ball: ((balls - 1) % 6) + 1, strikerId: s.player.id, nonStrikerId: batters[nonStriker].player.id,
        bowlerId: bowler.id, intent, runs: o.wicket ? 0 : o.runs, wicket: o.wicket, how: null, fielderId: null,
        total: 0, wickets: 0, nextInId: null,
      };
      if (o.wicket) {
        const d = dismissal(bowler, bowlingXI, opts.cosmetic);
        s.out = true; s.dismissedBy = bowler; s.how = d.how; s.fielder = d.fielder;
        ev.how = d.how; ev.fielderId = d.fielder ? d.fielder.id : null;
        card.wickets += 1; card.dots += 1;
        wickets += 1;
        fall.push({ wicket: wickets, score: total, batter: s, ball: balls });
        ev.total = total; ev.wickets = wickets;
        if (wickets >= 10) { events.push(ev); break; }
        striker = nextIn; nextIn += 1;
        ev.nextInId = batters[striker].player.id;
      } else {
        s.runs += o.runs; total += o.runs; card.runs += o.runs;
        if (o.runs === 0) card.dots += 1;
        else if (o.runs === 4) s.fours += 1;
        else if (o.runs === 6) s.sixes += 1;
        phaseRuns[phaseOf(over)] += o.runs;
        if (o.runs % 2 === 1) [striker, nonStriker] = [nonStriker, striker];
        ev.total = total; ev.wickets = wickets;
      }
      events.push(ev);
      if (balls % 6 === 0 && wickets < 10) [striker, nonStriker] = [nonStriker, striker];
    }

    return {
      xi: batting, bowlingXI, total, wickets, balls, batters, bowlers: bowlerOrder, fall, phaseRuns, target, events,
      get oversText() { return oversText(this.balls); },
      get allOut() { return this.wickets >= 10; },
      get runRate() { return this.balls ? 6.0 * this.total / this.balls : 0.0; },
    };
  }

  return (Cricket.innings = { simulateInnings, oversText, batterCard, bowlerCard });
});
