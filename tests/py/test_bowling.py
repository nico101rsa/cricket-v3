import random

from conftest import xis
from cricket.mock import mock_fixture
from cricket.model import BowlKind, pick_xi
from cricket.sim.bowling import phase_bonus, preferred_kind, rotation
from cricket.sim.intent import phase_of


def test_phase_bonus_values(itun):
    assert phase_bonus(BowlKind.PACE, 1, itun) == 9.375
    assert phase_bonus(BowlKind.SPIN, 1, itun) == -9.375
    assert phase_bonus(BowlKind.SPIN, 10, itun) == 9.375
    assert phase_bonus(BowlKind.PACE, 20, itun) == 9.375


def test_preferred_kind_is_textbook():
    assert [preferred_kind(o) for o in (1, 6, 7, 15, 16, 20)] == \
        [BowlKind.PACE, BowlKind.PACE, BowlKind.SPIN, BowlKind.SPIN, BowlKind.PACE, BowlKind.PACE]


def test_rotation_is_legal_for_many_teams(itun):
    for seed in range(1, 200):
        home, away = mock_fixture(seed)
        for xi in (pick_xi(home), pick_xi(away)):
            plan = rotation(xi.bowlers, itun)
            assert len(plan) == 20
            assert set(map(id, plan)) <= set(map(id, xi.bowlers))
            for b in xi.bowlers:
                assert plan.count(b) <= itun.overs_per_bowler
            for a, b in zip(plan, plan[1:]):
                assert a is not b, "no bowler bowls consecutive overs"


def test_rotation_prefers_pace_in_powerplay_and_spin_in_middle(itun):
    hits = total = 0
    for seed in range(1, 100):
        hxi, _ = xis(seed)
        plan = rotation(hxi.bowlers, itun)
        for over, b in enumerate(plan, 1):
            total += 1
            hits += b.bowl_kind == preferred_kind(over)
    assert hits / total > 0.8, "most overs go to the textbook kind"


def test_rotation_is_deterministic(itun):
    hxi, _ = xis(5)
    assert [b.name for b in rotation(hxi.bowlers, itun)] == [b.name for b in rotation(hxi.bowlers, itun)]
