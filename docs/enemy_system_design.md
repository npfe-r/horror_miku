# 敌人系统设计文档

## 1. 系统概述

### 1.1 基本信息
- **系统名称**: 敌人AI系统
- **版本**: 2.0
- **更新日期**: 2026-04-26
- **相关文件**:
  - `scripts/enemies/monster_ai.gd` - 敌人AI控制器
  - `scripts/enemies/monster_perception.gd` - 感知系统
  - `scenes/enemies/monster.tscn` - 敌人场景

### 1.2 系统架构

```
MonsterAI (CharacterBody3D)
├── Perception (感知系统)
│   ├── 视觉感知
│   └── 听觉感知
├── NavigationAgent3D (导航代理)
│   ├── 路径规划
│   └── 避障系统
└── CollisionShape3D (碰撞体)
```

### 1.3 核心特性

1. **警觉值系统**: 渐进式警觉，避免立即追击
2. **随机因数**: 使用正态分布生成随机因数，增加不可预测性
3. **距离衰减**: 声音和视觉都有距离因素
4. **智能搜索**: 警觉状态会检查多个点
5. **持续追击**: 即使丢失视野也会继续追击一段时间

---

## 2. 状态机系统

### 2.1 状态定义

```gdscript
enum State {
    PATROL,   # 巡逻状态：随机巡逻
    ALERT,    # 警觉状态：调查可疑位置
    CHASE     # 追击状态：追击玩家
}
```

### 2.2 状态转换图

```
┌─────────────┐
│   PATROL    │ ←──────────────────────┐
│  (巡逻)     │                         │
└──────┬──────┘                         │
       │ 警觉值 ≥ 30                    │
       ▼                                │
┌─────────────┐                         │
│   ALERT     │ ──检查完成─────────────┤
│  (警觉)     │                         │
└──────┬──────┘                         │
       │ 警觉值 ≥ 80 或 玩家距离 ≤ 3米   │
       ▼                                │
┌─────────────┐                         │
│   CHASE     │ ──追击时间结束──────────┘
│  (追击)     │
└─────────────┘
```

### 2.3 状态详细说明

#### 2.3.1 巡逻状态 (PATROL)

**行为**:
- 在玩家周围或当前位置周围随机生成巡逻点
- 巡逻点距离范围: 5-20米
- 到达巡逻点后停留1-3秒
- 持续监听周围噪音和视觉信息

**状态转换条件**:
- 警觉值 ≥ 30 → 进入警觉状态
- 警觉值 ≥ 80 → 进入追击状态

**移动速度**: 2.0 m/s

#### 2.3.2 警觉状态 (ALERT)

**行为**:
- 在可疑位置周围生成1-3个检查点
- 检查点半径: 8米
- 依次检查每个检查点
- 每个检查点停留2-5秒

**状态转换条件**:
- 警觉值 ≥ 80 → 进入追击状态
- 所有检查点检查完成 → 返回巡逻状态

**移动速度**: 3.0 m/s

#### 2.3.3 追击状态 (CHASE)

**行为**:
- 随机追击时间: 10-30秒
- 看到玩家时: 每0.3秒更新玩家位置
- 看不到玩家时: 在最后位置附近随机搜索
- 距离玩家 < 1.5米: 抓住玩家

**状态转换条件**:
- 追击时间结束 → 返回巡逻状态

**移动速度**: 6.5 m/s (略快于玩家奔跑速度6.0 m/s)

---

## 3. 警觉值系统

### 3.1 系统概述

警觉值系统是敌人AI的核心，决定了敌人的行为状态。通过累计警觉值，敌人会从巡逻状态逐步升级到追击状态。

### 3.2 警觉值参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 最大警觉值 | 100.0 | 警觉值上限 |
| 警觉阈值 | 30.0 | 进入警觉状态的警觉值 |
| 追击阈值 | 80.0 | 进入追击状态的警觉值 |
| 自然衰减速率 | 5.0/秒 | 非追击状态下的警觉值衰减速度 |

### 3.3 警觉值来源

#### 3.3.1 视觉警觉值

**计算公式**:
```
视觉警觉值增量 = (1 - 距离/检测范围) × 视觉因数 × 15.0
```

**示例**:
- 距离5米，视觉因数1.0: (1 - 5/15) × 1.0 × 15 = 10.0
- 距离10米，视觉因数1.2: (1 - 10/15) × 1.2 × 15 = 6.0

**立即追击**:
- 玩家距离 ≤ 3米时，警觉值直接设为最大值

