# 交互对象系统设计文档

## 1. 系统概述

### 1.1 基本信息
- **系统名称**: 交互对象系统
- **版本**: 1.3
- **更新日期**: 2026-05-04
- **相关文件**:
  - `resources/shaders/stencil_fill.gdshader` - Stencil 标记填充 Shader
  - `resources/shaders/outline_expand.gdshader` - 外扩描边高亮 Shader
  - `scripts/objects/interactable_object.gd` - 可交互对象基类
  - `scripts/objects/highlight_component.gd` - 高亮效果组件
  - `scripts/objects/pickup_item.gd` - 可拾取物品
  - `scripts/objects/door.gd` - 门系统
  - `scripts/objects/hiding_spot.gd` - 藏身处
  - `scripts/objects/switch.gd` - 开关机关
  - `scenes/objects/*.tscn` - 对应场景文件
  - `scripts/autoload/interaction_manager.gd` - 交互管理器

### 1.2 类继承体系

```
AnimatableBody3D
└── InteractableObject (基类)
    ├── PickupItem (可拾取物品)
    ├── HidingSpot (藏身处)
    └── Switch (开关机关)

Node3D
└── Door (门系统) — 独立实现，不继承 InteractableObject

RefCounted
└── HighlightComponent (高亮组件) — 纯逻辑复用组件
```

### 1.3 交互架构

```
InteractionManager (Autoload)
│
├─ 每帧射线检测 → 找到可交互对象
│   ├─ InteractableObject 子类
│   ├─ Door (独立检测)
│   └─ 其他实现了 can_interact + set_highlight 的节点
│
├─ 高亮管理 → HighlightComponent
│   └─ 采用 Stencil Buffer 方案：先在原始物体上写入 Stencil 标记，再在外扩 Mesh 中只渲染 Stencil 不匹配的区域，解决转角间隙问题
│
└─ 交互分发 → 调用对象的 interact() 方法
    ├─ PickupItem → 添加到背包
    ├─ HidingSpot → 进入/离开躲藏
    ├─ Door → 开/关/上锁逻辑
    └─ Switch → 切换状态 + 触发连接对象
```

---

## 2. InteractableObject — 可交互对象基类

**类名**: InteractableObject
**继承**: AnimatableBody3D
**文件**: [interactable_object.gd](../scripts/objects/interactable_object.gd)

### 2.1 导出变量

| 变量名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `interaction_text` | String | "交互" | 交互提示文本 |
| `highlight_color` | Color | (1.0, 1.0, 0.5, 1.0) | 高亮颜色（淡黄色）|
| `is_enabled` | bool | true | 是否启用交互 |

### 2.2 内部变量

```gdscript
var highlight: HighlightComponent = null       # 高亮组件实例
var mesh_instances: Array[MeshInstance3D] = []  # 缓存的所有 MeshInstance3D
```

### 2.3 初始化

```gdscript
func _ready() -> void:
    highlight = HighlightComponent.new()
    _find_mesh_instances()

func _find_mesh_instances() -> void:
    mesh_instances.clear()
    for child in get_children():
        if child is MeshInstance3D:
            mesh_instances.append(child)
        for subchild in child.get_children():
            if subchild is MeshInstance3D:
                mesh_instances.append(subchild)
```

递归查找子节点中的所有 `MeshInstance3D`，深度限制为 2 层。

### 2.4 方法

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `can_interact()` | — | bool | 返回 `is_enabled` |
| `get_interaction_text()` | — | String | 返回 `interaction_text` |
| `interact()` | — | void | 虚方法，子类必须重写 |
| `set_highlight(on)` | bool | void | 应用/移除高亮 |
| `enable()` | — | void | 启用交互 |
| `disable()` | — | void | 禁用交互并移除高亮 |

---

## 3. HighlightComponent — 高亮组件

**类名**: HighlightComponent
**继承**: RefCounted
**文件**: [highlight_component.gd](../scripts/objects/highlight_component.gd)

### 3.1 设计说明

`RefCounted` 类型，非 Node，不参与场景树。每个 `InteractableObject` 持有自己的 `HighlightComponent` 实例。

高亮实现采用 **Stencil Buffer 背面外扩方案**。该方案通过两遍绘制解决纯法线外扩在转角处不连续的问题：

