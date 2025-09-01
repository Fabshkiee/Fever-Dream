extends Node2D

# Corrected node name to lowercase 'arrow' based on your scene tree
@onready var prompt_arrow = $arrow
@onready var prompt_label = $Label

var player_near = false

func _ready():
	print("Prompt Arrow: ", prompt_arrow)
	print("Prompt Label: ", prompt_label)

	# Start with both hidden
	if prompt_label:
		prompt_label.visible = false

	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	print("Body entered: ", body.name)
	if body.name == "Nicole":
		print("Player has entered! Toggling label")
		player_near = true
		if prompt_label:
			prompt_label.visible = true

func _on_body_exited(body):
	print("Body exited: ", body.name)
	if body.name == "Nicole":
		print("Player has exited. Hiding label and arrow.")
		player_near = false
		if prompt_label:
			prompt_label.visible = false

func _process(_delta):
	# The Dialogic logic
	if player_near and Input.is_action_just_pressed("interact"):
		show_dialog()

func show_dialog():
	if prompt_label:
		prompt_label.visible = false

	Dialogic.start("alcohol_fact")
