class_name PlayerController
extends CharacterBody3D

signal noise_made(noise_level: float, position: Vector3)
signal stamina_changed(stamina: float)
signal interaction_prompt_changed(prompt_text: String)

const WALK_SPEED: float = 3.5
const RUN_SPEED: float = 6.0
const CROUCH_SPEED: float = 1.5
const JUMP_VELOCITY: float = 4.5
const MOUSE_SENSITIVITY: float = 0.002

const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN_RATE: float = 20.0
const STAMINA_RECOVERY_RATE: float = 15.0
const STAMINA_MIN_TO_RUN: float = 10.0

const NOISE_WALK: float = 2.0
const NOISE_RUN: float = 3.0
const NOISE_CROUCH: float = 1.0
const NOISE_STATIONARY: float = 0.0
const NOISE_JUMP: float = 3.5
const NOISE_LAND: float = 3.0

@export var mouse_sensitivity: float = MOUSE_SENSITIVITY

var stamina: float = STAMINA_MAX
var noise_level: float = NOISE_STATIONARY
var is_hiding: bool = false
var is_crouching: bool = false
var is_running: bool = false
var is_jumping: bool = false
var was_on_floor: bool = true

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

const HEAD_HEIGHT_NORMAL: float = 1.5
const HEAD_HEIGHT_CROUCH: float = 0.8
const CROUCH_TRANSITION_SPEED: float = 8.0
const COLLISION_HEIGHT_NORMAL: float = 1.8
const COLLISION_HEIGHT_CROUCH: float = 1.0

var _target_head_height: float = HEAD_HEIGHT_NORMAL
var _target_collision_height: float = COLLISION_HEIGHT_NORMAL
var _can_stand_up: bool = true

var _current_interactable: Node = null
var _previous_interactable: Node = null

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/InteractionRay
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ceiling_check: ShapeCast3D = $CeilingCheck

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_target_head_height = HEAD_HEIGHT_NORMAL
	head.position.y = HEAD_HEIGHT_NORMAL
	
	_setup_interaction_manager()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	if is_hiding:
		return
	
	_check_ceiling_clearance()
	_handle_movement(delta)
	_handle_crouch()
	_handle_stamina(delta)
	_update_noise_level()
	_smooth_crouch_transition(delta)
	_check_interaction()
	_handle_interaction_input()
	move_and_slide()

func _handle_movement(delta: float) -> void:
	_check_landing()
	
	if not is_on_floor():
		velocity.y -= _gravity * delta
		is_jumping = true
	else:
		if is_jumping:
			is_jumping = false
	
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY
		is_jumping = true
		make_noise(NOISE_JUMP)
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed: float = WALK_SPEED
	is_running = false
	
	if is_crouching:
		current_speed = CROUCH_SPEED
	elif Input.is_action_pressed("run") and stamina > STAMINA_MIN_TO_RUN and direction != Vector3.ZERO:
		current_speed = RUN_SPEED
		is_running = true
	
	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	was_on_floor = is_on_floor()

func _handle_crouch() -> void:
	if Input.is_action_just_pressed("crouch"):
		if is_crouching:
			if _can_stand_up:
				is_crouching = false
				_update_crouch_state()
		else:
			is_crouching = true
			_update_crouch_state()

func _check_ceiling_clearance() -> void:
	if is_crouching and ceiling_check:
		ceiling_check.force_shapecast_update()
		_can_stand_up = not ceiling_check.is_colliding()

func _check_landing() -> void:
	if not was_on_floor and is_on_floor():
		make_noise(NOISE_LAND)

func _update_crouch_state() -> void:
	if is_crouching:
		_target_head_height = HEAD_HEIGHT_CROUCH
		_target_collision_height = COLLISION_HEIGHT_CROUCH
	else:
		_target_head_height = HEAD_HEIGHT_NORMAL
		_target_collision_height = COLLISION_HEIGHT_NORMAL