1. **Pass 1（Stencil 标记）**：在原始 Mesh 上叠加一个不可见的 Stencil 填充材质，将物体轮廓写入 Stencil Buffer
2. **Pass 2（外扩检测）**：外扩 Mesh 使用 Stencil 测试条件 `COMPARE_OP_NOT_EQUAL`，仅渲染 **Stencil 值不匹配**的区域（即原始物体轮廓之外）

这确保了即使法线外扩在转角处产生间隙，描边也只出现在原始物体边界之外，形成视觉连续的轮廓。

### 3.2 技术原理

```
GPU 渲染管线（单帧内两遍绘制）:

                    ┌─── Stencil Buffer ───┐
                    │ 初始值: 0             │
                    └───────────────────────┘

Pass 1 — Stencil 标记（原始 Mesh 不可见叠加层）
  Mesh: 原始 Mesh（共享引用，不修改原始材质）
  Shader: stencil_fill.gdshader
    → fragment(): ALPHA = 0.0（不可见）
    → Material.stencil_write_value = 1  ★ 写入 Stencil = 1
    → 结果：原始物体所在像素的 Stencil 值变为 1

                    ┌─── Stencil Buffer ───┐
                    │ 物体区域: 1           │
                    │ 其他区域: 0           │
                    └───────────────────────┘

Pass 2 — 外扩描边（外扩 Mesh，背面渲染 + Stencil 测试）
  Mesh: 外扩副本（顶点沿法线扩展）
  Shader: outline_expand.gdshader
    → vertex(): VERTEX += NORMAL * outline_width  ★ 顶点外扩
    → render_mode: cull_front                     ★ 仅渲染背面
    → Material.stencil_test_value = 1
    → Material.stencil_test_op = NOT_EQUAL        ★ 只在 Stencil != 1 区域绘制
    → 结果：原始物体外扩的背面区域中，只有超出原始轮廓的部分被渲染
```

**解决转角间隙的原理**：

```
法线外扩转角（无 Stencil）         +    Stencil Buffer 标记        =   最终渲染结果
                                      ┌──────────┐
    ┌────────┐                        │ Stencil=1 │                ┌────────┐
    │  正    │   ← 间隙(无三角形)     │  (原始)   │                │  正    │
    │  面    │                        │           │                │  面    │
    └────────┘                        │           │                └──┄┄┄┄┄┄┤
   ↙        ↘                         │           │                     ↙  ↘
 ┌─┐        ┌─┐                      │           │                ┌─┐    ┌─┐
 │背│        │背│  ← 外扩背面       └──────────┘                │背│    │背│
 │面│        │面│  被间隙割裂                                   │面│    │面│
 └─┘        └─┘                                               └─┘    └─┘
                                                                 ▲     ▲
                                                         Stencil 测试裁剪
                                                         只保留外部区域
```

关键区别：
- **纯法线外扩**：转角处的顶点沿平均法线移动，相邻三角面分离产生间隙
- **Stencil Buffer 方案**：间隙处的 Stencil 值仍为 0（非原始物体），外扩 Mesh 在此处被 Stencil 测试通过的区域形成连续轮廓，间隙视觉上消失

### 3.3 Shader

#### stencil_fill.gdshader — Stencil 标记

**文件**: [stencil_fill.gdshader](../resources/shaders/stencil_fill.gdshader)

```glsl
shader_type spatial;
render_mode blend_mix, unshaded;

void fragment() {
    ALBEDO = vec3(0.0);
    ALPHA = 0.0;
}
```

| 行 | 说明 |
|----|------|
| `blend_mix, unshaded` | 非光照混合模式，保证渲染通过且不写入可见颜色 |
| `ALPHA = 0.0` | 完全透明，不产生可见像素 |
| Stencil 写入 | 通过 Material 属性 `stencil_write_value = 1` 在 GDScript 中配置 |

#### outline_expand.gdshader — 外扩描边

**文件**: [outline_expand.gdshader](../resources/shaders/outline_expand.gdshader)

```glsl
shader_type spatial;
render_mode blend_mix, unshaded, cull_front, depth_draw_always;

uniform vec4 outline_color: source_color = vec4(1.0, 1.0, 0.5, 1.0);
uniform float outline_width: hint_range(0.0, 0.5) = 0.06;

void vertex() {
    VERTEX += NORMAL * outline_width;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
```

