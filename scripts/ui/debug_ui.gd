class_name DebugUI
extends Control

@onready var stamina_bar: ProgressBar = $VBoxContainer/StaminaBar
@onready var stamina_label: Label = $VBoxContainer/StaminaBar/StaminaLabel
@onready var noise_label: Label = $VBoxContainer/NoiseLabel
@onready var state_label: Label = $VBoxContainer/StateLabel
@onready var stand_up_label: Label = $VBoxContainer/StandUpLabel
@onready var interaction_label: Label = $InteractionLabel

var player: PlayerController = null

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent().get_node("Player") as PlayerController
	if player:
		player.stamina_changed.connect(_on_stamina_changed)
		player.noise_made.connect(_on_noise_made)
		player.interaction_prompt_changed.connect(_on_interaction_prompt_changed)

func _process(_delta: float) -> void:
	if not player:
		return
	
	_update_state_display()

func _on_stamina_changed(stamina: float) -> void:
	if stamina_bar:
		stamina_bar.value = stamina
	if stamina_label:
		stamina_label.text = "体力: %.1f" % stamina

func _on_noise_made(noise_level: float, _position: Vector3) -> void:
	if noise_label:
		noise_label.text = "噪音等级: %.1f" % noise_level
		await get_tree().create_timer(0.5).timeout
		if noise_label:
			noise_label.text = "噪音等级: 0.0"

func _update_state_display() -> void:
	if not state_label or not player:
		return
	
	var state_text := ""
	if player.is_hiding:
		state_text = "状态: 躲藏中"
	elif player.is_jumping:
		state_text = "状态: 跳跃中"
	elif player.is_crouching:
		state_text = "状态: 蹲下"
		if not player._can_stand_up:
			state_text += " (无法起身)"
	elif player.is_running:
		state_text = "状态: 奔跑"
	else:
		state_text = "状态: 行走"
	
	state_label.text = state_text
	
	if stand_up_label:
		if player.is_crouching:
			stand_up_label.text = "可以起身: " + ("是" if player._can_stand_up else "否")
			stand_up_label.visible = true
		else:
			stand_up_label.visible = false

func _on_interaction_prompt_changed(prompt_text: String) -> void:
	if interaction_label:
		if prompt_text.is_empty():
			interaction_label.visible = false
		else:
			interaction_label.text = "[E] " + prompt_text
			interaction_label.visible = true
