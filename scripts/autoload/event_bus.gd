## EventBus — 全局信号总线
## 所有跨系统事件通过此单例广播，系统间不直接引用
extends Node

## 游戏流程
signal game_started
signal game_paused(paused: bool)
signal player_died
signal game_won

## 玩家事件
signal noise_made(level: float, position: Vector3, max_range: float)
signal player_caught
signal stamina_changed(current: float)

## 怪物事件
signal monster_state_changed(state: String)
signal monster_detected_player(position: Vector3)
signal monster_lost_player

## 道具事件
signal item_picked_up(item: ItemData, count: int)
signal item_used(item: ItemData)
signal item_equipped(item: ItemData)
signal item_unequipped
signal inventory_changed

## 交互事件
signal door_opened(door_id: String)
signal mechanism_activated(mech_id: String)
signal hiding_state_changed(hiding: bool)

## 提示事件
signal interaction_prompt_changed(text: String)

## 存档事件
signal game_saved
signal game_loaded
