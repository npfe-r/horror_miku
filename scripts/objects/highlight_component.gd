## HighlightComponent — 可交互物体的高亮效果复用组件
class_name HighlightComponent
extends RefCounted

var _is_highlighted: bool = false
var _original_materials: Dictionary = {}

func is_highlighted() -> bool:
	return _is_highlighted

func apply(mesh_instances: Array[MeshInstance3D], color: Color) -> void:
	if _is_highlighted:
		return
	_is_highlighted = true

	for mesh in mesh_instances:
		_original_materials[mesh] = mesh.get_surface_override_material(0)
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.set_surface_override_material(0, material)

func remove(mesh_instances: Array[MeshInstance3D]) -> void:
	if not _is_highlighted:
		return
	_is_highlighted = false

	for mesh in mesh_instances:
		if _original_materials.has(mesh):
			mesh.set_surface_override_material(0, _original_materials[mesh])
		else:
			mesh.set_surface_override_material(0, null)
	_original_materials.clear()
