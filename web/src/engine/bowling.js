// Who bowls which over. Deterministic, no RNG. Pace in the powerplay and at
// the death, spin through the middle. Each bowler bowls at most
// overs_per_bowler overs and never two in a row; a pigeonhole guard forces a
// bowler in when they hold more overs than alternation could otherwise fit.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}), typeof require === 'function' ? require : null);
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket, require) {
  const { phaseOf } = require ? require('./intent.js') : Cricket.intent;
  const { bowling } = require ? require('./model.js') : Cricket.model;

  const preferredKind = (over) => (phaseOf(over) === 1 ? 'SPIN' : 'PACE');

  function phaseBonus(kind, over, itun) {
    const ph = phaseOf(over);
    return kind === 'PACE' ? itun.pace_phase_bonus[ph] : itun.spin_phase_bonus[ph];
  }

  // The bowler for each over 1..over_limit, in order.
  function rotation(bowlers, itun) {
    const quota = new Map(bowlers.map((b) => [b.id, itun.overs_per_bowler]));
    let total = 0;
    for (const q of quota.values()) total += q;
    if (total < itun.over_limit) throw new Error('bowlers cannot cover the innings');
    const plan = [];
    let prev = null;
    for (let over = 1; over <= itun.over_limit; over++) {
      const remaining = itun.over_limit - over + 1;
      const avail = bowlers.filter((b) => quota.get(b.id) > 0);
      const forced = avail.filter((b) => 2 * quota.get(b.id) - 1 >= remaining);
      let pool = forced.length ? forced : avail.filter((b) => b !== prev);
      if (!pool.length) pool = avail;
      const want = preferredKind(over);
      pool = pool.slice().sort((a, b) =>
        ((a.kind !== want) - (b.kind !== want)) ||
        (quota.get(b.id) - quota.get(a.id)) ||
        (bowling(b) - bowling(a)));
      const pick = pool[0];
      quota.set(pick.id, quota.get(pick.id) - 1);
      plan.push(pick);
      prev = pick;
    }
    return plan;
  }

  return (Cricket.bowling = { preferredKind, phaseBonus, rotation });
});
