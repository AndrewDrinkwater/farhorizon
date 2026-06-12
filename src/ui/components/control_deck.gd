class_name ControlDeck
extends HBoxContainer
## The contents of the control box (ADR 0034): a centred row of command Sections.
## Whole sections hide per a visibility map so only context-appropriate orders show
## (the resolver stays pure — e.g. HelmGroups, ADR 0032). It lives inside the frame's
## fixed control box; one reusable row fed different sections per console/context.

var _sections: Dictionary = {}  # id:String -> Section


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 28)


func add_section(section: Section) -> void:
	add_child(section)
	_sections[section.id] = section


## Show only the sections the context allows (id -> bool); an id not in the map
## stays shown. Buttons within a visible section grey via Travel.available.
func apply_visibility(visible_by_id: Dictionary) -> void:
	for id: String in _sections:
		_sections[id].visible = bool(visible_by_id.get(id, true))
