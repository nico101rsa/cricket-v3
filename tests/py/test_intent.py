from cricket.sim.ball import Intent
from cricket.sim.intent import IntentPlan, phase_of


def test_phase_of_maps_boundaries():
    assert [phase_of(o) for o in (1, 6, 7, 15, 16, 20)] == [0, 0, 1, 1, 2, 2]


def test_for_over_reads_phase_bands():
    p = IntentPlan.textbook()
    assert p.for_over(3) == Intent.AGGRESSIVE
    assert p.for_over(10) == Intent.BALANCED
    assert p.for_over(18) == Intent.AGGRESSIVE


def test_static_plan_ignores_state():
    p = IntentPlan.balanced()
    assert p.for_state(10, 20, 8, 60, 200, 120) == Intent.BALANCED


def test_chase_rules_escalate_and_de_escalate():
    p = IntentPlan.adaptive()
    # over 10, 60 balls gone, need 120 more off 60 -> req RR 12 -> up one band
    assert p.for_state(10, 80, 2, 60, 200, 120) == Intent.AGGRESSIVE
    # need 20 off 60 -> req RR 2 -> down one band
    assert p.for_state(10, 180, 2, 60, 200, 120) == Intent.BALANCED
    # not chasing: the plain band
    assert p.for_state(10, 80, 2, 60, 0, 120) == Intent.AGGRESSIVE


def test_collapse_protection_never_overrides_a_chase_escalation():
    p = IntentPlan.adaptive()
    assert p.for_state(10, 80, 6, 60, 200, 120) == Intent.AGGRESSIVE
    # no chase, 6 down in the middle -> aggressive band drops to balanced
    assert p.for_state(10, 80, 6, 60, 0, 120) == Intent.BALANCED
    # chase de-escalation stacks with collapse -> defensive
    assert p.for_state(10, 180, 6, 60, 200, 120) == Intent.DEFENSIVE


def test_bands_clamp():
    p = IntentPlan(Intent.DEFENSIVE, Intent.DEFENSIVE, Intent.DEFENSIVE, chase_down_rr=5.0, collapse_wkts=1)
    assert p.for_state(10, 180, 6, 60, 200, 120) == Intent.DEFENSIVE