**Shader 参数**：

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `outline_color` | vec4 | (1.0, 1.0, 0.5, 1.0) | 描边颜色 + 透明度（淡黄色） |
| `outline_width` | float | 0.06 | 描边宽度（0~0.5，值越大描边越宽） |

### 3.4 组件实现

```gdscript
const STENCIL_FILL_SHADER: String = "res://resources/shaders/stencil_fill.gdshader"
const OUTLINE_EXPAND_SHADER: String = "res://resources/shaders/outline_expand.gdshader"
const STENCIL_VALUE: int = 1

var _is_highlighted: bool = false
var _fill_material: ShaderMaterial = null
var _outline_material: ShaderMaterial = null
var _outline_nodes: Array[MeshInstance3D] = []
var _original_meshes: Array[MeshInstance3D] = []

func _init() -> void:
    _fill_material = ShaderMaterial.new()
    var fill_shader: Shader = load(STENCIL_FILL_SHADER)
    if fill_shader:
        _fill_material.shader = fill_shader
    _fill_material.render_priority = 1
    _fill_material.stencil_write_value = STENCIL_VALUE

    _outline_material = ShaderMaterial.new()
    var outline_shader: Shader = load(OUTLINE_EXPAND_SHADER)
    if outline_shader:
        _outline_material.shader = outline_shader
    _outline_material.stencil_test_value = STENCIL_VALUE
    _outline_material.stencil_test_op = RenderingServer.COMPARE_OP_NOT_EQUAL

func apply(mesh_instances: Array[MeshInstance3D], color: Color) -> void:
    if _is_highlighted:
        return
    _is_highlighted = true
    _outline_material.set_shader_parameter("outline_color", color)

    for mesh in mesh_instances:
        if not is_instance_valid(mesh) or not mesh.mesh:
            continue

        # Pass 1: Stencil 标记 — 在原始 Mesh 上叠加不可见的填充材质
        mesh.material_overlay = _fill_material
        _original_meshes.append(mesh)

        # Pass 2: 外扩描边 — 创建外扩副本 Mesh，仅渲染 Stencil 不匹配区域
        var outline_mesh := MeshInstance3D.new()
        outline_mesh.name = mesh.name + "_outline"
        outline_mesh.mesh = mesh.mesh
        outline_mesh.material_overlay = _outline_material
        outline_mesh.transform = Transform3D.IDENTITY
        mesh.add_child(outline_mesh)
        _outline_nodes.append(outline_mesh)

func remove(mesh_instances: Array[MeshInstance3D]) -> void:
    if not _is_highlighted:
        return
    _is_highlighted = false

    for node in _outline_nodes:
        if is_instance_valid(node):
            node.queue_free()
    _outline_nodes.clear()

    for mesh in _original_meshes:
        if is_instance_valid(mesh):
            mesh.material_overlay = null
    _original_meshes.clear()
```

**关键点**：
- 外扩 Mesh **共享**原始 Mesh 的网格数据（`outline_mesh.mesh = mesh.mesh`），不复制顶点，仅通过 Shader 在 GPU 上实现外扩
- Stencil 填充材质通过 `material_overlay` 叠加在原始 Mesh 上，不可见，仅写入 Stencil
- 外扩 Mesh 作为原始 Mesh 的**子节点**，自动同步所有变换
- `render_priority = 1` 确保 Stencil 填充在透明通道中**先于**外扩 Mesh 渲染（写入 Stencil 后再读取）
- 移除高亮时同时清理外扩节点和原始 Mesh 上的 `material_overlay`

### 3.5 方法

| 方法 | 说明 |
|------|------|
| `is_highlighted()` | 检查当前是否高亮 |
| `apply(mesh_instances, color)` | 应用 Stencil 外扩描边高亮 |
| `remove(mesh_instances)` | 移除高亮，清理外扩节点和 Stencil 标记 |

---

## 4. PickupItem — 可拾取物品

**类名**: PickupItem
**继承**: InteractableObject
**文件**: [pickup_item.gd](../scripts/objects/pickup_item.gd)
**场景**: [pickup_item.tscn](../scenes/objects/pickup_item.tscn)

### 4.1 导出变量

| 变量名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `item_data` | ItemData | null | 要拾取的道具数据资源 |
| `pickup_count` | int | 1 | 拾取数量 |

