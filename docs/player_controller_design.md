# 玩家控制器详细设计文档

## 1. 概述

### 1.1 基本信息
- **脚本名称**: PlayerController
- **继承自**: CharacterBody3D
- **文件路径**: `scripts/player/player_controller.gd`
- **场景路径**: `scenes/player/player.tscn`
- **引擎版本**: Godot 4.6

### 1.2 功能概述
玩家控制器实现了第一人称恐怖游戏的核心玩家功能，包括移动、视角控制、体力系统、噪音系统等。设计遵循恐怖游戏的潜行机制，玩家的行动会产生噪音，可能吸引怪物注意。

---

## 2. 核心系统

### 2.1 移动系统

#### 2.1.1 移动速度
| 状态 | 速度 (m/s) | 常量名 |
|------|-----------|--------|
| 行走 | 3.5 | WALK_SPEED |
| 奔跑 | 6.0 | RUN_SPEED |
| 蹲下 | 1.5 | CROUCH_SPEED |

#### 2.1.2 移动控制
- **输入映射**:
  - `move_forward` - W键 - 向前移动
  - `move_backward` - S键 - 向后移动
  - `move_left` - A键 - 向左移动
  - `move_right` - D键 - 向右移动

#### 2.1.3 移动逻辑
```gdscript
func _handle_movement(delta: float) -> void:
    # 重力处理
    if not is_on_floor():
        velocity.y -= _gravity * delta
    
    # 跳跃处理
    if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
        velocity.y = JUMP_VELOCITY
        is_jumping = true
        make_noise(NOISE_JUMP)
    
    # 方向计算
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    # 速度选择
    var current_speed: float = WALK_SPEED
    if is_crouching:
        current_speed = CROUCH_SPEED
    elif Input.is_action_pressed("run") and stamina > STAMINA_MIN_TO_RUN:
        current_speed = RUN_SPEED
    
    # 应用速度
    velocity.x = direction.x * current_speed
    velocity.z = direction.z * current_speed
```

---

### 2.2 视角控制系统

#### 2.2.1 鼠标灵敏度
- **默认值**: 0.002
- **可配置**: 通过 `mouse_sensitivity` 导出变量调整

#### 2.2.2 视角限制
- **垂直角度**: -90° 到 +90°
- **水平角度**: 无限制（360°旋转）

#### 2.2.3 视角控制逻辑
```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        # 水平旋转（整个角色）
        rotate_y(-event.relative.x * mouse_sensitivity)
        # 垂直旋转（仅头部）
        head.rotate_x(-event.relative.y * mouse_sensitivity)
        head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))
```

#### 2.2.4 鼠标捕获
- 游戏开始时自动捕获鼠标
- 鼠标模式: `Input.MOUSE_MODE_CAPTURED`

---

### 2.3 跳跃系统

#### 2.3.1 跳跃参数
| 参数 | 值 | 说明 |
|------|-----|------|
| 跳跃速度 | 4.5 m/s | JUMP_VELOCITY |
| 跳跃噪音 | 3.5 | NOISE_JUMP |
| 落地噪音 | 3.0 | NOISE_LAND |

#### 2.3.2 跳跃条件
- 必须在地面上 (`is_on_floor() == true`)
- 不能处于蹲下状态 (`is_crouching == false`)

#### 2.3.3 跳跃状态管理
```gdscript
var is_jumping: bool = false
var was_on_floor: bool = true

func _check_landing() -> void:
    if not was_on_floor and is_on_floor():
        make_noise(NOISE_LAND)
```

---

### 2.4 蹲下系统

#### 2.4.1 蹲下参数
| 参数 | 值 | 说明 |
|------|-----|------|
| 正常头部高度 | 1.5m | HEAD_HEIGHT_NORMAL |
| 蹲下头部高度 | 0.8m | HEAD_HEIGHT_CROUCH |
| 正常碰撞高度 | 1.8m | COLLISION_HEIGHT_NORMAL |
| 蹲下碰撞高度 | 1.0m | COLLISION_HEIGHT_CROUCH |
| 过渡速度 | 8.0 | CROUCH_TRANSITION_SPEED |

#### 2.4.2 平滑过渡
蹲下和起身时，相机高度和碰撞体高度会平滑过渡，避免突变。

```gdscript
func _smooth_crouch_transition(delta: float) -> void:
    # 相机高度过渡
    var current_height: float = head.position.y
    if abs(current_height - _target_head_height) > 0.001:
        head.position.y = lerp(current_height, _target_head_height, CROUCH_TRANSITION_SPEED * delta)
    
    # 碰撞体高度和位置过渡
    if collision_shape.shape is CapsuleShape3D:
        var capsule := collision_shape.shape as CapsuleShape3D
        var current_collision_height: float = capsule.height
        if abs(current_collision_height - _target_collision_height) > 0.001:
            capsule.height = lerp(current_collision_height, _target_collision_height, CROUCH_TRANSITION_SPEED * delta)
            collision_shape.position.y = capsule.height / 2.0
```

