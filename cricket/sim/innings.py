"""One T20 innings, ball by ball. Port of Cricket v2's InningsResolver with
named batters and named bowlers instead of a statted hero plus clones.

Every ball: the striker's power/composure against the over's bowler
(attack/control + that kind's phase bonus), at the batting side's intent for
the match state. Strike rotates on odd runs and at the end of each over.
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field

from cricket.model import Player, XI
from cricket.sim.ball import Intent, resolve_ball
from cricket.sim.bowling import phase_bonus, rotation
from cricket.sim.intent import IntentPlan, phase_of
from cricket.tuning import BallTuning, InningsTuning


@dataclass
class BatterCard:
    player: Player
    position: int              # 1-based batting position
    runs: int = 0
    balls: int = 0
    fours: int = 0
    sixes: int = 0
    out: bool = False
    dismissed_by: Player | None = None

    @property
    def batted(self) -> bool:
        return self.balls > 0 or self.out

    @property
    def strike_rate(self) -> float:
        return 100.0 * self.runs / self.balls if self.balls else 0.0


@dataclass
class BowlerCard:
    player: Player
    balls: int = 0
    runs: int = 0
    wickets: int = 0
    dots: int = 0

    @property
    def overs_text(self) -> str:
        return f"{self.balls // 6}.{self.balls % 6}" if self.balls % 6 else f"{self.balls // 6}"

    @property
    def economy(self) -> float:
        return 6.0 * self.runs / self.balls if self.balls else 0.0


@dataclass
class FallOfWicket:
    wicket: int
    score: int
    batter: BatterCard
    ball: int      # balls bowled in the innings when it fell (1-based)

    @property
    def over_text(self) -> str:
        return f"{(self.ball - 1) // 6}.{(self.ball - 1) % 6 + 1}"


@dataclass
class InningsResult:
    xi: XI
    total: int
    wickets: int
    balls: int
    batters: list[BatterCard]
    bowlers: list[BowlerCard]           # in order of first over bowled
    fall: list[FallOfWicket]
    phase_runs: list[int] = field(default_factory=lambda: [0, 0, 0])
    target: int = 0

    @property
    def overs_text(self) -> str:
        return f"{self.balls // 6}.{self.balls % 6}" if self.balls % 6 else f"{self.balls // 6}"

    @property
    def all_out(self) -> bool:
        return self.wickets >= 10

    @property
    def run_rate(self) -> float:
        return 6.0 * self.total / self.balls if self.balls else 0.0


def simulate_innings(batting: XI, bowling: XI, tuning: BallTuning, itun: InningsTuning,
                     rng: random.Random, plan: IntentPlan | None = None,
                     target: int = 0) -> InningsResult:
    """Simulate one innings. target > 0 stops the innings the instant the
    total reaches it (a chase); 0 means bat the full quota."""
    plan = plan or IntentPlan.balanced()
    batters = [BatterCard(p, i + 1) for i, p in enumerate(batting.batting_order)]
    over_plan = rotation(bowling.bowlers, itun)
    cards: dict[int, BowlerCard] = {}
    bowler_order: list[BowlerCard] = []
    for b in over_plan:
        if id(b) not in cards:
            cards[id(b)] = BowlerCard(b)
            bowler_order.append(cards[id(b)])

    max_balls = itun.over_limit * 6
    striker, nonstriker, next_in = 0, 1, 2
    wickets = balls = total = 0
    fall: list[FallOfWicket] = []
    phase_runs = [0, 0, 0]

    while balls < max_balls and wickets < 10 and (target == 0 or total < target):
        s = batters[striker]
        over = balls // 6 + 1
        intent = plan.for_state(over, total, wickets, balls, target, max_balls)
        bowler = over_plan[over - 1]
        card = cards[id(bowler)]
        bonus = phase_bonus(bowler.bowl_kind, over, itun)
        attack = max(itun.attr_floor, bowler.attrs.attack + bonus)
        control = max(itun.attr_floor, bowler.attrs.control + bonus)

        o = resolve_ball(max(itun.attr_floor, s.player.attrs.power),
                         max(itun.attr_floor, s.player.attrs.composure),
                         attack, control, intent, tuning, rng, bowler.bowl_kind)
        balls += 1
        s.balls += 1
        card.balls += 1
        if o.wicket:
            s.out = True
            s.dismissed_by = bowler
            card.wickets += 1
            card.dots += 1
            wickets += 1
            fall.append(FallOfWicket(wickets, total, s, balls))
            if wickets >= 10:
                break
            striker = next_in
            next_in += 1
        else:
            s.runs += o.runs
            total += o.runs
            card.runs += o.runs
            if o.runs == 0:
                card.dots += 1
            elif o.runs == 4:
                s.fours += 1
            elif o.runs == 6:
                s.sixes += 1
            phase_runs[phase_of(over)] += o.runs
            if o.runs % 2 == 1:
                striker, nonstriker = nonstriker, striker
        if balls % 6 == 0 and wickets < 10:
            striker, nonstriker = nonstriker, striker

    return InningsResult(batting, total, wickets, balls, batters, bowler_order, fall, phase_runs, target)
