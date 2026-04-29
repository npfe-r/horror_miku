## 敌人AI控制器
## 实现敌人的状态机行为，包括巡逻、警觉、追击三种状态
## 使用NavigationAgent3D进行路径导航和避障
## 使用警觉值系统决定状态转换
class_name MonsterAI
extends CharacterBody3D

## 状态改变信号，当敌人状态切换时触发
signal state_changed(new_state: String)

## 检测到玩家信号，当敌人发现玩家时触发
signal player_detected(position: Vector3)

## 抓住玩家信号，当敌人成功抓住玩家时触发
signal player_caught

## 敌人状态枚举
enum State {
	PATROL,   ## 巡逻状态：随机巡逻
	ALERT,    ## 警觉状态：调查可疑位置
	CHASE     ## 追击状态：追击玩家
}

## === 移动设置 ===
@export_group("Movement Settings")
## 巡逻时的移动速度（米/秒）
@export var patrol_speed: float = 2.0
## 警觉时的移动速度（米/秒）
@export var alert_speed: float = 3.0
## 追击时的移动速度（米/秒），略快于玩家奔跑速度
@export var chase_speed: float = 6.5
## 加速度（米/秒²），控制敌人加速到目标速度的快慢
@export var acceleration: float = 15.0
## 减速度（米/秒²），控制敌人减速停止的快慢
@export var deceleration: float = 20.0

## === 检测设置 ===
@export_group("Detection Settings")
## 检测范围（米），用于视觉检测的最大距离
@export var detection_range: float = 15.0
## 听觉范围（米），能听到声音的最大距离
@export var hearing_range: float = 25.0
## 视野角度（度），半角值，总视野范围为 sight_angle * 2
@export var sight_angle: float = 90.0
## 视觉检测更新间隔（秒），优化性能，避免每帧检测
@export var sight_update_interval: float = 0.2
## 立即追击距离（米），玩家进入此距离直接触发追击
@export var instant_chase_distance: float = 3.0

## === 警觉值设置 ===
@export_group("Alertness Settings")
## 最大警觉值
@export var max_alertness: float = 100.0
## 追击阈值，警觉值达到此值触发追击
@export var chase_threshold: float = 80.0
## 警觉状态阈值，警觉值达到此值进入警觉状态
@export var alert_threshold: float = 30.0
## 警觉值自然衰减速率（每秒）
@export var alertness_decay_rate: float = 5.0
## 听觉因数更新间隔（秒）
@export var hearing_factor_interval: float = 2.0
## 视觉因数更新间隔（秒）
@export var visual_factor_interval: float = 1.5

## === 巡逻设置 ===
@export_group("Patrol Settings")
## 巡逻半径（米），在玩家周围生成巡逻点的范围
@export var patrol_radius: float = 15.0
## 巡逻点最小距离（米），新巡逻点与当前点的最小距离
@export var patrol_min_distance: float = 5.0
## 巡逻点最大距离（米），新巡逻点与当前点的最大距离
@export var patrol_max_distance: float = 20.0

## === 警觉状态设置 ===
@export_group("Alert State Settings")
## 警觉状态停留时间最小值（秒）
@export var alert_wait_time_min: float = 2.0
## 警觉状态停留时间最大值（秒）
@export var alert_wait_time_max: float = 5.0
## 警觉状态检查点数量最小值
@export var alert_check_points_min: int = 1
## 警觉状态检查点数量最大值
@export var alert_check_points_max: int = 3
## 警觉状态检查半径（米）
@export var alert_check_radius: float = 8.0

## === 追击设置 ===
@export_group("Chase Settings")
## 追击时间最小值（秒）
@export var chase_time_min: float = 10.0
## 追击时间最大值（秒）
@export var chase_time_max: float = 30.0
## 追击目标点更新间隔（秒）
@export var chase_target_interval: float = 0.3
## 追击目标点随机偏移范围（米）
@export var chase_target_offset: float = 3.0

