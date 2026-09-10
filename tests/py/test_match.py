import random

from conftest import xis
from cricket.sim.innings import InningsResult
from cricket.sim.intent import IntentPlan
from cricket.sim.match import Outcome, decide_result, simulate_match


def _inn(xi, total, wkts, balls):
    return InningsResult(xi, total, wkts, balls, [], [], [])


def test_decide_win_by_runs():
    h, a = xis(1)
    r = decide_result(h, a, True, _inn(h, 150, 8, 120), _inn(a, 140, 9, 120), 120)
    assert r.outcome == Outcome.HOME_WIN and r.margin_runs == 10 and r.margin_wickets == 0
    assert r.result_line() == f"{h.team.name} won by 10 runs"


def test_decide_win_by_wickets():
    h, a = xis(1)
    r = decide_result(h, a, False, _inn(a, 140, 10, 120), _inn(h, 141, 4, 112), 120)
    assert r.outcome == Outcome.HOME_WIN and r.margin_wickets == 6 and r.balls_remaining == 8
    assert r.result_line() == f"{h.team.name} won by 6 wickets (8 balls left)"


def test_decide_tie():
    h, a = xis(1)
    r = decide_result(h, a, True, _inn(h, 150, 7, 120), _inn(a, 150, 10, 120), 120)
    assert r.outcome == Outcome.TIE and r.winner is None and r.result_line() == "Match tied"


def test_decide_perspective_away_defends():
    h, a = xis(1)
    r = decide_result(h, a, False, _inn(a, 150, 8, 120), _inn(h, 140, 9, 120), 120)
    assert r.outcome == Outcome.AWAY_WIN and r.margin_runs == 10


def test_same_seed_deterministic(tuning, itun):
    h, a = xis(7)
    r1 = simulate_match(h, a, tuning, itun, random.Random(2024))
    r2 = simulate_match(h, a, tuning, itun, random.Random(2024))
    assert (r1.outcome, r1.innings1.total, r1.innings2.total, r1.margin_runs, r1.margin_wickets) == \
           (r2.outcome, r2.innings1.total, r2.innings2.total, r2.margin_runs, r2.margin_wickets)


def test_forced_toss_places_sides(tuning, itun):
    h, a = xis(7)
    r = simulate_match(h, a, tuning, itun, random.Random(1), home_bats_first=True)
    assert r.innings1.xi is h and r.innings2.xi is a and r.toss_winner is h.team
    r = simulate_match(h, a, tuning, itun, random.Random(1), home_bats_first=False)
    assert r.innings1.xi is a and r.innings2.xi is h


def test_outcome_always_valid_and_consistent(tuning, itun):
    for seed in range(1, 60):
        h, a = xis(seed)
        r = simulate_match(h, a, tuning, itun, random.Random(seed))
        assert r.innings2.target == r.innings1.total + 1
        if r.outcome == Outcome.TIE:
            assert r.innings1.total == r.innings2.total
        elif r.margin_runs > 0:
            assert r.margin_wickets == 0 and r.innings1.total > r.innings2.total
        else:
            assert r.margin_wickets > 0 and r.innings2.total > r.innings1.total


def test_even_contest_roughly_balanced(tuning, itun):
    wins = decided = 0
    for seed in range(1, 200):
        h, a = xis(seed)
        r = simulate_match(h, a, tuning, itun, random.Random(seed), IntentPlan.adaptive(), IntentPlan.adaptive())
        if r.outcome == Outcome.TIE:
            continue
        decided += 1
        wins += r.outcome == Outcome.HOME_WIN
    assert 0.35 <= wins / decided <= 0.65
