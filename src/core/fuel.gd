class_name Fuel
extends RefCounted
## Fuel pools (CONVENTIONS.md). Reaction Mass drives thrust/manoeuvring and is
## the α0.1 pool; Warp Fuel is reserved for FTL (out of scope until multi-system).
## The enum value is the int payload of EventBus.fuel_changed(pool, value).

enum Pool { REACTION_MASS, WARP }
