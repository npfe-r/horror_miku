class_name InteractableObject
extends AnimatableBody3D

@export var interaction_text: String = "交互"
@export var highlight_color: Color = Color(1.0, 1.0, 0.5, 1.0)
@export var is_enabled: bool = true

var highlight: HighlightComponent = null

@onready var mesh_instances: Array[MeshInstance3D] = []

func _ready() -> void:
	highlight = HighlightComponent.new()
	_find_mesh_instances()

func _find_mesh_instances() -> void:
	mesh_instances.clear()
	for child in get_children():
		if child is MeshInstance3D:
			mesh_instances.append(child)
		for subchild in child.get_children():
			if subchild is MeshInstance3D:
				mesh_instances.append(subchild)

func can_interact() -> bool:
	return is_enabled

func get_interaction_text() -> String:
	return interaction_text

func interact() -> void:
	push_warning("interact() should be overridden in subclass: " + name)

func set_highlight(on: bool) -> void:
	if on:
		highlight.apply(mesh_instances, highlight_color)
	else:
		highlight.remove(mesh_instances)

func enable() -> void:
	is_enabled = true

func disable() -> void:
	is_enabled = false
	set_highlight(false)
