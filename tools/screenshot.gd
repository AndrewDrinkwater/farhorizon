extends SceneTree
## Dev utility: boot the main scene, render a few frames, save a screenshot to
## user://helm_shot.png. Useful for eyeballing UI without a headless renderer.
## Run NON-headless (needs a GPU/window):
##   godot --path . -s tools/screenshot.gd

var _frame: int = 0


func _initialize() -> void:
	var scene := load("res://src/ui/shell/main.tscn") as PackedScene
	root.add_child(scene.instantiate())


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame >= 45:
		root.get_texture().get_image().save_png("user://helm_shot.png")
		print("[screenshot] saved user://helm_shot.png")
		return true
	return false