#### 3.3.2 听觉警觉值

**计算公式**:
```
声音衰减 = 1 - (距离/最大传播距离)
接收音量 = 原始音量 × max(声音衰减, 0.0)
听觉警觉值增量 = 接收音量 × 听觉因数 × 10.0
```

**示例**:
- 原始音量3.0，距离10米，最大传播距离24米，听觉因数1.0
  - 声音衰减 = 1 - (10/24) = 0.583
  - 接收音量 = 3.0 × 0.583 = 1.75
  - 警觉值增量 = 1.75 × 1.0 × 10 = 17.5

### 3.4 随机因数系统

#### 3.4.1 听觉因数

- **生成方式**: 正态分布随机数
- **均值**: 1.0
- **标准差**: 0.3
- **范围**: 0.1 - 2.0
- **更新间隔**: 2秒

**作用**: 让敌人对声音的敏感度随机变化，增加不可预测性

#### 3.4.2 视觉因数

- **生成方式**: 正态分布随机数
- **均值**: 1.0
- **标准差**: 0.2
- **范围**: 0.5 - 1.5
- **更新间隔**: 1.5秒

**作用**: 让敌人对视觉刺激的敏感度随机变化

#### 3.4.3 正态分布实现

使用Box-Muller变换生成正态分布随机数：

```gdscript
func _normal_random(mean: float, std_dev: float) -> float:
    var u1 := randf()
    var u2 := randf()
    while u1 <= 0.0:
        u1 = randf()
    
    var z: float = sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)
    return mean + z * std_dev
```

### 3.5 警觉值衰减

- **衰减条件**: 非追击状态
- **衰减速率**: 5.0/秒
- **最小值**: 0.0

**实现**:
```gdscript
func _decay_alertness(delta: float) -> void:
    if current_state == State.CHASE:
        return
    
    alertness -= alertness_decay_rate * delta
    alertness = max(alertness, 0.0)
```

---

## 4. 感知系统

### 4.1 视觉感知

#### 4.1.1 视觉参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 视野范围 | 15.0米 | 能看到玩家的最大距离 |
| 视野角度 | 90° | 半角值，总视野180° |
| 检测间隔 | 0.2秒 | 优化性能，避免每帧检测 |
| 射线碰撞掩码 | 0xFFFFFFFF | 检测所有层 |

#### 4.1.2 视觉检测流程

```
1. 距离检测
   └─ 距离 > 视野范围 → 无法看到

2. 角度检测
   └─ 角度 > 视野角度 → 无法看到

3. 射线检测
   └─ 射线被遮挡 → 无法看到
   └─ 射线碰撞到玩家 → 可以看到
```

#### 4.1.3 视觉检测实现

```gdscript
func _check_vision() -> void:
    var player := _get_player()
    if not player:
        return
    
    # 1. 距离检测
    var distance := monster_pos.distance_to(player_pos)
    if distance > sight_range:
        if _can_see_player:
            emit_signal("player_lost")
        return
    
    # 2. 角度检测
    var angle := rad_to_deg(acos(forward.dot(direction_to_player)))
    if angle > sight_angle:
        if _can_see_player:
            emit_signal("player_lost")
        return
    
    # 3. 射线检测
    var result := space_state.intersect_ray(query)
    if not result.is_empty() and result.get("collider") == player:
        if not _can_see_player:
            emit_signal("player_seen", player_pos)
```

### 4.2 听觉感知

#### 4.2.1 听觉参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 最大听觉范围 | 25.0米 | 能听到声音的最大距离 |
| 噪音检测阈值 | 1.0 | 最小噪音等级 |

#### 4.2.2 声音传播距离

玩家不同行为产生的噪音及其传播距离：

| 行为 | 噪音等级 | 最大传播距离 |
|------|----------|--------------|
| 行走 | 2.0 | 16.0米 |
| 奔跑 | 3.0 | 24.0米 |
| 蹲走 | 1.0 | 8.0米 |
| 跳跃 | 3.5 | 28.0米 |
| 落地 | 3.0 | 24.0米 |

#### 4.2.3 声音衰减计算

```gdscript
# 线性衰减模型
声音衰减 = 1 - (距离/最大传播距离)
接收音量 = 原始音量 × max(声音衰减, 0.0)
```

