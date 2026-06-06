extends SceneTree
## Authoring tool: (re)generates the hardcoded "Sol" system resource.
##
## The authored artifact is resources/systems/sol.tres; this script is its source
## of truth. Run headless:  godot --headless -s tools/build_sol_system.gd
##
## Bodies are placed at realistic solar-system distances (AU × Travel.WU_PER_AU):
## an inner world at 1 AU, a mid giant, a refuelling station, and the outer world
## at 40 AU. Tune by feel — none of this touches logic.

const OUT_PATH: String = "res://resources/systems/sol.tres"


func _init() -> void:
	var bodies: Array[BodyData] = []
	bodies.append(_body("sol_star", "BODY_SOL_STAR", BodyData.Kind.STAR,
		Vector2.ZERO, 120.0, Color(1.0, 0.85, 0.4)))
	bodies.append(_body("verdant", "BODY_VERDANT", BodyData.Kind.PLANET,
		_at(1.0, 0.0), 48.0, Color(0.4, 0.78, 0.52)))      # ~Earth, 1 AU
	bodies.append(_body("rubicon", "BODY_RUBICON", BodyData.Kind.PLANET,
		_at(5.2, 130.0), 56.0, Color(0.82, 0.42, 0.34)))   # ~Jupiter, 5.2 AU
	bodies.append(_body("tethys", "BODY_TETHYS", BodyData.Kind.PLANET,
		_at(40.0, 215.0), 40.0, Color(0.55, 0.62, 0.82)))  # outer world, 40 AU

	var station := _body("anchorage", "BODY_ANCHORAGE", BodyData.Kind.STATION,
		_at(9.5, -55.0), 22.0, Color(0.78, 0.78, 0.92))    # ~Saturn orbit, refuel point
	station.can_dock = true
	station.can_refuel = true
	bodies.append(station)

	var system := SystemData.new()
	system.id = "sol"
	system.name_key = "SYSTEM_SOL"
	system.bodies = bodies
	system.ship_start = _at(1.0, -40.0)  # in the inner system, near Verdant

	var err: int = ResourceSaver.save(system, OUT_PATH)
	if err == OK:
		print("[build_sol_system] wrote %s (%d bodies)" % [OUT_PATH, bodies.size()])
	else:
		push_error("[build_sol_system] save failed: %d" % err)
	quit()


## World position at `au` astronomical units from the star, at `degrees`.
func _at(au: float, degrees: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(degrees)) * au * Travel.WU_PER_AU


func _body(id: String, name_key: String, kind: BodyData.Kind, pos: Vector2,
		radius: float, tint: Color) -> BodyData:
	var b := BodyData.new()
	b.id = id
	b.name_key = name_key
	b.kind = kind
	b.position = pos
	b.radius = radius
	b.tint = tint
	return b
