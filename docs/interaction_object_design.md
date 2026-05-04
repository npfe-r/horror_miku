# 交互对象系统设计文档

## 1. 系统概述

### 1.1 基本信息
- **系统名称**: 交互对象系统
- **版本**: 1.5
- **更新日期**: 2026-05-04
- **相关文件**:
  - `resources/shaders/highlight_depth_encode.gdshader` - 深度编码 Shader
  - `resources/shaders/highlight_composite.gdshader` - 合成 Shader（内发光+描边）
  - `scripts/objects/interactable_object.gd` - 可交互对象基类
  - `scripts/objects/highlight_component.gd` - 高亮组件（图层管理）
  - `scripts/autoload/highlight_manager.gd` - 高亮管理器（Autoload）
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
HighlightManager (Autoload)
│
├─ SubViewport (仅渲染 1024 层)
│   ├─ transparent_bg = true（无高亮物体处透明）
│   └─ 跟随玩家相机变换、FOV、视口大小
│
├─ 玩家相机子节点: MeshInstance3D (QuadMesh) + composite Shader
│   ├─ 读取主场景 screen_tex
│   ├─ 读取 SubViewport 的 highlighted_tex
│   ├─ hl.a > 0 → 内发光检测（无深度编码，纯 Alpha 判断）
│   └─ 邻域采样 → 描边检测（膨胀算法）
│
InteractionManager (Autoload)
│
├─ 每帧射线检测 → 找到可交互对象
│   ├─ InteractableObject 子类
│   ├─ Door (独立检测)
│   └─ 其他实现了 can_interact + set_highlight 的节点
│
├─ 高亮管理 → HighlightComponent
│   └─ 调用 set_layer_mask_value(layer 1024) 启用/禁用高亮
│       └─ 高亮管理器自动渲染并合成后处理效果
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

## 3. 高亮系统

高亮系统由三层组成：

| 层级 | 组件 | 职责 |
|------|------|------|
| 应用层 | `HighlightComponent` | 每个可交互对象持有，管理 Mesh 的渲染图层 |
| 管理/渲染层 | `HighlightManager` (Autoload) | 管理 SubViewport + 合成效果 |
| Shader 层 | `highlight_composite.gdshader` | GPU 后处理内发光 + 描边 |

---

### 3.1 HighlightComponent — 高亮组件

**类名**: HighlightComponent
**继承**: RefCounted
**文件**: [highlight_component.gd](../scripts/objects/highlight_component.gd)

#### 3.1.1 设计说明

`RefCounted` 类型，非 Node，不参与场景树。每个 `InteractableObject` 持有自己的 `HighlightComponent` 实例。

**职责**：管理渲染图层。当物体被高亮时，将 Mesh 的渲染图层添加到 1024 层；取消高亮时恢复原始图层。

#### 3.1.2 组件实现

```gdscript
var _is_highlighted: bool = false
var _highlight_layer_bit: int = -1
var _affected_meshes: Array[MeshInstance3D] = []
var _original_layers: Dictionary = {}

func _init() -> void:
    var hm := Engine.get_main_loop().root.get_node_or_null("/root/HighlightManager")
    _highlight_layer_bit = hm.get_highlight_layer_bit() if hm else 10

func apply(mesh_instances: Array[MeshInstance3D], _color: Color) -> void:
    if _is_highlighted:
        return
    _is_highlighted = true

    for mesh in mesh_instances:
        if not is_instance_valid(mesh):
            continue
        _affected_meshes.append(mesh)
        if not _original_layers.has(mesh):
            _original_layers[mesh] = mesh.layers
        mesh.set_layer_mask_value(_highlight_layer_bit + 1, true)

func remove(_mesh_instances: Array[MeshInstance3D]) -> void:
    if not _is_highlighted:
        return
    _is_highlighted = false

    for mesh in _affected_meshes:
        if not is_instance_valid(mesh):
            continue
        if _original_layers.has(mesh):
            mesh.layers = _original_layers[mesh]
        else:
            mesh.set_layer_mask_value(_highlight_layer_bit + 1, false)

    _affected_meshes.clear()
    _original_layers.clear()
```

