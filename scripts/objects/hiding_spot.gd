class_name HidingSpot
extends InteractableObject

@export var discovery_chance: float = 0.3
@export var can_observe: bool = false

var is_occupied: bool = false

func _ready() -> void:
	super._ready()
	interaction_text = "躲藏"

func interact() -> void:
	# TODO: 实现完整的进入/离开藏身处逻辑
	if is_occupied:
		_exit_hiding()
	else:
		_enter_hiding()

func _enter_hiding() -> void:
	is_occupied = true
	interaction_text = "离开"
	var player := InteractionManager.get_player()
	if player:
		player.set_hiding(true)
	EventBus.hiding_state_changed.emit(true)

func _exit_hiding() -> void:
	is_occupied = false
	interaction_text = "躲藏"
	var player := InteractionManager.get_player()
	if player:
		player.set_hiding(false)
	EventBus.hiding_state_changed.emit(false)