## === 状态变量 ===
## 当前状态
var current_state: State = State.PATROL
## 目标位置
var target_position: Vector3 = Vector3.ZERO
## 玩家最后已知位置
var last_known_player_position: Vector3 = Vector3.ZERO
## 当前警觉值
var alertness: float = 0.0
## 当前听觉因数
var hearing_factor: float = 1.0
## 当前视觉因数
var visual_factor: float = 1.0
## 听觉因数更新计时器
var hearing_factor_timer: float = 0.0
## 视觉因数更新计时器
var visual_factor_timer: float = 0.0
## 路径更新计时器
var path_update_timer: float = 0.0
## 警觉状态检查点列表
var alert_check_points: Array[Vector3] = []
## 当前检查点索引
var current_check_point_index: int = 0
## 停留计时器
var wait_timer: float = 0.0
## 追击时间
var chase_timer: float = 0.0

## === 内部变量 ===
## 重力值，从项目设置获取
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## 玩家弱引用，避免强引用导致的内存问题
var _player_ref: WeakRef = WeakRef.new()
## 是否能看到玩家
var _can_see_player: bool = false

## === 节点引用 ===
## 感知系统节点
@onready var perception: Node = $Perception if has_node("Perception") else null
## 导航代理节点
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null

## 初始化函数
func _ready() -> void:
	# 添加到敌人组，便于其他脚本查找
	add_to_group("enemies")
	# 获取玩家引用
	_setup_player_reference()
	# 连接感知系统信号
	_connect_perception_signals()
	# 连接全局事件
	_connect_global_events()
	# 初始化随机因数
	_update_hearing_factor()
	_update_visual_factor()
	
	# 初始化导航代理
	if navigation_agent:
		# 连接速度计算信号，用于避障系统
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		# 延迟设置导航，确保场景完全加载
		call_deferred("_setup_navigation")

## 设置导航代理的初始目标
func _setup_navigation() -> void:
	# 等待物理帧，确保导航网格已加载
	await get_tree().physics_frame
	# 生成初始巡逻点
	_generate_patrol_point()

## 设置玩家引用
## 使用弱引用避免循环引用问题
func _setup_player_reference() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = weakref(players[0])
		print("[MonsterAI] 找到玩家引用")

## 连接感知系统信号
## 将感知系统的事件连接到对应的处理函数
func _connect_perception_signals() -> void:
	if perception:
		# 连接看到玩家信号
		if perception.has_signal("player_seen"):
			perception.player_seen.connect(_on_player_seen)
			print("[MonsterAI] 已连接 player_seen 信号")
		else:
			push_warning("[MonsterAI] Perception 节点没有 player_seen 信号")
		
		# 连接听到噪音信号
		if perception.has_signal("noise_heard"):
			perception.noise_heard.connect(_on_noise_heard)
			print("[MonsterAI] 已连接 noise_heard 信号")
		
		# 连接丢失玩家信号
		if perception.has_signal("player_lost"):
			perception.player_lost.connect(_on_player_lost)
			print("[MonsterAI] 已连接 player_lost 信号")
	else:
		push_warning("[MonsterAI] 没有找到 Perception 节点")

## 连接全局事件
func _connect_global_events() -> void:
	if EventBus.hiding_state_changed.is_connected(_on_player_hiding_changed):
		return
	EventBus.hiding_state_changed.connect(_on_player_hiding_changed)

## 玩家躲藏状态变化回调
func _on_player_hiding_changed(hiding: bool) -> void:
	if hiding:
		_can_see_player = false

## 物理处理函数
## 每个物理帧调用，处理状态更新和移动
func _physics_process(delta: float) -> void:
	# 更新随机因数
	_update_factors(delta)
	# 衰减警觉值
	_decay_alertness(delta)
	
	# 根据当前状态调用对应的处理函数
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.ALERT:
			_process_alert(delta)
		State.CHASE:
			_process_chase(delta)
	
	# 应用重力
	_apply_gravity(delta)
	# 计算移动速度
	_calculate_velocity(delta)
	
	# 使用避障系统移动
	if navigation_agent and navigation_agent.avoidance_enabled:
		# 将期望速度发送给导航代理，由避障系统计算安全速度
		navigation_agent.set_velocity(velocity)
	else:
		# 无避障时直接移动
		move_and_slide()

