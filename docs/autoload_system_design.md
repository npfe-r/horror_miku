# 自动加载单例系统设计文档

## 1. 系统概述

### 1.1 基本信息
- **系统名称**: 自动加载单例系统
- **版本**: 1.0
- **更新日期**: 2026-04-29
- **相关文件**:
  - `scripts/autoload/event_bus.gd` - 全局事件总线
  - `scripts/autoload/game_manager.gd` - 游戏流程管理
  - `scripts/autoload/interaction_manager.gd` - 交互系统管理
  - `scripts/autoload/ui_manager.gd` - UI层级管理
  - `scripts/autoload/save_manager.gd` - 存档管理
  - `project.godot` - 自动加载配置

### 1.2 加载配置

所有单例在 `project.godot` 的 `[autoload]` 段中声明，使用星号（`*`）前缀表示在场景加载前初始化：

```gdscript
EventBus             = "*res://scripts/autoload/event_bus.gd"
GameManager          = "*res://scripts/autoload/game_manager.gd"
InteractionManager   = "*res://scripts/autoload/interaction_manager.gd"
UIManager            = "*res://scripts/autoload/ui_manager.gd"
SaveManager          = "*res://scripts/autoload/save_manager.gd"
```

### 1.3 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    AutoLoad 单例层                           │
│                                                             │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────┐  │
│  │  EventBus    │   │ GameManager  │   │ SaveManager    │  │
│  │  (信号总线)   │   │ (流程状态机)  │   │ (存档管理)      │  │
│  └──────┬───────┘   └──────┬───────┘   └──────┬─────────┘  │
│         │                  │                   │            │
│  ┌──────┴──────────────────┴───────────────────┴─────────┐  │
│  │                 InteractionManager                     │  │
│  │              (交互检测与事件分发)                        │  │
│  └────────────────────────┬───────────────────────────────┘  │
│                           │                                  │
│  ┌────────────────────────┴───────────────────────────────┐  │
│  │                     UIManager                          │  │
│  │                  (UI显示层级管理)                        │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.4 通信模式

项目采用**事件驱动架构**：所有跨系统通信通过 `EventBus` 进行，系统间不保存直接引用。发送方通过 `EventBus.signal.emit()` 广播事件，接收方在 `_ready()` 中通过 `EventBus.signal.connect(callback)` 订阅。

```
系统A ──→ EventBus.xxx.emit() ──→ EventBus ──→ EventBus.xxx.connect() ──→ 系统B
                                                                    └──→ 系统C
```

---

## 2. EventBus — 全局信号总线

**文件**: [event_bus.gd](../scripts/autoload/event_bus.gd)

### 2.1 设计原则

- 所有跨系统通信必须通过 EventBus
- 每个信号的参数类型和含义明确定义
- 不传递节点引用，只传递基本数据类型（String, float, Vector3 等）

### 2.2 信号分类

#### 2.2.1 游戏流程

| 信号 | 参数 | 触发时机 |
|------|------|----------|
| `game_started` | — | GameManager.start_game() |
| `game_paused` | paused: bool | GameManager.pause_game() / resume_game() |
| `player_died` | — | GameManager.game_over() |
| `game_won` | — | GameManager.win_game() |

#### 2.2.2 玩家事件

| 信号 | 参数 | 触发时机 |
|------|------|----------|
| `noise_made` | level: float, position: Vector3, max_range: float | 玩家移动/跳跃/落地时 |
| `player_caught` | — | 怪物抓住玩家时 |
| `stamina_changed` | current: float | 体力值变化时 |

#### 2.2.3 怪物事件

| 信号 | 参数 | 触发时机 |
|------|------|----------|
| `monster_state_changed` | state: String | 怪物状态切换时 |
| `monster_detected_player` | position: Vector3 | 怪物发现玩家时 |
| `monster_lost_player` | — | 怪物丢失玩家视野时 |

#### 2.2.4 道具事件

| 信号 | 参数 | 触发时机 |
|------|------|----------|
| `item_picked_up` | item: ItemData, count: int | 拾取物品时 |
| `item_used` | item: ItemData | 使用物品时 |
| `item_equipped` | item: ItemData | 装备物品时 |
| `item_unequipped` | — | 卸下装备时 |
| `inventory_changed` | — | 背包内容变化时 |

#### 2.2.5 交互事件

| 信号 | 参数 | 触发时机 |
|------|------|----------|
| `door_opened` | door_id: String | 门打开时 |
| `mechanism_activated` | mech_id: String | 机关触发时 |
| `hiding_state_changed` | hiding: bool | 躲藏状态变化时 |

