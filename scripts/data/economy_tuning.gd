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
@export var runs_rate: float = 0.50      # ₸ per run scored (0.4->0.45 at card-rescale; 0.45->0.50
                                          # at the economy-reconciliation rung 2026-06-15: post-
                                          # world-scale-v2 the pure batter had drifted to the pay-
                                          # FLOOR — archetype spread ₸2.1, batter ₸66.3 < all-
                                          # rounder ₸68.4. The batter scores ~34 runs/match vs ~0-4
                                          # for the others, so this single pay-only dial lifts the
                                          # floor build most: spread ₸2.1->₸0.8, batter off the
                                          # floor. Bottoms out ~₸0.8 because the bowler's pay is
                                          # anchored by bowling components no runs dial moves.)
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
@export var attr_cost_base: float = 7.0   # +1 /100-point costs attr_cost_base × current value.
                                          # Career-pacing DP3 (Nico's ruling 2026-06-12): attributes
                                          # are the CAREER-horizon ₸ sink — a no-joker player should
                                          # max out around the naive line's median completion (~49
                                          # Seasons), not by Season 2. Supersedes the 7c-D DE7
                                          # legacy-ROI calibration (was 0.256 = 10/6.25²); the
                                          # joker-vs-attribute ROI gets re-solved at the Shop rung
                                          # when both sinks coexist. Re-pegged 11→13 at the
                                          # difficulty-sheet-v2 rung: prize escalation added income
                                          # and pulled max-out to S41 — 13 restored ~S46 (spec §10.2).
                                          # World-scale v2 (2026-06-13, WS4): the fresh hero now starts
                                          # at 11 (was 35), so the climb is 44->240 not 125->240 — many
                                          # more points to buy. Re-pegged 13->7 (attr_only max-out
                                          # S89->S67). Final pacing target is Nico's call (deferred).
@export var sell_refund_frac: float = 0.5 # partial refund selling a joker back (DE9)
@export var loadout_cap: int = 4          # max active joker slots (CONTEXT.md 4 slots; DE8)

# Team winning bonus (career-loop rung DC10, ideas cluster 2): ₸ per Player-team
# win, scaling with Level. Deliberately small next to ~₸66 match pay so
# build-pay equality is untouched (team wins are build-independent).
@export var win_bonus_base: float = 5.0
@export var win_bonus_level_step: float = 5.0

# Prize escalation + prize objects (difficulty-sheet v2, spec DV7/DV8 — the
# incentive replacing the removed endgame gate). Escalation = per-tour ABSOLUTE
# multipliers vs the Tour-1 base (Nico 2026-06-12: not compounding, T8 = 1.6x);
# scales the four match-prize objects only — game fee + performance pay are
# untouched, so build-pay equality is untouched.
@export var prize_escalation: Array[float] = [1.0, 1.1, 1.1, 1.1, 1.3, 1.4, 1.5, 1.6]
@export var playoff_win_base: float = 15.0        # winning a semi / the 3rd-place playoff
@export var playoff_win_level_step: float = 10.0
@export var final_appearance_base: float = 25.0   # playing The Final
@export var final_appearance_level_step: float = 15.0
@export var grand_final_base: float = 60.0        # winning The Final
@export var grand_final_level_step: float = 40.0
@export var premier_super_base: float = 250.0     # Premier (T8) Grand Final trophy payout,
@export var premier_super_level_step: float = 250.0   # NOT escalated (DV8)

# Shop pricing (shop rung DK5): catalog price x level mult x tour mult.
# Tour mult initialised to the prize-escalation shape so cost tracks income;
# a SEPARATE dial so they can diverge when measured (E4).
@export var joker_price_level_mult: Array[float] = [1.0, 1.5, 2.0]
@export var joker_price_tour_mult: Array[float] = [1.0, 1.1, 1.1, 1.1, 1.3, 1.4, 1.5, 1.6]

# Kit Room offer rarity odds (Nico 2026-06-13): Common always on the shelf;
# Rare a coin-flip; Legendary ~15% (≈ one every 1.5 seasons over 4 paid visits).
@export var shop_rare_chance: float = 0.5
@export var shop_legendary_chance: float = 0.15