**衰减曲线**:
```
接收音量
    │
1.0 ┤●
    │  ╲
0.8 ┤    ╲
    │      ╲
0.6 ┤        ╲
    │          ╲
0.4 ┤            ╲
    │              ╲
0.2 ┤                ╲
    │                  ╲
0.0 ┤────────────────────●───→ 距离
    0      8     16    24
```

### 4.3 感知信号

#### 4.3.1 信号定义

```gdscript
# 看到玩家信号
signal player_seen(position: Vector3)

# 听到噪音信号
signal noise_heard(position: Vector3, level: float, max_range: float)

# 丢失玩家信号
signal player_lost
```

#### 4.3.2 信号连接

```gdscript
func _connect_perception_signals() -> void:
    if perception:
        perception.player_seen.connect(_on_player_seen)
        perception.noise_heard.connect(_on_noise_heard)
        perception.player_lost.connect(_on_player_lost)
```

---

## 5. 移动系统

### 5.1 移动参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 巡逻速度 | 2.0 m/s | 巡逻时的移动速度 |
| 警觉速度 | 3.0 m/s | 警觉时的移动速度 |
| 追击速度 | 6.5 m/s | 追击时的移动速度 |
| 加速度 | 15.0 m/s² | 加速到目标速度的快慢 |
| 减速度 | 20.0 m/s² | 减速停止的快慢 |

### 5.2 导航系统

#### 5.2.1 NavigationAgent3D配置

```gdscript
radius = 0.5
height = 1.8
path_desired_distance = 0.5
target_desired_distance = 0.5
path_max_distance = 100.0
simplify_path = true
simplify_epsilon = 0.2
avoidance_enabled = true
max_speed = 6.0
```

#### 5.2.2 避障系统

**工作流程**:
1. 计算期望速度 (`_calculate_velocity`)
2. 发送给导航代理 (`set_velocity`)
3. 导航代理计算安全速度
4. 接收安全速度 (`_on_velocity_computed`)
5. 应用安全速度移动 (`move_and_slide`)

**实现**:
```gdscript
func _physics_process(delta: float) -> void:
    # ... 状态处理 ...
    _calculate_velocity(delta)
    
    if navigation_agent and navigation_agent.avoidance_enabled:
        navigation_agent.set_velocity(velocity)
    else:
        move_and_slide()

func _on_velocity_computed(safe_velocity: Vector3) -> void:
    velocity = safe_velocity
    move_and_slide()
```

### 5.3 速度计算

```gdscript
func _calculate_velocity(delta: float) -> void:
    # 选择目标速度
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
    
    # 计算移动方向
    var next_position := navigation_agent.get_next_path_position()
    var direction := (next_position - global_position).normalized()
    
    # 平滑加速
    velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
    velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
```

---

## 6. 巡逻系统

### 6.1 随机巡逻算法

#### 6.1.1 巡逻点生成

```gdscript
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
    navigation_agent.set_target_position(target)
```

#### 6.1.2 巡逻参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 巡逻半径 | 15.0米 | 在玩家周围生成巡逻点的范围 |
| 最小距离 | 5.0米 | 新巡逻点与当前点的最小距离 |
| 最大距离 | 20.0米 | 新巡逻点与当前点的最大距离 |
| 停留时间 | 1-3秒 | 到达巡逻点后的停留时间 |

### 6.2 巡逻流程

```
1. 生成巡逻点
   ↓
2. 移动到巡逻点
   ↓
3. 到达后停留1-3秒
   ↓
4. 检查警觉值
   ├─ 警觉值 ≥ 30 → 进入警觉状态
   ├─ 警觉值 ≥ 80 → 进入追击状态
   └─ 警觉值 < 30 → 生成新巡逻点
   ↓
5. 重复步骤2
```

---

## 7. 警觉状态系统

### 7.1 检查点生成

```gdscript
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
```

### 7.2 警觉状态参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 检查点数量 | 1-3个 | 随机生成的检查点数量 |
| 检查半径 | 8.0米 | 检查点围绕目标位置的范围 |
| 停留时间 | 2-5秒 | 每个检查点的停留时间 |

### 7.3 警觉状态流程

```
1. 进入警觉状态
   ├─ 生成1-3个检查点
   └─ 设置第一个检查点为目标
   ↓
2. 移动到检查点
   ↓
3. 到达后停留2-5秒
   ↓
4. 检查警觉值
   ├─ 警觉值 ≥ 80 → 进入追击状态
   └─ 警觉值 < 80 → 继续检查
   ↓
5. 移动到下一个检查点
   ↓
6. 所有检查点检查完成
   └─ 返回巡逻状态
```