#### 2.4.3 天花板检测
蹲下时无法起身的情况：头顶空间不足。

```gdscript
func _check_ceiling_clearance() -> void:
    if is_crouching and ceiling_check:
        ceiling_check.force_shapecast_update()
        _can_stand_up = not ceiling_check.is_colliding()
```

**天花板检测节点配置**:
- 节点类型: ShapeCast3D
- 形状: BoxShape3D (0.5 x 0.1 x 0.5)
- 检测位置: 头顶 (y = 1.7)
- 检测范围: 向上 0.2 米

---

### 2.5 体力系统

#### 2.5.1 体力参数
| 参数 | 值 | 说明 |
|------|-----|------|
| 最大体力 | 100.0 | STAMINA_MAX |
| 奔跑消耗率 | 20.0/s | STAMINA_DRAIN_RATE |
| 恢复率 | 15.0/s | STAMINA_RECOVERY_RATE |
| 最低奔跑体力 | 10.0 | STAMINA_MIN_TO_RUN |

#### 2.5.2 体力逻辑
```gdscript
func _handle_stamina(delta: float) -> void:
    if is_running and velocity.length() > 0.1:
        stamina -= STAMINA_DRAIN_RATE * delta
        stamina = max(stamina, 0.0)
        emit_signal("stamina_changed", stamina)
    elif not is_running:
        stamina += STAMINA_RECOVERY_RATE * delta
        stamina = min(stamina, STAMINA_MAX)
        emit_signal("stamina_changed", stamina)
```

#### 2.5.3 体力限制
- 体力低于 `STAMINA_MIN_TO_RUN` 时无法奔跑
- 奔跑时体力持续消耗
- 停止奔跑时体力自动恢复

---

### 2.6 噪音系统

#### 2.6.1 噪音等级
| 状态 | 噪音等级 | 检测半径 | 说明 |
|------|---------|---------|------|
| 静止 | 0.0 | 0m | NOISE_STATIONARY |
| 蹲下行走 | 1.0 | ~8m | NOISE_CROUCH |
| 正常行走 | 2.0 | ~16m | NOISE_WALK |
| 奔跑 | 3.0 | ~24m | NOISE_RUN |
| 跳跃 | 3.5 | ~28m | NOISE_JUMP |
| 落地 | 3.0 | ~24m | NOISE_LAND |

#### 2.6.2 噪音发射间隔
| 状态 | 发射间隔 | 每秒次数 |
|------|---------|---------|
| 蹲下行走 | 0.8秒 | 1.25次 |
| 正常行走 | 0.5秒 | 2次 |
| 奔跑 | 0.3秒 | 3.3次 |

#### 2.6.3 噪音发射逻辑
```gdscript
func _update_noise_level(delta: float) -> void:
    # 计算当前噪音等级
    if velocity.length() < 0.1:
        noise_level = NOISE_STATIONARY
        _noise_emit_timer = 0.0
    elif is_crouching:
        noise_level = NOISE_CROUCH
    elif is_running:
        noise_level = NOISE_RUN
    else:
        noise_level = NOISE_WALK
    
    # 持续发出噪音
    if noise_level > NOISE_STATIONARY:
        var emit_interval: float = NOISE_EMIT_INTERVAL_WALK
        if is_running:
            emit_interval = NOISE_EMIT_INTERVAL_RUN
        elif is_crouching:
            emit_interval = NOISE_EMIT_INTERVAL_CROUCH
        
        _noise_emit_timer += delta
        if _noise_emit_timer >= emit_interval:
            emit_signal("noise_made", noise_level, global_position)
            _noise_emit_timer = 0.0
```

#### 2.6.4 噪音信号
```gdscript
signal noise_made(noise_level: float, position: Vector3)
```

---

## 3. 节点结构

### 3.1 玩家场景树
```
Player (CharacterBody3D)
├── CollisionShape3D (CapsuleShape3D)
│   └── 位置: (0, 0.9, 0)
│   └── 尺寸: radius=0.3, height=1.8
├── Head (Node3D)
│   ├── Camera3D (主相机)
│   │   └── FOV: 75°
│   └── InteractionRay (RayCast3D)
│       └── 检测距离: 2.5m
├── MeshInstance3D (可视化模型)
│   └── CapsuleMesh (调试用)
└── CeilingCheck (ShapeCast3D)
    └── 天花板碰撞检测
```

### 3.2 节点引用
```gdscript
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/InteractionRay
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ceiling_check: ShapeCast3D = $CeilingCheck
```

---

## 4. 状态变量

