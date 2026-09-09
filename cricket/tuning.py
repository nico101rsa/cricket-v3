"""Balance coefficients, ported verbatim from Cricket v2's BallTuning and
InningsTuning resources (scripts/data/ball_tuning.gd, innings_tuning.gd).

Everything lives here as DATA so a balance harness can sweep it. The numbers
carry the v2 tuning history: an even contest (31.25 vs 31.25 on the /100 card
scale) gives ~3.5% wickets per ball and a 20-over total in the 150-167 band.
"""
from dataclasses import dataclass, field

RUN_VALUES = (0, 1, 2, 3, 4, 6)

# One legacy (1-8 era) attribute point in /100 card units.
SCALE = 6.25


@dataclass
class BallTuning:
    # Stage 1: wicket log-odds = base_w + k_w*(attack - composure) + intent_w[intent] + matchup
    base_w: float = -3.3174   # ln(0.035/0.965): even contest ~3.5%/ball
    k_w: float = 0.0384       # 0.24 / SCALE
    intent_w: tuple = (-0.55, 0.0, 0.60)   # [defensive, balanced, aggressive]

    # Stage 2: scoring strength s = sigmoid(base_r + k_r*(power - control) + intent_r[intent])
    base_r: float = 0.2
    k_r: float = 0.0544       # 0.34 / SCALE
    intent_r: tuple = (-0.75, 0.0, 0.80)

    # Runs distributions aligned to RUN_VALUES, blended DEF -> AGG by s.
    def_dist: tuple = (0.68, 0.255, 0.035, 0.004, 0.020, 0.006)
    agg_dist: tuple = (0.30, 0.300, 0.090, 0.010, 0.200, 0.100)

    # Intent x bowler-kind matchup added to the wicket logit: slogging spin is risky.
    matchup_w_pace: tuple = (0.0, 0.0, 0.0)
    matchup_w_spin: tuple = (0.0, 0.0, 0.30)


@dataclass
class InningsTuning:
    over_limit: int = 20
    overs_per_bowler: int = 4       # T20 law: at most a fifth of the overs

    # Per-kind phase effectiveness bonus added to BOTH attack and control,
    # indexed by phase [powerplay, middle, death]. Pace owns the powerplay and
    # death, spin owns the middle. +-1.5 legacy points x SCALE.
    pace_phase_bonus: tuple = (9.375, -9.375, 9.375)
    spin_phase_bonus: tuple = (-9.375, 9.375, -9.375)

    # Safety floor for any effective attribute fed to the ball resolver.
    attr_floor: float = 0.5
