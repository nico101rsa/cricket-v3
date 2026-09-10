// One T20 match: toss, two innings, a result.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}), typeof require === 'function' ? require : null);
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket, require) {
  const { simulateInnings } = require ? require('./innings.js') : Cricket.innings;

  const Outcome = { HOME_WIN: 'HOME_WIN', AWAY_WIN: 'AWAY_WIN', TIE: 'TIE' };
  const plural = (n, w) => `${n} ${w}${n === 1 ? '' : 's'}`;

  function decideResult(home, away, homeBatsFirst, innings1, innings2, maxBalls) {
    const t1 = innings1.total, t2 = innings2.total;
    const r = {
      home, away, homeBatsFirst, innings1, innings2, outcome: Outcome.TIE,
      marginRuns: 0, marginWickets: 0, ballsRemaining: 0,
      get tossWinner() { return this.homeBatsFirst ? this.home.team : this.away.team; },
      get winner() {
        if (this.outcome === Outcome.HOME_WIN) return this.home.team;
        if (this.outcome === Outcome.AWAY_WIN) return this.away.team;
        return null;
      },
      marginText() {
        if (this.outcome === Outcome.TIE) return 'match tied';
        if (this.marginRuns > 0) return `won by ${plural(this.marginRuns, 'run')}`;
        return `won by ${plural(this.marginWickets, 'wicket')} (${plural(this.ballsRemaining, 'ball')} left)`;
      },
      resultLine() {
        return this.outcome === Outcome.TIE ? 'Match tied' : `${this.winner.name} ${this.marginText()}`;
      },
    };
    if (t2 > t1) {
      r.marginWickets = 10 - innings2.wickets;
      r.ballsRemaining = maxBalls - innings2.balls;
      r.outcome = homeBatsFirst ? Outcome.AWAY_WIN : Outcome.HOME_WIN;
    } else if (t2 < t1) {
      r.marginRuns = t1 - t2;
      r.outcome = homeBatsFirst ? Outcome.HOME_WIN : Outcome.AWAY_WIN;
    }
    return r;
  }

  // Toss (one rng draw, winner bats first) unless opts.homeBatsFirst is given,
  // then the first innings, then a chase of total + 1.
  function simulateMatch(home, away, tuning, itun, rng, homePlan, awayPlan, opts = {}) {
    const tossed = rng.random() < 0.5;
    const homeBatsFirst = opts.homeBatsFirst === undefined ? tossed : !!opts.homeBatsFirst;
    const [first, second] = homeBatsFirst ? [home, away] : [away, home];
    const [p1, p2] = homeBatsFirst ? [homePlan, awayPlan] : [awayPlan, homePlan];
    const innings1 = simulateInnings(first, second, tuning, itun, rng, p1, 0, opts);
    const innings2 = simulateInnings(second, first, tuning, itun, rng, p2, innings1.total + 1, opts);
    return decideResult(home, away, homeBatsFirst, innings1, innings2, itun.over_limit * 6);
  }

  return (Cricket.match = { Outcome, decideResult, simulateMatch });
});
