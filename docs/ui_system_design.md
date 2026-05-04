# UI系统设计文档

## 1. 系统概述

### 1.1 基本信息
- **系统名称**: UI系统
- **版本**: 1.0
- **更新日期**: 2026-04-29
- **相关文件**:
  - `scripts/ui/player_hud.gd` - 玩家 HUD
  - `scripts/ui/inventory_menu.gd` - 背包菜单
  - `scripts/ui/debug_ui.gd` - 调试信息 UI
  - `scenes/ui/player_hud.tscn` - HUD 场景
  - `scenes/ui/inventory_menu.tscn` - 背包菜单场景
  - `scenes/ui/debug_ui.tscn` - 调试 UI 场景
  - `scripts/autoload/ui_manager.gd` - UI 管理器

### 1.2 UI 层级结构

```
根场景 (test_level.tscn)
│
├─ PlayerHUD (Control)                    ← 始终显示
│   ├─ Crosshair (Control)                — 准星
│   ├─ InteractionLabel (Label)           — 交互提示
│   ├─ StaminaBar (ProgressBar)           — 体力条
│   ├─ EquippedItemLabel (Label)          — 装备名称
│   ├─ QuickBarHBox (HBoxContainer)       — 快捷栏
│   │   ├─ QuickSlot0~3 (PanelContainer)
│   └─ InventoryMenu (InventoryMenu)      ← Tab 键切换显示
│       ├─ GridContainer (8 个槽位)
│       ├─ ItemInfoPanel (物品信息面板)
│       ├─ QuickBarContainer (4 个快捷栏槽)
│       └─ DropZone (丢弃区域)
│
└─ DebugUI (Control)                      ← T 键切换显示
    ├─ NoiseLabel
    ├─ StateLabel / StandUpLabel
    ├─ MonsterLabel
    └─ QuickBarLabel / ItemsLabel
```

---

## 2. UIManager — UI管理器

**文件**: [ui_manager.gd](../scripts/autoload/ui_manager.gd)

详见 [autoload_system_design.md](autoload_system_design.md) 第 5 章。

| 方法 | 说明 |
|------|------|
| `register_hud(h)` | 注册 HUD 控件 |
| `show_hud()` / `hide_hud()` | 显示/隐藏 HUD |
| `show_interaction_prompt(text)` | 通过 EventBus 显示交互提示 |
| `hide_interaction_prompt()` | 隐藏交互提示 |

---

## 3. PlayerHUD — 玩家 HUD

**类名**: PlayerHUD
**继承**: Control
**文件**: [player_hud.gd](../scripts/ui/player_hud.gd)
**场景**: [player_hud.tscn](../scenes/ui/player_hud.tscn)

### 3.1 场景节点结构

```
PlayerHUD (Control)
├── Crosshair (Control)                    — 屏幕中央准星
├── InteractionLabel (Label)               — 交互提示文本 "[E] 开门"
├── StaminaBarContainer (Control)
│   └── StaminaBar (ProgressBar)           — 体力条 (0~100)
├── EquippedItemContainer (Control)
│   └── EquippedItemLabel (Label)          — 当前装备名称
└── QuickBarContainer (Control)
    └── QuickBarHBox (HBoxContainer)
        ├── QuickSlot0 (PanelContainer)    — 快捷栏 1
        │   ├── Icon (TextureRect)
        │   └── IndexLabel (Label)
        ├── QuickSlot1 (PanelContainer)    — 快捷栏 2
        ├── QuickSlot2 (PanelContainer)    — 快捷栏 3
        └── QuickSlot3 (PanelContainer)    — 快捷栏 4
```

### 3.2 信号订阅

| 信号 | 处理函数 | 功能 |
|------|---------|------|
| `EventBus.stamina_changed` | `_on_stamina_changed` | 更新体力条数值 |
| `EventBus.interaction_prompt_changed` | `_on_interaction_prompt_changed` | 显示/隐藏交互提示 |
| `EventBus.inventory_changed` | `_on_inventory_changed` | 刷新快捷栏显示 |
| `EventBus.item_equipped` | `_on_item_equipped` | 显示装备名称 |
| `EventBus.item_unequipped` | `_on_item_unequipped` | 隐藏装备名称 |
| `inventory.selected_slot_changed` | `_on_selected_slot_changed` | 高亮选中快捷栏 |

### 3.3 初始化

```gdscript
func _ready() -> void:
    EventBus.stamina_changed.connect(_on_stamina_changed)
    EventBus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
    EventBus.inventory_changed.connect(_on_inventory_changed)
    EventBus.item_equipped.connect(_on_item_equipped)
    EventBus.item_unequipped.connect(_on_item_unequipped)

    inventory_menu = get_node_or_null("InventoryMenu")
    await get_tree().process_frame
    player = InteractionManager.get_player()

    if player:
        _on_stamina_changed(player.stamina)
        inventory_menu.set_player(player)
        player.inventory.selected_slot_changed.connect(_on_selected_slot_changed)
        _update_quick_bar()

    UIManager.register_hud(self)
```

