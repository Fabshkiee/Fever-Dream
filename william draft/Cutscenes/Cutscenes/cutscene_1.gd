extends Node2D

@onready var anim_tree: AnimationTree = $AnimationTree
var state_machine: AnimationNodeStateMachinePlayback

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Wire AnimationTree safely
	if anim_tree == null:
		push_error("AnimationTree not found at $AnimationTree. Update the path or add one.")
	else:
		anim_tree.active = true
		state_machine = anim_tree["parameters/playback"]  # requires StateMachine root

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_travel("Cutscene1")


# --- Animation helper ---
func _travel(state: String) -> void:
	if state_machine != null:
		state_machine.travel(state)
