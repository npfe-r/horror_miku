class_name InteractableObject
extends AnimatableBody3D

@export var interaction_text: String = "交互"
@export var highlight_color: Color = Color(1.0, 1.0, 0.5, 1.0)
@export var is_enabled: bool = true

var _original_materials: Dictionary = {}
var _is_highlighted: bool = false

@onready var mesh_instances: Array[MeshInstance3D] = []

func _ready() -> void:
	_find_mesh_instances()
	_store_original_materials()

func _find_mesh_instances() -> void:
	mesh_instances.clear()
	for child in get_children():
		if child is MeshInstance3D:
			mesh_instances.append(child)
		for subchild in child.get_children():
			if subchild is MeshInstance3D:
				mesh_instances.append(subchild)

func _store_original_materials() -> void:
	_original_materials.clear()
	for mesh in mesh_instances:
		_original_materials[mesh] = mesh.get_surface_override_material(0)

func can_interact() -> bool:
	return is_enabled

func get_interaction_text() -> String:
	return interaction_text

func interact() -> void:
	push_warning("interact() method should be overridden in derived class")

func set_highlight(highlight: bool) -> void:
	if _is_highlighted == highlight:
		return
	
	_is_highlighted = highlight
	
	if highlight:
		_apply_highlight()
	else:
		_remove_highlight()

func _apply_highlight() -> void:
	for mesh in mesh_instances:
		var material := StandardMaterial3D.new()
		material.albedo_color = highlight_color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.set_surface_override_material(0, material)

func _remove_highlight() -> void:
	for mesh in mesh_instances:
		if _original_materials.has(mesh):
			mesh.set_surface_override_material(0, _original_materials[mesh])
		else:
			mesh.set_surface_override_material(0, null)

func enable() -> void:
	is_enabled = true

func disable() -> void:
	is_enabled = false
	set_highlight(false)
