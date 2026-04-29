class_name HidingSpot
extends InteractableObject

signal player_entered
signal player_exited

@export var door_open_speed: float = 2.0
@export var door_open_angle: float = -100.0
@export var can_observe: bool = false
@export var exit_push_distance: float = 1.5

const TWEEN_DURATION: float = 0.35

var is_occupied: bool = false
var is_door_open: bool = false
var is_animating: bool = false

var _saved_player_transform: Transform3D
var _active_tween: Tween = null
var _current_player: PlayerController = null

@onready var left_door_pivot: Node3D = $LeftDoorPivot
@onready var right_door_pivot: Node3D = $RightDoorPivot
@onready var player_anchor: Marker3D = $PlayerAnchor


func _ready() -> void:
	super._ready()
	if not is_occupied:
		interaction_text = "躲藏"


func can_interact() -> bool:
	return is_enabled and not is_animating


func get_interaction_text() -> String:
	if is_occupied:
		return "离开"
	return interaction_text


func interact() -> void:
	if is_animating:
		return

	if is_occupied:
		_exit_hiding()
	else:
		_enter_hiding()


func _enter_hiding() -> void:
	is_animating = true
	is_door_open = false

	var player := InteractionManager.get_player()
	if not player:
		is_animating = false
		return

	_current_player = player
	_saved_player_transform = player.global_transform

	_open_doors()
	await _active_tween.finished

	_tween_player_to_spot(player)
	await _active_tween.finished
	player.set_physics_process(true)

	player.hide_in_spot(self)

	_close_doors()
	await _active_tween.finished

	is_occupied = true
	is_animating = false
	interaction_text = "离开"
	EventBus.hiding_state_changed.emit(true)
	player_entered.emit()


func _exit_hiding() -> void:
	is_animating = true
	is_door_open = true

	var player := InteractionManager.get_player()
	if not player:
		is_animating = false
		return

	EventBus.hiding_state_changed.emit(false)

	_open_doors()
	await _active_tween.finished

	_tween_player_out_of_spot(player)
	await _active_tween.finished
	player.set_physics_process(true)
	player.set_hiding(false)

	_close_doors()
	await _active_tween.finished

	is_occupied = false
	is_animating = false
	interaction_text = "躲藏"
	_current_player = null
	player_exited.emit()


func _open_doors() -> void:
	is_door_open = true

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween().set_parallel(true)

	if left_door_pivot:
		_active_tween.tween_property(left_door_pivot, "rotation:y", deg_to_rad(door_open_angle), 1.0 / door_open_speed).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	if right_door_pivot:
		_active_tween.tween_property(right_door_pivot, "rotation:y", deg_to_rad(-door_open_angle), 1.0 / door_open_speed).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _close_doors() -> void:
	is_door_open = false

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween().set_parallel(true)

	if left_door_pivot:
		_active_tween.tween_property(left_door_pivot, "rotation:y", 0.0, 1.0 / door_open_speed).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	if right_door_pivot:
		_active_tween.tween_property(right_door_pivot, "rotation:y", 0.0, 1.0 / door_open_speed).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)


func _tween_player_to_spot(player: PlayerController) -> void:
	if not player_anchor:
		push_warning("[HidingSpot] player_anchor 未设置")
		return

	player.set_physics_process(false)
	player.velocity = Vector3.ZERO

	player.camera_rotation_restore()

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(player, "global_position", player_anchor.global_position, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(player, "global_rotation", player_anchor.global_rotation, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _tween_player_out_of_spot(player: PlayerController) -> void:
	var exit_pos: Vector3 = global_position + global_transform.basis.z * exit_push_distance
	exit_pos.y = player.global_position.y

	var space_state := get_world_3d().direct_space_state
	var ray_from := exit_pos + Vector3.UP
	var ray_to := exit_pos - Vector3.UP * 2.0
	var ray_query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	ray_query.collision_mask = 1
	var hit := space_state.intersect_ray(ray_query)

	if not hit.is_empty():
		exit_pos.y = hit.position.y

	player.set_physics_process(false)
	player.velocity = Vector3.ZERO

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(player, "global_position", exit_pos, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(player.head, "rotation", Vector3.ZERO, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _get_exit_position(player: PlayerController) -> Vector3:
	var exit_pos: Vector3 = global_position + global_transform.basis.z * exit_push_distance
	exit_pos.y = player.global_position.y

	var space_state := get_world_3d().direct_space_state
	var ray_from := exit_pos + Vector3.UP
	var ray_to := exit_pos - Vector3.UP * 2.0
	var ray_query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	ray_query.collision_mask = 1
	var hit := space_state.intersect_ray(ray_query)

	if not hit.is_empty():
		exit_pos.y = hit.position.y

	return exit_pos


func _exit_direct() -> void:
	if is_animating or not is_occupied:
		return

	_exit_hiding()