## 更新随机因数
func _update_factors(delta: float) -> void:
	# 更新听觉因数
	hearing_factor_timer -= delta
	if hearing_factor_timer <= 0.0:
		hearing_factor_timer = hearing_factor_interval
		_update_hearing_factor()
	
	# 更新视觉因数
	visual_factor_timer -= delta
	if visual_factor_timer <= 0.0:
		visual_factor_timer = visual_factor_interval
		_update_visual_factor()

## 更新听觉因数
## 使用正态分布生成随机因数
func _update_hearing_factor() -> void:
	# 正态分布随机数（均值1.0，标准差0.3）
	hearing_factor = _normal_random(1.0, 0.3)
	# 限制在0.1到2.0之间
	hearing_factor = clamp(hearing_factor, 0.1, 2.0)

## 更新视觉因数
## 使用正态分布生成随机因数
func _update_visual_factor() -> void:
	# 正态分布随机数（均值1.0，标准差0.2）
	visual_factor = _normal_random(1.0, 0.2)
	# 限制在0.5到1.5之间
	visual_factor = clamp(visual_factor, 0.5, 1.5)

## 生成正态分布随机数
## 使用Box-Muller变换
func _normal_random(mean: float, std_dev: float) -> float:
	var u1 := randf()
	var u2 := randf()
	# 避免log(0)
	while u1 <= 0.0:
		u1 = randf()
	
	var z: float = sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)
	return mean + z * std_dev

## 衰减警觉值
func _decay_alertness(delta: float) -> void:
	# 追击状态不衰减
	if current_state == State.CHASE:
		return
	
	# 警觉值自然衰减
	alertness -= alertness_decay_rate * delta
	alertness = max(alertness, 0.0)

## 处理巡逻状态
## 敌人随机巡逻
func _process_patrol(delta: float) -> void:
	# 检查警觉值，决定是否切换状态
	if alertness >= chase_threshold:
		change_state(State.CHASE)
		return
	elif alertness >= alert_threshold:
		change_state(State.ALERT)
		return
	
	# 等待计时器未结束，继续等待
	if wait_timer > 0.0:
		wait_timer -= delta
		return
	
	# 到达当前巡逻点，生成新的巡逻点
	if navigation_agent and navigation_agent.is_navigation_finished():
		_generate_patrol_point()
		# 设置随机等待时间
		wait_timer = randf_range(1.0, 3.0)

## 处理警觉状态
## 敌人调查可疑位置
func _process_alert(delta: float) -> void:
	# 检查警觉值，决定是否切换状态
	if alertness >= chase_threshold:
		change_state(State.CHASE)
		return
	
	# 等待计时器未结束，继续等待
	if wait_timer > 0.0:
		wait_timer -= delta
		return
	
	# 到达当前检查点
	if navigation_agent and navigation_agent.is_navigation_finished():
		current_check_point_index += 1
		
		# 检查是否还有未检查的点
		if current_check_point_index < alert_check_points.size():
			# 移动到下一个检查点
			navigation_agent.set_target_position(alert_check_points[current_check_point_index])
		else:
			# 所有检查点都已检查，返回巡逻
			change_state(State.PATROL)

