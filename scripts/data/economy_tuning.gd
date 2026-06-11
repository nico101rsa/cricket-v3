class_name EconomyTuning
extends Resource

# Dials for the V1 ₸ economy (spec 2026-06-10-tons-economy-7cD §5.1 + the
# performance-contract re-design, spec §10.2). All @export so the balance
# harness can sweep them. Solved against tools/sweep_economy.gd measurements
# (2026-06-10): game fee ≈ 50% of a specialist's take-home; perf components
# baselined on the measured going rates (SR ~110, RR ~9.0 → club-par 12).

@export var base_pay: float = 33.0        # the game fee — ≈50% of total pay at ★3 (Nico 2026-06-10)
@export var star_pay_slope: float = 5.0   # ₸ less per ★ above 3 — stronger Teams pay less (CONTEXT §Tons)

# Batting components
@export var runs_rate: float = 0.45      # ₸ per run scored (0.4->0.45 at card-rescale: the
                                          # proportional-noise env trimmed batter runs ~₸2 vs
                                          # bowling pay — one-dial re-peg, spread back ≤₸1)
@export var sr_par_pay: float = 125.0     # tempo baseline SR — runs above this tempo earn extra (re-pegged 110->125 at the bowling-balance rung: the new environment runs hotter SRs)
@export var sr_rate: float = 1.3          # ₸ per run scored above par tempo (clamped ≥0)
@export var fifty_bonus: float = 20.0     # flat milestone ₸ at 50+
@export var ton_bonus: float = 100.0      # flat milestone ₸ on top at 100+ — a Ton pays a ₸100 (ADR 0008)

# Bowling components
@export var wicket_rate: float = 10.0     # ₸ per wicket taken (8->10 at the bowling-balance rung: wickets cost more, so taking them pays more)
@export var rr_par_pay: float = 12.0      # economy baseline RR ("club par" = measured going rate ~9 + 3);
                                          # pay accrues per run kept below this over the spell
@export var econ_rate: float = 1.3        # ₸ per run saved vs club par, scaled by balls bowled (clamped ≥0)

# Versatility (Nico 2026-06-10: any build must earn ~equal — the minor
# discipline's balls count more). Bonus = versatility_rate × min(balls faced /
# bat_ref_balls, balls bowled / bowl_ref_balls), each capped at 1. Pure
# specialists score 0 on their minor discipline → no bonus; doing both jobs
# pays the gap an opportunity-starved all-rounder loses on raw components.
@export var versatility_rate: float = 100.0  # solved on the realized bonus (sweep 2026-06-10)
@export var bat_ref_balls: float = 20.0   # a "full" batting innings worth of balls
@export var bowl_ref_balls: float = 24.0  # a full 4-over spell

# Shop / meta
@export var attr_cost_base: float = 0.256 # +1 /100-point costs attr_cost_base × current value.
                                          # Card-rescale DR11: = 10 / 6.25² — preserves the DE7
                                          # calibration exactly (+1 legacy point at legacy-8 = ₸80;
                                          # tuned 12→10 then: +1 legacy attr ≈ +0.5% win, Career-
                                          # permanent, ~1.3–2.6× joker ₸-per-win-point over 3 Seasons).
                                          # The shop's natural unit is a +5 block ≈ ₸64 at card 50.
@export var sell_refund_frac: float = 0.5 # partial refund selling a joker back (DE9)
@export var loadout_cap: int = 4          # max active joker slots (CONTEXT.md 4 slots; DE8)