**关键点**：
- 使用 `set_layer_mask_value(index, bool)` 操作渲染图层，不破坏原有的图层设置
- 通过 `_original_layers` 字典保存每个 Mesh 的原始图层，确保完全恢复
- `color` 参数保留签名兼容性，实际颜色由后处理 Shader 控制（通过 `HighlightManager` 配置）

#### 3.1.3 方法

| 方法 | 说明 |
|------|------|
| `is_highlighted()` | 检查当前是否高亮 |
| `apply(mesh_instances, color)` | 启用高亮（将 mesh 加入 1024 渲染层） |
| `remove(mesh_instances)` | 移除高亮（恢复原始渲染层） |

---

### 3.2 HighlightManager — 高亮管理器

**类名**: HighlightManager
**继承**: Node
**文件**: [highlight_manager.gd](../scripts/autoload/highlight_manager.gd)

#### 3.2.1 设计说明

`HighlightManager` 是 Autoload 单例，负责整个高亮效果的视口管理和后处理合成。使用 **SubViewport 多通道渲染** 方案：

1. **高亮通道（Highlight Pass）**：一个独立的 SubViewport 仅渲染 1024 层的物体。`transparent_bg = true`，无高亮物体处保持透明
2. **合成通道（Composite Pass）**：一个全屏 QuadMesh（挂载在玩家相机下）读取主场景颜色以及 SubViewport 纹理，通过 Alpha 通道检测高亮区域，再通过邻域采样检测描边

#### 3.2.2 场景节点结构

```
HighlightManager (Autoload, 不可见)
 │
 ├── HighlightViewport (SubViewport)
 │   ├── size = 视口大小, transparent_bg = true
 │   └── render_target_update_mode = UPDATE_ALWAYS
 │       │
 │       └── HighlightCamera (Camera3D)
 │           ├── cull_mask = 1024 (仅渲染高亮层)
 │           ├── environment = null (无天空/环境)
 │           └── 每帧同步玩家相机的 Transform + FOV
 │
 玩家相机 (Camera3D, 玩家场景中)
 │
 └── HighlightCompositeQuad (MeshInstance3D)
     ├── mesh = QuadMesh (size 2x2)
     ├── extra_cull_margin = 16384
     ├── ignore_occlusion_culling = true
     └── composite Shader
         ├─ 读取 screen_tex (主场景)
         ├─ 读取 highlighted_tex (SubViewport)
         ├─ hl.a > 0 → 内发光检测
```

