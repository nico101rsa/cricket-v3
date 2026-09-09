"""One T20 match: toss, two innings, a result. Port of Cricket v2's
MatchResolver, with both sides as real XIs."""
from __future__ import annotations

import random
from dataclasses import dataclass
from enum import IntEnum

from cricket.model import XI, Team
from cricket.sim.innings import InningsResult, simulate_innings
from cricket.sim.intent import IntentPlan
from cricket.tuning import BallTuning, InningsTuning


class Outcome(IntEnum):
    HOME_WIN = 0
    AWAY_WIN = 1
    TIE = 2


@dataclass
class MatchResult:
    home: XI
    away: XI
    home_bats_first: bool
    innings1: InningsResult
    innings2: InningsResult
    outcome: Outcome
    margin_runs: int = 0
    margin_wickets: int = 0
    balls_remaining: int = 0

    @property
    def toss_winner(self) -> Team:
        return self.home.team if self.home_bats_first else self.away.team

    @property
    def winner(self) -> Team | None:
        if self.outcome == Outcome.HOME_WIN:
            return self.home.team
        if self.outcome == Outcome.AWAY_WIN:
            return self.away.team
        return None

    def result_line(self) -> str:
        if self.outcome == Outcome.TIE:
            return "Match tied"
        who = self.winner.name
        if self.margin_runs > 0:
            return f"{who} won by {self.margin_runs} run{'' if self.margin_runs == 1 else 's'}"
        return (f"{who} won by {self.margin_wickets} wicket{'' if self.margin_wickets == 1 else 's'} "
                f"({self.balls_remaining} ball{'' if self.balls_remaining == 1 else 's'} left)")


def decide_result(home: XI, away: XI, home_bats_first: bool,
                  innings1: InningsResult, innings2: InningsResult, max_balls: int) -> MatchResult:
    t1, t2 = innings1.total, innings2.total
    r = MatchResult(home, away, home_bats_first, innings1, innings2, Outcome.TIE)
    if t2 > t1:
        r.margin_wickets = 10 - innings2.wickets
        r.balls_remaining = max_balls - innings2.balls
        r.outcome = Outcome.AWAY_WIN if home_bats_first else Outcome.HOME_WIN
    elif t2 < t1:
        r.margin_runs = t1 - t2
        r.outcome = Outcome.HOME_WIN if home_bats_first else Outcome.AWAY_WIN
    return r


def simulate_match(home: XI, away: XI, tuning: BallTuning, itun: InningsTuning, rng: random.Random,
                   home_plan: IntentPlan | None = None, away_plan: IntentPlan | None = None,
                   home_bats_first: bool | None = None) -> MatchResult:
    """Toss (one rng draw, winner bats first) unless home_bats_first is
    given, then first innings, then a chase of total + 1."""
    tossed = rng.random() < 0.5
    if home_bats_first is None:
        home_bats_first = tossed
    first, second = (home, away) if home_bats_first else (away, home)
    p1, p2 = (home_plan, away_plan) if home_bats_first else (away_plan, home_plan)
    innings1 = simulate_innings(first, second, tuning, itun, rng, p1)
    innings2 = simulate_innings(second, first, tuning, itun, rng, p2, target=innings1.total + 1)
    return decide_result(home, away, home_bats_first, innings1, innings2, itun.over_limit * 6)
