"""Pure resolution of a single delivery. Port of Cricket v2's BallResolver.

Two rolls, always in this order so a seed replays: the wicket roll (bowler
attack vs batter composure, in log-odds), then, if survived, the runs roll
(batter power vs bowler control picks a blend between a defensive and an
aggressive run distribution).
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass
from enum import IntEnum

from cricket.model import BowlKind
from cricket.tuning import RUN_VALUES, BallTuning


class Intent(IntEnum):
    DEFENSIVE = 0
    BALANCED = 1
    AGGRESSIVE = 2


@dataclass(frozen=True)
class BallOutcome:
    wicket: bool
    runs: int


def _sigmoid(x: float) -> float:
    return 1.0 / (1.0 + math.exp(-x))


def blended_distribution(s: float, tuning: BallTuning) -> list[float]:
    """Blend the defensive and aggressive anchors by scoring strength s in
    [0, 1], normalised to sum to 1."""
    weights = [d + (a - d) * s for d, a in zip(tuning.def_dist, tuning.agg_dist)]
    total = sum(weights)
    return [w / total for w in weights]


def wicket_probability(bat_composure: float, bowl_attack: float, intent: Intent,
                       tuning: BallTuning, bowler_kind: BowlKind | None = None) -> float:
    matchup = 0.0
    if bowler_kind == BowlKind.PACE:
        matchup = tuning.matchup_w_pace[intent]
    elif bowler_kind == BowlKind.SPIN:
        matchup = tuning.matchup_w_spin[intent]
    logit = tuning.base_w + tuning.k_w * (bowl_attack - bat_composure) + tuning.intent_w[intent] + matchup
    return _sigmoid(logit)


def scoring_strength(bat_power: float, bowl_control: float, intent: Intent, tuning: BallTuning) -> float:
    return _sigmoid(tuning.base_r + tuning.k_r * (bat_power - bowl_control) + tuning.intent_r[intent])


def sample_runs(s: float, tuning: BallTuning, rng: random.Random) -> int:
    probs = blended_distribution(s, tuning)
    roll = rng.random()
    acc = 0.0
    for value, p in zip(RUN_VALUES, probs):
        acc += p
        if roll < acc:
            return value
    return RUN_VALUES[-1]


def resolve_ball(bat_power: float, bat_composure: float, bowl_attack: float, bowl_control: float,
                 intent: Intent, tuning: BallTuning, rng: random.Random,
                 bowler_kind: BowlKind | None = None) -> BallOutcome:
    """Resolve one delivery. Consumes rng in fixed order: wicket roll always;
    runs roll only if the ball is survived."""
    p_wicket = wicket_probability(bat_composure, bowl_attack, intent, tuning, bowler_kind)
    if rng.random() < p_wicket:
        return BallOutcome(True, 0)
    s = scoring_strength(bat_power, bowl_control, intent, tuning)
    return BallOutcome(False, sample_runs(s, tuning, rng))
