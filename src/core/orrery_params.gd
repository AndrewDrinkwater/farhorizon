class_name OrreryParams
extends RefCounted
## Tuning for the orrery projection (ADR 0016/0018). Pure data — the Nav Plot
## fills `center`/rings from the viewport; the rest are play-tuned constants.
## `center` and the ring radii are screen pixels; the `r_*` clamps are real wu.

var center: Vector2 = Vector2.ZERO
## Real radius (wu) mapped to the inner/outer ring; clamp outside this band.
var r_min: float = 300.0       # ~0.3 AU
var r_max: float = 45000.0     # 45 AU (a touch beyond the 40 AU outer body)
var ring_inner: float = 60.0   # px
var ring_outer: float = 450.0  # px
## Moon (child) local cluster about the parent's projected point.
var moon_r_min: float = 10.0       # wu offset from parent
var moon_r_max: float = 600.0      # wu offset from parent
var moon_ring_inner: float = 16.0  # px
var moon_ring_outer: float = 44.0  # px