### 4.1 公开变量
```gdscript
var stamina: float = STAMINA_MAX           # 体力值
var noise_level: float = NOISE_STATIONARY  # 当前噪音等级
var is_hiding: bool = false                # 是否在藏身处
var is_crouching: bool = false             # 是否蹲下
var is_running: bool = false               # 是否奔跑
var is_jumping: bool = false               # 是否跳跃中
```

### 4.2 私有变量
```gdscript
var _target_head_height: float = HEAD_HEIGHT_NORMAL
var _target_collision_height: float = COLLISION_HEIGHT_NORMAL
var _can_stand_up: bool = true
var _noise_emit_timer: float = 0.0
var was_on_floor: bool = true
```

---

## 5. 公开方法

### 5.1 噪音相关
```gdscript
func make_noise(level: float) -> void
```
手动发出指定等级的噪音。

**参数**:
- `level`: 噪音等级 (0.0 - 4.0)

**示例**:
```gdscript
player.make_noise(3.0)  # 发出奔跑级别的噪音
```

### 5.2 藏身相关
```gdscript
func set_hiding(hiding: bool) -> void
```
设置玩家的藏身状态。

**参数**:
- `hiding`: true = 进入藏身状态, false = 离开藏身状态

**效果**:
- 藏身时停止所有移动
- 禁用玩家控制

### 5.3 速度查询
```gdscript
func get_current_speed() -> float
```
获取当前移动速度。

**返回值**: 当前速度 (m/s)

---

## 6. 信号

### 6.1 噪音信号
```gdscript
signal noise_made(noise_level: float, position: Vector3)
```
玩家发出噪音时触发。

**参数**:
- `noise_level`: 噪音等级
- `position`: 噪音发出的世界坐标

### 6.2 体力信号
```gdscript
signal stamina_changed(stamina: float)
```
体力值变化时触发。

**参数**:
- `stamina`: 当前体力值

---

## 7. 输入映射

### 7.1 移动输入
| 动作名 | 默认按键 | 说明 |
|--------|---------|------|
| move_forward | W | 向前移动 |
| move_backward | S | 向后移动 |
| move_left | A | 向左移动 |
| move_right | D | 向右移动 |

### 7.2 动作输入
| 动作名 | 默认按键 | 说明 |
|--------|---------|------|
| run | Shift | 奔跑（按住） |
| crouch | C | 蹲下（切换） |
| jump | Space | 跳跃 |
| interact | E | 交互 |

---

## 8. 物理参数

### 8.1 重力
- 使用项目默认重力设置
- 获取方式: `ProjectSettings.get_setting("physics/3d/default_gravity")`

### 8.2 碰撞
- **碰撞层**: 默认层
- **碰撞形状**: CapsuleShape3D
  - 半径: 0.3m
  - 高度: 1.8m (正常) / 1.0m (蹲下)

---

## 9. 性能优化

### 9.1 噪音发射优化
- 使用计时器控制噪音发射频率
- 避免每帧都发出噪音信号
- 停止移动时立即重置计时器

### 9.2 天花板检测优化
- 仅在蹲下状态时检测
- 使用 `force_shapecast_update()` 确保实时性

---

## 10. 调试支持

### 10.1 调试UI
- 显示体力条
- 显示当前噪音等级
- 显示移动状态（行走/奔跑/蹲下/跳跃）
- 显示是否可以起身

### 10.2 可视化模型
- 使用 CapsuleMesh 作为调试模型
- 材质颜色: 蓝色 (0.2, 0.6, 1.0)

---

## 11. 设计决策

### 11.1 为什么蹲下时不能跳跃？
蹲下时无法跳跃符合恐怖游戏的潜行机制，玩家需要谨慎选择移动方式。

### 11.2 为什么奔跑噪音最频繁？
奔跑是最高风险的移动方式，频繁的噪音增加了被怪物发现的风险，鼓励玩家谨慎使用。

### 11.3 为什么使用平滑过渡？
避免相机突变导致的视觉不适，提升游戏体验。

---

## 12. 未来扩展

### 12.1 计划功能
- [ ] 交互系统（门、物品、藏身处）
- [ ] 道具系统
- [ ] 受伤系统
- [ ] 死亡和重生

### 12.2 可配置参数
- [ ] 鼠标灵敏度设置界面
- [ ] 移动速度调整
- [ ] 体力参数调整

---

## 13. 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-04-26 | 初始实现：基础移动、视角控制 |
| 1.1 | 2026-04-26 | 添加跳跃功能 |
| 1.2 | 2026-04-26 | 添加蹲下系统和平滑过渡 |
| 1.3 | 2026-04-26 | 添加天花板检测 |
| 1.4 | 2026-04-26 | 实现持续噪音系统 |

---

## 14. 参考资料

- [Godot 4.6 官方文档 - CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)
- [游戏设计文档](../游戏设计文档.md)
- [GDScript 风格指南](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