使用 `await get_tree().process_frame` 等待一帧，确保玩家场景已完全初始化。

### 3.4 各模块功能

#### 3.4.1 交互提示

```gdscript
func _on_interaction_prompt_changed(prompt_text: String) -> void:
    if prompt_text.is_empty():
        interaction_label.visible = false
    else:
        interaction_label.text = "[E] " + prompt_text
        interaction_label.visible = true
```

#### 3.4.2 快捷栏显示

```gdscript
func _update_quick_bar() -> void:
    for i in range(QUICK_BAR_SIZE):
        var slot := quick_slots[i]
        var slot_index: int = inventory.quick_bar[i]
        if slot_index >= 0:
            var item := inventory.get_item_at_slot(slot_index)
            if item:
                icon.texture = item.icon
                continue
        icon.texture = null
    _highlight_selected_slot(inventory.selected_quick_slot)
```

#### 3.4.3 快捷栏高亮

```gdscript
func _highlight_selected_slot(slot_index: int) -> void:
    var selected_style := StyleBoxFlat.new()
    selected_style.bg_color = Color(0.3, 0.6, 0.9, 0.8)  # 蓝色半透明

    var default_style := StyleBoxFlat.new()
    default_style.bg_color = Color(0.1, 0.1, 0.1, 0.6)   # 深灰半透明

    for i in range(quick_slots.size()):
        if i == slot_index:
            slot.add_theme_stylebox_override("panel", selected_style)
        else:
            slot.add_theme_stylebox_override("panel", default_style)
```

### 3.5 输入处理

| 按键 | 动作名 | 功能 |
|------|--------|------|
| Tab | `toggle_inventory` | 打开/关闭背包菜单 |

```gdscript
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_inventory"):
        toggle_inventory_menu()
        get_viewport().set_input_as_handled()

func toggle_inventory_menu() -> void:
    inventory_menu.toggle()
    crosshair.visible = not inventory_menu.visible
```

---

## 4. InventoryMenu — 背包菜单

**类名**: InventoryMenu
**继承**: Control
**文件**: [inventory_menu.gd](../scripts/ui/inventory_menu.gd)
**场景**: [inventory_menu.tscn](../scenes/ui/inventory_menu.tscn)

### 4.1 设计说明

背包菜单是完整的拖放式背包界面，支持：
- 8 个背包槽位（GridContainer 布局）
- 4 个快捷栏槽位（HBoxContainer 布局）
- 鼠标拖拽移动/交换物品
- 右键快速使用物品
- 拖拽到 DropZone 丢弃物品
- 点击物品显示详细信息

### 4.2 场景节点结构

```
InventoryMenu (Control)
├── Background (Control)                    — 背景遮罩 (MOUSE_FILTER_IGNORE)
└── Panel
    └── MarginContainer
        └── VBoxContainer
            ├── HBoxContainer
            │   ├── Label ("背包")
            │   └── CloseButton (Button)    — 关闭按钮
            ├── SlotsContainer
            │   └── GridContainer            — 8 个物品槽 (2×4 网格)
            │       ├── SlotPanel 0 (PanelContainer)
            │       │   ├── Margin/Icon (TextureRect)
            │       │   ├── NameLabel (Label)
            │       │   └── CountLabel (Label)
            │       └── ... (共 8 个)
            ├── ItemInfoPanel (PanelContainer)
            │   └── ItemName / ItemType / ItemDesc
            └── QuickBarContainer (HBoxContainer)
                └── 4 个快捷栏槽 (含 KeyLabel 显示按键号)
└── DropZone (Control)                      — 丢弃区域
```

### 4.3 槽位创建

每个槽位由 `_create_slot_panel()` 创建：

```gdscript
func _create_slot_panel(slot_index: int, is_quick_bar: bool) -> Control:
    var container := VBoxContainer.new()
    # 设置 meta 数据 (slot_index, is_quick_bar)
    container.set_meta("slot_index", slot_index)
    container.set_meta("is_quick_bar", is_quick_bar)

    var panel := PanelContainer.new()        # 64×64 面板
    panel.name = "SlotPanel"
    panel.custom_minimum_size = Vector2(64, 64)

    var icon_rect := TextureRect.new()       # 物品图标
    icon_rect.name = "Icon"
    var name_label := Label.new()            # 物品名称
    name_label.name = "NameLabel"
    var count_label := Label.new()           # 数量
    count_label.name = "CountLabel"

    # 快捷栏额外显示按键号
    if is_quick_bar:
        var key_label := Label.new()
        key_label.name = "KeyLabel"
        key_label.text = str(slot_index + 1)

    panel.gui_input.connect(_on_slot_gui_input.bind(container))
    return container
```

