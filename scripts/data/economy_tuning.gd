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
@export var runs_rate: float = 0.4        # ₸ per run scored
@export var sr_par_pay: float = 110.0     # tempo baseline SR — runs above this tempo earn extra
@export var sr_rate: float = 1.3          # ₸ per run scored above par tempo (clamped ≥0)
@export var fifty_bonus: float = 20.0     # flat milestone ₸ at 50+
@export var ton_bonus: float = 100.0      # flat milestone ₸ on top at 100+ — a Ton pays a ₸100 (ADR 0008)

# Bowling components
@export var wicket_rate: float = 8.0      # ₸ per wicket taken
@export var rr_par_pay: float = 12.0      # economy baseline RR ("club par" = measured going rate ~9 + 3);
                                          # pay accrues per run kept below this over the spell
@export var econ_rate: float = 1.3        # ₸ per run saved vs club par, scaled by balls bowled (clamped ≥0)

# Shop / meta
@export var attr_cost_base: float = 10.0  # +1 attribute costs attr_cost_base × current value (DE7;
                                          # tuned 12→10: +1 attr ≈ +0.5% win and is Career-permanent —
                                          # ~1.3–2.6× joker ₸-per-win-point on a 3-Season horizon)
@export var sell_refund_frac: float = 0.5 # partial refund selling a joker back (DE9)
@export var loadout_cap: int = 4          # max active joker slots (CONTEXT.md 4 slots; DE8)
