class_name ItemData
extends Resource

enum ItemType {
	KEY,
	CONSUMABLE,
	SPECIAL,
	EQUIPMENT
}

@export var item_id: String = ""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.KEY
@export var max_stack: int = 1
@export var is_consumable: bool = false
@export var is_equippable: bool = false
@export var use_effect: String = ""
@export var model_scene: PackedScene

func _init() -> void:
	resource_name = item_name

func can_stack_with(other: ItemData) -> bool:
	if not other:
		return false
	if item_id != other.item_id:
		return false
	if max_stack <= 1:
		return false
	return true

func get_type_name() -> String:
	match item_type:
		ItemType.KEY:
			return "关键道具"
		ItemType.CONSUMABLE:
			return "消耗品"
		ItemType.SPECIAL:
			return "特殊道具"
		ItemType.EQUIPMENT:
			return "装备"
	return "未知"

## 虚方法：子类可重写此方法实现自定义使用行为
## 返回 true 表示使用已处理，false 则交由 ItemEffectManager 按 use_effect 处理
func use(user: Node) -> bool:
	print("[ItemData] 使用物品: %s — 默认使用行为（无具体效果）" % item_name)
	return false
