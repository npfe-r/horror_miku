# 道具与背包系统设计文档

## 1. 系统概述

### 1.1 基本信息
- **系统名称**: 道具与背包系统
- **版本**: 1.0
- **更新日期**: 2026-04-29
- **相关文件**:
  - `scripts/items/item_data.gd` - 道具数据类
  - `scripts/items/item_slot.gd` - 物品槽位类
  - `scripts/items/inventory.gd` - 背包系统
  - `scripts/items/item_effect_manager.gd` - 道具效果管理器
  - `resources/items/*.tres` - 道具数据资源文件

### 1.2 系统架构

```
┌───────────────────────────────────────────────────────────────┐
│                    道具数据层                                  │
│  ItemData (Resource)                                          │
│  ├── resources/items/classroom_key.tres                        │
│  ├── resources/items/first_aid_kit.tres                        │
│  ├── resources/items/flashlight.tres                           │
│  └── resources/items/noise_lure.tres                           │
├───────────────────────────────────────────────────────────────┤
│                    背包逻辑层                                  │
│  Inventory (Node)                                              │
│  ├── slots: Array[ItemSlot] (×8)                              │
│  ├── quick_bar: Array[int] (×4)                               │
│  └── ItemEffectManager (static)                               │
├───────────────────────────────────────────────────────────────┤
│                    玩家交互层                                   │
│  PlayerController                                              │
│  ├── pickup_item()             ← PickupItem                   │
│  ├── equip_item() / unequip_item()                            │
│  ├── use_current_item()                                       │
│  └── EquipmentPoint (模型挂载点)                               │
└───────────────────────────────────────────────────────────────┘
```

---

## 2. ItemData — 道具数据类

**类名**: ItemData
**继承**: Resource
**文件**: [item_data.gd](../scripts/items/item_data.gd)

道具数据以 `.tres` 资源文件形式存储在 `resources/items/` 目录下，可在编辑器中进行可视化编辑和复用。

### 2.1 属性定义

| 属性 | 类型 | 说明 |
|------|------|------|
| `item_id` | String | 唯一标识符，用于逻辑引用 |
| `item_name` | String | 显示名称 |
| `description` | String (multiline) | 描述文本 |
| `icon` | Texture2D | UI 中显示的图标 |
| `item_type` | ItemType (enum) | 道具类型 |
| `max_stack` | int | 最大堆叠数，默认 1 |
| `is_consumable` | bool | 是否消耗品（使用后减少数量） |
| `is_equippable` | bool | 是否可装备（显示 3D 模型） |
| `use_effect` | String | 效果标识符，映射到 ItemEffectManager |
| `model_scene` | PackedScene | 装备时在玩家手中显示的 3D 模型 |

### 2.2 类型枚举

```gdscript
enum ItemType {
    KEY,         # 关键道具（钥匙、门禁卡等）
    CONSUMABLE,  # 消耗品（急救包、电池等）
    SPECIAL,     # 特殊道具（地图、指南针等）
    EQUIPMENT    # 装备（手电筒等）
}
```

### 2.3 方法

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `can_stack_with(other: ItemData)` | bool | 判断能否与另一个物品堆叠（同 item_id 且 max_stack > 1）|
| `get_type_name()` | String | 获取类型中文名（关键道具/消耗品/特殊道具/装备）|
| `use(user: Node)` | bool | 虚方法。子类可重写，返回 true 表示已处理 |

### 2.4 已实现道具

| 资源文件 | item_id | 名称 | 类型 | 堆叠 | 可消耗 | 可装备 | 效果 |
|---------|---------|------|------|------|--------|--------|------|
| classroom_key.tres | classroom_key_001 | 教室钥匙 | KEY | 1 | ✗ | ✗ | key |
| first_aid_kit.tres | first_aid_kit_001 | 急救包 | CONSUMABLE | 5 | ✓ | ✗ | heal |
| flashlight.tres | flashlight_001 | 手电筒 | EQUIPMENT | 1 | ✗ | ✓ | flashlight |
| noise_lure.tres | noise_lure_001 | 噪音诱饵 | CONSUMABLE | 3 | ✓ | ✓ | noise_lure |

### 2.5 道具资源文件格式

以手电筒为例 (`flashlight.tres`)：

```gdscript
[gd_resource type="Resource" script_class="ItemData" format=3]
[ext_resource type="Script" path="res://scripts/items/item_data.gd" id="1"]
[ext_resource type="Texture2D" path="res://icon.svg" id="2"]
[ext_resource type="PackedScene" path="res://resources/models/flashlight_model.tscn" id="3"]

[resource]
script = ExtResource("1")
item_id = "flashlight_001"
item_name = "手电筒"
description = "一个手电筒，可以照亮黑暗的区域。注意：使用时会暴露你的位置！"
icon = ExtResource("2")
item_type = 3  # EQUIPMENT
is_equippable = true
use_effect = "flashlight"
model_scene = ExtResource("3")
```

