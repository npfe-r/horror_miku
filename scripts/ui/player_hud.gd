class_name PlayerHUD
extends Control

@onready var crosshair: Control = $Crosshair
@onready var interaction_label: Label = $InteractionLabel
@onready var stamina_bar: ProgressBar = $StaminaBarContainer/StaminaBar

var player: PlayerController = null

func _ready() -> void:
	await get_tree().process_frame
	_find_and_connect_player()

func _find_and_connect_player() -> void:
	player = get_parent().get_node("Player") as PlayerController
	if not player:
		push_warning("[PlayerHUD] 未找到玩家节点")
		return
	
	player.stamina_changed.connect(_on_stamina_changed)
	player.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	
	_on_stamina_changed(player.stamina)
	print("[PlayerHUD] 已连接玩家信号")

func _on_stamina_changed(stamina: float) -> void:
	if stamina_bar:
		stamina_bar.value = stamina

func _on_interaction_prompt_changed(prompt_text: String) -> void:
	if interaction_label:
		if prompt_text.is_empty():
			interaction_label.visible = false
		else:
			interaction_label.text = "[E] " + prompt_text
			interaction_label.visible = true