### 4.4 打开/关闭

```gdscript
func toggle() -> void:
    visible = not visible
    if visible:
        _open_menu()
    else:
        _close_menu()

func _open_menu() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # 显示鼠标
    selected_slot_index = -1
    _hide_item_info()
    # 重新连接玩家信号（场景切换后可能断开）
    _connect_player_signals()
    _update_display()

func _close_menu() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # 捕获鼠标
    selected_slot_index = -1
    _cancel_drag()
    emit_signal("menu_closed")
```

### 4.5 拖拽系统

#### 4.5.1 开始拖拽

```gdscript
func _on_slot_gui_input(event, container):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _start_drag(container, slot_index, is_quick_bar)
            else:
                _end_drag(container, slot_index, is_quick_bar)
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            _on_slot_right_click(slot_index, is_quick_bar)

func _start_drag(container, slot_index, is_quick_bar):
    # 创建拖拽图标 (Control + TextureRect + Label)
    dragged_item = Control.new()
    var drag_icon := TextureRect.new()
    drag_icon.texture = icon_rect.texture
    dragged_item.add_child(drag_icon)

    var drag_count := Label.new()
    drag_count.text = str(count)
    dragged_item.add_child(drag_count)

    add_child(dragged_item)
    # 降低原槽位透明度
```

#### 4.5.2 拖拽中

```gdscript
func _process(delta):
    if dragged_item:
        dragged_item.global_position = get_global_mouse_position() - drag_offset
```

#### 4.5.3 释放拖拽

```gdscript
func _end_drag(_container, _slot_index, _is_quick_bar):
    var drop_pos := get_global_mouse_position()

    # 检查释放位置
    for i in slot_controls.size():
        if target.get_global_rect().has_point(drop_pos):
            _handle_drop_on_slot(i, false)      # 拖到背包槽
            return
    for i in quick_bar_controls.size():
        if target.get_global_rect().has_point(drop_pos):
            _handle_drop_on_slot(i, true)       # 拖到快捷栏
            return
    if drop_zone.get_global_rect().has_point(drop_pos):
        _handle_drop_outside()                  # 拖到丢弃区域

    _cancel_drag()
```

#### 4.5.4 拖拽放置逻辑

拖拽放置由 `_handle_drop_on_slot()` 处理，根据来源和目标的不同组合执行不同操作：

```
来源 \ 目标   |  背包槽            |  快捷栏
-------------|--------------------|-------------------
背包槽       | move_slot()        | 设置快捷栏映射
快捷栏       | move_slot()        | 交换快捷栏映射
```

**快捷栏映射交换**:

```gdscript
# 快捷栏 → 快捷栏: 交换两个映射索引
player.inventory.quick_bar[dragged_from_index] = to_inv_index
player.inventory.quick_bar[target_index] = from_inv_index

# 背包槽 → 快捷栏: 清除该槽位的旧快捷栏映射，设置为新映射
player.inventory.quick_bar[target_index] = dragged_from_index
```

### 4.6 右键使用

```gdscript
func _on_slot_right_click(slot_index: int, is_quick_bar: bool) -> void:
    var actual_index: int = slot_index
    if is_quick_bar:
        actual_index = player.inventory.quick_bar[slot_index]

    var slot := player.inventory.get_slot(actual_index)
    if not slot or slot.is_empty():
        return

    player.inventory.use_item(actual_index, player)
```

### 4.7 物品信息面板

```gdscript
func _show_item_info(index: int) -> void:
    var slot := player.inventory.get_slot(index)
    if not slot or slot.is_empty():
        _hide_item_info()
        return
    item_name_label.text = slot.item_data.item_name
    item_type_label.text = slot.item_data.get_type_name()
    item_desc_label.text = slot.item_data.description
    item_info_panel.visible = true
```

### 4.8 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `menu_closed` | — | 背包菜单关闭时触发 |

### 4.9 输入处理

| 输入 | 处理 |
|------|------|
| `ui_cancel` (Esc) | 关闭背包菜单 |
| 鼠标左键拖拽 | 移动/交换物品 |
| 鼠标右键 | 使用物品 |

---

## 5. DebugUI — 调试信息UI

**类名**: DebugUI
**继承**: Control
**文件**: [debug_ui.gd](../scripts/ui/debug_ui.gd)
**场景**: [debug_ui.tscn](../scenes/ui/debug_ui.tscn)

### 5.1 切换

按 `T` 键切换显示/隐藏。

### 5.2 显示内容