#### 3.2.3 组件实现
 
 ```gdscript
 const HIGHLIGHT_LAYER_BIT: int = 10
 
 var _highlight_viewport: SubViewport = null
 var _viewport_camera: Camera3D = null
 var _composite_quad: MeshInstance3D = null
 
 func _ready() -> void:
     _setup_highlight_viewport()
 
 func _setup_highlight_viewport() -> void:
     _highlight_viewport = SubViewport.new()
     _highlight_viewport.size = get_tree().root.size
     _highlight_viewport.transparent_bg = true
     _highlight_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
     add_child(_highlight_viewport)
 
     _viewport_camera = Camera3D.new()
     _viewport_camera.cull_mask = 1 << HIGHLIGHT_LAYER_BIT
     _viewport_camera.environment = null
     _highlight_viewport.add_child(_viewport_camera)
 
 func get_highlight_layer_bit() -> int:
     return HIGHLIGHT_LAYER_BIT
 
 func _process(_delta: float) -> void:
     if not _composite_quad:
         _try_setup_composite_quad()
     _sync_camera()
 
 func _try_setup_composite_quad() -> void:
     var player := InteractionManager.get_player()
     if not player: return
     var player_camera := player.camera as Camera3D
     if not player_camera: return
     _setup_composite_quad(player_camera)
 
 func _setup_composite_quad(camera: Camera3D) -> void:
     _composite_quad = MeshInstance3D.new()
     _composite_quad.mesh = QuadMesh.new()
     _composite_quad.mesh.size = Vector2(2.0, 2.0)
     _composite_quad.extra_cull_margin = 16384
     _composite_quad.ignore_occlusion_culling = true
     _composite_material = ShaderMaterial.new()
     _composite_material.shader = load("res://resources/shaders/highlight_composite.gdshader")
     _composite_material.set_shader_parameter("highlighted_tex", _highlight_viewport.get_texture())
     _composite_quad.material_override = _composite_material
     _composite_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
     camera.add_child(_composite_quad)
 
 func _sync_camera() -> void:
     var player := InteractionManager.get_player()
     if not player: return
     var player_camera := player.camera as Camera3D
     if not player_camera or not _viewport_camera: return
     _viewport_camera.global_transform = player_camera.global_transform
     _viewport_camera.fov = player_camera.fov
     _highlight_viewport.size = get_tree().root.size
 ```
 
 **关键逻辑**：
 - `_ready()` 创建 SubViewport + 相机，直接渲染高亮层物体到透明背景
 - `_process()` 中延迟初始化合成 Quad（需等待玩家相机就绪），每帧同步相机变换
 - `_sync_camera()` 确保 SubViewport 相机的 Transform、FOV、视口大小与主相机完全一致
 - 不进行深度编码，SubViewport 只负责渲染高亮物体的原始外观到透明背景

---

### 3.3 Shader
 
 #### 3.3.1 highlight_composite.gdshader — 合成效果
 
 **文件**: [highlight_composite.gdshader](../resources/shaders/highlight_composite.gdshader)
 
 ```glsl
 shader_type spatial;
 render_mode blend_mix, cull_disabled, unshaded, shadows_disabled, fog_disabled;
 
 uniform int width_outline = 2;
 uniform vec4 color_inner : source_color = vec4(1.0, 1.0, 0.5, 0.25);
 uniform vec4 color_outline : source_color = vec4(1.0, 1.0, 0.5, 1.0);
 uniform sampler2D highlighted_tex : repeat_disable, filter_nearest;
 uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
 
 void vertex() {
     POSITION = vec4(VERTEX.xy, 1.0, 1.0);
 }
 
 void fragment() {
     vec2 suv = SCREEN_UV;
     vec4 ss = texture(screen_tex, suv);
     vec4 hl = texture(highlighted_tex, suv);
 
     bool is_inner = hl.a > 0.001;
     bool is_outline = false;
 
     if (!is_inner) {
         vec2 p = 1.0 / vec2(VIEWPORT_SIZE.xy);
         for (int x = -width_outline; x <= width_outline && !is_outline; ++x) {
             for (int y = -width_outline; y <= width_outline && !is_outline; ++y) {
                 if (y == 0 && x == 0) continue;
                 vec2 n_uv = suv + vec2(-p.x * float(x), -p.y * float(y));
                 if (texture(highlighted_tex, n_uv).a > 0.001) {
                     is_outline = true;
                 }
             }
         }
     }
 
     ss.rgb = mix(ss.rgb, color_inner.rgb, is_inner ? color_inner.a : 0.0);
     ALBEDO = mix(ss.rgb, color_outline.rgb, is_outline ? color_outline.a : 0.0);
 }
 ```
 
 **合成算法**：
 
 ```
 输入:
   主场景 screen_tex
   高亮视口 highlighted_tex（透明背景 + 高亮物体）
 
 内发光检测:
   hl.a > 0.001 → 该像素处有高亮物体
   ★ 不需要深度编码，SubViewport 透明背景处 alpha = 0
 
 描边检测 (在非内部像素上执行):
   对当前像素的 (2*width_outline+1)² 邻域进行采样
   ┌─ 任意邻居的 hl.a > 0.001 → 当前像素标记为描边
   └─ → 形成膨胀描边效果
 
 颜色混合:
   ├─ 内发光: mix(screen, color_inner.rgb, color_inner.a)
   ├─ 描边:   mix(screen, color_outline.rgb, color_outline.a)
   └─ 其他:   保持原样
 ```
 
 **Shader 参数**：
 
 | 参数 | 类型 | 默认值 | 说明 |
 |------|------|--------|------|
 | `width_outline` | int | 2 | 描边采样半径像素数 |
 | `color_inner` | vec4 | (1,1,0.5,0.25) | 内发光颜色（淡黄色，25% 强度） |
 | `color_outline` | vec4 | (1,1,0.5,1) | 描边颜色（淡黄色，100% 不透明） |
 | `highlighted_tex` | sampler2D | — | SubViewport 的高亮物体渲染结果 |
 | `screen_tex` | sampler2D | — | 主场景渲染结果（`hint_screen_texture`） |
 
 #### 3.3.2 与纯法线外扩/Stencil 方案对比

