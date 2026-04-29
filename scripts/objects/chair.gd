class_name Chair
extends InteractableObject

signal player_sat_down
signal player_stood_up

@export var exit_push_distance: float = 1.5

const TWEEN_DURATION: float = 0.35
const SITTING_HEAD_HEIGHT: float = 0.6

var is_occupied: bool = false
var is_animating: bool = false

var _saved_player_transform: Transform3D
var _active_tween: Tween = null
var _current_player: PlayerController = null

@onready var player_anchor: Marker3D = $PlayerAnchor


func _ready() -> void:
	super._ready()
	if not is_occupied:
		interaction_text = "坐下"


func can_interact() -> bool:
	return is_enabled and not is_animating


func get_interaction_text() -> String:
	if is_occupied:
		return "站起来"
	return interaction_text


func interact() -> void:
	if is_animating:
		return

	if is_occupied:
		_stand_up()
	else:
		_sit_down()


func _sit_down() -> void:
	is_animating = true

	var player := InteractionManager.get_player()
	if not player:
		is_animating = false
		return

	_current_player = player
	_saved_player_transform = player.global_transform

	_tween_player_to_seat(player)
	await _active_tween.finished

	player.set_physics_process(true)
	player.hide_in_spot(self)

	is_occupied = true
	is_animating = false
	interaction_text = "站起来"
	EventBus.hiding_state_changed.emit(true)
	player_sat_down.emit()


func _stand_up() -> void:
	is_animating = true

	var player := InteractionManager.get_player()
	if not player:
		is_animating = false
		return

	EventBus.hiding_state_changed.emit(false)

	_tween_player_out_of_seat(player)
	await _active_tween.finished

	player.set_physics_process(true)
	player.set_hiding(false)

	is_occupied = false
	is_animating = false
	interaction_text = "坐下"
	_current_player = null
	player_stood_up.emit()


func _tween_player_to_seat(player: PlayerController) -> void:
	if not player_anchor:
		push_warning("[Chair] player_anchor 未设置")
		return

	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.camera_rotation_restore()

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(player, "global_position", player_anchor.global_position, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(player, "global_rotation", player_anchor.global_rotation, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(player.head, "position:y", SITTING_HEAD_HEIGHT, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _tween_player_out_of_seat(player: PlayerController) -> void:
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
	_active_tween.tween_property(player.head, "position:y", PlayerController.HEAD_HEIGHT_NORMAL, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _exit_direct() -> void:
	if is_animating or not is_occupied:
		return

	_stand_up()
