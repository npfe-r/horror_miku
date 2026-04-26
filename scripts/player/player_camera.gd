class_name PlayerCamera
extends Node3D

@export var bob_enabled: bool = true
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.08

var _bob_time: float = 0.0
var _initial_position: Vector3 = Vector3.ZERO

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	_initial_position = camera.position

func _process(delta: float) -> void:
	if bob_enabled:
		_handle_head_bob(delta)

func _handle_head_bob(delta: float) -> void:
	var player := get_parent() as PlayerController
	if not player:
		return
	
	var velocity := player.velocity
	var speed := velocity.length()
	
	if speed > 0.5 and player.is_on_floor() and not player.is_hiding:
		_bob_time += delta * bob_frequency * (speed / PlayerController.WALK_SPEED)
		var bob_offset := sin(_bob_time) * bob_amplitude
		camera.position.y = _initial_position.y + bob_offset
	else:
		_bob_time = 0.0
		camera.position.y = lerp(camera.position.y, _initial_position.y, delta * 10.0)
