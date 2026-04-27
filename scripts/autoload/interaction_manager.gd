## InteractionManager — 可交互物体的统一管理入口
## PlayerController 每帧调用 check_interaction()，按下交互键时调用 try_interact()
extends Node

signal prompt_changed(text: String)
signal interactable_changed(obj: InteractableObject)

var current_interactable: Node = null
var player: PlayerController = null

const INTERACT_RANGE: float = 2.5

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_player(p: PlayerController) -> void:
	player = p

func get_player() -> PlayerController:
	return player

func check_interaction() -> void:
	if not player:
		return

	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	if not camera:
		return

	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * INTERACT_RANGE

	var space_state := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1

	var result := space_state.intersect_ray(query)

	if not result.is_empty():
		var collider: Object = result.collider
		var interactable := _find_interactable(collider)

		if interactable and interactable.has_method(&"can_interact") and interactable.call(&"can_interact"):
			if current_interactable != interactable:
				if current_interactable:
					current_interactable.call(&"set_highlight", false)
				current_interactable = interactable
				current_interactable.call(&"set_highlight", true)
				interactable_changed.emit(current_interactable)

				var text: String = current_interactable.call(&"get_interaction_text")
				EventBus.interaction_prompt_changed.emit(text)
			return

	if current_interactable:
		current_interactable.call(&"set_highlight", false)
		current_interactable = null
		interactable_changed.emit(null)
		EventBus.interaction_prompt_changed.emit("")

func try_interact() -> void:
	if current_interactable and current_interactable.has_method(&"can_interact") and current_interactable.call(&"can_interact"):
		current_interactable.call(&"set_highlight", false)
		current_interactable.call(&"interact")
		current_interactable = null
		EventBus.interaction_prompt_changed.emit("")

func has_interactable() -> bool:
	return current_interactable != null

func _find_interactable(collider: Object) -> Node:
	if collider is InteractableObject:
		return collider

	# Check for Door (inherits Node3D, not InteractableObject)
	if collider is AnimatableBody3D:
		var parent: Node = collider.get_parent()
		while parent:
			if parent is Door:
				return parent
			parent = parent.get_parent()

	# Walk up tree for any node with can_interact method
	var node: Node = collider
	while node:
		if node.has_method(&"can_interact") and node.has_method(&"set_highlight"):
			return node
		node = node.get_parent()

	return null
