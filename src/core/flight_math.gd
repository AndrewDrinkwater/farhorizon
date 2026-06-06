class_name FlightMath
extends RefCounted
## Pure flight math (ADR 0005): course distance, ETA in ticks, and reaction-mass
## cost as a function of burn intensity. No node deps, so it's GUT-testable and
## the canonical owner of the Burn enum used by Helm, FlightController, and here.
##
## The model is deliberately simple for α0.1: a straight-line course at a fixed
## per-burn cruise speed, with reaction mass spent per world-unit travelled.
## Higher burn = faster (shorter ETA) but costs more RM per wu — the real
## time-vs-fuel lever the design wants. All numbers below are TUNING constants
## (CONVENTIONS.md), expected to change at the step-9 feel pass and likely to
## move onto per-hull authored data later (ADR 0005 consequences).

## Burn intensity — the player's control lever (Helm burn selector).
enum Burn { ECONOMY, STANDARD, HARD }

## Warp 1 = the speed of light: light crosses 1 AU in this many ticks (one tick =
## one in-game minute; real value ~8.3, rounded to 8). So Warp 1 in wu/tick is
## WU_PER_AU / LIGHT_MINUTES_PER_AU.
const LIGHT_MINUTES_PER_AU: float = 8.0

## Each burn's warp factor (multiple of light speed). Economy is the slow cruise
## (2.5× c); Standard/Hard scale up. Speeds derive from these — tuning knobs.
const _WARP_FACTOR: Dictionary = {
	Burn.ECONOMY: 2.5,
	Burn.STANDARD: 4.0,
	Burn.HARD: 6.0,
}

## Reaction mass (RM) spent per world unit travelled. Tuned (against the AU-scale
## Sol spacing + 100 RM tank) so inner trips are cheap and the 40 AU outer haul
## needs a refuel stop on the faster burns.
const _RM_PER_WU: Dictionary = {
	Burn.ECONOMY: 0.0018,
	Burn.STANDARD: 0.0030,
	Burn.HARD: 0.0052,
}


## Warp 1 (speed of light) in world units per tick.
static func warp_1_speed() -> float:
	return Travel.WU_PER_AU / LIGHT_MINUTES_PER_AU


static func is_valid_burn(burn: int) -> bool:
	return _WARP_FACTOR.has(burn)


## The warp factor (× light speed) for a burn intensity.
static func warp_factor(burn: int) -> float:
	return _WARP_FACTOR.get(burn, _WARP_FACTOR[Burn.STANDARD])


## Cruise speed (wu/tick) for a burn intensity = warp factor × light speed.
static func speed_wu_per_tick(burn: int) -> float:
	return warp_factor(burn) * warp_1_speed()


## Straight-line course distance in world units.
static func distance(from: Vector2, to: Vector2) -> float:
	return from.distance_to(to)


## Whole ticks to traverse `dist` at `burn`. Rounded up — a partial tick still
## costs a tick of clock time. Zero distance = zero ticks.
static func eta_ticks(dist: float, burn: int) -> int:
	if dist <= 0.0:
		return 0
	return int(ceil(dist / speed_wu_per_tick(burn)))


## Reaction mass spent to traverse `dist` at `burn` (linear in distance).
static func rm_cost(dist: float, burn: int) -> float:
	if dist <= 0.0:
		return 0.0
	var rate: float = _RM_PER_WU.get(burn, _RM_PER_WU[Burn.STANDARD])
	return dist * rate


## Course preview for the Helm plot: distance + ETA + fuel for a from→to course.
## `available_rm` flags whether the current tank can afford it (UI shows
## "Unable — insufficient reaction mass" when false).
static func preview(from: Vector2, to: Vector2, burn: int, available_rm: float) -> Dictionary:
	var dist: float = distance(from, to)
	var cost: float = rm_cost(dist, burn)
	return {
		"distance": dist,
		"eta_ticks": eta_ticks(dist, burn),
		"rm_cost": cost,
		"affordable": cost <= available_rm,
	}
