import random

import pytest

from cricket.mock import mock_fixture
from cricket.model import pick_xi
from cricket.tuning import BallTuning, InningsTuning


@pytest.fixture
def tuning():
    return BallTuning()


@pytest.fixture
def itun():
    return InningsTuning()


def rng(seed: int) -> random.Random:
    return random.Random(seed)


def xis(seed: int = 1):
    home, away = mock_fixture(seed)
    return pick_xi(home), pick_xi(away)