```
[状态信息]
状态: 奔跑                   ← 行走/奔跑/蹲下/躲藏/跳跃
可以起身: 是                 ← 蹲下时显示
噪音等级: 2.0               ← 闪烁显示，0.5秒后归零

[敌人信息]
敌人状态: CHASE              ← PATROL / ALERT / CHASE
速度: 5.23 m/s | 距离: 8.5m  ← 实时速度和与玩家距离
警觉: [████████░░░░░░] 50%   ← 警觉值进度条

[背包信息]
快捷栏:
  [1]  手电筒 x1
  [2]* 噪音诱饵 x2            ← * 表示当前选中
  [3]  空
  [4]  空
背包物品:
  教室钥匙 x1
  急救包 x3
```

### 5.3 信号订阅

| 信号 | 处理函数 | 说明 |
|------|---------|------|
| `EventBus.noise_made` | `_on_noise_made` | 显示当前噪音等级（0.5秒后消失）|
| `EventBus.inventory_changed` | `_update_inventory_display` | 刷新背包显示 |
| `EventBus.item_picked_up` | `_update_inventory_display` | 拾取后刷新 |

### 5.4 敌人信息更新

```gdscript
func _update_monster_display() -> void:
    var speed := Vector2(monster.velocity.x, monster.velocity.z).length()
    var distance := " | 距离: %.1fm" % dist_to_player
    var alertness_percent := monster.get_alertness_percent()

    # 警觉值进度条 (20格)
    var bar_length := 20
    var filled := int(alertness_percent * bar_length)
    var empty := bar_length - filled
    alertness_bar = "\n警觉: [%s%s] %.0f%%" % ["█".repeat(filled), "░".repeat(empty), alertness_percent * 100]

    monster_label.text = "敌人状态: %s\n速度: %.2f m/s%s%s" % [
        monster.get_state_name(), speed, distance, alertness_bar
    ]
```

---

## 6. 数据流

### 6.1 体力值更新

```
PlayerController._handle_stamina()
└─ EventBus.stamina_changed.emit(current)
    └─ PlayerHUD._on_stamina_changed()
        └─ stamina_bar.value = stamina
```

### 6.2 交互提示更新

```
InteractionManager.check_interaction()
├─ 找到可交互对象
│   └─ EventBus.interaction_prompt_changed.emit("开门")
│       └─ PlayerHUD._on_interaction_prompt_changed()
│           └─ interaction_label.text = "[E] 开门"
│           └─ interaction_label.visible = true
└─ 未找到
    └─ EventBus.interaction_prompt_changed.emit("")
        └─ PlayerHUD 隐藏交互提示
```

### 6.3 背包打开/关闭

```
PlayerHUD._input() → Tab键
├─ inventory_menu.toggle()
│   ├─ visible = true
│   │   ├─ Input.mouse_mode = MOUSE_MODE_VISIBLE
│   │   ├─ 连接玩家信号
│   │   └─ _update_display()
│   └─ visible = false
│       ├─ Input.mouse_mode = MOUSE_MODE_CAPTURED
│       ├─ _cancel_drag()
│       └─ emit menu_closed
└─ crosshair.visible = not inventory_menu.visible
```

---

## 7. 扩展指南

### 7.1 添加新的 HUD 元素

1. 在 `player_hud.tscn` 中添加 UI 控件
2. 在 `PlayerHUD.gd` 中添加 `@onready` 节点引用
3. 连接对应的 EventBus 信号或玩家信号
4. 实现更新函数

### 7.2 添加新的调试信息

1. 在 `debug_ui.tscn` 中添加 Label 控件
2. 在 `DebugUI.gd` 中添加节点引用
3. 在 `_process` 或信号回调中更新文本

### 7.3 自定义背包槽行为

修改 `InventoryMenu._on_slot_gui_input()` 中的事件处理：
- 添加双击行为
- 添加 Shift+点击分割堆叠
- 添加 Ctrl+点击快速丢弃

---

## 附录

### A. 参数配置表

| 参数 | 位置 | 默认值 | 说明 |
|------|------|--------|------|
| SLOT_SIZE | InventoryMenu.gd | 64 | 背包槽尺寸 |
| SLOT_GAP | InventoryMenu.gd | 8 | 槽位间距 |
| DEFAULT_ICON_PATH | InventoryMenu.gd | res://icon.svg | 默认图标路径 |

### B. 文件引用索引

| 文件 | 说明 |
|------|------|
| [player_hud.gd](../scripts/ui/player_hud.gd) | 玩家 HUD |
| [inventory_menu.gd](../scripts/ui/inventory_menu.gd) | 背包菜单 |
| [debug_ui.gd](../scripts/ui/debug_ui.gd) | 调试 UI |

### C. 文档版本

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-04-29 | 初始版本 |

---

**文档维护**: 游戏开发团队