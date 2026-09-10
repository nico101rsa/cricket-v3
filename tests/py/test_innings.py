import random
import statistics

from conftest import xis
from cricket.model import Attributes, BowlKind, Player, Role, Team, XI
from cricket.sim.innings import simulate_innings
from cricket.sim.intent import IntentPlan


def _uniform_xi(name, bat, bowl):
    ps = [Player(f"P{i}", name, 25, Role.ALLROUNDER, BowlKind.PACE if i % 2 else BowlKind.SPIN,
                 Attributes(bat, bat, bowl, bowl)) for i in range(11)]
    return XI(Team(name, "Cape Town", "SA", ps), ps, ps[:5])


def test_same_seed_gives_identical_innings(tuning, itun):
    h, a = xis(3)
    r1 = simulate_innings(h, a, tuning, itun, random.Random(9))
    r2 = simulate_innings(h, a, tuning, itun, random.Random(9))
    assert (r1.total, r1.wickets, r1.balls) == (r2.total, r2.wickets, r2.balls)
    assert [f.score for f in r1.fall] == [f.score for f in r2.fall]


def test_termination_bounds_and_accounting(tuning, itun):
    for seed in range(1, 60):
        h, a = xis(seed)
        r = simulate_innings(h, a, tuning, itun, random.Random(seed))
        assert r.balls <= 120 and r.wickets <= 10
        assert len(r.batters) == 11
        assert sum(b.balls for b in r.batters) == r.balls == sum(c.balls for c in r.bowlers)
        assert sum(b.runs for b in r.batters) == r.total == sum(c.runs for c in r.bowlers)
        assert sum(b.out for b in r.batters) == r.wickets == sum(c.wickets for c in r.bowlers)
        assert sum(r.phase_runs) == r.total
        assert len(r.fall) == r.wickets
        assert [f.wicket for f in r.fall] == list(range(1, r.wickets + 1))
        assert all(x.score <= y.score for x, y in zip(r.fall, r.fall[1:]))
        for b in r.batters:
            assert b.out == (b.dismissed_by is not None)
        assert len(r.bowlers) == 5


def test_all_out_stops_immediately(tuning, itun):
    weak = _uniform_xi("Weak", 6.25, 6.25)
    strong = _uniform_xi("Strong", 60.0, 60.0)
    seen = False
    for seed in range(1, 20):
        r = simulate_innings(weak, strong, tuning, itun, random.Random(seed))
        if r.wickets == 10:
            seen = True
            assert r.balls < 120
    assert seen, "a brutal mismatch bowls the side out in some seeds"


def test_chase_stops_at_target(tuning, itun):
    h, a = xis(2)
    r = simulate_innings(h, a, tuning, itun, random.Random(1), IntentPlan.adaptive(), target=60)
    assert r.total >= 60 and r.total < 60 + 6
    assert r.balls < 120


def test_strike_rotates(tuning, itun):
    h, a = xis(4)
    r = simulate_innings(h, a, tuning, itun, random.Random(4))
    assert sum(1 for b in r.batters if b.balls > 0) > 1


def test_even_contest_total_in_sane_t20_band(tuning, itun):
    """Port of v2's band check (balanced plan): 110-175 average."""
    totals = []
    for seed in range(1, 120):
        h, a = xis(seed)
        totals.append(simulate_innings(h, a, tuning, itun, random.Random(seed)).total)
    assert 110.0 <= statistics.mean(totals) <= 175.0


def test_textbook_mirror_scores_in_tuned_band(tuning, itun):
    """v2's BB11 environment peg: textbook v textbook first innings ~150-167.
    Loose band so the mock jitter and a different RNG cannot flake it."""
    totals = []
    for seed in range(1, 300):
        h, a = xis(seed)
        totals.append(simulate_innings(h, a, tuning, itun, random.Random(seed), IntentPlan.textbook()).total)
    assert 145.0 <= statistics.mean(totals) <= 172.0


def test_stronger_bowling_concedes_less(tuning, itun):
    bat = _uniform_xi("Bat", 50.0, 12.5)
    weak = _uniform_xi("WeakBowl", 30.0, 20.0)
    strong = _uniform_xi("StrongBowl", 30.0, 45.0)
    w = statistics.mean(simulate_innings(bat, weak, tuning, itun, random.Random(s)).total for s in range(40))
    s = statistics.mean(simulate_innings(bat, strong, tuning, itun, random.Random(s)).total for s in range(40))
    assert s < w
