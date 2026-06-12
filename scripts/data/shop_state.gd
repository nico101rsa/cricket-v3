class_name ShopState
extends Resource

# Season-scoped joker ownership (shop rung DK6). Created fresh each Season by
# play_season; the only cross-Season survivor is CareerState.carryover_joker_id.
@export var owned_ids: Array[String] = []      # <= loadout_cap (4)
@export var paid_prices: Dictionary = {}       # id -> Tons paid (refund base, DK14)
@export var held_id: String = ""               # one held offer (DK15); "" = none
