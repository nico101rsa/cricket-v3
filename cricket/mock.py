"""Deterministic mock squads. Each player is jittered off a Cricket v2
archetype so a mock XI plays at the tuned even-contest strength:

  batter       power/composure ~50,    attack/control ~12.5
  all-rounder  power/composure ~31.25, bowling ~31.25 tilted by kind
  bowler       power/composure ~6.25,  bowling ~31.25 tilted by kind

The kind tilt (+-12.5 between attack and control) is v2's BowlingAttack: a
pace bowler is attack-heavy, a spinner control-heavy.
"""
from __future__ import annotations

import random

from cricket.model import Attributes, BowlKind, Player, Role, Team
from cricket.names import CLUBS, FIRST_NAMES, SURNAMES, country_of_city

TILT = 12.5
JITTER = 0.2            # +-20% around the archetype value
SQUAD_SHAPE = [Role.BATTER] * 7 + [Role.ALLROUNDER] * 2 + [Role.BOWLER] * 6


def _jitter(base: float, rng: random.Random) -> float:
    return round(base * (1.0 + rng.uniform(-JITTER, JITTER)), 2)


def mock_player(role: Role, country: str, rng: random.Random, kind: BowlKind | None = None) -> Player:
    if kind is None:
        kind = BowlKind.PACE if rng.random() < 0.5 else BowlKind.SPIN
    if role == Role.BATTER:
        bat, bowl = 50.0, 12.5
    elif role == Role.ALLROUNDER:
        bat, bowl = 31.25, 31.25
    else:
        bat, bowl = 6.25, 31.25
    tilt = TILT if role != Role.BATTER else 0.0
    if kind == BowlKind.PACE:
        attack, control = bowl + tilt, max(6.25, bowl - tilt)
    else:
        attack, control = max(6.25, bowl - tilt), bowl + tilt
    attrs = Attributes(_jitter(bat, rng), _jitter(bat, rng), _jitter(attack, rng), _jitter(control, rng))
    first = rng.choice(FIRST_NAMES[country])
    surname = rng.choice(SURNAMES[country])
    age = rng.randint(19, 35)
    return Player(first, surname, age, role, kind, attrs)


def mock_team(city: str, club_index: int, rng: random.Random) -> Team:
    country = country_of_city(city)
    name = CLUBS[city][club_index % len(CLUBS[city])]
    squad: list[Player] = []
    used: set[str] = set()
    kinds = [BowlKind.PACE, BowlKind.SPIN]
    for i, role in enumerate(SQUAD_SHAPE):
        kind = kinds[i % 2] if role != Role.BATTER else None
        p = mock_player(role, country, rng, kind)
        while p.surname in used:    # unique surnames: the phone scorecard shows surname only
            p = mock_player(role, country, rng, kind)
        used.add(p.surname)
        squad.append(p)
    return Team(name, city, country, squad)


def mock_fixture(seed: int, home_city: str = "Cape Town", away_city: str = "Sydney") -> tuple[Team, Team]:
    """Two mock squads from one seed. The same seed always gives the same squads."""
    rng = random.Random(seed)
    return mock_team(home_city, 0, rng), mock_team(away_city, 0, rng)
