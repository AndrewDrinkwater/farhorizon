class_name ShipView
extends Node2D
## The ship marker — a triangle at the ship's world position, pointed along its
## heading. Reads GameState.ship each frame (ADR 0002 binding); it never mutates.
## Step 4 places it statically; once FlightController lands (step 6) it moves
## with the ship, and rendering will interpolate between ticks (ADR 0004).

const SIZE: float = 28.0
const TINT: Color = Color(0.9, 0.95, 1.0)


func _process(_delta: float) -> void:
	position = GameState.ship.position
	rotation = GameState.ship.heading


func _draw() -> void:
	var nose := Vector2(SIZE, 0.0)
	var wing := SIZE * 0.7
	var tri := PackedVector2Array([
		nose, Vector2(-SIZE * 0.6, -wing), Vector2(-SIZE * 0.6, wing),
	])
	draw_colored_polygon(tri, TINT)