| 对比项 | Fresnel 描边 | 法线外扩 + Stencil | SubViewport 后处理（当前） |
|--------|-------------|-------------------|--------------------------|
| 转角连续性 | 依赖视角，凹面失效 | 中等（Stencil 裁剪） | ★ 最佳（屏幕空间邻域检测） |
| 内发光 | 无 | 无 | ★ 支持（透明度可调） |
| 性能 | ★ 最佳 | 中等 | 中等（额外一次视口渲染） |
| 对场景无侵入 | ★ 是 | 是（外扩 Mesh 子节点） | ★ 是（仅改渲染层位） |
| 描边一致性 | 边缘薄中间厚 | ★ 均匀 | ★ 均匀 |
| 多物体同时高亮 | 支持 | 支持 | ★ 优化（单次视口渲染服务所有物体） |
| 实现复杂度 | ★ 简单 | 中等 | 较复杂（需管理 SubViewport） |

---

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

高亮效果由合成 Shader `highlight_composite.gdshader` 控制，无需修改代码即可调整：

**调整颜色/强度**：修改 `color_inner` 和 `color_outline` 参数的默认值，或在 `HighlightManager` 中通过 `set_shader_parameter()` 动态设置。

**修改描边宽度**：调整 `width_outline` 参数（像素半径）。

**创建全新的后处理效果**：
1. **创建新的深度编码 Shader**（参考 `highlight_depth_encode.gdshader`）
2. **创建新的合成 Shader**（参考 `highlight_composite.gdshader`）
3. **修改 `HighlightManager`**：替换 Shader 加载路径和参数传递

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
| [resources/shaders/highlight_composite.gdshader](../resources/shaders/highlight_composite.gdshader) | 合成 Shader（内发光 + 描边后处理） |
| [interactable_object.gd](../scripts/objects/interactable_object.gd) | 可交互对象基类 |
| [highlight_component.gd](../scripts/objects/highlight_component.gd) | 高亮组件（渲染图层管理） |
| [highlight_manager.gd](../scripts/autoload/highlight_manager.gd) | 高亮管理器（Autoload，SubViewport + 合成） |
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
| 1.2 | 2026-05-04 | 高亮系统重写：改为背面外扩描边方案，外扩 Mesh 顶点沿法线扩展 + cull_front |
| 1.3 | 2026-05-04 | 高亮系统重写：改为 Stencil Buffer 外扩方案，解决法线外扩转角不连续问题 |
| 1.4 | 2026-05-04 | 高亮系统重写：参考 higilight 项目，改为 SubViewport 多通道后处理方案，HighlightComponent 简化为图层管理，新增 HighlightManager Autoload 和 composite Shader，支持内发光 + 描边 |
| 1.5 | 2026-05-04 | 修复全屏红黄条纹深度渐变问题：移除深度编码 Shader（highlight_depth_encode.gdshader），改为直接检测 SubViewport 纹理 Alpha 通道，composite Shader 使用 hl.a > 0 判断高亮区域，不再需要深度比较 |

---

**文档维护**: 游戏开发团队
