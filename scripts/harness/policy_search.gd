class_name PolicySearch
extends RefCounted

# E1 self-play helpers (spec 2026-06-10-selfplay-baseline-7cE1-design.md D7).
# A static no-joker policy = one batting Intent per phase x one bowler Kind per
# phase = 27 x 8 = 216. Pure functions only; the oracle composes them.

const INTENTS := [BallResolver.Intent.DEFENSIVE, BallResolver.Intent.BALANCED, BallResolver.Intent.AGGRESSIVE]
const KINDS := [BowlingPlan.Kind.PACE, BowlingPlan.Kind.SPIN]

const INTENT_LETTER := {
	BallResolver.Intent.DEFENSIVE: "D",
	BallResolver.Intent.BALANCED: "B",
	BallResolver.Intent.AGGRESSIVE: "A",
}
const KIND_LETTER := {
	BowlingPlan.Kind.PACE: "P",
	BowlingPlan.Kind.SPIN: "S",
}


# All 216 policies in a stable order (intent loops outer, bowling inner).
static func enumerate() -> Array:
	var out: Array = []
	for pp_i in INTENTS:
		for mid_i in INTENTS:
			for death_i in INTENTS:
				for pp_b in KINDS:
					for mid_b in KINDS:
						for death_b in KINDS:
							out.append({
								"pp_intent": pp_i, "mid_intent": mid_i, "death_intent": death_i,
								"pp_bowl": pp_b, "mid_bowl": mid_b, "death_bowl": death_b,
							})
	return out


static func intent_plan_of(p: Dictionary) -> IntentPlan:
	var plan := IntentPlan.new()
	plan.powerplay = p["pp_intent"]
	plan.middle = p["mid_intent"]
	plan.death = p["death_intent"]
	return plan


static func bowling_plan_of(p: Dictionary) -> BowlingPlan:
	var plan := BowlingPlan.new()
	plan.powerplay = p["pp_bowl"]
	plan.middle = p["mid_bowl"]
	plan.death = p["death_bowl"]
	return plan


# Compact display label, e.g. "A/B/A·P/S/P" (textbook).
static func label_of(p: Dictionary) -> String:
	return "%s/%s/%s·%s/%s/%s" % [
		INTENT_LETTER[p["pp_intent"]], INTENT_LETTER[p["mid_intent"]], INTENT_LETTER[p["death_intent"]],
		KIND_LETTER[p["pp_bowl"]], KIND_LETTER[p["mid_bowl"]], KIND_LETTER[p["death_bowl"]],
	]


# The textbook start point: attack PP, build middle, slog death; pace/spin/pace.
static func textbook() -> Dictionary:
	return {
		"pp_intent": BallResolver.Intent.AGGRESSIVE,
		"mid_intent": BallResolver.Intent.BALANCED,
		"death_intent": BallResolver.Intent.AGGRESSIVE,
		"pp_bowl": BowlingPlan.Kind.PACE,
		"mid_bowl": BowlingPlan.Kind.SPIN,
		"death_bowl": BowlingPlan.Kind.PACE,
	}


# All-BALANCED intent + textbook rotation (the pre-rung-4a "no plan" player).
static func balanced() -> Dictionary:
	return {
		"pp_intent": BallResolver.Intent.BALANCED,
		"mid_intent": BallResolver.Intent.BALANCED,
		"death_intent": BallResolver.Intent.BALANCED,
		"pp_bowl": BowlingPlan.Kind.PACE,
		"mid_bowl": BowlingPlan.Kind.SPIN,
		"death_bowl": BowlingPlan.Kind.PACE,
	}


# Argmax over win rates; ties go to the LOWER index (stable).
static func best_index(win_rates: Array) -> int:
	var best := 0
	for i in range(1, win_rates.size()):
		if win_rates[i] > win_rates[best]:
			best = i
	return best


# The ADR 0003 "naive" player: one uniform draw from the policy list per match.
static func random_policy(policies: Array, rng: RandomNumberGenerator) -> Dictionary:
	return policies[rng.randi_range(0, policies.size() - 1)]
