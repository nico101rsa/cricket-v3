class_name DRSPolicy
extends RefCounted

# The DRS (Decision Review System) as a harness input. A review is attempted at a
# close decision (the Player dismissed while batting → review to survive; the
# Player conceding a dot while bowling → review to claim a wicket). base_reviews
# is the per-innings resource; base_p the success chance before Reviewer jokers
# modify it. Strawman, balance-tunable. See spec 2026-06-08-…-7cC2f-drs-design.md.

var base_reviews: int = 2
var base_p: float = 0.32
