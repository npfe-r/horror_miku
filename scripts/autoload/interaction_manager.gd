extends Node

signal interaction_prompt_changed(prompt_text: String)
signal interaction_available(interactable: Node)
signal interaction_lost()

var current_interactable: Node = null
var player: Node = null

const INTERACT_RANGE: float = 2.5

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_player(player_node: Node) -> void:
	player = player_node

func check_interaction(from: Vector3, to: Vector3, space_state: PhysicsDirectSpaceState3D) -> void:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	
	var result := space_state.intersect_ray(query)
	
	if result and result.has("collider"):
		var collider: Object = result.collider
		
		if collider.has_method(&"can_interact"):
			var can_interact_result: bool = collider.call(&"can_interact")
			if can_interact_result:
				if collider.has_method(&"get_interaction_text"):
					var prompt_text: String = collider.call(&"get_interaction_text")
					emit_signal("interaction_prompt_changed", prompt_text)
				
				if current_interactable != collider:
					if current_interactable:
						emit_signal("interaction_lost")
					
					current_interactable = collider
					emit_signal("interaction_available", collider)
				return
	
	if current_interactable:
		emit_signal("interaction_lost")
		emit_signal("interaction_prompt_changed", "")
		current_interactable = null

func try_interact() -> void:
	if current_interactable and current_interactable.has_method(&"interact"):
		current_interactable.call(&"interact")

func get_current_interactable() -> Node:
	return current_interactable

func has_interactable() -> bool:
	return current_interactable != null
