class_name OrreryProjection
extends RefCounted
## Pure orrery projection (ADR 0016/0018/0021): real positions → chart positions.
## **Bearing is preserved exactly** so direction stays truthful; only the *radius*
## mapping varies by `OrreryParams.mode`:
##   LOG    — radius log-compressed onto the ring band (the schematic default).
##   LINEAR — radius proportional to real distance (true scale; r_max → ring_outer).
## No node deps; GUT-tested. The Nav Plot is a thin renderer over this.
##
## `project` takes an offset from the star hub (caller subtracts the star pos);
## `project_child` places a moon about its parent's projected point.

## Map a real radius (wu) to a chart radius (px) under the current scale mode.
static func _radius_px(r: float, p: OrreryParams) -> float:
	if p.mode == OrreryParams.ScaleMode.LINEAR:
		return clampf(r / p.r_max, 0.0, 1.0) * p.ring_outer
	var t := (log(r) - log(p.r_min)) / (log(p.r_max) - log(p.r_min))
	return lerpf(p.ring_inner, p.ring_outer, clampf(t, 0.0, 1.0))


## Smallest real radius that still has a bearing to draw (below it → the hub).
static func _hub_cutoff(p: OrreryParams) -> float:
	return 0.001 if p.mode == OrreryParams.ScaleMode.LINEAR else p.r_min


## Project a body's offset-from-star to its chart position (screen px).
static func project(offset_from_star: Vector2, p: OrreryParams) -> Vector2:
	var r := offset_from_star.length()
	if r < _hub_cutoff(p):
		return p.center  # star / very-inner clamps to the hub (no log(0))
	return p.center + offset_from_star.normalized() * _radius_px(r, p)


## Inverse of `project`: a chart position (screen px) back to a real offset-from-
## star (wu), for turning an empty-space click into a destination point (ADR 0020).
## Bearing comes straight from the chart; radius inverts the active mode's map.
## Round-trips `project` for any real point inside the ring band.
static func unproject(chart_pos: Vector2, p: OrreryParams) -> Vector2:
	var offset := chart_pos - p.center
	var radius_px := offset.length()
	if radius_px < 0.001:
		return Vector2.ZERO  # the hub
	var r: float
	if p.mode == OrreryParams.ScaleMode.LINEAR:
		r = radius_px * p.r_max / p.ring_outer
	else:
		var t := clampf((radius_px - p.ring_inner) / (p.ring_outer - p.ring_inner), 0.0, 1.0)
		r = exp(lerpf(log(p.r_min), log(p.r_max), t))
	return offset.normalized() * r


## Like `project`, but in LOG mode the inner region (r < r_min) **ramps inward**
## from `ring_inner` down to the hub, at the true bearing — so a course passing
## near/through the star is pulled in toward the centre (a real fly-by passes close
## to it) rather than ballooning out around the inner ring or spiking through the
## hub (ADR 0016 gently-curved line; amended ADR 0023 feel pass). In LINEAR mode
## there is no log singularity, so it is exactly `project`.
static func project_path(offset_from_star: Vector2, p: OrreryParams) -> Vector2:
	if p.mode == OrreryParams.ScaleMode.LINEAR:
		return project(offset_from_star, p)
	var r := offset_from_star.length()
	if r < 0.001:
		return p.center  # exactly at the hub; no bearing to preserve (no log(0))
	var radius: float
	if r >= p.r_min:
		var t := (log(r) - log(p.r_min)) / (log(p.r_max) - log(p.r_min))
		radius = lerpf(p.ring_inner, p.ring_outer, clampf(t, 0.0, 1.0))
	else:
		radius = p.ring_inner * (r / p.r_min)  # ramp ring_inner → 0 toward the hub
	return p.center + offset_from_star.normalized() * radius


## Lay out a moon inside the focus inset (ADR 0022): the moon's real offset-from-
## parent scaled so the farthest moon sits at `inset_radius` from the centre,
## bearing preserved. A pure local map (no scale-mode coupling), GUT-tested.
static func project_satellite(offset_from_parent: Vector2, center: Vector2,
		inset_radius: float, max_offset: float) -> Vector2:
	if max_offset <= 0.0 or offset_from_parent.length() < 0.001:
		return center
	return center + offset_from_parent * (inset_radius / max_offset)


## Project a moon from its offset-from-parent, about the parent's already-projected
## chart position. Bearing-from-parent preserved. In LOG mode the moon sits in a
## small legible local cluster; in LINEAR (true scale) it takes its real scaled
## offset — so moons collapse onto the parent, as reality has them (ADR 0021/0022).
static func project_child(offset_from_parent: Vector2, parent_projected: Vector2,
		p: OrreryParams) -> Vector2:
	var d := offset_from_parent.length()
	if p.mode == OrreryParams.ScaleMode.LINEAR:
		if d < 0.001:
			return parent_projected
		return parent_projected + offset_from_parent.normalized() * _radius_px(d, p)
	if d <= p.moon_r_min:
		return parent_projected
	var t := (log(d) - log(p.moon_r_min)) / (log(p.moon_r_max) - log(p.moon_r_min))
	var radius := lerpf(p.moon_ring_inner, p.moon_ring_outer, clampf(t, 0.0, 1.0))
	return parent_projected + offset_from_parent.normalized() * radius
