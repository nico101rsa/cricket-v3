class_name BallTuning
extends Resource

# All ball-resolution coefficients live here as DATA, never hardcoded in the
# resolver — the future balance harness (Theme 7c) sweeps these. Values below
# are strawman defaults; see spec 2026-06-06-ball-resolution-design.md §7.

# The run values a single ball can yield. Distributions align to this order.
const RUN_VALUES: Array[int] = [0, 1, 2, 3, 4, 6]

# --- Stage 1: wicket log-odds = base_w + k_w*(attack - composure) + intent_w[intent]
@export var base_w: float = -3.3174  # ln(0.035/0.965): even contest ~3.5%/ball
@export var k_w: float = 0.0384      # gain per attribute point of bowler advantage.
                                     # = 0.24 / Attributes.SCALE — card-rescale 2026-06-11 (DR1):
                                     # attributes x6.25, gains /6.25 -> logits bit-equal.
                                     # History: tuned 0.42 -> 0.24 (2026-06-08): the old gain let a
                                     # 4-over specialist take ~3.17 wkts/match (unreal) and made
                                     # an 8-composure batter near-immortal (avg ~141). At 0.24 the
                                     # specialist takes ~1.9 wkts (elite-realistic) and the batting
                                     # avg falls to ~86 — base_w (even-contest 3.5%) is unchanged.
@export var intent_w: Array[float] = [-0.55, 0.0, 0.60]  # [defensive, balanced, aggressive]

# --- Stage 2: scoring strength s = sigmoid(base_r + k_r*(power - control) + intent_r[intent])
@export var base_r: float = 0.2  # was 0.0; BB11 environment re-peg after the steep
                                  # tail pulled the textbook-mirror mean to 149 — lifts
                                  # scoring ~6 runs back into the 150-167 band
@export var k_r: float = 0.0544   # = 0.34 / Attributes.SCALE (card-rescale DR1)
@export var intent_r: Array[float] = [-0.75, 0.0, 0.80]

# Runs distributions (aligned to RUN_VALUES), blended DEF->AGG by s.
@export var def_dist: Array[float] = [0.68, 0.255, 0.035, 0.004, 0.020, 0.006]
@export var agg_dist: Array[float] = [0.30, 0.300, 0.090, 0.010, 0.200, 0.100]

# --- Intent x bowler-kind matchup (BB3, bowling-balance spec): added to the
# wicket logit when the bowler's kind is known. Indexed by BallResolver.Intent
# [DEF, BAL, AGG]. Strawman: only slogging spin is extra-risky (stumped /
# holed out to the deep).
@export var matchup_w_pace: Array[float] = [0.0, 0.0, 0.0]
@export var matchup_w_spin: Array[float] = [0.0, 0.0, 0.30]
