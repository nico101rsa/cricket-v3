// Balance coefficients, carried verbatim from Cricket v2 (BallTuning /
// InningsTuning) via the Python port. Everything is DATA so a harness can
// sweep it. An even contest (31.25 v 31.25 on the /100 card scale) gives
// ~3.5% wickets per ball and a 20-over total in the 150-167 band.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}));
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket) {
  const RUN_VALUES = [0, 1, 2, 3, 4, 6];
  const SCALE = 6.25; // one legacy (1-8 era) attribute point in /100 units

  function ballTuning() {
    return {
      base_w: -3.3174,
      k_w: 0.0384,
      intent_w: [-0.55, 0.0, 0.60],
      base_r: 0.2,
      k_r: 0.0544,
      intent_r: [-0.75, 0.0, 0.80],
      def_dist: [0.68, 0.255, 0.035, 0.004, 0.020, 0.006],
      agg_dist: [0.30, 0.300, 0.090, 0.010, 0.200, 0.100],
      matchup_w_pace: [0.0, 0.0, 0.0],
      matchup_w_spin: [0.0, 0.0, 0.30],
    };
  }

  function inningsTuning() {
    return {
      over_limit: 20,
      overs_per_bowler: 4,
      pace_phase_bonus: [9.375, -9.375, 9.375],
      spin_phase_bonus: [-9.375, 9.375, -9.375],
      attr_floor: 0.5,
    };
  }

  return (Cricket.tuning = { RUN_VALUES, SCALE, ballTuning, inningsTuning });
});
