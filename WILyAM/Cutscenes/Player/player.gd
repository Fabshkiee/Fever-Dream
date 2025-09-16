extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

const GRAVITY = 1000
@export var speed : int = 200
@export var jump_force : int = 350
@export var dash_speed : int = 500
@export var dash_time : float = 0.2
@export var dash_cooldown : float = 0.5  # half a second cooldown

enum State { Idle, Run, Jump, Dash }
var current_state = State.Idle

var dash_timer : float = 0.0
var dash_cooldown_timer : float = 0.0
var has_air_dashed : bool = false

func _physics_process(delta : float):
	# Handle cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Apply gravity (not during dash)
	if current_state != State.Dash:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			if velocity.y > 0:
				velocity.y = 0
			if current_state == State.Jump:
				current_state = State.Idle
			# reset air dash when grounded
			has_air_dashed = false

	# Handle movement input
	var direction = Input.get_axis("move_left", "move_right")

	# Dash handling
	if current_state == State.Dash:
		dash_timer -= delta
		if dash_timer <= 0:
			current_state = State.Idle if is_on_floor() else State.Jump
	else:
		# Normal movement
		if current_state == State.Jump:
			velocity.x = direction * speed if direction != 0 else move_toward(velocity.x, 0, speed)
		else:
			if direction != 0:
				velocity.x = direction * speed
				current_state = State.Run if is_on_floor() else current_state
				animated_sprite_2d.flip_h = direction < 0
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				if is_on_floor():
					current_state = State.Idle

		# Jump input
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = -jump_force
			current_state = State.Jump

		# Dash input (with cooldown & air dash restriction)
		if Input.is_action_just_pressed("dash") and direction != 0 and dash_cooldown_timer <= 0:
			if is_on_floor() or not has_air_dashed:
				current_state = State.Dash
				velocity.x = direction * dash_speed
				velocity.y = 0
				dash_timer = dash_time
				dash_cooldown_timer = dash_cooldown

				if not is_on_floor():
					has_air_dashed = true

	# Apply movement
	move_and_slide()

	# Play animations
	player_animation()


func player_animation():
	match current_state:
		State.Idle:
			animated_sprite_2d.play("idle")
		State.Run:
			animated_sprite_2d.play("run")
		State.Jump:
			animated_sprite_2d.play("jump")
		State.Dash:
			animated_sprite_2d.play("dash")
