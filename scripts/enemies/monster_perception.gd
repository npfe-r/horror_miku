class_name MonsterPerception
extends Node

signal player_seen(position: Vector3)
signal noise_heard(position: Vector3, level: float)
signal player_lost

@export_group("Vision Settings")
@export var sight_range: float = 15.0
@export var sight_angle: float = 60.0
@export var sight_update_interval: float = 0.2
@export var vision_ray_mask: int = 4294967295

@export_group("Hearing Settings")
@export var hearing_range: float = 25.0
@export var noise_threshold: float = 1.0

var _monster: CharacterBody3D = null
var _player_ref: WeakRef = WeakRef.new()
var _sight_timer: float = 0.0
var _can_see_player: bool = false
var _last_seen_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	_monster = get_parent() as CharacterBody3D
	if not _monster:
		push_error("MonsterPerception 必须作为 CharacterBody3D 的子节点")
		return
	
	call_deferred("_setup_player_reference")

func _setup_player_reference() -> void:
	await get_tree().physics_frame
	
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = weakref(players[0])
		print("[MonsterPerception] 找到玩家引用: %s" % players[0].name)
		_connect_player_noise_signal()
	else:
		push_warning("[MonsterPerception] 未找到玩家，将在1秒后重试")
		await get_tree().create_timer(1.0).timeout
		_setup_player_reference()

func _connect_player_noise_signal() -> void:
	var player := _get_player()
	if player and player.has_signal("noise_made"):
		player.noise_made.connect(_on_player_noise_made)
		print("[MonsterPerception] 已连接玩家噪音信号")

func _process(delta: float) -> void:
	_sight_timer += delta
	
	if _sight_timer >= sight_update_interval:
		_sight_timer = 0.0
		_check_vision()

func _check_vision() -> void:
	var player := _get_player()
	if not player:
		return
	
	var monster_pos := _monster.global_position
	var player_pos := player.global_position
	var distance := monster_pos.distance_to(player_pos)
	
	if distance > sight_range:
		if _can_see_player:
			_can_see_player = false
			emit_signal("player_lost")
		return
	
	var direction_to_player := (player_pos - monster_pos).normalized()
	var forward := -_monster.transform.basis.z.normalized()
	var angle := rad_to_deg(acos(forward.dot(direction_to_player)))
	
	if angle > sight_angle:
		if _can_see_player:
			_can_see_player = false
			emit_signal("player_lost")
		return
	
	var space_state := _monster.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		monster_pos + Vector3(0, 1.0, 0),
		player_pos + Vector3(0, 1.0, 0)
	)
	query.collision_mask = vision_ray_mask
	query.exclude = [_monster.get_rid()]
	
	var result := space_state.intersect_ray(query)
	
	var can_see := false
	if not result.is_empty():
		var collider = result.get("collider")
		if collider == player:
			can_see = true
	
	if can_see and not _can_see_player:
		_can_see_player = true
		_last_seen_position = player_pos
		emit_signal("player_seen", player_pos)
		print("[MonsterPerception] 看到玩家！距离: %.1fm, 角度: %.1f°" % [distance, angle])
	elif not can_see and _can_see_player:
		_can_see_player = false
		emit_signal("player_lost")

func _on_player_noise_made(noise_level: float, noise_position: Vector3) -> void:
	if noise_level < noise_threshold:
		return
	
	var distance := _monster.global_position.distance_to(noise_position)
	var effective_range := noise_level * 8.0
	
	if distance <= effective_range and distance <= hearing_range:
		emit_signal("noise_heard", noise_position, noise_level)
		print("[MonsterPerception] 听到噪音，等级: %.1f, 距离: %.1fm" % [noise_level, distance])

func can_hear_noise(noise_position: Vector3, noise_level: float) -> bool:
	var distance := _monster.global_position.distance_to(noise_position)
	var effective_range := noise_level * 8.0
	return distance <= effective_range and distance <= hearing_range

func can_see_player() -> bool:
	return _can_see_player

func get_last_seen_position() -> Vector3:
	return _last_seen_position

func _get_player() -> Node3D:
	if _player_ref.get_ref():
		return _player_ref.get_ref() as Node3D
	return null
