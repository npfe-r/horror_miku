class_name PlayerController
extends CharacterBody3D

## 噪音信号，传递噪音等级、位置和最大传播距离
signal noise_made(noise_level: float, position: Vector3, max_range: float)
signal stamina_changed(stamina: float)
signal interaction_prompt_changed(prompt_text: String)
signal item_picked_up(item: ItemData, count: int)
signal inventory_updated()

const WALK_SPEED: float = 3.5
const RUN_SPEED: float = 6.0
const CROUCH_SPEED: float = 1.5
const JUMP_VELOCITY: float = 4.5
const MOUSE_SENSITIVITY: float = 0.002

const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN_RATE: float = 20.0
const STAMINA_RECOVERY_RATE: float = 15.0
const STAMINA_RECOVERY_COOLDOWN: float = 2.0

const NOISE_WALK: float = 2.0
const NOISE_RUN: float = 3.0
const NOISE_CROUCH: float = 1.0
const NOISE_STATIONARY: float = 0.0
const NOISE_JUMP: float = 3.5
const NOISE_LAND: float = 3.0

## 噪音最大传播距离
const NOISE_MAX_RANGE_WALK: float = 16.0
const NOISE_MAX_RANGE_RUN: float = 24.0
const NOISE_MAX_RANGE_CROUCH: float = 8.0
const NOISE_MAX_RANGE_JUMP: float = 28.0
const NOISE_MAX_RANGE_LAND: float = 24.0

const NOISE_EMIT_INTERVAL_WALK: float = 0.5
const NOISE_EMIT_INTERVAL_RUN: float = 0.3
const NOISE_EMIT_INTERVAL_CROUCH: float = 0.8

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
var _noise_emit_timer: float = 0.0
var _stamina_recovery_cooldown: float = 0.0

var inventory: Inventory = null

var equipped_item: ItemData = null
var equipped_model_instance: Node3D = null

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var equipment_point: Node3D = $Head/EquipmentPoint
@onready var interaction_ray: RayCast3D = $Head/InteractionRay
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ceiling_check: ShapeCast3D = $CeilingCheck

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_target_head_height = HEAD_HEIGHT_NORMAL
	head.position.y = HEAD_HEIGHT_NORMAL
	
	InteractionManager.set_player(self)
	_setup_inventory()

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
	_update_noise_level(delta)
	_smooth_crouch_transition(delta)
	_check_interaction()
	_handle_interaction_input()
	_handle_quick_bar_input()
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
		make_noise(NOISE_JUMP, NOISE_MAX_RANGE_JUMP)
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed: float = WALK_SPEED
	is_running = false
	
	if is_crouching:
		current_speed = CROUCH_SPEED
	elif Input.is_action_pressed("run") and stamina > 0.0 and direction != Vector3.ZERO:
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
		make_noise(NOISE_LAND, NOISE_MAX_RANGE_LAND)

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
		if stamina <= 0.0:
			_stamina_recovery_cooldown = STAMINA_RECOVERY_COOLDOWN
		EventBus.stamina_changed.emit(stamina)
	elif not is_running:
		if stamina >= STAMINA_MAX:
			_stamina_recovery_cooldown = 0.0
			return
		if _stamina_recovery_cooldown > 0.0:
			_stamina_recovery_cooldown -= delta
		else:
			stamina += STAMINA_RECOVERY_RATE * delta
			stamina = min(stamina, STAMINA_MAX)
			EventBus.stamina_changed.emit(stamina)

func _update_noise_level(delta: float) -> void:
	var previous_noise := noise_level
	
	if velocity.length() < 0.1:
		noise_level = NOISE_STATIONARY
		_noise_emit_timer = 0.0
	elif is_crouching:
		noise_level = NOISE_CROUCH
	elif is_running:
		noise_level = NOISE_RUN
	else:
		noise_level = NOISE_WALK
	
	if noise_level > NOISE_STATIONARY:
		var emit_interval: float = NOISE_EMIT_INTERVAL_WALK
		var max_range: float = NOISE_MAX_RANGE_WALK
		
		if is_running:
			emit_interval = NOISE_EMIT_INTERVAL_RUN
			max_range = NOISE_MAX_RANGE_RUN
		elif is_crouching:
			emit_interval = NOISE_EMIT_INTERVAL_CROUCH
			max_range = NOISE_MAX_RANGE_CROUCH
		
		_noise_emit_timer += delta
		if _noise_emit_timer >= emit_interval:
			EventBus.noise_made.emit(noise_level, global_position, max_range)
			_noise_emit_timer = 0.0

func make_noise(level: float, max_range: float = -1.0) -> void:
	if max_range < 0.0:
		max_range = level * 8.0
	EventBus.noise_made.emit(level, global_position, max_range)