#### 2.2.6 提示事件

| 信号 | 参数 | 触发时机 |
|------|------|----------|
| `interaction_prompt_changed` | text: String | 交互提示文本变化时 |

#### 2.2.7 存档事件

| 信号 | 参数 | 触发时机 |
|------|------|----------|
| `game_saved` | — | 保存游戏时 |
| `game_loaded` | — | 加载游戏时 |

### 2.3 信号订阅关系

| 信号 | 监听方 |
|------|--------|
| `noise_made` | MonsterPerception |
| `stamina_changed` | PlayerHUD |
| `interaction_prompt_changed` | PlayerHUD |
| `inventory_changed` | PlayerHUD, InventoryMenu, DebugUI |
| `item_picked_up` | DebugUI |
| `item_equipped` / `item_unequipped` | PlayerHUD |
| `monster_state_changed` | DebugUI |
| `player_caught` | GameManager |

---

## 3. GameManager — 游戏流程管理

**文件**: [game_manager.gd](../scripts/autoload/game_manager.gd)

### 3.1 状态机

```
┌──────────┐
│   MENU   │ (菜单)
└────┬─────┘
     │ start_game()
     ▼
┌──────────┐    pause_game()    ┌──────────┐
│ PLAYING  │ ────────────────── │  PAUSED  │
│ (游戏进行)│ ────────────────── │ (暂停)   │
└────┬─────┘    resume_game()   └──────────┘
     │
     ├── game_over() ────→ GAME_OVER
     └── win_game()  ────→ WON
```

### 3.2 枚举定义

```gdscript
enum State { MENU, PLAYING, PAUSED, GAME_OVER, WON }
```

### 3.3 接口说明

| 方法 | 功能 | 副作用 |
|------|------|--------|
| `start_game()` | 开始游戏 | 捕获鼠标, 发射 `game_started` |
| `pause_game()` | 暂停游戏 | 释放鼠标, 发射 `game_paused(true)` |
| `resume_game()` | 恢复游戏 | 捕获鼠标, 发射 `game_paused(false)` |
| `game_over()` | 游戏结束 | 释放鼠标, 发射 `player_died` |
| `win_game()` | 游戏胜利 | 释放鼠标, 发射 `game_won` |
| `restart_level()` | 重载当前场景 | 调用 `reload_current_scene()` + `start_game()` |
| `get_state()` | 获取当前状态 | 返回 State 枚举值 |

### 3.4 关键实现

```gdscript
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时仍然运行
```

`process_mode = PROCESS_MODE_ALWAYS` 确保 GameManager 在游戏暂停时依然能处理输入。

---

## 4. InteractionManager — 交互系统管理

**文件**: [interaction_manager.gd](../scripts/autoload/interaction_manager.gd)

### 4.1 系统职责

1. 每帧执行射线检测，找到当前可交互对象
2. 管理交互对象的高亮显示和提示文本
3. 在玩家按下交互键时分发交互事件

### 4.2 交互检测流程

```
每帧调用 check_interaction()
│
├─ 获取玩家引用
├─ 获取玩家主相机 (Head/Camera3D)
├─ 计算射线: from = camera.global_position
│             to = from - camera.basis.z × INTERACT_RANGE (2.5m)
├─ PhysicsRayQueryParameters3D.create(from, to)
├─ space_state.intersect_ray(query)
│
├─ 命中对象:
│   ├─ _find_interactable(collider)
│   │   ├─ 是 InteractableObject → 直接返回
│   │   ├─ 是 AnimatableBody3D → 向上遍历找 Door
│   │   └─ 其他 → 向上遍历找有 can_interact + set_highlight 的节点
│   │
│   ├─ 找到可交互对象且 can_interact() == true
│   │   ├─ 与前一个不同:
│   │   │   ├─ 取消旧对象高亮
│   │   │   └─ 应用新对象高亮
│   │   │   └─ 更新提示文本
│   │   └─ 与前一相同: 维持状态
│   │
│   └─ 未找到或不可交互:
│       └─ 取消高亮，清空提示
│
└─ 未命中:
    └─ 取消高亮，清空提示
```

### 4.3 交互执行

```gdscript
func try_interact() -> void:
    if current_interactable and current_interactable.call("can_interact"):
        current_interactable.call("set_highlight", false)
        current_interactable.call("interact")
        current_interactable = null
        EventBus.interaction_prompt_changed.emit("")
```

### 4.4 接口说明

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `set_player(p)` | PlayerController | void | 注册玩家引用 |
| `get_player()` | — | PlayerController | 获取玩家引用 |
| `check_interaction()` | — | void | 每帧射线检测，由 PlayerController 调用 |
| `try_interact()` | — | void | 执行当前可交互对象的交互 |
| `has_interactable()` | — | bool | 是否存在当前可交互对象 |

