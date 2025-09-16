extends CharacterBody2D

# === STATE ENUM ===
enum State { IDLE, CHASE, ATTACK }
var state: State = State.IDLE

# === PARAMETERS ===
@export var speed := 80
@export var attack_range := 30
@export var chase_range := 200
@export var attack_cooldown := 1.5

# === INTERNAL VARIABLES ===
var player: Node2D = null
var can_attack := true

# === FLIP NODE ===
@export var flip_node: Node2D = null
var facing_dir: int = 1 # 1 = right, -1 = left

# === NODES ===
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var sprite := $Sprite2D
@onready var attack_timer := $Timer

# === READY ===
func _ready():
	anim_tree.active = true
	$Area2D.connect("body_entered", _on_Area2D_body_entered)
	$Area2D.connect("body_exited", _on_Area2D_body_exited)
	attack_timer.connect("timeout", _on_Timer_timeout)

	# Auto-detect flip node if none provided
	if flip_node == null:
		flip_node = get_node_or_null("Skeleton2D")
		if flip_node == null:
			flip_node = get_node_or_null("Sprite2D")
		if flip_node == null:
			flip_node = get_node_or_null("AnimatedSprite2D")

	if flip_node == null:
		push_error("Flip node not set! Assign a Skeleton2D, Sprite2D, or AnimatedSprite2D to 'flip_node' in the inspector.")

# === MAIN LOOP ===
func _physics_process(delta):
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			anim_state.travel("RESET")

		State.CHASE:
			if player:
				var direction = (player.global_position - global_position).normalized()
				velocity = direction * speed
				anim_state.travel("Walk_Drag")
				_face_direction(direction.x)

				if global_position.distance_to(player.global_position) < attack_range and can_attack:
					state = State.ATTACK

		State.ATTACK:
			velocity = Vector2.ZERO
			anim_state.travel("Melee")
			can_attack = false
			attack_timer.start(attack_cooldown)

			await get_tree().create_timer(0.5).timeout  # Adjust based on Melee animation timing

			if player and global_position.distance_to(player.global_position) <= chase_range:
				state = State.CHASE
			else:
				state = State.IDLE

	move_and_slide()

# === FLIP FUNCTIONS ===
func _face_direction(dir_x: float) -> void:
	if dir_x < 0 and facing_dir != -1:
		facing_dir = -1
		_set_flip_x(-1)
	elif dir_x > 0 and facing_dir != 1:
		facing_dir = 1
		_set_flip_x(1)

func _set_flip_x(sign_x: int) -> void:
	if flip_node == null:
		return
	var sx := flip_node.scale.x
	var sy := flip_node.scale.y
	flip_node.scale = Vector2(sign_x * abs(sx if sx != 0.0 else 1.0), sy if sy != 0.0 else 1.0)

# === PLAYER DETECTION ===
func _on_Area2D_body_entered(body):
	if body.is_in_group("player"):
		player = body
		state = State.CHASE

func _on_Area2D_body_exited(body):
	if body == player:
		player = null
		state = State.IDLE

# === ATTACK COOLDOWN ===
func _on_Timer_timeout():
	can_attack = true
