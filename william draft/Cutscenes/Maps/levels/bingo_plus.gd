extends Area2D

@export var dialogue_name: String = "bingo_plus"
var triggered: bool = false
var player_inside: Node2D = null  # Track the player for interaction

@onready var prompt_label = $Label



func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if prompt_label:
		prompt_label.visible = false

func _on_body_entered(body: Node2D) -> void:
	if prompt_label:
				prompt_label.visible = true
	if body.is_in_group("player") and not triggered:
		print("Player Entered:", dialogue_name)
		player_inside = body  # Store the player reference
		# Start monitoring for interact input
		set_process(true)  # Enable _process to check input
		

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Player exited hidden achievement area:", dialogue_name)
		if prompt_label:
				prompt_label.visible = false
		if body == player_inside:
			player_inside = null  # Clear reference
			triggered = false  # Reset for re-entry
			set_process(false)  # Disable _process if no player

func _process(delta: float) -> void:
	if player_inside != null and not triggered and Input.is_action_just_pressed("interact"):
		_trigger_dialogue(player_inside)

func _trigger_dialogue(body: Node2D) -> void:
	triggered = true
	var nicole = body
	if nicole.get("can_move") != null and nicole.get("freeze_timer") != null:
		# Start dialogue and set 1-second freeze
		DialogManager.start_dialogue(dialogue_name)
		nicole.freeze_timer.wait_time = 1.0
		nicole.freeze_timer.start()
		print("Started hidden achievement dialogue", dialogue_name, "and 1-second freeze timer for", nicole.name)
		# Connect to timeline_ended to unfreeze
		Dialogic.timeline_ended.connect(_on_timeline_ended.bind(nicole))
		print("Connected timeline_ended signal for", dialogue_name)
		# Log achievement
		print("Achievement unlocked:", dialogue_name)

func _on_timeline_ended(nicole: CharacterBody2D) -> void:
	print("Timeline ended for", dialogue_name)
	if nicole.get("can_move") != null:
		nicole.set("can_move", true)
		print("Set can_move to true for", nicole.name)
		if nicole.get("guide_label") != null:
			nicole.guide_label.text = ""
			nicole.call_deferred("_on_dialogue_ended")  # Show custom guide
	Dialogic.timeline_ended.disconnect(_on_timeline_ended.bind(nicole))
	print("Disconnected timeline_ended signal for", dialogue_name)
