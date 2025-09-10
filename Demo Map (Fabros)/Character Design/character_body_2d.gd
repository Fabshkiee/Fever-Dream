extends CharacterBody2D

signal player_died
signal infection_changed(infection_level: float)  # Signal for infection updates

var health: int = 3
var infection_level: float = 0.0  # Tracks infection from 0 to 100
var is_dead: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var wrist_sprite: Sprite2D = $Character/Body/Wrist2
var hit_effect_strength: float = 1.0
var hit_effect_decay: float = 1.0 # how fast it fades back to 0

func _ready() -> void:
	add_to_group("player")
	if anim_tree == null:
		push_error("AnimationTree not found at $AnimationTree. Update the path or add one.")
	else:
		anim_tree.active = true
		state_machine = anim_tree["parameters/playback"]
	if flip_node == null:
		flip_node = get_node_or_null("Skeleton2D")
		if flip_node == null:
			flip_node = get_node_or_null("Sprite2D")
		if flip_node == null:
			flip_node = get_node_or_null("AnimatedSprite2D")
		if flip_node == null:
			push_error("Flip node not set/found. In the Inspector, set 'Flip Node' to your Skeleton2D.")
	# Reset state
	is_dead = false
	health = 5
	infection_level = 0.0
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	var infection_bar = get_node_or_null("/root/Node2D/CanvasLayer/InfectionBar")
	if infection_bar == null:
		push_error("Player: InfectionBar not found at /root/Node2D/CanvasLayer/InfectionBar. Please check the node path.")
	else:
		if not infection_bar.is_connected("infection_maxed", Callable(self, "die")):
			infection_bar.connect("infection_maxed", Callable(self, "die"))
			print("Player: Connected to infection_maxed signal")
		infection_bar.reset_infection()
		emit_signal("infection_changed", infection_level)
		print("Player: Called reset_infection and emitted infection_changed")
	print("Player reset: health=%d, infection=%.1f, is_dead=%s" % [health, is_dead])


func _process(delta):
	if hit_effect_strength > 0.0:
		hit_effect_strength = max(hit_effect_strength - delta * hit_effect_decay, 0.0)
		wrist_sprite.material.set_shader_parameter("hit_effect", hit_effect_strength)

func apply_hit_effect():
	hit_effect_strength = 1.0
	wrist_sprite.material.set_shader_parameter("hit_effect", hit_effect_strength)


func apply_hit() -> void:
	if is_dead:
		return
	health -= 1
	apply_hit_effect()
	infection_level = min(infection_level + 20.0, 100.0)  # Increase by 20 per hit
	print("Player: apply_hit called, health=%d, infection=%.1f" % [health, infection_level])
	emit_signal("infection_changed", infection_level)
	if health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	_travel("Dead")
	print("You Died!!")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	emit_signal("player_died")

# --- Movement Settings ---
@export var speed: float = 200
@export var jump_force: float = 350
@export var gravity: float = 1000
@export var dash_speed: float = 500
@export var dash_time: float = 0.6

# --- Drag your Skeleton2D (or visual root) here in the Inspector ---
@export var flip_node: Node2D

# --- Node References (resolved at runtime) ---
@onready var anim_tree: AnimationTree = $AnimationTree
var state_machine: AnimationNodeStateMachinePlayback

# Picked/Throw
var canPick: bool = true

# --- Dash / Facing ---
var is_dashing := false
var dash_timer := 0.0
var facing_dir := 1  # 1 = right, -1 = left

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
		_travel("Jump_D")
	var input_dir := Input.get_axis("ui_left", "ui_right")
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
		velocity.x = dash_speed * facing_dir
		_travel("Dash")
	elif Input.is_action_pressed("ui_down") and is_on_floor():
		velocity.x = 0
		_travel("Duck")
	elif Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"):
		velocity.x = input_dir * speed
		_face_direction(input_dir)
		_travel("Run")
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		if is_on_floor():
			_travel("Idle")
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force
		_travel("Jump")
	elif Input.is_action_just_pressed("ui_AttackM") and is_on_floor() and input_dir == 0 and not is_dashing:
		_travel("AttackM_2")
	elif Input.is_action_just_pressed("ui_AttackM") and is_on_floor() and input_dir != 0 and not is_dashing:
		_travel("Run_Attack")
	elif Input.is_action_pressed("ui_AttackM") and is_dashing:
		_travel("Attack_Air")
	elif Input.is_action_just_pressed("ui_AttackM") and not is_on_floor():
		_travel("Attack_Air")
	elif Input.is_action_pressed("ui_AttackR") and is_on_floor():
		velocity.x = 0
		_travel("AttackR")
	if Input.is_action_just_pressed("ui_Dash") and not is_dashing:
		is_dashing = true
		dash_timer = dash_time
		if input_dir != 0.0:
			facing_dir = sign(input_dir)
		velocity.x = dash_speed * facing_dir
		_travel("Dash")
	move_and_slide()
	
	

func _travel(state: String) -> void:
	if state_machine != null:
		state_machine.travel(state)

func _face_direction(dir: float) -> void:
	if dir < 0 and facing_dir != -1:
		facing_dir = -1
		_set_flip_x(-1)
	elif dir > 0 and facing_dir != 1:
		facing_dir = 1
		_set_flip_x(1)

func _set_flip_x(sign_x: int) -> void:
	if flip_node == null:
		return
	var sx := flip_node.scale.x
	var sy := flip_node.scale.y
	flip_node.scale = Vector2(sign_x * abs(sx if sx != 0.0 else 1.0), sy if sy != 0.0 else 1.0)
