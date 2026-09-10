"""Who bowls which over. Deterministic, no RNG.

Textbook rotation: pace in the powerplay and at the death, spin through the
middle. Each bowler bowls at most `overs_per_bowler` overs and never two in a
row. A pigeonhole guard forces a bowler in when they still hold more overs
than the alternating pattern could otherwise fit.
"""
from __future__ import annotations

from cricket.model import BowlKind, Player
from cricket.sim.intent import phase_of
from cricket.tuning import InningsTuning


def preferred_kind(over: int) -> BowlKind:
    return BowlKind.SPIN if phase_of(over) == 1 else BowlKind.PACE


def phase_bonus(kind: BowlKind, over: int, itun: InningsTuning) -> float:
    ph = phase_of(over)
    return itun.pace_phase_bonus[ph] if kind == BowlKind.PACE else itun.spin_phase_bonus[ph]


def rotation(bowlers: list[Player], itun: InningsTuning) -> list[Player]:
    """The bowler for each over 1..over_limit, in order."""
    quota = {id(b): itun.overs_per_bowler for b in bowlers}
    if sum(quota.values()) < itun.over_limit:
        raise ValueError("bowlers cannot cover the innings")
    plan: list[Player] = []
    prev: Player | None = None
    for over in range(1, itun.over_limit + 1):
        remaining = itun.over_limit - over + 1
        avail = [b for b in bowlers if quota[id(b)] > 0]
        # Pigeonhole guard: a bowler holding more than half the remaining overs
        # (rounded up) must bowl now or the no-consecutive rule breaks later.
        forced = [b for b in avail if 2 * quota[id(b)] - 1 >= remaining]
        pool = forced or [b for b in avail if b is not prev] or avail
        want = preferred_kind(over)
        pool.sort(key=lambda b: (b.bowl_kind != want, -quota[id(b)], -b.attrs.bowling))
        pick = pool[0]
        quota[id(pick)] -= 1
        plan.append(pick)
        prev = pick
    return plan
