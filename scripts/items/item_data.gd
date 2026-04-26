class_name ItemData
extends Resource

enum ItemType {
	KEY,
	CONSUMABLE,
	SPECIAL
}

@export var item_id: String = ""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.KEY
@export var max_stack: int = 1
@export var is_consumable: bool = false
@export var use_effect: String = ""

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
	return "未知"