---

## 3. ItemSlot — 物品槽位

**类名**: ItemSlot
**继承**: Resource
**文件**: [item_slot.gd](../scripts/items/item_slot.gd)

### 3.1 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `item_data` | ItemData | null | 槽位中的物品数据 |
| `count` | int | 0 | 当前数量 |

### 3.2 方法

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `is_empty()` | — | bool | 槽位是否为空 |
| `can_add_amount(amount)` | int | bool | 能否添加指定数量 |
| `add_amount(amount)` | int | int | 添加数量，返回未添加的剩余数 |
| `remove_amount(amount)` | int | int | 移除数量，返回实际移除数 |
| `clear()` | — | void | 清空槽位 |
| `set_item(data, amount)` | ItemData, int | void | 设置物品和数量 |
| `get_free_space()` | — | int | 获取剩余可堆叠空间 |
| `duplicate_slot()` | — | ItemSlot | 复制槽位 |

### 3.3 关键实现

```gdscript
func add_amount(amount: int) -> int:
    var space_available: int = item_data.max_stack - count
    var amount_to_add: int = mini(amount, space_available)
    count += amount_to_add
    return amount - amount_to_add  # 返回未添加的剩余

func remove_amount(amount: int) -> int:
    var amount_removed: int = mini(amount, count)
    count -= amount_removed
    if count <= 0:
        clear()
    return amount_removed
```

---

## 4. Inventory — 背包系统

**类名**: Inventory
**继承**: Node
**文件**: [inventory.gd](../scripts/items/inventory.gd)

### 4.1 核心参数

| 常量 | 值 | 说明 |
|------|-----|------|
| `MAX_SLOTS` | 8 | 背包槽位总数 |
| `QUICK_BAR_SIZE` | 4 | 快捷栏数量 |

### 4.2 数据结构

```gdscript
var slots: Array[ItemSlot] = []           # 8 个槽位
var quick_bar: Array[int] = [-1, -1, -1, -1]  # 快捷栏索引映射 (值 = slots 索引)
var selected_quick_slot: int = 0          # 当前选中的快捷栏索引
```

`quick_bar` 数组存储的是 `slots` 数组的索引。例如 `quick_bar[0] = 2` 表示快捷栏第 1 格对应 `slots[2]` 中的物品。

### 4.3 核心方法

#### 4.3.1 物品添加

```gdscript
func add_item(item: ItemData, amount: int = 1) -> bool

    ├─ _try_stack_existing_item(item, amount)
    │   └─ 遍历所有 slots，找到同 item_id 且未满的槽位进行堆叠
    │
    └─ _try_add_to_empty_slot(item, remaining)
        └─ 遍历所有 slots，找到空槽位放入
```

**返回值**: true 表示至少成功添加了 1 个物品。

#### 4.3.2 物品移除

```gdscript
func remove_item(item_id: String, amount: int = 1) -> bool
```

从后向前遍历槽位，优先移除靠后的物品。需要获取足够数量的物品才会执行移除。

#### 4.3.3 物品使用

```gdscript
func use_item(slot_index: int, user: Node = null) -> bool
    ├─ 获取槽位中的 ItemData
    ├─ ItemEffectManager.use_item(item, user)
    │   └─ 处理效果逻辑
    ├─ 效果成功 + is_consumable → 调用 remove_item(item_id, 1)
    └─ 返回效果是否成功

func use_quick_slot_item(quick_slot_index: int, user: Node = null) -> bool
    └─ 通过 quick_bar 映射到实际槽位，调用 use_item()
```

#### 4.3.4 快捷栏操作

```gdscript
func select_quick_slot(index: int) -> bool          # 选中快捷栏
func set_quick_bar_slot(quick_slot_index, inventory_slot_index) -> bool  # 设置映射
func clear_quick_bar_slot(quick_slot_index) -> bool  # 清除映射
func get_selected_item() -> ItemData                 # 获取选中物品
```

#### 4.3.5 槽位操作

```gdscript
func move_slot(from_index: int, to_index: int) -> bool
    ├─ 目标空 → 移动
    ├─ 同 item_id 且目标未满 → 堆叠
    └─ 不同物品 → 交换

func drop_item(slot_index: int, amount: int = -1) -> Dictionary
    └─ 掉落物品，返回 { item, count }

func split_slot(slot_index: int, amount: int) -> bool
    └─ 拆分堆叠到空槽位
```

