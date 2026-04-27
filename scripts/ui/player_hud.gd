class_name PlayerHUD
extends Control

@onready var crosshair: Control = $Crosshair
@onready var interaction_label: Label = $InteractionLabel
@onready var stamina_bar: ProgressBar = $StaminaBarContainer/StaminaBar

var player: PlayerController = null

func _ready() -> void:
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)

	await get_tree().process_frame
	player = InteractionManager.get_player()
	if player:
		_on_stamina_changed(player.stamina)
	else:
		push_warning("[PlayerHUD] 未找到玩家")
	if UIManager:
		UIManager.register_hud(self)

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
