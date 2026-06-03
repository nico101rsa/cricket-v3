class_name Classifier
extends RefCounted

# Pure function: maps an Attributes distribution to a flavour label.
# Thresholds are V1 strawman (spec §3.5) — Theme 7 balance harness will tune.

const BATTER_HI := 6       # Power AND Composure must be ≥ this for Batter family
const BOWLER_HI := 6       # Attack AND Control must be ≥ this for Bowler
const BATTER_LO := 4       # Attack AND Control must be ≤ this for Batter family
const BOWLER_LO := 4       # Power AND Composure must be ≤ this for Bowler
const WK_GAP    := 2       # Composure - Power must be ≥ this for WK refinement

static func classify(a: Attributes) -> int:
	var bat_family := a.power >= BATTER_HI \
		and a.composure >= BATTER_HI \
		and a.attack <= BATTER_LO \
		and a.control <= BATTER_LO

	if bat_family and (a.composure - a.power) >= WK_GAP:
		return ClassifierLabel.Kind.WK_BATTER
	if bat_family:
		return ClassifierLabel.Kind.BATTER

	var bowl_family := a.attack >= BOWLER_HI \
		and a.control >= BOWLER_HI \
		and a.power <= BOWLER_LO \
		and a.composure <= BOWLER_LO
	if bowl_family:
		return ClassifierLabel.Kind.BOWLER

	return ClassifierLabel.Kind.ALL_ROUNDER