### 4.2 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `item_picked_up` | item: ItemData, count: int | 物品被拾取时触发 |

### 4.3 交互流程

```gdscript
func _ready() -> void:
    super._ready()
    if item_data:
        interaction_text = "拾取 " + item_data.item_name
    else:
        interaction_text = "拾取物品"

func interact() -> void:
    var player := _get_player()
    var success = player.pickup_item(item_data, pickup_count)
    if success:
        emit_signal("item_picked_up", item_data, pickup_count)
        queue_free()    # 拾取后销毁
    else:
        print("背包已满")
```

### 4.4 获取玩家

```gdscript
func _get_player() -> PlayerController:
    # 优先通过 InteractionManager 获取
    var im := get_node_or_null("/root/InteractionManager")
    if im and im.has_method("get_player"):
        return im.call("get_player")
    # 备选: 从组查找
    var player := get_tree().get_first_node_in_group("player")
    if player is PlayerController:
        return player
    return null
```

### 4.5 辅助方法

```gdscript
func get_item_info() -> Dictionary
```

返回物品信息的字典（包括 id, name, description, type, count），供 UI 或其他系统使用。

---

## 5. Door — 门系统

**类名**: Door
**继承**: Node3D
**文件**: [door.gd](../scripts/objects/door.gd)
**场景**: [door.tscn](../scenes/objects/door.tscn)

### 5.1 设计说明

Door 不继承 `InteractableObject`，而是独立实现。其碰撞体为子节点 `AnimatableBody3D`，`InteractionManager._find_interactable()` 中通过检测 `AnimatableBody3D` 并向上遍历父节点找到 Door。

### 5.2 场景节点结构

```
Door (Node3D)
├── Pivot (Node3D)                    # 旋转轴心
│   └── DoorBody (AnimatableBody3D)   # 门的物理碰撞体
│       └── DoorMesh (MeshInstance3D) # 门的模型
├── 可选: CollisionShape3D            # 门框碰撞
```

### 5.3 导出变量

| 变量名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `is_locked` | bool | false | 是否上锁 |
| `open_speed` | float | 5.0 | 开门/关门动画速度 |
| `noise_level` | float | 2.0 | 开门时产生的噪音等级 |
| `interaction_text` | String | "开门" | 交互提示文本 |
| `highlight_color` | Color | (1,1,0.5,1) | 高亮颜色 |
| `is_enabled` | bool | true | 是否可交互 |

### 5.4 状态变量

```gdscript
var is_open: bool = false       # 门是否处于打开状态
var is_moving: bool = false     # 门是否正在旋转动画中
var _target_rotation: float = 0.0  # 目标旋转角度
var highlight: HighlightComponent = null  # 高亮组件
```

### 5.5 行为逻辑

#### 5.5.1 交互入口

```gdscript
func interact() -> void:
    if is_locked:
        print("门被锁住了！")
        return

    if is_moving:
        # 正在移动中，反向操作
        if is_open:
            _target_rotation = 0.0      # 改为关门
        else:
            _target_rotation = -deg_to_rad(90.0)  # 改为开门
        return

    is_moving = true
    if is_open:
        _close_door()
    else:
        _open_door()
```

**重要**: 门正在旋转时再次交互，会立即反向旋转。这允许玩家在门开到一半时反悔关门。

#### 5.5.2 开门/关门

```gdscript
func _open_door() -> void:
    is_open = true
    _target_rotation = -deg_to_rad(90.0)  # 绕 Y 轴旋转 -90°
    interaction_text = "关门"

func _close_door() -> void:
    is_open = false
    _target_rotation = 0.0               # 回到初始位置
    interaction_text = "开门"
```

#### 5.5.3 旋转动画

```gdscript
func _process(delta: float) -> void:
    if not is_moving or not pivot:
        return

    var current_rotation: float = pivot.rotation.y
    var new_rotation: float = lerpf(current_rotation, _target_rotation, open_speed * delta)

    if abs(new_rotation - _target_rotation) < 0.01:
        new_rotation = _target_rotation
        is_moving = false

    pivot.rotation.y = new_rotation
```

使用 `lerpf()` 进行平滑插值，`open_speed` 控制速度。

#### 5.5.4 高亮

