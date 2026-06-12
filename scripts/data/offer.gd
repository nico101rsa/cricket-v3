class_name Offer
extends RefCounted

# One end-of-Season recruitment proposal (career-loop spec §3.2). Pure data;
# stars is a snapshot taken AFTER the rollover mutation (DC8) so the Offer
# shows the ★ the Team will actually have next Season.

var team_index: int = 0
var level: int = 0
var stars: float = 0.0
