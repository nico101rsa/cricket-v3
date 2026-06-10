class_name EconomyTuning
extends Resource

# Dials for the V1 ₸ economy (spec 2026-06-10-tons-economy-7cD §5.1, DE2/DE3/
# DE7/DE8/DE9). All @export so the balance harness can sweep them. runs_rate /
# wicket_rate are tuned by tools/sweep_economy.gd for ±15% build pay-fairness;
# finals recorded in spec §10.

@export var base_pay: float = 50.0        # base contract ₸ per match at ★3 ("base 50 + perf 18")
@export var star_pay_slope: float = 8.0   # ₸ less per ★ above 3 — stronger Teams pay less (CONTEXT §Tons)
@export var runs_rate: float = 0.5        # perf ₸ per run scored
@export var wicket_rate: float = 11.0     # perf ₸ per wicket taken
@export var attr_cost_base: float = 10.0  # +1 attribute costs attr_cost_base × current value (DE7;
                                          # tuned 12→10 by sweep_economy: +1 attr ≈ +0.5% win and is
                                          # Career-permanent — 10× lands it ~1.3–2.6× joker ₸-per-win-
                                          # point on a 3-Season horizon, inside the ~2× premium target)
@export var sell_refund_frac: float = 0.5 # partial refund selling a joker back (DE9)
@export var loadout_cap: int = 4          # max active joker slots (CONTEXT.md 4 slots; DE8)
