class_name DRSPolicy
extends RefCounted

# The DRS (Decision Review System) as a harness input. A review is attempted at a
# close decision (the Player dismissed while batting → review to survive; the
# Player conceding a dot while bowling → review to claim a wicket). base_reviews
# is the per-innings resource; base_p the success chance before Reviewer jokers
# modify it. Strawman, balance-tunable. See spec 2026-06-08-…-7cC2f-drs-design.md.

var base_reviews: int = 2
var base_p: float = 0.32

# Interactive (DI3): when non-null, the Player's batting-side survive-review fires
# ONLY on the [over, ball_in_over] pairs in this set (scripted by MatchSession).
# null = auto policy (every sweep / headless call) → byte-identical to pre-rung.
var review_balls = null
