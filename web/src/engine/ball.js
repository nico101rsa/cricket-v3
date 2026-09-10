// One delivery. Two rolls, always in this order so a seed replays: the wicket
// roll (bowler attack v batter composure, log-odds), then, if survived, the
// runs roll (batter power v bowler control picks a blend between a defensive
// and an aggressive run distribution).
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}), typeof require === 'function' ? require : null);
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket, require) {
  const { RUN_VALUES } = require ? require('./tuning.js') : Cricket.tuning;

  const Intent = { DEFENSIVE: 0, BALANCED: 1, AGGRESSIVE: 2 };
  const sigmoid = (x) => 1.0 / (1.0 + Math.exp(-x));

  function blendedDistribution(s, tuning) {
    const w = tuning.def_dist.map((d, i) => d + (tuning.agg_dist[i] - d) * s);
    const total = w.reduce((a, b) => a + b, 0);
    return w.map((x) => x / total);
  }

  function wicketProbability(batComposure, bowlAttack, intent, tuning, kind) {
    let matchup = 0.0;
    if (kind === 'PACE') matchup = tuning.matchup_w_pace[intent];
    else if (kind === 'SPIN') matchup = tuning.matchup_w_spin[intent];
    const logit = tuning.base_w + tuning.k_w * (bowlAttack - batComposure) + tuning.intent_w[intent] + matchup;
    return sigmoid(logit);
  }

  function scoringStrength(batPower, bowlControl, intent, tuning) {
    return sigmoid(tuning.base_r + tuning.k_r * (batPower - bowlControl) + tuning.intent_r[intent]);
  }

  function sampleRuns(s, tuning, rng) {
    const probs = blendedDistribution(s, tuning);
    const roll = rng.random();
    let acc = 0.0;
    for (let i = 0; i < probs.length; i++) {
      acc += probs[i];
      if (roll < acc) return RUN_VALUES[i];
    }
    return RUN_VALUES[RUN_VALUES.length - 1];
  }

  function resolveBall(batPower, batComposure, bowlAttack, bowlControl, intent, tuning, rng, kind) {
    const p = wicketProbability(batComposure, bowlAttack, intent, tuning, kind);
    if (rng.random() < p) return { wicket: true, runs: 0 };
    const s = scoringStrength(batPower, bowlControl, intent, tuning);
    return { wicket: false, runs: sampleRuns(s, tuning, rng) };
  }

  return (Cricket.ball = { Intent, blendedDistribution, wicketProbability, scoringStrength, sampleRuns, resolveBall });
});
