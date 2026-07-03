class_name DRSPolicy
extends RefCounted

# The DRS (Decision Review System) as a harness input. A review is attempted at a
# close decision (the Player dismissed while batting → review to survive; the
# Player conceding a dot while bowling → review to claim a wicket). base_reviews
# is the per-innings resource; base_p the success chance before Reviewer jokers
# modify it. Strawman, balance-tunable. See spec 2026-06-08-…-7cC2f-drs-design.md.

var base_reviews: int = 2
var base_p: float = 0.32   # claim-channel (dot review) success chance; the survive
                           # channel rolls DRSMoments.moment_p per moment (T8)

# Interactive (DI3): when non-null, the Player's batting-side survive-review fires
# ONLY on the [over, ball_in_over] pairs in this set (scripted by MatchSession).
# null = auto policy (sweeps / headless / the AI) → DRS decision moments
# (spec 2026-07-04): only DRSMoments.is_moment wickets, at the hash-drawn moment p,
# attempted iff p >= DRSMoments.AI_BURN_P.
var review_balls = null

# Test seam (spec 2026-07-04 DT6): when >= 0, every survive-channel moment p is
# forced to this value (deterministic tests). < 0 = hash-drawn per moment.
var moment_p_override: float = -1.0