#### 4.3.6 查询方法

```gdscript
func get_item_count(item_id: String) -> int    # 获取某物品总数量
func has_item(item_id: String, amount: int) -> bool  # 检查是否有足够数量
func get_item_at_slot(slot_index: int) -> ItemData    # 获取某槽位物品
func find_item_by_id(item_id: String) -> int          # 查找某物品所在槽位索引
func get_all_items() -> Array[ItemData]               # 获取所有物品
func get_empty_slot_count() -> int                    # 获取空格数量
```

#### 4.3.7 序列化

```gdscript
func serialize() -> Dictionary
    └─ 序列化为可存储格式（slots 数组 + quick_bar + selected_quick_slot）

func deserialize(data: Dictionary, item_database: Dictionary) -> void
    └─ 从数据还原背包（需传入道具数据库用于 ItemData 查找）
```

### 4.4 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `item_added` | item: ItemData, count: int | 物品添加时触发 |
| `item_removed` | item_id: String, count: int | 物品移除时触发 |
| `inventory_changed` | — | 背包内容变化时触发 |
| `quick_bar_changed` | slot_index: int | 快捷栏变化时触发 |
| `selected_slot_changed` | slot_index: int | 选中快捷栏变化时触发 |

---

## 5. ItemEffectManager — 道具效果管理器

**类名**: ItemEffectManager
**继承**: RefCounted
**文件**: [item_effect_manager.gd](../scripts/items/item_effect_manager.gd)

### 5.1 设计说明

道具效果管理器采用**静态方法 + 字符串映射**模式。`use_item()` 是唯一入口，它按以下优先级处理：

1. 调用 `item.use(user)` — 子类可在此方法中实现自定义效果
2. 检查 `use_effect` 是否为空 — 空字符串表示无效果但视为成功
3. 根据 `use_effect` 字符串 `match` 到具体效果函数

### 5.2 核心方法

```gdscript
static func use_item(item: ItemData, user: Node) -> bool:
    if not item:
        return false

    # 优先级 1: 物品子类的自定义 use() 方法
    if item.use(user):
        return true

    # 优先级 2: 无效果标识
    if item.use_effect.is_empty():
        return true

    # 优先级 3: 按 use_effect 分发
    match item.use_effect:
        "flashlight":       return _toggle_flashlight(user)
        "noise_lure":       return _spawn_noise_lure(user)
        "flashbang":        return _throw_flashbang(user)
        "heal":             return _heal_player(user)
        "key":              return _use_key(user, item)
        "map":              return _show_map(user)
        "compass":          return _show_compass(user)
        "monster_detector": return _use_monster_detector(user)
        _:                  return false
```

### 5.3 效果实现

所有效果函数通过 `user.has_method("method_name")` 调用玩家身上的方法：

| 效果标识 | 函数 | 调用玩家方法 | 当前状态 |
|---------|------|-------------|---------|
| `flashlight` | `_toggle_flashlight` | `toggle_flashlight()` | 待实现 |
| `noise_lure` | `_spawn_noise_lure` | `spawn_noise_lure()` | 待实现 |
| `flashbang` | `_throw_flashbang` | `throw_flashbang()` | 待实现 |
| `heal` | `_heal_player` | 优先 `heal()`, 失败则直接操作 `stamina` 属性 | 可用 |
| `key` | `_use_key` | 仅打印日志，实际由交互系统处理 | 可用 |
| `map` | `_show_map` | `show_map()` | 待实现 |
| `compass` | `_show_compass` | `show_compass()` | 待实现 |
| `monster_detector` | `_use_monster_detector` | `use_monster_detector()` | 待实现 |

### 5.4 辅助方法

```gdscript
static func get_effect_description(effect_name: String) -> String
    └─ 返回效果的中文描述文本（用于 UI 显示）
```

---

## 6. 快捷栏与装备联动

### 6.1 装备流程

装备逻辑由 `PlayerController` 的 `_auto_equip_from_selected_slot()` 触发：

```
切换快捷栏 (1-4键)
└─ inventory.select_quick_slot(index)
    └─ _auto_equip_from_selected_slot()
        ├─ 有已装备物品且与选中物品不同 → 卸下 (unequip_item)
        │   └─ 删除 EquipmentPoint 下的模型实例
        │   └─ 发射 EventBus.item_unequipped
        ├─ 选中物品且 is_equippable → 装备 (equip_item)
        │   ├─ 从 item.model_scene 实例化 PackedScene
        │   └─ 添加到 EquipmentPoint 下
        │   └─ 发射 EventBus.item_equipped
        └─ 不可装备 → 仅切换选中

使用物品 (鼠标左键)
└─ use_current_item()
    └─ inventory.use_quick_slot_item(selected_quick_slot, self)
        └─ ItemEffectManager.use_item(item, user)
            └─ 消耗品 → remove_item(item_id, 1)
```