### 4.5 可交互对象查找算法

```gdscript
func _find_interactable(collider: Object) -> Node:
    # 1. 直接命中 InteractableObject
    if collider is InteractableObject:
        return collider

    # 2. 检查 AnimatableBody3D 父链中的 Door
    if collider is AnimatableBody3D:
        var parent := collider.get_parent()
        while parent:
            if parent is Door:
                return parent
            parent = parent.get_parent()

    # 3. 沿节点树向上查找可交互节点
    var node := collider
    while node:
        if node.has_method("can_interact") and node.has_method("set_highlight"):
            return node
        node = node.get_parent()

    return null
```

### 4.6 常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `INTERACT_RANGE` | 2.5 | 交互检测距离（米） |

---

## 5. UIManager — UI层级管理

**文件**: [ui_manager.gd](../scripts/autoload/ui_manager.gd)

### 5.1 接口说明

| 方法 | 参数 | 说明 |
|------|------|------|
| `register_hud(h)` | Control | 注册 HUD 控件引用 |
| `show_hud()` | — | 显示 HUD |
| `hide_hud()` | — | 隐藏 HUD |
| `show_interaction_prompt(text)` | String | 通过 EventBus 显示交互提示 |
| `hide_interaction_prompt()` | — | 隐藏交互提示 |

### 5.2 关键实现

```gdscript
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func show_interaction_prompt(text: String) -> void:
    EventBus.interaction_prompt_changed.emit(text)

func hide_interaction_prompt() -> void:
    EventBus.interaction_prompt_changed.emit("")
```

交互提示通过 EventBus 广播到 PlayerHUD，实现解耦。

---

## 6. SaveManager — 存档管理

**文件**: [save_manager.gd](../scripts/autoload/save_manager.gd)

### 6.1 当前状态

当前为内存存档骨架实现，文件 I/O 待后续实现。

### 6.2 接口说明

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `save_game(data)` | Dictionary | bool | 保存游戏数据到内存 |
| `load_game()` | — | Dictionary | 从内存加载游戏数据 |
| `has_save()` | — | bool | 检查是否有存档 |
| `delete_save()` | — | void | 清除存档 |

### 6.3 关键实现

```gdscript
var _save_data: Dictionary = {}

func save_game(data: Dictionary) -> bool:
    _save_data = data.duplicate(true)
    EventBus.game_saved.emit()
    return true

func load_game() -> Dictionary:
    EventBus.game_loaded.emit()
    return _save_data.duplicate(true)
```

使用 `duplicate(true)` 进行深拷贝，避免外部修改影响存档数据。

---

## 7. 性能优化

### 7.1 交互检测优化

- 仅在玩家 _physics_process 中调用 `check_interaction()`
- 使用 RayCast3D 替代每帧的 PhysicsRayQuery（简化版）
- `_find_interactable` 的遍历深度有限

### 7.2 单例生命周期

所有单例设置 `process_mode = PROCESS_MODE_ALWAYS`，确保在暂停和场景切换时持续运行。

---

## 8. 扩展指南

### 8.1 添加新的事件信号

1. 在 `EventBus` 中声明新的 `signal`
2. 在发送方通过 `EventBus.new_signal.emit(params)` 发送
3. 在接收方通过 `EventBus.new_signal.connect(callback)` 订阅

### 8.2 添加新的单例

1. 在 `scripts/autoload/` 下创建脚本
2. 在 `project.godot` 的 `[autoload]` 段中添加引用

### 8.3 添加新的可交互对象类型

1. 继承 `InteractableObject` 或实现 `can_interact` / `set_highlight` / `interact` 方法
2. 如使用独立类层次（如 Door），在 `InteractionManager._find_interactable()` 中添加检测分支

---

## 附录

### A. 文件引用索引

| 文件 | 说明 |
|------|------|
| [event_bus.gd](../scripts/autoload/event_bus.gd) | 全局信号总线 |
| [game_manager.gd](../scripts/autoload/game_manager.gd) | 游戏流程管理 |
| [interaction_manager.gd](../scripts/autoload/interaction_manager.gd) | 交互系统管理 |
| [ui_manager.gd](../scripts/autoload/ui_manager.gd) | UI层级管理 |
| [save_manager.gd](../scripts/autoload/save_manager.gd) | 存档管理 |

### B. 文档版本

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-04-29 | 初始版本 |

---

**文档维护**: 游戏开发团队
