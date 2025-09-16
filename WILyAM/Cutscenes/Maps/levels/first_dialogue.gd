extends Area2D

@export var dialogue_name: String = "first_dialogue"
var triggered: bool = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		triggered = true
		var nicole = body
		if nicole.get("can_move") != null and nicole.get("freeze_timer") != null:
			# Start dialogue and set 1-second freeze
			DialogManager.start_dialogue(dialogue_name)
			nicole.freeze_timer.wait_time = 1.0
			nicole.freeze_timer.start()
			print("Started dialogue", dialogue_name, "and 1-second freeze timer for", nicole.name)
			# Connect to timeline_ended to unfreeze and show guide
			Dialogic.timeline_ended.connect(_on_timeline_ended.bind(nicole))
			print("Connected timeline_ended signal for", dialogue_name)

func _on_timeline_ended(nicole: CharacterBody2D) -> void:
	print("Timeline ended for", dialogue_name)
	if nicole.get("can_move") != null:
		nicole.set("can_move", true)
		print("Set can_move to true for", nicole.name)
		if nicole.get("guide_label") != null:
			nicole.guide_label.text = "Press Left arrow or Right arrow to Navigate"
			nicole.call_deferred("_on_dialogue_ended")  # Show custom guide
	Dialogic.timeline_ended.disconnect(_on_timeline_ended.bind(nicole))
	print("Disconnected timeline_ended signal for", dialogue_name)
