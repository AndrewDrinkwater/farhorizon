extends SceneTree
## Authoring tool: (re)generates the hardcoded "Sol" system resource.
##
## The authored artifact is resources/systems/sol.tres; this script is its
## source of truth so it can be regenerated deterministically rather than
## hand-editing typed-array sub-resources by hand. Run headless:
##   godot --headless -s tools/build_sol_system.gd
## Positions are in world units (CONVENTIONS.md). Re-run after editing, then
## commit the resulting .tres.

const OUT_PATH: String = "res://resources/systems/sol.tres"


func _init() -> void:
	# Deliberate spacing (wu): the nearest planet is ~3 standard-burn ticks
	# (~3 in-game hours / ~3 real minutes at 1x) from the ship start; outer bodies
	# scale up from there. Tune by feel — none of this touches logic.
	var bodies: Array[BodyData] = []
	bodies.append(_body("sol_star", "BODY_SOL_STAR", BodyData.Kind.STAR,
		Vector2(0, 0), 120.0, Color(1.0, 0.85, 0.4)))
	bodies.append(_body("verdant", "BODY_VERDANT", BodyData.Kind.PLANET,
		Vector2(450, 0), 48.0, Color(0.4, 0.78, 0.52)))
	bodies.append(_body("rubicon", "BODY_RUBICON", BodyData.Kind.PLANET,
		Vector2(-450, 250), 56.0, Color(0.82, 0.42, 0.34)))
	bodies.append(_body("tethys", "BODY_TETHYS", BodyData.Kind.PLANET,
		Vector2(200, 700), 40.0, Color(0.55, 0.62, 0.82)))

	var station := _body("anchorage", "BODY_ANCHORAGE", BodyData.Kind.STATION,
		Vector2(700, 300), 22.0, Color(0.78, 0.78, 0.92))
	station.can_dock = true
	station.can_refuel = true
	bodies.append(station)

	var system := SystemData.new()
	system.id = "sol"
	system.name_key = "SYSTEM_SOL"
	system.bodies = bodies
	system.ship_start = Vector2(450, -360)

	var err: int = ResourceSaver.save(system, OUT_PATH)
	if err == OK:
		print("[build_sol_system] wrote %s (%d bodies)" % [OUT_PATH, bodies.size()])
	else:
		push_error("[build_sol_system] save failed: %d" % err)
	quit()


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