func _smooth_crouch_transition(delta: float) -> void:
	var current_height: float = head.position.y
	if abs(current_height - _target_head_height) > 0.001:
		head.position.y = lerp(current_height, _target_head_height, CROUCH_TRANSITION_SPEED * delta)
	
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		var current_collision_height: float = capsule.height
		if abs(current_collision_height - _target_collision_height) > 0.001:
			capsule.height = lerp(current_collision_height, _target_collision_height, CROUCH_TRANSITION_SPEED * delta)
			collision_shape.position.y = capsule.height / 2.0

func _handle_stamina(delta: float) -> void:
	if is_running and velocity.length() > 0.1:
		stamina -= STAMINA_DRAIN_RATE * delta
		stamina = max(stamina, 0.0)
		emit_signal("stamina_changed", stamina)
	elif not is_running:
		stamina += STAMINA_RECOVERY_RATE * delta
		stamina = min(stamina, STAMINA_MAX)
		emit_signal("stamina_changed", stamina)

func _update_noise_level() -> void:
	var previous_noise := noise_level
	
	if velocity.length() < 0.1:
		noise_level = NOISE_STATIONARY
	elif is_crouching:
		noise_level = NOISE_CROUCH
	elif is_running:
		noise_level = NOISE_RUN
	else:
		noise_level = NOISE_WALK
	
	if noise_level > NOISE_STATIONARY and noise_level != previous_noise:
		emit_signal("noise_made", noise_level, global_position)

func make_noise(level: float) -> void:
	emit_signal("noise_made", level, global_position)

func set_hiding(hiding: bool) -> void:
	is_hiding = hiding
	if hiding:
		velocity = Vector3.ZERO

func get_current_speed() -> float:
	if is_crouching:
		return CROUCH_SPEED
	elif is_running:
		return RUN_SPEED
	return WALK_SPEED

func _setup_interaction_manager() -> void:
	var interaction_manager := get_node_or_null("/root/InteractionManager")
	if interaction_manager:
		interaction_manager.set_player(self)

func _check_interaction() -> void:
	if not interaction_ray:
		return
	
	interaction_ray.force_raycast_update()
	
	if interaction_ray.is_colliding():
		var collider := interaction_ray.get_collider()
		var interactable_node: Node = null
		
		if collider is InteractableObject:
			interactable_node = collider as InteractableObject
		elif collider is AnimatableBody3D:
			var parent: Node = collider.get_parent()
			while parent:
				if parent.has_method(&"can_interact"):
					interactable_node = parent
					break
				parent = parent.get_parent()
		
		if interactable_node and interactable_node.has_method(&"can_interact"):
			var can_interact_result: bool = interactable_node.call(&"can_interact")
			if can_interact_result:
				_current_interactable = interactable_node
				
				if _previous_interactable != _current_interactable:
					if _previous_interactable and _previous_interactable.has_method(&"set_highlight"):
						_previous_interactable.call(&"set_highlight", false)
					
					if _current_interactable.has_method(&"set_highlight"):
						_current_interactable.call(&"set_highlight", true)
					
					if _current_interactable.has_method(&"get_interaction_text"):
						var prompt_text: String = _current_interactable.call(&"get_interaction_text")
						emit_signal("interaction_prompt_changed", prompt_text)
					
					_previous_interactable = _current_interactable
				return
	
	if _current_interactable:
		if _current_interactable.has_method(&"set_highlight"):
			_current_interactable.call(&"set_highlight", false)
		_current_interactable = null
		_previous_interactable = null
		emit_signal("interaction_prompt_changed", "")

func _handle_interaction_input() -> void:
	if Input.is_action_just_pressed("interact"):
		if _current_interactable and _current_interactable.has_method(&"can_interact"):
			var can_interact_result: bool = _current_interactable.call(&"can_interact")
			if can_interact_result and _current_interactable.has_method(&"interact"):
				_current_interactable.call(&"interact")
				
				if _current_interactable and _current_interactable.has_method(&"set_highlight"):
					_current_interactable.call(&"set_highlight", false)
				_current_interactable = null
				_previous_interactable = null
				emit_signal("interaction_prompt_changed", "")