---

## 8. 追击系统

### 8.1 追击参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 追击时间 | 10-30秒 | 随机生成的追击时间 |
| 路径更新间隔 | 0.3秒 | 看到玩家时更新路径的频率 |
| 目标偏移 | 3.0米 | 看不到玩家时的随机偏移范围 |
| 抓捕距离 | 1.5米 | 抓住玩家的距离 |

### 8.2 追击流程

```
1. 进入追击状态
   ├─ 设置随机追击时间(10-30秒)
   └─ 设置玩家位置为目标
   ↓
2. 检查视野
   ├─ 能看到玩家
   │   ├─ 每0.3秒更新玩家位置
   │   └─ 直接追向玩家
   └─ 看不到玩家
       ├─ 在最后位置附近随机搜索
       └─ 每0.6秒更新目标位置
   ↓
3. 检查抓捕条件
   └─ 距离玩家 < 1.5米 → 抓住玩家
   ↓
4. 检查追击时间
   ├─ 时间未到 → 继续追击
   └─ 时间到 → 返回巡逻状态
```

### 8.3 追击实现

```gdscript
func _process_chase(delta: float) -> void:
    chase_timer -= delta
    path_update_timer -= delta
    
    # 追击时间结束
    if chase_timer <= 0.0:
        change_state(State.PATROL)
        return
    
    var player := _get_player()
    
    # 能看到玩家
    if _can_see_player and player:
        last_known_player_position = player.global_position
        
        # 定期更新路径
        if path_update_timer <= 0.0:
            path_update_timer = chase_target_interval
            navigation_agent.set_target_position(last_known_player_position)
        
        # 检查抓捕
        if global_position.distance_to(player.global_position) < 1.5:
            emit_signal("player_caught")
    else:
        # 看不到玩家，随机搜索
        if path_update_timer <= 0.0:
            path_update_timer = chase_target_interval * 2.0
            var offset := Vector3(
                randf_range(-chase_target_offset, chase_target_offset),
                0.0,
                randf_range(-chase_target_offset, chase_target_offset)
            )
            navigation_agent.set_target_position(last_known_player_position + offset)
```

---

## 9. 调试与可视化

### 9.1 调试UI

#### 9.1.1 显示内容

```
敌人状态: CHASE
速度: 5.23 m/s | 距离: 8.5m
警觉: [████████████████████] 100%
```

#### 9.1.2 实现代码

```gdscript
func _update_monster_display() -> void:
    var speed := Vector2(monster.velocity.x, monster.velocity.z).length()
    var distance := ""
    var alertness_bar := ""
    
    if player:
        var dist_to_player := monster.global_position.distance_to(player.global_position)
        distance = " | 距离: %.1fm" % dist_to_player
    
    # 警觉值进度条
    var alertness_percent := monster.get_alertness_percent()
    var bar_length := 20
    var filled := int(alertness_percent * bar_length)
    var empty := bar_length - filled
    alertness_bar = "\n警觉: [%s%s] %.0f%%" % ["█".repeat(filled), "░".repeat(empty), alertness_percent * 100]
    
    monster_label.text = "敌人状态: %s\n速度: %.2f m/s%s%s" % [monster.get_state_name(), speed, distance, alertness_bar]
```

### 9.2 日志输出

#### 9.2.1 状态切换日志

```
[MonsterAI] 切换到巡逻状态
[MonsterAI] 切换到警觉状态，警觉值: 35.2
[MonsterAI] 切换到追击状态
```

#### 9.2.2 感知日志

```
[MonsterPerception] 看到玩家！距离: 8.5m, 角度: 45.2°
[MonsterPerception] 听到噪音，等级: 3.0, 距离: 12.3m, 最大传播距离: 24.0m
[MonsterPerception] 丢失玩家视野
```

#### 9.2.3 警觉值日志

```
[MonsterAI] 看到玩家，距离: 8.5m, 警觉值增量: 6.5, 当前警觉值: 42.3
[MonsterAI] 听到噪音，距离: 12.3m, 接收音量: 1.8, 警觉值增量: 18.0, 当前警觉值: 60.3
```

---

## 10. 性能优化

### 10.1 视觉检测优化

- **检测间隔**: 0.2秒，避免每帧检测
- **距离优先**: 先检测距离，再检测角度，最后射线检测
- **早期退出**: 不满足条件时立即返回

### 10.2 导航优化

- **路径简化**: 启用路径简化，减少路径点数量
- **路径缓存**: 避免频繁更新目标位置
- **避障优化**: 使用合理的避障参数

