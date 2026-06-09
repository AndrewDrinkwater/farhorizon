class_name LandingMath
extends RefCounted
## Pure landing math (ADR 0029): the atmosphere display class + the modifiable-stat
## chain for descent/ascent duration. No node deps; GUT-tested. Atmosphere is the
## first (only, now) factor; mass / pilot skill / equipment just append to the
## chain later — the chain shape is the point, not a global stat engine.
##
## All numbers here are TUNING constants (CONVENTIONS.md), expected to change at
## the feel pass; none change the chain's shape.

## Derived display class (never stored) from surface pressure in Earth atmospheres.
enum AtmoClass { NONE, THIN, STANDARD, DENSE, CRUSHING }

## Class thresholds (atm). None at vacuum; Thin trace; Standard ~Earth; Dense; Crushing.
const THIN_ATM: float = 0.5
const STANDARD_ATM: float = 2.0
const DENSE_ATM: float = 10.0

## Descent/ascent time grows with pressure: factor 1.0 at vacuum, + this per atm.
const FACTOR_PER_ATM: float = 0.4


static func atmosphere_class(atm: float) -> int:
	if atm <= 0.0:
		return AtmoClass.NONE
	if atm < THIN_ATM:
		return AtmoClass.THIN
	if atm < STANDARD_ATM:
		return AtmoClass.STANDARD
	if atm < DENSE_ATM:
		return AtmoClass.DENSE
	return AtmoClass.CRUSHING


## Time multiplier from surface pressure: 1.0 at vacuum, monotonically larger with
## more atmosphere (more to descend through / push up against).
static func atmosphere_factor(atm: float) -> float:
	return 1.0 + maxf(0.0, atm) * FACTOR_PER_ATM


## Modifiable stat: base ticks × the product of all factors, rounded. Empty chain
## returns the base unchanged. Descent and ascent both run through this.
static func modified_ticks(base: int, factors: Array[float]) -> int:
	var ticks := float(base)
	for f: float in factors:
		ticks *= f
	return int(round(ticks))
