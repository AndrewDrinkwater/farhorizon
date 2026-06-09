extends GutTest
## SurfaceView (ADR 0030): tracks the landed body + the ship's surface position.
## Presentation node; we exercise its body/position logic. Snapshots GameState.

var _snapshot: Dictionary
var _sv: SurfaceView


func before_each() -> void:
	_snapshot = GameState.to_dict()
	GameState.system.system_id = "sol"
	GameState.ship = ShipState.new()
	_sv = SurfaceView.new()
	add_child_autofree(_sv)
	_sv.build(TypeRegistry.get_system("sol"))


func after_each() -> void:
	GameState.from_dict(_snapshot)


func test_no_body_when_not_landed() -> void:
	GameState.ship.location = Travel.Location.DEEP_SPACE
	EventBus.ship_context_changed.emit()
	assert_null(_sv._body, "surface map is empty in space")


func test_tracks_the_landed_body() -> void:
	GameState.ship.location = Travel.Location.LANDED
	GameState.ship.location_body_id = "verdant"
	EventBus.ship_context_changed.emit()
	assert_not_null(_sv._body, "the landed body drives the map")
	assert_eq(_sv._body.id, "verdant")


func test_ship_surface_position_is_the_authoritative_field() -> void:
	GameState.ship.location = Travel.Location.LANDED
	GameState.ship.location_body_id = "verdant"
	GameState.ship.surface_position = Vector2(42.0, -17.0)  # e.g. a free touchdown
	EventBus.ship_context_changed.emit()
	assert_eq(_sv._ship_surface_pos(), Vector2(42.0, -17.0), "renders at the live surface coord")
