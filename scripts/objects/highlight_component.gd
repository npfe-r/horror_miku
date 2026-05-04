class_name HighlightComponent
extends RefCounted

var _is_highlighted: bool = false
var _highlight_layer_bit: int = -1
var _affected_meshes: Array[MeshInstance3D] = []
var _original_layers: Dictionary = {}

func _init() -> void:
	var hm := Engine.get_main_loop().root.get_node_or_null("/root/HighlightManager") as Node
	if hm:
		_highlight_layer_bit = hm.get_highlight_layer_bit()

func is_highlighted() -> bool:
	return _is_highlighted

func apply(mesh_instances: Array[MeshInstance3D], _color: Color) -> void:
	if _is_highlighted:
		return
	_is_highlighted = true

	for mesh in mesh_instances:
		if not is_instance_valid(mesh):
			continue

		_affected_meshes.append(mesh)
		if not _original_layers.has(mesh):
			_original_layers[mesh] = mesh.layers

		mesh.set_layer_mask_value(_highlight_layer_bit + 1, true)

func remove(_mesh_instances: Array[MeshInstance3D]) -> void:
	if not _is_highlighted:
		return
	_is_highlighted = false

	for mesh in _affected_meshes:
		if not is_instance_valid(mesh):
			continue

		if _original_layers.has(mesh):
			mesh.layers = _original_layers[mesh]
		else:
			mesh.set_layer_mask_value(_highlight_layer_bit + 1, false)

	_affected_meshes.clear()
	_original_layers.clear()
