class_name TestDoor
extends Node3D

@export var is_locked: bool = false
@export var open_speed: float = 5
@export var noise_level: float = 2.0
@export var interaction_text: String = "开门"
@export var highlight_color: Color = Color(1.0, 1.0, 0.5, 1.0)
@export var is_enabled: bool = true

var is_open: bool = false
var is_moving: bool = false
var _target_rotation: float = 0.0
var _original_materials: Dictionary = {}
var _is_highlighted: bool = false

@onready var pivot: Node3D = $Pivot
@onready var door_body: AnimatableBody3D = $Pivot/DoorBody
@onready var door_mesh: MeshInstance3D = $Pivot/DoorBody/DoorMesh

func _ready() -> void:
	interaction_text = "开门" if not is_open else "关门"
	if is_locked:
		interaction_text = "门已锁住"
	
	if door_mesh:
		_original_materials[door_mesh] = door_mesh.get_surface_override_material(0)

func can_interact() -> bool:
	return is_enabled

func get_interaction_text() -> String:
	return interaction_text

func interact() -> void:
	if is_locked:
		print("门被锁住了！")
		return
	
	if is_moving:
		if is_open:
			_target_rotation = 0.0
			is_open = false
			interaction_text = "开门"
			print("门开始关闭！")
		else:
			_target_rotation = -deg_to_rad(90.0)
			is_open = true
			interaction_text = "关门"
			print("门开始打开！")
		return
	
	is_moving = true
	
	if is_open:
		_close_door()
	else:
		_open_door()

func _open_door() -> void:
	is_open = true
	_target_rotation = -deg_to_rad(90.0)
	interaction_text = "关门"
	print("门打开了！")

func _close_door() -> void:
	is_open = false
	_target_rotation = 0.0
	interaction_text = "开门"
	print("门关闭了！")

func _process(delta: float) -> void:
	if not is_moving or not pivot:
		return
	
	var current_rotation: float = pivot.rotation.y
	var new_rotation: float = lerpf(current_rotation, _target_rotation, open_speed * delta)
	
	if abs(new_rotation - _target_rotation) < 0.01:
		new_rotation = _target_rotation
		is_moving = false
	
	pivot.rotation.y = new_rotation

func set_highlight(highlight: bool) -> void:
	if _is_highlighted == highlight or not door_mesh:
		return
	
	_is_highlighted = highlight
	
	if highlight:
		var material := StandardMaterial3D.new()
		material.albedo_color = highlight_color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		door_mesh.set_surface_override_material(0, material)
	else:
		if _original_materials.has(door_mesh):
			door_mesh.set_surface_override_material(0, _original_materials[door_mesh])
		else:
			door_mesh.set_surface_override_material(0, null)

func unlock() -> void:
	is_locked = false
	interaction_text = "开门"
	print("门已解锁！")

func lock() -> void:
	is_locked = true
	interaction_text = "门已锁住"
	print("门已锁住！")

func enable() -> void:
	is_enabled = true

func disable() -> void:
	is_enabled = false
	set_highlight(false)
