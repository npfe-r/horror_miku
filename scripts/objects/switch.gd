class_name Switch
extends InteractableObject

@export var is_on: bool = false
@export var toggle_objects: Array[NodePath] = []

signal switch_toggled(is_on: bool)

@onready var switch_mesh: MeshInstance3D = $SwitchMesh if has_node("SwitchMesh") else null

func _ready() -> void:
	super._ready()
	interaction_text = "打开开关" if not is_on else "关闭开关"
	_update_visual()

func interact() -> void:
	is_on = not is_on
	interaction_text = "打开开关" if not is_on else "关闭开关"
	_update_visual()
	emit_signal("switch_toggled", is_on)
	print("开关已", "打开" if is_on else "关闭")
	
	for node_path in toggle_objects:
		var node := get_node_or_null(node_path)
		if node:
			if node.has_method(&"enable"):
				node.enable() if is_on else node.disable()
			elif "visible" in node:
				node.visible = is_on

func _update_visual() -> void:
	if not switch_mesh:
		return
	
	var material := StandardMaterial3D.new()
	if is_on:
		material.albedo_color = Color(0.2, 1.0, 0.2)
	else:
		material.albedo_color = Color(0.5, 0.5, 0.5)
	
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	switch_mesh.set_surface_override_material(0, material)

func get_state() -> bool:
	return is_on
