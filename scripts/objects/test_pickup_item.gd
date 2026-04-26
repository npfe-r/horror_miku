class_name TestPickupItem
extends InteractableObject

@export var item_name: String = "测试物品"
@export var item_description: String = "这是一个测试物品"
@export var pickup_message: String = "拾取了 %s"

signal item_picked_up(item: TestPickupItem)

func _ready() -> void:
	super._ready()
	interaction_text = "拾取 " + item_name

func interact() -> void:
	print(pickup_message % item_name)
	print("物品描述: ", item_description)
	emit_signal("item_picked_up", self)
	queue_free()

func get_item_info() -> Dictionary:
	return {
		"name": item_name,
		"description": item_description
	}