## 处理追击状态
## 敌人追击玩家
func _process_chase(delta: float) -> void:
	# 减少追击计时器
	chase_timer -= delta
	path_update_timer -= delta
	
	# 追击时间结束，返回巡逻
	if chase_timer <= 0.0:
		change_state(State.PATROL)
		return
	
	# 获取玩家引用
	var player := _get_player()
	
	# 如果能看到玩家
	if _can_see_player and player:
		# 更新玩家最后已知位置
		last_known_player_position = player.global_position
		
		# 定期更新追击路径
		if path_update_timer <= 0.0:
			path_update_timer = chase_target_interval
			if navigation_agent:
				navigation_agent.set_target_position(last_known_player_position)
		
		# 检查是否抓到玩家
		if global_position.distance_to(player.global_position) < 1.5:
			emit_signal("player_caught")
			EventBus.player_caught.emit()
			print("[MonsterAI] 抓住玩家！")
	else:
		# 看不到玩家，追击至最后位置附近
		if path_update_timer <= 0.0:
			path_update_timer = chase_target_interval * 2.0
			# 在最后位置附近生成随机目标点
			var offset := Vector3(
				randf_range(-chase_target_offset, chase_target_offset),
				0.0,
				randf_range(-chase_target_offset, chase_target_offset)
			)
			var target := last_known_player_position + offset
			if navigation_agent:
				navigation_agent.set_target_position(target)

## 生成巡逻点
## 在玩家周围或当前位置周围随机生成
func _generate_patrol_point() -> void:
	var player := _get_player()
	var center: Vector3
	
	if player:
		# 在玩家周围生成
		center = player.global_position
	else:
		# 在当前位置周围生成
		center = global_position
	
	# 生成随机偏移
	var angle: float = randf() * 2.0 * PI
	var distance := randf_range(patrol_min_distance, patrol_max_distance)
	var offset := Vector3(
		cos(angle) * distance,
		0.0,
		sin(angle) * distance
	)
	
	var target := center + offset
	
	# 设置导航目标
	if navigation_agent:
		navigation_agent.set_target_position(target)

## 生成警觉状态检查点
func _generate_alert_check_points() -> void:
	alert_check_points.clear()
	current_check_point_index = 0
	
	# 随机生成检查点数量
	var num_points := randi_range(alert_check_points_min, alert_check_points_max)
	
	for i in range(num_points):
		# 在目标位置周围生成检查点
		var angle: float = randf() * 2.0 * PI
		var distance := randf_range(2.0, alert_check_radius)
		var offset := Vector3(
			cos(angle) * distance,
			0.0,
			sin(angle) * distance
		)
		alert_check_points.append(last_known_player_position + offset)

## 应用重力
## 当敌人不在地面时应用重力
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

## 计算移动速度
## 根据导航路径计算期望移动速度
func _calculate_velocity(delta: float) -> void:
	if not navigation_agent:
		return
	
	# 根据状态选择目标速度
	var target_speed := patrol_speed
	match current_state:
		State.ALERT:
			target_speed = alert_speed
		State.CHASE:
			target_speed = chase_speed
	
	# 到达目标，减速停止
	if navigation_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		return
	
	# 获取下一个路径点
	var next_position := navigation_agent.get_next_path_position()
	# 计算移动方向
	var direction := (next_position - global_position).normalized()
	
	# 平滑加速到目标速度
	velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
	
	# 朝向移动方向
	_look_at_direction(direction)

## 避障系统回调
## 当导航代理计算出安全速度时调用
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	# 应用安全速度
	velocity = safe_velocity
	# 使用安全速度移动
	move_and_slide()

## 朝向指定方向
## 平滑旋转敌人朝向移动方向
func _look_at_direction(direction: Vector3) -> void:
	if direction.length_squared() > 0.001:
		# 计算目标旋转角度
		var target_rotation := atan2(direction.x, direction.z)
		# 平滑插值旋转
		rotation.y = lerp_angle(rotation.y, target_rotation, 0.1)

