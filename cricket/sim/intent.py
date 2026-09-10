"""Batting intent per phase, with the state-aware chase and collapse rules.
Port of Cricket v2's IntentPlan (E2 rules)."""
from __future__ import annotations

from dataclasses import dataclass

from cricket.sim.ball import Intent

POWERPLAY_OVERS = 6
DEATH_START_OVER = 16


def phase_of(over: int) -> int:
    """0 = powerplay (overs 1-6), 1 = middle (7-15), 2 = death (16-20)."""
    if over <= POWERPLAY_OVERS:
        return 0
    if over < DEATH_START_OVER:
        return 1
    return 2


@dataclass
class IntentPlan:
    powerplay: Intent = Intent.BALANCED
    middle: Intent = Intent.BALANCED
    death: Intent = Intent.BALANCED
    # State rules; negative = off. req_rr = runs still needed per over.
    chase_up_rr: float = -1.0     # chasing and req_rr >= this -> one band up
    chase_down_rr: float = -1.0   # chasing and req_rr <= this -> one band down
    collapse_wkts: int = -1       # wickets down >= this -> one band down

    def for_over(self, over: int) -> Intent:
        return (self.powerplay, self.middle, self.death)[phase_of(over)]

    def for_state(self, over: int, total: int, wickets: int, balls: int,
                  target: int, max_balls: int) -> Intent:
        band = int(self.for_over(over))
        delta = 0
        if target > 0 and balls < max_balls:
            req_rr = (target - total) * 6.0 / (max_balls - balls)
            if self.chase_up_rr >= 0.0 and req_rr >= self.chase_up_rr:
                delta = 1
            elif self.chase_down_rr >= 0.0 and req_rr <= self.chase_down_rr:
                delta = -1
        if self.collapse_wkts >= 0 and wickets >= self.collapse_wkts and delta <= 0:
            delta -= 1
        return Intent(max(int(Intent.DEFENSIVE), min(int(Intent.AGGRESSIVE), band + delta)))

    @staticmethod
    def balanced() -> "IntentPlan":
        return IntentPlan()

    @staticmethod
    def textbook() -> "IntentPlan":
        return IntentPlan(Intent.AGGRESSIVE, Intent.BALANCED, Intent.AGGRESSIVE)

    @staticmethod
    def adaptive() -> "IntentPlan":
        """The v2 self-play equilibrium: balanced/aggressive/balanced with the
        chase rule supplying the death slog when the match asks for it."""
        return IntentPlan(Intent.BALANCED, Intent.AGGRESSIVE, Intent.BALANCED,
                          chase_up_rr=10.0, chase_down_rr=5.0, collapse_wkts=5)