### 6.2 PlayerController 相关方法

| 方法 | 说明 |
|------|------|
| `equip_item(item: ItemData)` | 装备物品，实例化 model_scene 到 EquipmentPoint |
| `unequip_item()` | 卸下装备，删除模型实例 |
| `is_item_equipped()` | 检查是否有已装备物品 |
| `get_equipped_item()` | 获取当前装备的物品 |
| `pickup_item(item, count)` | 拾取物品到背包 |
| `use_current_item()` | 使用当前选中快捷栏的物品 |
| `use_item_at_slot(slot_index)` | 使用指定槽位的物品 |
| `has_item(item_id, amount)` | 检查背包中是否有指定物品 |
| `remove_item(item_id, amount)` | 从背包中移除物品 |
| `get_item_count(item_id)` | 获取物品数量 |

---

## 7. 数据流示例

### 7.1 拾取道具流程

```
玩家靠近 PickupItem → 按 E
└─ PickupItem.interact()
    ├─ player = InteractionManager.get_player()
    ├─ player.pickup_item(item_data, pickup_count)
    │   └─ inventory.add_item(item, count)
    │       ├─ _try_stack_existing_item()
    │       ├─ _try_add_to_empty_slot()
    │       └─ emit item_added + inventory_changed
    │           ├─ EventBus.item_picked_up
    │           └─ EventBus.inventory_changed
    ├─ 成功 → PickupItem.queue_free()
    └─ 失败 → 打印"背包已满"
```

### 7.2 使用道具流程

```
玩家选中的道具 → 按鼠标左键
└─ PlayerController.use_current_item()
    └─ inventory.use_quick_slot_item(selected_quick_slot, self)
        └─ inventory.use_item(slot_index, self)
            ├─ ItemEffectManager.use_item(item, player)
            │   └─ match use_effect:
            │       ├─ "heal" → _heal_player(player)
            │       └─ ...
            ├─ 效果成功 + is_consumable
            │   └─ inventory.remove_item(item_id, 1)
            │       └─ emit inventory_changed
            └─ 返回效果是否成功
```

---

## 8. 扩展指南

### 8.1 添加新道具

1. 在 `resources/items/` 下创建 `*.tres` 资源文件
2. 设置 `item_id`, `item_name`, `description` 等属性
3. 如需自定义使用效果：
   - 在 `ItemEffectManager.use_item()` 的 `match` 中添加新的 `use_effect` 分支
   - 或在 `ItemData` 的子类中重写 `use(user)` 方法
4. 如需 3D 装备模型，在 `resources/models/` 下创建模型场景，并赋值给 `model_scene`

### 8.2 添加新道具类型

在 `ItemData.ItemType` 枚举中添加新类型，并在 `get_type_name()` 中返回对应中文名。

### 8.3 自定义使用逻辑

两种方式：
1. **轻量方式**: 在 `ItemEffectManager` 中添加新的 `match` 分支
2. **重量方式**: 创建 `ItemData` 的子类，重写 `use(user)` 方法

---

## 附录

### A. 参数配置表

| 参数 | 位置 | 默认值 | 说明 |
|------|------|--------|------|
| MAX_SLOTS | Inventory.gd | 8 | 背包槽位数 |
| QUICK_BAR_SIZE | Inventory.gd | 4 | 快捷栏数量 |
| STAMINA_MAX | PlayerController.gd | 100.0 | 玩家最大体力（受 heal 影响）|

### B. 文件引用索引

| 文件 | 说明 |
|------|------|
| [item_data.gd](../scripts/items/item_data.gd) | 道具数据类 |
| [item_slot.gd](../scripts/items/item_slot.gd) | 物品槽位类 |
| [inventory.gd](../scripts/items/inventory.gd) | 背包系统 |
| [item_effect_manager.gd](../scripts/items/item_effect_manager.gd) | 道具效果管理器 |
| [classroom_key.tres](../resources/items/classroom_key.tres) | 教室钥匙资源 |
| [first_aid_kit.tres](../resources/items/first_aid_kit.tres) | 急救包资源 |
| [flashlight.tres](../resources/items/flashlight.tres) | 手电筒资源 |
| [noise_lure.tres](../resources/items/noise_lure.tres) | 噪音诱饵资源 |

### C. 文档版本

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-04-29 | 初始版本 |

---

**文档维护**: 游戏开发团队