func set_hiding(hiding: bool) -> void:
	is_hiding = hiding
	if hiding:
		velocity = Vector3.ZERO
		if equipped_model_instance:
			equipped_model_instance.visible = false
	else:
		if equipped_model_instance:
			equipped_model_instance.visible = true

func get_current_speed() -> float:
	if is_crouching:
		return CROUCH_SPEED
	elif is_running:
		return RUN_SPEED
	return WALK_SPEED

func _check_interaction() -> void:
	var im := get_node_or_null("/root/InteractionManager")
	if im:
		im.check_interaction()

func _handle_interaction_input() -> void:
	if Input.is_action_just_pressed("interact"):
		var im := get_node_or_null("/root/InteractionManager")
		if im:
			im.try_interact()

func _setup_inventory() -> void:
	inventory = Inventory.new()
	add_child(inventory)
	inventory.item_added.connect(_on_inventory_item_added)
	inventory.inventory_changed.connect(_on_inventory_changed)
	print("[PlayerController] 背包系统已初始化")

func _handle_quick_bar_input() -> void:
	var slot_changed := false
	
	if Input.is_action_just_pressed("quick_slot_1"):
		inventory.select_quick_slot(0)
		slot_changed = true
	elif Input.is_action_just_pressed("quick_slot_2"):
		inventory.select_quick_slot(1)
		slot_changed = true
	elif Input.is_action_just_pressed("quick_slot_3"):
		inventory.select_quick_slot(2)
		slot_changed = true
	elif Input.is_action_just_pressed("quick_slot_4"):
		inventory.select_quick_slot(3)
		slot_changed = true
	
	if slot_changed:
		_auto_equip_from_selected_slot()
	
	if Input.is_action_just_pressed("use_item"):
		use_current_item()

func _auto_equip_from_selected_slot() -> void:
	var item: ItemData = inventory.get_selected_item()
	
	if equipped_item:
		if item and item.item_id == equipped_item.item_id:
			return
		unequip_item()
	
	if item and item.is_equippable:
		equip_item(item)

func pickup_item(item: ItemData, count: int = 1) -> bool:
	if not inventory:
		print("[PlayerController] pickup_item 失败: 背包未初始化")
		return false
	
	print("[PlayerController] pickup_item 调用: %s x%d" % [item.item_name, count])
	var success: bool = inventory.add_item(item, count)
	print("[PlayerController] pickup_item 结果: %s" % ("成功" if success else "失败"))
	return success

func use_current_item() -> void:
	if not inventory:
		return
	
	inventory.use_quick_slot_item(inventory.selected_quick_slot, self)

func equip_item(item: ItemData) -> void:
	if not item or not item.model_scene:
		push_warning("[PlayerController] 无法装备物品: 缺少模型场景")
		return
	
	if equipped_item:
		unequip_item()
	
	var model: Node3D = item.model_scene.instantiate() as Node3D
	if not model:
		push_warning("[PlayerController] 装备模型实例化失败")
		return
	
	equipment_point.add_child(model)
	equipped_model_instance = model
	equipped_item = item
	
	EventBus.item_equipped.emit(item)
	print("[PlayerController] 已装备: %s" % item.item_name)

func unequip_item() -> void:
	if not equipped_item:
		return
	
	if equipped_model_instance:
		equipped_model_instance.queue_free()
		equipped_model_instance = null
	
	var unequipped: ItemData = equipped_item
	equipped_item = null
	
	EventBus.item_unequipped.emit()
	print("[PlayerController] 已卸下装备: %s" % unequipped.item_name)

func is_item_equipped() -> bool:
	return equipped_item != null

func get_equipped_item() -> ItemData:
	return equipped_item

func use_item_at_slot(slot_index: int) -> bool:
	if not inventory:
		return false
	return inventory.use_item(slot_index, self)

func has_item(item_id: String, amount: int = 1) -> bool:
	if not inventory:
		return false
	return inventory.has_item(item_id, amount)

func remove_item(item_id: String, amount: int = 1) -> bool:
	if not inventory:
		return false
	return inventory.remove_item(item_id, amount)

func get_item_count(item_id: String) -> int:
	if not inventory:
		return 0
	return inventory.get_item_count(item_id)

func heal(amount: float = 50.0) -> void:
	stamina = mini(stamina + amount, STAMINA_MAX)
	_stamina_recovery_cooldown = 0.0
	emit_signal("stamina_changed", stamina)

func _on_inventory_item_added(item: ItemData, count: int) -> void:
	print("[PlayerController] 物品添加信号: %s x%d" % [item.item_name, count])
	emit_signal("item_picked_up", item, count)

func _on_inventory_changed() -> void:
	print("[PlayerController] 背包变化信号")
	emit_signal("inventory_updated")
