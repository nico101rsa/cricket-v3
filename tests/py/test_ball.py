"""Port of Cricket v2's test_ball_resolver.gd: the tuned per-ball rates."""
import random

from cricket.model import BowlKind
from cricket.sim.ball import Intent, blended_distribution, resolve_ball, wicket_probability
from cricket.tuning import RUN_VALUES

EVEN = 31.25


def _wicket_rate(power, comp, attack, control, intent, seed, n, tuning, kind=None):
    r = random.Random(seed)
    return sum(resolve_ball(power, comp, attack, control, intent, tuning, r, kind).wicket for _ in range(n)) / n


def _mean_runs(power, comp, attack, control, intent, seed, n, tuning):
    r = random.Random(seed)
    total = balls = 0
    for _ in range(n):
        o = resolve_ball(power, comp, attack, control, intent, tuning, r)
        if not o.wicket:
            total += o.runs
            balls += 1
    return total / balls


def test_blended_distribution_sums_to_one(tuning):
    for s in (0.0, 0.25, 0.5, 0.75, 1.0):
        assert abs(sum(blended_distribution(s, tuning)) - 1.0) < 1e-6


def test_blend_endpoints_match_anchor_shapes(tuning):
    d = blended_distribution(0.0, tuning)
    a = blended_distribution(1.0, tuning)
    assert a[4] > d[4], "aggressive blend has more 4s"
    assert d[0] > a[0], "defensive blend has more dots"


def test_higher_s_raises_expected_runs(tuning):
    def ev(probs):
        return sum(v * p for v, p in zip(RUN_VALUES, probs))
    assert ev(blended_distribution(0.8, tuning)) > ev(blended_distribution(0.2, tuning))


def test_same_seed_gives_identical_sequence(tuning):
    a, b = random.Random(12345), random.Random(12345)
    for _ in range(200):
        assert resolve_ball(EVEN, EVEN, EVEN, EVEN, Intent.BALANCED, tuning, a) == \
               resolve_ball(EVEN, EVEN, EVEN, EVEN, Intent.BALANCED, tuning, b)


def test_runs_in_alphabet_and_wicket_scores_zero(tuning):
    r = random.Random(999)
    for _ in range(500):
        o = resolve_ball(37.5, 37.5, 37.5, 37.5, Intent.BALANCED, tuning, r)
        assert o.runs in RUN_VALUES
        if o.wicket:
            assert o.runs == 0


def test_even_contest_wicket_rate_near_baseline(tuning):
    rate = _wicket_rate(EVEN, EVEN, EVEN, EVEN, Intent.BALANCED, 2024, 20000, tuning)
    assert abs(rate - 0.035) < 0.008, "even contest ~3.5% per ball"


def test_even_contest_wicket_probability_exact(tuning):
    assert abs(wicket_probability(EVEN, EVEN, Intent.BALANCED, tuning) - 0.035) < 1e-4


def test_higher_attack_raises_wicket_rate(tuning):
    low = _wicket_rate(EVEN, EVEN, 25.0, EVEN, Intent.BALANCED, 77, 20000, tuning)
    high = _wicket_rate(EVEN, EVEN, 56.25, EVEN, Intent.BALANCED, 77, 20000, tuning)
    assert high > low


def test_higher_power_raises_mean_runs(tuning):
    low = _mean_runs(25.0, EVEN, EVEN, EVEN, Intent.BALANCED, 88, 20000, tuning)
    high = _mean_runs(56.25, EVEN, EVEN, EVEN, Intent.BALANCED, 88, 20000, tuning)
    assert high > low


def test_aggressive_intent_raises_both_wickets_and_runs(tuning):
    assert _wicket_rate(EVEN, EVEN, EVEN, EVEN, Intent.AGGRESSIVE, 55, 20000, tuning) > \
           _wicket_rate(EVEN, EVEN, EVEN, EVEN, Intent.DEFENSIVE, 55, 20000, tuning)
    assert _mean_runs(EVEN, EVEN, EVEN, EVEN, Intent.AGGRESSIVE, 66, 20000, tuning) > \
           _mean_runs(EVEN, EVEN, EVEN, EVEN, Intent.DEFENSIVE, 66, 20000, tuning)


def test_extreme_mismatch_stays_valid(tuning):
    r = random.Random(3)
    for _ in range(200):
        assert resolve_ball(618.75, 618.75, 6.25, 6.25, Intent.AGGRESSIVE, tuning, r).runs in RUN_VALUES
    r = random.Random(4)
    for _ in range(200):
        assert resolve_ball(6.25, 6.25, 618.75, 618.75, Intent.DEFENSIVE, tuning, r).runs in RUN_VALUES


def test_slogging_spin_is_riskier_than_slogging_pace(tuning):
    p_spin = wicket_probability(EVEN, EVEN, Intent.AGGRESSIVE, tuning, BowlKind.SPIN)
    p_pace = wicket_probability(EVEN, EVEN, Intent.AGGRESSIVE, tuning, BowlKind.PACE)
    assert p_spin > p_pace
    assert p_pace == wicket_probability(EVEN, EVEN, Intent.AGGRESSIVE, tuning, None)