```gdscript
func set_highlight(on: bool) -> void:
    if not door_mesh:
        return
    var meshes: Array[MeshInstance3D] = [door_mesh]
    if on:
        highlight.apply(meshes, highlight_color)
    else:
        highlight.remove(meshes)
```

### 5.6 公开方法

| 方法 | 说明 |
|------|------|
| `can_interact()` | 返回 is_enabled |
| `get_interaction_text()` | 返回 interaction_text |
| `interact()` | 执行开门/关门 |
| `set_highlight(on)` | 应用/移除高亮 |
| `unlock()` | 解锁门 |
| `lock()` | 锁门 |
| `enable()` / `disable()` | 启用/禁用交互 |

---

## 6. HidingSpot — 藏身处

**类名**: HidingSpot
**继承**: InteractableObject
**文件**: [hiding_spot.gd](../scripts/objects/hiding_spot.gd)

### 6.1 导出变量

| 变量名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `discovery_chance` | float | 0.3 | 被怪物发现的基础概率 |
| `can_observe` | bool | false | 能否观察外部情况 |

### 6.2 状态变量

```gdscript
var is_occupied: bool = false  # 是否被玩家占据
```

### 6.3 交互流程

```gdscript
func _ready() -> void:
    super._ready()
    interaction_text = "躲藏"

func interact() -> void:
    if is_occupied:
        _exit_hiding()
    else:
        _enter_hiding()

func _enter_hiding() -> void:
    is_occupied = true
    interaction_text = "离开"
    var player := InteractionManager.get_player()
    if player:
        player.set_hiding(true)
    EventBus.hiding_state_changed.emit(true)

func _exit_hiding() -> void:
    is_occupied = false
    interaction_text = "躲藏"
    var player := InteractionManager.get_player()
    if player:
        player.set_hiding(false)
    EventBus.hiding_state_changed.emit(false)
```

玩家进入藏身处后：
- `PlayerController.set_hiding(true)` → `velocity = Vector3.ZERO`，每帧 `_physics_process` 跳过移动
- 通过 `EventBus.hiding_state_changed` 通知 UI 和其他系统

---

## 7. Switch — 开关机关

**类名**: Switch
**继承**: InteractableObject
**文件**: [switch.gd](../scripts/objects/switch.gd)
**场景**: [switch.tscn](../scenes/objects/switch.tscn)

### 7.1 导出变量

| 变量名 | 类型 | 说明 |
|--------|------|------|
| `is_on` | bool | 开关当前状态 |
| `toggle_objects` | Array[NodePath] | 开关控制的场景节点列表 |

### 7.2 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `switch_toggled` | is_on: bool | 开关状态变化时触发 |

### 7.3 交互流程

```gdscript
func _ready() -> void:
    super._ready()
    interaction_text = "打开开关" if not is_on else "关闭开关"
    _update_visual()

func interact() -> void:
    is_on = not is_on
    interaction_text = "打开开关" if not is_on else "关闭开关"
    _update_visual()
    emit_signal("switch_toggled", is_on)

    for node_path in toggle_objects:
        var node := get_node_or_null(node_path)
        if node:
            if node.has_method("enable"):
                node.enable() if is_on else node.disable()
            elif "visible" in node:
                node.visible = is_on
```

### 7.4 视觉反馈

```gdscript
func _update_visual() -> void:
    var material := StandardMaterial3D.new()
    if is_on:
        material.albedo_color = Color(0.2, 1.0, 0.2)    # 绿色：开启
    else:
        material.albedo_color = Color(0.5, 0.5, 0.5)    # 灰色：关闭
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    switch_mesh.set_surface_override_material(0, material)
```

### 7.5 控制的节点

Switch 通过 `toggle_objects` 控制其他节点，支持两种模式：
1. **方法调用**: 节点有 `enable()` 方法 → 开时调用 `enable()`，关时调用 `disable()`
2. **可见性控制**: 节点有 `visible` 属性 → 设置 `visible = is_on`

典型用途：控制门的开关（调用 `Door.enable()/disable()`）、控制灯光（设置 `visible`）等。

---

## 8. 交互数据流

### 8.1 完整交互流程

