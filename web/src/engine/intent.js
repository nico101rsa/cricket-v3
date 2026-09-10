// Batting intent per phase with the state-aware chase and collapse rules.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}), typeof require === 'function' ? require : null);
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket, require) {
  const { Intent } = require ? require('./ball.js') : Cricket.ball;

  const POWERPLAY_OVERS = 6;
  const DEATH_START_OVER = 16;

  // 0 = powerplay (overs 1-6), 1 = middle (7-15), 2 = death (16-20).
  function phaseOf(over) {
    if (over <= POWERPLAY_OVERS) return 0;
    if (over < DEATH_START_OVER) return 1;
    return 2;
  }
  const PHASE_NAMES = ['Powerplay', 'Middle', 'Death'];

  function makePlan(powerplay = Intent.BALANCED, middle = Intent.BALANCED, death = Intent.BALANCED, rules = {}) {
    const plan = {
      powerplay, middle, death,
      chase_up_rr: rules.chase_up_rr ?? -1.0,
      chase_down_rr: rules.chase_down_rr ?? -1.0,
      collapse_wkts: rules.collapse_wkts ?? -1,
      forOver(over) { return [this.powerplay, this.middle, this.death][phaseOf(over)]; },
      forState(over, total, wickets, balls, target, maxBalls) {
        const band = this.forOver(over);
        let delta = 0;
        if (target > 0 && balls < maxBalls) {
          const reqRR = (target - total) * 6.0 / (maxBalls - balls);
          if (this.chase_up_rr >= 0.0 && reqRR >= this.chase_up_rr) delta = 1;
          else if (this.chase_down_rr >= 0.0 && reqRR <= this.chase_down_rr) delta = -1;
        }
        if (this.collapse_wkts >= 0 && wickets >= this.collapse_wkts && delta <= 0) delta -= 1;
        return Math.max(Intent.DEFENSIVE, Math.min(Intent.AGGRESSIVE, band + delta));
      },
    };
    return plan;
  }

  const balanced = () => makePlan();
  const textbook = () => makePlan(Intent.AGGRESSIVE, Intent.BALANCED, Intent.AGGRESSIVE);
  // The v2 self-play equilibrium: the chase rule supplies the death slog.
  const adaptive = () => makePlan(Intent.BALANCED, Intent.AGGRESSIVE, Intent.BALANCED,
    { chase_up_rr: 10.0, chase_down_rr: 5.0, collapse_wkts: 5 });

  // The manager's one match-level lever: three presets, all state-aware.
  const PRESETS = {
    cautious: { label: 'Cautious', blurb: 'Keep wickets, build, go late.',
      make: () => makePlan(Intent.BALANCED, Intent.BALANCED, Intent.BALANCED, { chase_up_rr: 10.0, chase_down_rr: 5.0, collapse_wkts: 4 }) },
    balanced: { label: 'Balanced', blurb: 'Steady start, push through the middle.',
      make: adaptive },
    attacking: { label: 'Attacking', blurb: 'Swing from ball one. High risk, high score.',
      make: () => makePlan(Intent.AGGRESSIVE, Intent.AGGRESSIVE, Intent.AGGRESSIVE, { chase_down_rr: 5.0, collapse_wkts: 6 }) },
  };
  const presetPlan = (key) => (PRESETS[key] || PRESETS.balanced).make();

  return (Cricket.intent = {
    Intent, POWERPLAY_OVERS, DEATH_START_OVER, PHASE_NAMES, phaseOf, makePlan, balanced, textbook, adaptive, PRESETS, presetPlan,
  });
});
