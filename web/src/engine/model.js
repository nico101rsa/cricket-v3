// Players, teams and picked elevens. Attributes sit on the /100 card scale:
// power and composure (batting), attack and control (bowling). Every player
// has an integer id; the sim and the stats key everything by id.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}));
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket) {
  const Role = { BATTER: 'BATTER', ALLROUNDER: 'ALLROUNDER', BOWLER: 'BOWLER' };
  const Kind = { PACE: 'PACE', SPIN: 'SPIN' };

  const batting = (p) => p.attrs.power + p.attrs.composure;
  const bowling = (p) => p.attrs.attack + p.attrs.control;
  const byBattingDesc = (a, b) => batting(b) - batting(a);
  const byBowlingDesc = (a, b) => bowling(b) - bowling(a);

  function makePlayer(id, firstName, surname, age, role, kind, attrs) {
    return { id, firstName, surname, age, role, kind, attrs: { ...attrs } };
  }
  const shortName = (p) => `${p.firstName[0]}. ${p.surname}`;
  const fullName = (p) => `${p.firstName} ${p.surname}`;

  // A picked eleven: batting order (11 players) and the five who bowl.
  function makeXI(team, order, bowlers) {
    if (order.length !== 11) throw new Error(`an XI needs 11 batters, got ${order.length}`);
    if (new Set(order.map((p) => p.id)).size !== 11) throw new Error('duplicate player in XI');
    if (bowlers.length !== 5) throw new Error(`an XI needs 5 bowlers, got ${bowlers.length}`);
    const ids = new Set(order.map((p) => p.id));
    for (const b of bowlers) if (!ids.has(b.id)) throw new Error(`bowler ${b.surname} is not in the XI`);
    if (new Set(bowlers.map((p) => p.id)).size !== 5) throw new Error('duplicate bowler');
    return { team, order, bowlers };
  }

  // Auto-pick the strongest XI from a squad (mirrors the Python pick_xi): the 6
  // best batters, the best all-rounder by bowling, the 2 best pace and 2 best
  // spin bowlers. Order = top six by batting, then the all-rounder, then the
  // bowlers by batting. The five bowlers are the XI's five best by bowling.
  // This reads TRUE attributes, so it is for AI teams only.
  function pickXI(team, squad) {
    const batters = squad.filter((p) => p.role === Role.BATTER).sort(byBattingDesc);
    const alls = squad.filter((p) => p.role === Role.ALLROUNDER).sort(byBowlingDesc);
    const pace = squad.filter((p) => p.role === Role.BOWLER && p.kind === Kind.PACE).sort(byBowlingDesc);
    const spin = squad.filter((p) => p.role === Role.BOWLER && p.kind === Kind.SPIN).sort(byBowlingDesc);
    let bowlers = pace.slice(0, 2).concat(spin.slice(0, 2));
    if (bowlers.length < 4) {
      const spare = pace.slice(2).concat(spin.slice(2)).sort(byBowlingDesc);
      bowlers = bowlers.concat(spare.slice(0, 4 - bowlers.length));
    }
    let chosen = batters.slice(0, 6).concat(alls.slice(0, 1), bowlers);
    if (chosen.length < 11) {
      const ids = new Set(chosen.map((p) => p.id));
      const rest = squad.filter((p) => !ids.has(p.id))
        .sort((a, b) => (batting(b) + bowling(b)) - (batting(a) + bowling(a)));
      chosen = chosen.concat(rest.slice(0, 11 - chosen.length));
    }
    if (chosen.length < 11) throw new Error(`${team.name} has only ${squad.length} players; an XI needs 11`);
    const top = chosen.slice(0, 6).sort(byBattingDesc);
    const tail = chosen.slice(6).sort(byBattingDesc);
    const order = top.concat(tail);
    const five = order.slice().sort(byBowlingDesc).slice(0, 5);
    return makeXI(team, order, five);
  }

  return (Cricket.model = {
    Role, Kind, batting, bowling, makePlayer, shortName, fullName, makeXI, pickXI,
  });
});