## 改变状态
## 切换到新状态并执行相应的初始化
func change_state(new_state: State) -> void:
	# 状态未改变，直接返回
	if current_state == new_state:
		return
	
	# 更新当前状态
	current_state = new_state
	
	# 根据新状态执行初始化
	match new_state:
		State.PATROL:
			print("[MonsterAI] 切换到巡逻状态")
			# 重置警觉值
			alertness = 0.0
			# 生成巡逻点
			_generate_patrol_point()
		
		State.ALERT:
			print("[MonsterAI] 切换到警觉状态，警觉值: %.1f" % alertness)
			# 生成检查点
			_generate_alert_check_points()
			# 设置第一个检查点为目标
			if alert_check_points.size() > 0 and navigation_agent:
				navigation_agent.set_target_position(alert_check_points[0])
			# 设置随机停留时间
			wait_timer = randf_range(alert_wait_time_min, alert_wait_time_max)
		
		State.CHASE:
			print("[MonsterAI] 切换到追击状态")
			# 设置随机追击时间
			chase_timer = randf_range(chase_time_min, chase_time_max)
			# 立即更新路径
			path_update_timer = 0.0
			# 发送检测到玩家信号
			emit_signal("player_detected", last_known_player_position)
			EventBus.monster_detected_player.emit(last_known_player_position)
			# 设置追击目标
			if navigation_agent:
				navigation_agent.set_target_position(last_known_player_position)
	
	# 发送状态改变信号
	emit_signal("state_changed", State.keys()[new_state])
	EventBus.monster_state_changed.emit(State.keys()[new_state])

## 感知系统回调：看到玩家
## 当感知系统检测到玩家时调用
func _on_player_seen(player_position: Vector3) -> void:
	# 更新玩家最后已知位置
	last_known_player_position = player_position
	_can_see_player = true
	
	# 获取玩家引用
	var player := _get_player()
	if not player:
		return
	
	var distance := global_position.distance_to(player_position)
	
	# 如果玩家距离足够近，直接触发追击
	if distance <= instant_chase_distance:
		alertness = max_alertness
		change_state(State.CHASE)
		return
	
	# 计算视觉警觉值增量
	# 距离越近，警觉值增量越大
	var distance_factor: float = 1.0 - (distance / detection_range)
	var alertness_gain: float = distance_factor * visual_factor * 15.0
	
	# 累计警觉值
	alertness += alertness_gain
	alertness = min(alertness, max_alertness)
	
	print("[MonsterAI] 看到玩家，距离: %.1fm, 警觉值增量: %.1f, 当前警觉值: %.1f" % [distance, alertness_gain, alertness])

## 感知系统回调：听到噪音
## 当感知系统检测到噪音时调用
func _on_noise_heard(noise_position: Vector3, noise_level: float, max_range: float) -> void:
	# 更新玩家最后已知位置
	last_known_player_position = noise_position
	
	# 计算距离
	var distance := global_position.distance_to(noise_position)
	
	# 计算声音衰减
	# 接收到的音量 = 原始音量 * (1 - 距离/最大传播距离)
	var attenuation: float = 1.0 - (distance / max_range)
	var received_volume: float = noise_level * max(attenuation, 0.0)
	
	# 计算听觉警觉值增量
	var alertness_gain: float = received_volume * hearing_factor * 10.0
	
	# 累计警觉值
	alertness += alertness_gain
	alertness = min(alertness, max_alertness)
	
	print("[MonsterAI] 听到噪音，距离: %.1fm, 接收音量: %.1f, 警觉值增量: %.1f, 当前警觉值: %.1f" % [distance, received_volume, alertness_gain, alertness])

## 感知系统回调：丢失玩家
## 当感知系统失去玩家视野时调用
func _on_player_lost() -> void:
	_can_see_player = false
	print("[MonsterAI] 丢失玩家视野")
	EventBus.monster_lost_player.emit()

## 获取玩家节点
## 通过弱引用安全获取玩家节点
func _get_player() -> Node3D:
	if _player_ref.get_ref():
		return _player_ref.get_ref() as Node3D
	return null

## 获取当前状态名称
## 返回状态的字符串表示
func get_state_name() -> String:
	return State.keys()[current_state]

## 获取当前警觉值百分比
func get_alertness_percent() -> float:
	return alertness / max_alertness