```
玩家朝向可交互物体
│
├─ PlayerController._physics_process()
│   └─ _check_interaction()
│       └─ InteractionManager.check_interaction()
│           ├─ 发射射线 (PhysicsRayQuery)
│           ├─ 碰撞检测
│           │   ├─ InteractableObject → 直接使用
│           │   ├─ AnimatableBody3D → 查找 Door
│           │   └─ 任意节点 → 向上遍历查找
│           ├─ 找到 → set_highlight(true) + 更新提示
│           └─ 未找到 → set_highlight(false) + 清空提示
│
玩家按下 E 键
│
├─ PlayerController._handle_interaction_input()
│   └─ InteractionManager.try_interact()
│       ├─ set_highlight(false)
│       ├─ current_interactable.interact()
│       │   ├─ PickupItem → 拾取
│       │   ├─ Door → 开门/关门
│       │   ├─ HidingSpot → 躲藏/离开
│       │   └─ Switch → 切换
│       ├─ 清空 current_interactable
│       └─ 清空交互提示
```

---

## 9. 扩展指南

### 9.1 添加新的可交互对象

1. 继承 `InteractableObject`（或直接继承 `Node3D`+ 实现接口方法）
2. 重写 `interact()`、`can_interact()`、`get_interaction_text()`
3. 实现 `set_highlight(on)`（使用 `HighlightComponent`）
4. 如使用独立类层次（不继承 `InteractableObject`），需在 `InteractionManager._find_interactable()` 中添加检测逻辑

### 9.2 添加新的高亮效果

通过创建新的 Shader 并修改 `HighlightComponent` 来实现不同的高亮效果：

1. **创建 Stencil 填充 Shader**（参考 `stencil_fill.gdshader`）— 用于在原始 Mesh 上写入 Stencil 标记
2. **创建外扩描边 Shader**（参考 `outline_expand.gdshader`）— 用于外扩 Mesh 的描边渲染
3. **替换材质创建逻辑**：修改 `_init()` 中的 Shader 加载路径
4. **调整 Stencil 参数**：设置 `stencil_write_value`、`stencil_test_value`、`stencil_test_op`

Shader 需要满足的条件：
- Stencil 填充 Shader：`blend_mix, unshaded`，`ALPHA = 0.0` 不可见
- 外扩描边 Shader：`render_mode cull_front`，`vertex()` 中做顶点外扩
- `render_mode unshaded` — 非光照模式，描边颜色不受光照影响

---

## 附录

### A. 场景文件引用

| 场景文件 | 对应的类 |
|---------|---------|
| [pickup_item.tscn](../scenes/objects/pickup_item.tscn) | PickupItem |
| [door.tscn](../scenes/objects/door.tscn) | Door |
| [switch.tscn](../scenes/objects/switch.tscn) | Switch |

### B. 文件引用索引

| 文件 | 说明 |
|------|------|
| [resources/shaders/stencil_fill.gdshader](../resources/shaders/stencil_fill.gdshader) | Stencil 标记填充 Shader |
| [resources/shaders/outline_expand.gdshader](../resources/shaders/outline_expand.gdshader) | 外扩描边高亮 Shader |
| [interactable_object.gd](../scripts/objects/interactable_object.gd) | 可交互对象基类 |
| [highlight_component.gd](../scripts/objects/highlight_component.gd) | 高亮组件 |
| [pickup_item.gd](../scripts/objects/pickup_item.gd) | 可拾取物品 |
| [door.gd](../scripts/objects/door.gd) | 门系统 |
| [hiding_spot.gd](../scripts/objects/hiding_spot.gd) | 藏身处 |
| [switch.gd](../scripts/objects/switch.gd) | 开关机关 |
| [interaction_manager.gd](../scripts/autoload/interaction_manager.gd) | 交互管理器 |

### C. 文档版本

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-04-29 | 初始版本 |
| 1.1 | 2026-05-04 | 高亮系统重写：使用 Shader + material_overlay 替代 StandardMaterial3D 替换方案，新增 Fresnel 描边效果 |
| 1.2 | 2026-05-04 | 高亮系统重写：改为背面外扩描边方案，外扩 Mesh 通过顶点沿法线扩展 + cull_front 渲染背面形成轮廓外壳 |
| 1.3 | 2026-05-04 | 高亮系统重写：改为 Stencil Buffer 外扩方案，通过 stencil_fill 材质写入标记 + 外扩 Mesh 中 Stencil 测试 NOT_EQUAL，解决转角处法线外扩不连续的问题 |

---

**文档维护**: 游戏开发团队