### 10.3 内存优化

- **弱引用**: 使用WeakRef引用玩家，避免循环引用
- **对象池**: 检查点数组复用，避免频繁创建销毁

---

## 11. 扩展性

### 11.1 新增状态

要添加新状态，需要：

1. 在State枚举中添加新状态
2. 实现`_process_[state_name]`函数
3. 在`_physics_process`中添加状态分支
4. 在`change_state`中添加状态初始化逻辑

### 11.2 自定义感知

要添加新的感知类型，需要：

1. 在MonsterPerception中添加新的检测逻辑
2. 定义新的信号
3. 在MonsterAI中连接信号并实现回调

### 11.3 自定义行为

要添加自定义行为，可以：

1. 继承MonsterAI类
2. 重写状态处理函数
3. 添加新的导出变量

---

## 12. 已知问题与限制

### 12.1 已知问题

1. **多敌人协作**: 当前系统不支持敌人之间的协作
2. **环境互动**: 敌人不会与环境物体互动（开门、推物体等）
3. **声音遮挡**: 声音不考虑墙壁遮挡

### 12.2 系统限制

1. **单玩家**: 系统设计为单玩家游戏
2. **平面移动**: 敌人只能在平面上移动，不支持爬楼梯
3. **固定速度**: 不支持动态调整速度

---

## 13. 未来改进方向

### 13.1 短期改进

- [ ] 添加声音遮挡系统
- [ ] 支持多敌人协作
- [ ] 添加环境互动能力

### 13.2 长期改进

- [ ] 机器学习驱动的行为
- [ ] 动态难度调整
- [ ] 更复杂的巡逻模式

---

## 附录

### A. 参数配置表

#### A.1 移动参数

| 参数 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| patrol_speed | float | 2.0 | 0.5-5.0 | 巡逻速度 |
| alert_speed | float | 3.0 | 1.0-6.0 | 警觉速度 |
| chase_speed | float | 6.5 | 2.0-10.0 | 追击速度 |
| acceleration | float | 15.0 | 5.0-30.0 | 加速度 |
| deceleration | float | 20.0 | 5.0-40.0 | 减速度 |

#### A.2 检测参数

| 参数 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| detection_range | float | 15.0 | 5.0-30.0 | 视觉检测范围 |
| hearing_range | float | 25.0 | 10.0-50.0 | 听觉检测范围 |
| sight_angle | float | 90.0 | 30.0-180.0 | 视野角度 |
| instant_chase_distance | float | 3.0 | 1.0-10.0 | 立即追击距离 |

#### A.3 警觉值参数

| 参数 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| max_alertness | float | 100.0 | 50.0-200.0 | 最大警觉值 |
| chase_threshold | float | 80.0 | 50.0-100.0 | 追击阈值 |
| alert_threshold | float | 30.0 | 10.0-50.0 | 警觉阈值 |
| alertness_decay_rate | float | 5.0 | 1.0-20.0 | 衰减速率 |

### B. API参考

#### B.1 MonsterAI公共方法

```gdscript
# 获取当前状态名称
func get_state_name() -> String

# 获取警觉值百分比
func get_alertness_percent() -> float

# 设置巡逻点（运行时）
func set_patrol_points(points: Array[NodePath]) -> void
```

#### B.2 MonsterPerception公共方法

```gdscript
# 检查是否能听到噪音
func can_hear_noise(noise_position: Vector3, noise_level: float, max_range: float = -1.0) -> bool

# 是否能看到玩家
func can_see_player() -> bool

# 获取最后看到玩家的位置
func get_last_seen_position() -> Vector3
```

### C. 信号参考

#### C.1 MonsterAI信号

```gdscript
# 状态改变信号
signal state_changed(new_state: String)

# 检测到玩家信号
signal player_detected(position: Vector3)

# 抓住玩家信号
signal player_caught
```

#### C.2 MonsterPerception信号

```gdscript
# 看到玩家信号
signal player_seen(position: Vector3)

# 听到噪音信号
signal noise_heard(position: Vector3, level: float, max_range: float)

# 丢失玩家信号
signal player_lost
```

---

**文档版本**: 2.1  
**最后更新**: 2026-04-29  
**维护者**: 游戏开发团队

### 更新记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 2.0 | 2026-04-26 | 初始版本 |
| 2.1 | 2026-04-29 | 对齐代码实现，chase_speed 更新为 6.5 |
