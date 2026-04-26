class_name MonsterAI
extends CharacterBody3D

signal state_changed(new_state: String)
signal player_detected(position: Vector3)
signal player_caught

enum State {
	PATROL,
	ALERT,
	CHASE,
	SEARCH
}

@export_group("Movement Settings")
@export var patrol_speed: float = 2.0
@export var chase_speed: float = 5.5
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0

@export_group("Detection Settings")
@export var detection_range: float = 15.0
@export var hearing_range: float = 25.0
@export var sight_angle: float = 60.0
@export var sight_update_interval: float = 0.2

@export_group("State Timers")
@export var alert_duration: float = 4.0
@export var chase_max_duration: float = 30.0
@export var search_duration: float = 20.0
@export var patrol_wait_time: float = 3.0

@export_group("Patrol Settings")
@export var patrol_points: Array[NodePath] = []
@export var patrol_loop: bool = true

@export_group("Search Settings")
@export var search_radius: float = 10.0
@export var hide_discovery_chance: float = 0.3

var current_state: State = State.PATROL
var target_position: Vector3 = Vector3.ZERO
var last_known_player_position: Vector3 = Vector3.ZERO
var current_patrol_index: int = 0
var state_timer: float = 0.0
var wait_timer: float = 0.0

var _patrol_point_nodes: Array[Node3D] = []
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _player_ref: WeakRef = WeakRef.new()

@onready var perception: Node = $Perception if has_node("Perception") else null
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null

func _ready() -> void:
	add_to_group("enemies")
	_setup_patrol_points()
	_setup_player_reference()
	_connect_perception_signals()
	
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		call_deferred("_setup_navigation")

func _setup_navigation() -> void:
	await get_tree().physics_frame
	if patrol_points.size() > 0 and _patrol_point_nodes.size() > 0:
		navigation_agent.set_target_position(_patrol_point_nodes[0].global_position)

func _setup_patrol_points() -> void:
	_patrol_point_nodes.clear()
	for path in patrol_points:
		var point := get_node_or_null(path)
		if point:
			_patrol_point_nodes.append(point)
	
	if _patrol_point_nodes.size() == 0:
		push_warning("MonsterAI: 没有设置巡逻点，怪物将原地待命")

func _setup_player_reference() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = weakref(players[0])
		print("[MonsterAI] 找到玩家引用")

func _connect_perception_signals() -> void:
	if perception:
		if perception.has_signal("player_seen"):
			perception.player_seen.connect(_on_player_seen)
		if perception.has_signal("noise_heard"):
			perception.noise_heard.connect(_on_noise_heard)
		if perception.has_signal("player_lost"):
			perception.player_lost.connect(_on_player_lost)

func _physics_process(delta: float) -> void:
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.ALERT:
			_process_alert(delta)
		State.CHASE:
			_process_chase(delta)
		State.SEARCH:
			_process_search(delta)
	
	_apply_gravity(delta)
	_move_towards_target(delta)
	move_and_slide()

func _process_patrol(delta: float) -> void:
	if _patrol_point_nodes.size() == 0:
		return
	
	if wait_timer > 0.0:
		wait_timer -= delta
		return
	
	if navigation_agent and navigation_agent.is_navigation_finished():
		_advance_patrol_point()
		wait_timer = randf_range(patrol_wait_time, patrol_wait_time + 2.0)

func _process_alert(delta: float) -> void:
	state_timer -= delta
	
	if state_timer <= 0.0:
		change_state(State.PATROL)

func _process_chase(delta: float) -> void:
	state_timer -= delta
	
	if state_timer <= 0.0:
		change_state(State.SEARCH)
		return
	
	var player := _get_player()
	if player:
		last_known_player_position = player.global_position
		if navigation_agent:
			navigation_agent.set_target_position(last_known_player_position)
		
		if global_position.distance_to(player.global_position) < 1.5:
			emit_signal("player_caught")
			print("[MonsterAI] 抓住玩家！")

func _process_search(delta: float) -> void:
	state_timer -= delta
	
	if state_timer <= 0.0:
		change_state(State.PATROL)
		return
	
	if navigation_agent and navigation_agent.is_navigation_finished():
		var random_offset := Vector3(
			randf_range(-search_radius, search_radius),
			0.0,
			randf_range(-search_radius, search_radius)
		)
		var search_pos := last_known_player_position + random_offset
		navigation_agent.set_target_position(search_pos)

func _advance_patrol_point() -> void:
	if _patrol_point_nodes.size() == 0:
		return
	
	current_patrol_index += 1
	
	if current_patrol_index >= _patrol_point_nodes.size():
		if patrol_loop:
			current_patrol_index = 0
		else:
			current_patrol_index = _patrol_point_nodes.size() - 1
			return
	
	if navigation_agent:
		navigation_agent.set_target_position(_patrol_point_nodes[current_patrol_index].global_position)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

func _move_towards_target(delta: float) -> void:
	if not navigation_agent:
		return
	
	var target_speed := patrol_speed
	if current_state == State.CHASE:
		target_speed = chase_speed
	
	if navigation_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		return
	
	var next_position := navigation_agent.get_next_path_position()
	var direction := (next_position - global_position).normalized()
	
	velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
	
	_look_at_direction(direction)

func _look_at_direction(direction: Vector3) -> void:
	if direction.length_squared() > 0.001:
		var target_rotation := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 0.1)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	state_timer = 0.0
	
	match new_state:
		State.PATROL:
			print("[MonsterAI] 切换到巡逻状态")
			if _patrol_point_nodes.size() > 0 and navigation_agent:
				navigation_agent.set_target_position(_patrol_point_nodes[current_patrol_index].global_position)
		
		State.ALERT:
			print("[MonsterAI] 切换到警觉状态")
			state_timer = alert_duration
			velocity = Vector3.ZERO
		
		State.CHASE:
			print("[MonsterAI] 切换到追击状态")
			state_timer = chase_max_duration
			emit_signal("player_detected", last_known_player_position)
		
		State.SEARCH:
			print("[MonsterAI] 切换到搜索状态")
			state_timer = search_duration
			if navigation_agent:
				navigation_agent.set_target_position(last_known_player_position)
	
	emit_signal("state_changed", State.keys()[new_state])

func _on_player_seen(player_position: Vector3) -> void:
	last_known_player_position = player_position
	
	if current_state == State.PATROL or current_state == State.ALERT:
		change_state(State.CHASE)

func _on_noise_heard(noise_position: Vector3, noise_level: float) -> void:
	if current_state == State.CHASE:
		return
	
	last_known_player_position = noise_position
	
	if current_state == State.PATROL:
		change_state(State.ALERT)
		_look_at_direction(noise_position - global_position)

func _on_player_lost() -> void:
	if current_state == State.CHASE:
		change_state(State.SEARCH)

func _get_player() -> Node3D:
	if _player_ref.get_ref():
		return _player_ref.get_ref() as Node3D
	return null

func get_state_name() -> String:
	return State.keys()[current_state]

func set_patrol_points(points: Array[NodePath]) -> void:
	patrol_points = points
	_setup_patrol_points()
