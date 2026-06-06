class_name OrreryProjection
extends RefCounted
## Pure orrery projection (ADR 0016/0018): real positions → chart positions.
## Radius is log-compressed onto a screen ring band; **bearing is preserved
## exactly** so direction stays truthful. No node deps; GUT-tested. The Nav Plot
## is a thin renderer over this.
##
## `project` takes an offset from the star hub (caller subtracts the star pos);
## `project_child` places a moon in a small local cluster about its parent's
## projected point, from the moon's offset-from-parent.

## Project a body's offset-from-star to its chart position (screen px).
static func project(offset_from_star: Vector2, p: OrreryParams) -> Vector2:
	var r := offset_from_star.length()
	if r < p.r_min:
		return p.center  # star / very-inner clamps to the hub (no log(0))
	var t := (log(r) - log(p.r_min)) / (log(p.r_max) - log(p.r_min))
	var radius := lerpf(p.ring_inner, p.ring_outer, clampf(t, 0.0, 1.0))
	return p.center + offset_from_star.normalized() * radius


## Project a moon from its offset-from-parent, clustered about the parent's
## already-projected chart position. Bearing-from-parent preserved.
static func project_child(offset_from_parent: Vector2, parent_projected: Vector2,
		p: OrreryParams) -> Vector2:
	var d := offset_from_parent.length()
	if d <= p.moon_r_min:
		return parent_projected
	var t := (log(d) - log(p.moon_r_min)) / (log(p.moon_r_max) - log(p.moon_r_min))
	var radius := lerpf(p.moon_ring_inner, p.moon_ring_outer, clampf(t, 0.0, 1.0))
	return parent_projected + offset_from_parent.normalized() * radius
