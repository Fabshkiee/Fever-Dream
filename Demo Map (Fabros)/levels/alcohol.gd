extends Node2D

@onready var prompt_arrow = $Arrow  
@onready var prompt_label = $Label   
var player_near = false

func _ready():
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":   
		player_near = true
		prompt_arrow.visible = true
		prompt_label.visible = true

func _on_body_exited(body):
	if body.name == "Player":
		player_near = false
		prompt_arrow.visible = false
		prompt_label.visible = false

func _process(delta):
	if player_near and Input.is_action_just_pressed("interact"): 
		show_dialog()

func show_dialog():
	Dialogic.start("alcohol_fact")
