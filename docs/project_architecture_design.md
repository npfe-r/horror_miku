# 项目架构设计文档（总览）

## 1. 项目概述

### 1.1 基本信息
- **项目名称**: HorrorMiku（夜校逃亡）
- **引擎版本**: Godot 4.6
- **渲染引擎**: Forward Plus
- **物理引擎**: Jolt Physics
- **游戏类型**: 第一人称恐怖生存
- **目标平台**: PC (Windows)

### 1.2 项目结构

```
horror_miku/
├── project.godot                          # 项目配置文件
├── 游戏设计文档.md                          # 游戏设计总纲
├── docs/                                  # 设计文档目录
│   ├── project_architecture_design.md     # 本项目架构总览
│   ├── autoload_system_design.md          # 自动加载单例系统详细设计
│   ├── enemy_system_design.md             # 敌人系统详细设计
│   ├── player_controller_design.md        # 玩家控制器详细设计
│   ├── interaction_object_design.md       # 交互对象系统详细设计
│   ├── item_inventory_design.md           # 道具与背包系统详细设计
│   └── ui_system_design.md               # UI系统详细设计
├── resources/
│   ├── items/                             # 道具数据资源
│   └── models/                            # 道具3D模型场景
├── scenes/
│   ├── enemies/monster.tscn               # 敌人场景
│   ├── levels/test_level.tscn             # 测试关卡
│   ├── objects/                           # 交互对象场景
│   ├── player/player.tscn                 # 玩家场景
│   └── ui/                                # UI场景
└── scripts/
    ├── autoload/                          # 自动加载单例
    ├── debug/                             # 调试工具
    ├── enemies/                           # 敌人AI
    ├── items/                             # 道具系统
    ├── objects/                           # 交互对象
    ├── player/                            # 玩家控制
    └── ui/                                # UI逻辑
```

### 1.3 核心架构图

```
┌──────────────────────────────────────────────────────────────────────┐
│                      AutoLoad 单例层                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  ┌───────────┐  │
│  │  EventBus    │  │ GameManager  │  │ SaveMgr    │  │ UIManager │  │
│  │  (信号总线)   │  │ (流程状态机)  │  │ (存档)     │  │ (UI管理)   │  │
│  └──────┬───────┘  └──────┬───────┘  └─────┬──────┘  └─────┬─────┘  │
│         │                 │                │              │         │
│  ┌──────┴─────────────────┴────────────────┴──────────────┴──────┐  │
│  │                   InteractionManager                           │  │
│  │               (交互检测与事件分发)                               │  │
│  └────────────────────────────┬───────────────────────────────────┘  │
│                               │                                      │
├───────────────────────────────┼──────────────────────────────────────┤
│                    游戏场景层   │                                      │
│  ┌────────────────────────────┴───────────────────────────────────┐  │
│  │   PlayerController (CharacterBody3D)                           │  │
│  │   ├── Head/Camera3D + PlayerCamera (头晃)                     │  │
│  │   └── Inventory (背包子系统)                                   │  │
│  ├───────────────────────────────────────────────────────────────┤  │
│  │   MonsterAI (CharacterBody3D)                                  │  │
│  │   └── MonsterPerception (视觉+听觉感知子系统)                   │  │
│  ├───────────────────────────────────────────────────────────────┤  │
│  │   InteractableObject / Door / HidingSpot / Switch / PickupItem │  │
│  └───────────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────────────┤
│                          UI 场景层                                    │
│  ┌──────────────┐  ┌────────────────┐  ┌────────────────────┐       │
│  │  PlayerHUD   │  │ InventoryMenu  │  │     DebugUI        │       │
│  │  (状态显示)   │  │  (背包界面)     │  │   (调试信息)       │       │
│  └──────────────┘  └────────────────┘  └────────────────────┘       │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.4 通信模式

项目采用**事件驱动架构**：所有跨系统通信通过 `EventBus` 进行，系统间不保存直接引用。

```
系统A ──→ EventBus.signal.emit() ──→ EventBus ──→ EventBus.signal.connect() ──→ 系统B
                                                                         └──→ 系统C
```

**事件示例**:
- `EventBus.noise_made` — 玩家系统 → 怪物感知系统
- `EventBus.stamina_changed` — 玩家系统 → UI系统
- `EventBus.inventory_changed` — 背包系统 → UI系统
- `EventBus.player_caught` — 怪物系统 → 游戏流程

---

## 2. 系统总览

### 2.1 自动加载单例系统

提供游戏运行所需的全局服务。详见 [autoload_system_design.md](autoload_system_design.md)。

| 单例 | 职责 | 核心功能 |
|------|------|---------|
| EventBus | 全局信号总线 | 56个信号，覆盖游戏流程/玩家/怪物/道具/交互/存档事件 |
| GameManager | 游戏流程管理 | 5状态状态机 (MENU/PLAYING/PAUSED/GAME_OVER/WON) |
| InteractionManager | 交互系统管理 | 射线检测、高亮管理、交互分发 |
| UIManager | UI层级管理 | HUD注册/显示、交互提示代理 |
| SaveManager | 存档管理 | 内存存档（文件I/O待实现） |

### 2.2 玩家系统

第一人称控制器，包含移动、视角控制、体力管理、噪音系统和装备系统。详见 [player_controller_design.md](player_controller_design.md)。

| 子系统 | 核心参数 |
|--------|---------|
| 移动 | 行走3.5 / 奔跑6.0 / 蹲下1.5 m/s |
| 体力 | 最大100.0 / 消耗20/s / 恢复15/s |
| 噪音 | 蹲走1→8m / 行走2→16m / 奔跑3→24m |
| 蹲下 | 头部高度1.5→0.8m / 碰撞体1.8→1.0m |
| 装备 | 通过快捷栏自动装备/卸下物品模型 |

### 2.3 敌人系统

基于状态机和警觉值系统的怪物AI。详见 [enemy_system_design.md](enemy_system_design.md)。

| 组件 | 功能 |
|------|------|
| MonsterAI | 3状态状态机（巡逻/警觉/追击），警觉值系统，NavigationAgent3D导航 |
| MonsterPerception | 视觉检测（15m/180°）+ 听觉检测（25m），正态分布随机因数 |

### 2.4 交互对象系统

可交互的环境物品系统。详见 [interaction_object_design.md](interaction_object_design.md)。

| 类 | 继承 | 功能 |
|----|------|------|
| InteractableObject | AnimatableBody3D | 基类，提供高亮、提示文本框架 |
| PickupItem | InteractableObject | 拾取后添加到玩家背包 |
| Door | Node3D | 独立实现，Pivot旋转动画，支持上锁 |
| HidingSpot | InteractableObject | 进入/离开躲藏状态 |
| Switch | InteractableObject | 切换状态，控制连接的节点 |

### 2.5 道具与背包系统

道具数据和背包逻辑。详见 [item_inventory_design.md](item_inventory_design.md)。

| 组件 | 功能 |
|------|------|
| ItemData (Resource) | 道具模板，支持自定义效果  |
| ItemSlot (Resource) | 槽位容器，支持堆叠 |
| Inventory (Node) | 8槽背包 + 4快捷栏 + 序列化 |
| ItemEffectManager | 8种效果映射（heal/flashlight/key等）|

### 2.6 UI系统

游戏内所有UI界面。详见 [ui_system_design.md](ui_system_design.md)。

| 界面 | 功能 |
|------|------|
| PlayerHUD | 体力条、交互提示、快捷栏、装备显示 |
| InventoryMenu | 背包界面，支持拖拽/右键使用/丢弃 |
| DebugUI | 调试信息，按T键切换 |

---

## 3. 输入映射总表

| 类别 | 动作名 | 按键 | 说明 |
|------|--------|------|------|
| 移动 | move_forward/backward | W/S | 前后移动 |
| 移动 | move_left/right | A/D | 左右移动 |
| 移动 | jump | Space | 跳跃 |
| 移动 | run | Shift | 奔跑（按住） |
| 移动 | crouch | C | 蹲下（切换） |
| 交互 | interact | E | 交互/拾取 |
| 道具 | use_item | 鼠标左键 | 使用当前选中道具 |
| 道具 | quick_slot_1~4 | 1~4 | 切换快捷栏 |
| 系统 | toggle_inventory | Tab | 打开/关闭背包 |
| 调试 | T | T | 切换调试UI |

---

## 4. 性能优化

### 4.1 视觉检测优化
- 检测间隔 0.2 秒，避免每帧检测
- 距离优先 → 角度检测 → 射线检测（早期退出）

### 4.2 导航优化
- NavigationAgent3D 路径简化 + 避障系统
- 避免频繁更新目标位置

### 4.3 内存优化
- 使用 `WeakRef` 引用玩家，避免循环引用
- 警觉状态检查点数组复用

### 4.4 噪音发射优化
- 计时器控制发射频率（站立0.5s / 奔跑0.3s / 蹲走0.8s）
- 停止移动时立即重置计时器

---

## 5. 扩展指南

### 5.1 添加新道具
1. 在 `resources/items/` 下创建 `*.tres`
2. 设置属性，在 `ItemEffectManager` 中添加效果

### 5.2 添加新可交互对象
1. 继承 `InteractableObject` 或实现接口方法
2. 在 `InteractionManager` 中添加类型检测

### 5.3 添加敌人新状态
1. 在 `MonsterAI.State` 枚举中添加
2. 实现 `_process_[state]()` 并在状态机中注册

### 5.4 添加新事件
1. 在 `EventBus` 中声明 `signal`
2. 发送方 `emit()`，接收方 `connect()`

---

## 6. 已知问题

- **存档系统**: 仅内存存档，无文件 I/O
- **道具效果**: 大部分效果（手电筒光照、噪音诱饵等）尚未实现完整逻辑
- **多敌人协作**: 不支持
- **声音遮挡**: 不考虑墙壁遮挡
- **环境互动**: 敌人不会与门等环境物体互动

---

## 附录

### A. 文档索引

| 文档 | 说明 |
|------|------|
| [autoload_system_design.md](autoload_system_design.md) | 自动加载单例系统详细设计 |
| [enemy_system_design.md](enemy_system_design.md) | 敌人AI与感知系统详细设计 |
| [player_controller_design.md](player_controller_design.md) | 玩家控制器详细设计 |
| [interaction_object_design.md](interaction_object_design.md) | 交互对象系统详细设计 |
| [item_inventory_design.md](item_inventory_design.md) | 道具与背包系统详细设计 |
| [ui_system_design.md](ui_system_design.md) | UI系统详细设计 |
| [游戏设计文档.md](../游戏设计文档.md) | 游戏设计总纲 |

### B. 文档版本

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-04-29 | 重构为总览文档，各子系统拆分为独立文件 |

---

**文档维护**: 游戏开发团队
