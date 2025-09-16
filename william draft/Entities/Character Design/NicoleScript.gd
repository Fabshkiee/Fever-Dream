extends CharacterBody2D

# ==== SIGNALS ====
signal player_died
signal infection_changed(infection_level: float)  # Signal for infection updates

# ==== HEALTH ====
var health: int = 3
var infection_level: float = 0.0  # Tracks infection from 0 to 100
var is_dead: bool = false
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_area: Area2D = $attackArea
@export var attack_area_offset: Vector2 = Vector2(50, 0)
@onready var wrist_sprite: Sprite2D = $Character/Body/Wrist2
var hit_effect_strength: float = 1.0
var hit_effect_decay: float = 1.0 # how fast it fades back to 0

# ==== MOVEMENT ====
@export var speed: float = 175
@export var gravity: float = 1000

# ==== JUMP SETTINGS ====
@export var jump_force: float = -300           # Initial low jump
@export var jump_extra_force: float = -20      # Continuous boost while holding
@export var jump_hold_time: float = 0.2        # Max boost time (seconds)

# ==== COYOTE TIME SETTINGS ====
@export var coyote_time_max: float = 0.15
var coyote_timer: float = 0.0

# ==== JUMP BUFFER SETTINGS ====
@export var jump_buffer_time_max: float = 0.15
var jump_buffer_timer: float = 0.0

var jump_time: float = 0.0
var is_jump_button_held: bool = false
var is_jumping: bool = false

# ==== DASH SETTINGS ====
const dash_speed: float = 500
@export var dash_time: float = 0.5

# ==== FLIP NODE ====
@export var flip_node: Node2D

# ==== ANIMATIONS ====
@onready var anim_tree: AnimationTree = $AnimationTree
var state_machine: AnimationNodeStateMachinePlayback

# ==== BODY PARTS ==== - for flash
@onready var body_parts = [ $Character/Body/Wrist2, $Character/Body/Elbow2, $Character/Body/Shoulder2, $Character/Body/Shoe2, $Character/Body/Knee2, $Character/Body/Hip2, $Character/Body/Shoe1, $Character/Body/Knee1, $Character/Body/Hip1, $Character/Body/Body2, $Character/Body/Head, $Character/Body/Melee, $Character/Body/Wrist1, $Character/Body/Elbow1, $Character/Body/Shoulder1 ]

# ==== CONTROL VARIABLES ====
var _is_flashing: bool = false       # Tracks if flash is running
var _stop_flash: bool = false        # Allows interrupting the flash

# ==== STATES ====
var is_dashing: bool = false
var dash_timer: float = 0.0
var facing_dir: int = 1
var can_dash: bool = true

# ==== SFX ====
@onready var jump_sfx: AudioStreamPlayer2D = $jump_sfx
@onready var run_sfx_1: AudioStreamPlayer2D = $run_sfx_1
@onready var spray_sfx: AudioStreamPlayer2D = $spray_sfx
@onready var _80_infection_sfx: AudioStreamPlayer2D = $"80_infection_sfx"
@onready var dash_sfx: AudioStreamPlayer2D = $dash_sfx
@onready var run_sfx_3: AudioStreamPlayer2D = $run_sfx_3

# ==== ATTACK ====
var attack_timer: float = 0.0
var is_attacking: bool = false
var damage = Global.playerDamageAmount

# ==== RUNNING SOUNDS ====
var is_running: bool = false
var step_timer: float = 0.0
var step_interval: float = 0.3  # Time between footstep sounds
var run_sounds: Array = []  # Will store multiple footstep variations

# ==== INFECTION TIMER ====
@onready var infection_reduction_timer: Timer

# ==== OTHER ====
var canPick: bool = true

func _ready() -> void:
	Global.playerBody = self
	add_to_group("player")
	
	# Load multiple footstep sounds for variation
	run_sounds = [
		preload("res://SFX/Run 1.mp3"),
		preload("res://SFX/Run 2.mp3"),
		preload("res://SFX/run 3.mp3str")
	]
	
	# If you don't have multiple sounds, just use one
	if run_sounds.is_empty():
		var default_sound = preload("res://SFX/Run 2.mp3") # Fallback if you only have one sound
		if default_sound:
			run_sounds = [default_sound]
	
	# Create and setup the infection reduction timer
	infection_reduction_timer = Timer.new()
	add_child(infection_reduction_timer)
	infection_reduction_timer.wait_time = 10.0  # 10 seconds
	infection_reduction_timer.one_shot = false  # Repeat every 10 seconds
	infection_reduction_timer.timeout.connect(_on_infection_reduction_timeout)
	infection_reduction_timer.start()
	
	# Setup AnimationTree
	if anim_tree == null:
		push_error("AnimationTree not found at $AnimationTree. Update the path or add one.")
	else:
		anim_tree.active = true
		state_machine = anim_tree["parameters/playback"]

	# Auto-detect Flip Node
	if flip_node == null:
		flip_node = get_node_or_null("Skeleton2D")
		if flip_node == null:
			flip_node = get_node_or_null("Sprite2D")
		if flip_node == null:
			flip_node = get_node_or_null("AnimatedSprite2D")

	if flip_node == null:
		push_error("Flip node not set/found. Assign 'Flip Node' to your Skeleton2D in the Inspector.")
	
	# Setup damage area
	if damage_area:
		damage_area.position = Vector2(100, 0)
		Global.playerDamageZone = damage_area
		if not damage_area.area_entered.is_connected(_on_damage_area_entered):
			damage_area.area_entered.connect(_on_damage_area_entered)
		if not damage_area.body_entered.is_connected(_on_damage_area_body_entered):
			damage_area.body_entered.connect(_on_damage_area_body_entered)
		damage_area.monitoring = false
	else:
		push_error("DamageArea not found as child of player")
	
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
	
	print("Player reset: health=%d, infection=%.1f, is_dead=%s" % [health, infection_level, is_dead])

func _on_infection_reduction_timeout():
	if not is_dead and infection_level > 0:
		# Reduce infection by 10% (but not below 0)
		infection_level = max(infection_level - 10.0, 0.0)
		if infection_level <=79:
			_80_infection_sfx.stream.loop = false
			_80_infection_sfx.stop()
			
		if infection_level >= 80:
			damage = 5
		elif infection_level >=50:
			damage = 10
		elif infection_level >= 30:
			damage = 15
		elif infection_level <= 20:
			damage = 20
			
		print("Infection reduced by 10%: ", infection_level)
		emit_signal("infection_changed", infection_level)

func _process(delta):
	if hit_effect_strength > 0.0:
		hit_effect_strength = max(hit_effect_strength - delta * hit_effect_decay, 0.0)
		wrist_sprite.material.set_shader_parameter("hit_effect", hit_effect_strength)
		
	# Handle running sound effects
	if is_running and is_on_floor():
		step_timer += delta
		if step_timer >= step_interval:
			play_footstep_sound()
			step_timer = 0.0
	else:
		# Reset timer when not running
		step_timer = step_interval
		
	# Die immediately if infection reaches 100%
	if not is_dead and infection_level >= 100.0:
		die()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Handle attack timer
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			if damage_area:
				damage_area.monitoring = false
				
	if damage_area:
		if facing_dir == -1:  # Facing left
			damage_area.position.x = -2500
		else:  # Facing right
			damage_area.position.x = 100
	
	# ==== COYOTE TIMER ====
	if is_on_floor():
		coyote_timer = coyote_time_max
		is_jumping = false
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	# ==== JUMP BUFFER TIMER ====
	if Input.is_action_just_pressed("ui_jump") or Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time_max
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		_travel("Jump_D")

	var input_dir := Input.get_axis("ui_left", "ui_right")
	
	# Update running state for sound effects
	is_running = is_on_floor() and abs(velocity.x) > 10 and input_dir != 0

	# ==== VARIABLE JUMP ====
	if (jump_buffer_timer > 0.0) and (is_on_floor() or coyote_timer > 0.0):
		velocity.y = jump_force
		is_jumping = true
		is_jump_button_held = true
		jump_time = 0.0
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		_travel("Jump")
		jump_sfx.play()

	# Holding jump to boost height
	if (Input.is_action_pressed("ui_jump") or Input.is_action_pressed("ui_accept")) and is_jump_button_held:
		if jump_time < jump_hold_time:
			velocity.y += jump_extra_force
			jump_time += delta

	# Stop boost when released
	if Input.is_action_just_released("ui_jump") or Input.is_action_just_released("ui_accept"):
		is_jump_button_held = false

	# ==== DASH ====
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
		velocity.x = dash_speed * facing_dir
		_travel("Dash")

	# ==== DUCK ====
	elif Input.is_action_pressed("ui_down") and is_on_floor():
		velocity.x = 0
		_travel("Duck")

	# ==== RUN ====
	elif Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"):
		velocity.x = input_dir * speed
		_face_direction(input_dir)
		_travel("Run")

	# ==== IDLE ====
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		if is_on_floor():
			_travel("Idle")

	# ==== MELEE ATTACKS ====
	if Input.is_action_pressed("ui_AttackM") and is_on_floor() and input_dir == 0 and not is_dashing:
		_travel("AttackM_2")
		spray_sfx.play()
		start_attack()
	elif Input.is_action_pressed("ui_AttackM") and is_on_floor() and input_dir != 0 and not is_dashing:
		_travel("Run_Attack")
		spray_sfx.play()
		start_attack()
	elif Input.is_action_pressed("ui_AttackM") and is_dashing:
		_travel("Attack_Air")
		start_attack()
	elif Input.is_action_pressed("ui_AttackM") and not is_on_floor():
		_travel("Attack_Air")
		spray_sfx.play()
		start_attack()

	# ==== RANGE ATTACK ====
	elif Input.is_action_pressed("ui_AttackR") and is_on_floor():
		velocity.x = 0
		spray_sfx.play()
		_travel("AttackR")
		start_attack()

	# ==== DASH RESET ====
	if is_on_floor():
		can_dash = true

	# ==== DASH START ====
	if Input.is_action_just_pressed("ui_Dash") and not is_dashing:
		if is_on_floor() and can_dash:
			flash()
			is_dashing = true
			dash_timer = dash_time
			if input_dir != 0.0:
				facing_dir = sign(input_dir)
			velocity.x = dash_speed * facing_dir * 3.0
			velocity.y = 0
			_travel("Dash")
			can_dash = false
			dash_sfx.play()
		elif not is_on_floor() and can_dash:
			flash()
			is_dashing = true
			dash_timer = dash_time
			if input_dir != 0.0:
				facing_dir = sign(input_dir)
			velocity.x = dash_speed * facing_dir * 3.0
			velocity.y = jump_force / 2.5
			_travel("Dash")
			can_dash = false
			dash_sfx.play()
			
	move_and_slide()

func play_footstep_sound():
	if run_sounds.is_empty() or not run_sfx_1:
		return
	
	var random_sound = run_sounds[randi() % run_sounds.size()]
	run_sfx_1.stream = random_sound
	run_sfx_1.pitch_scale = randf_range(1, 1.5)
	run_sfx_1.play()

func apply_hit_effect():
	hit_effect_strength = 1.0
	wrist_sprite.material.set_shader_parameter("hit_effect", hit_effect_strength)

func apply_hit() -> void:
	if is_dead:
		return
	
	apply_hit_effect()
	infection_level = min(infection_level + 20.0, 100.0)
	if infection_level >=80:
		_80_infection_sfx.stream.loop = true
		_80_infection_sfx.play()
		
	print("Player: apply_hit called, infection=%.1f/100" % infection_level)
	emit_signal("infection_changed", infection_level)
	
	if infection_level >= 100.0 and not is_dead:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	if run_sfx_1:
		run_sfx_1.stop()
	if infection_reduction_timer:
		infection_reduction_timer.stop()
	_travel("Dead")
	print("You Died from Infection!! Infection level: %.1f/100" % infection_level)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	emit_signal("player_died")

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
	
	if damage_area:
		if sign_x == -1:
			damage_area.position.x = -2500
		else:
			damage_area.position.x = 100

func flash():
	if _is_flashing:
		return
	
	_is_flashing = true
	_stop_flash = false

	for part in body_parts:
		if part.material is ShaderMaterial:
			part.material.set_shader_parameter("hit_effect", 1.0)

	var t = 1.0
	while t > 0.0 and not _stop_flash:
		t -= get_process_delta_time() * 10.0
		for part in body_parts:
			if part.material is ShaderMaterial:
				part.material.set_shader_parameter("hit_effect", max(t, 0.0))
				await get_tree().process_frame

	for part in body_parts:
		if part.material is ShaderMaterial:
			part.material.set_shader_parameter("hit_effect", 0.0)

	_is_flashing = false
	_stop_flash = false

func stop_flash():
	_stop_flash = true

func _on_damage_area_entered(area: Area2D) -> void:
	_handle_damage_target(area)

func _on_damage_area_body_entered(body: Node2D) -> void:
	_handle_damage_target(body)

func _handle_damage_target(target: Node) -> void:
	if not is_attacking:
		return
		
	if target.has_method("take_damage"):
		target.take_damage(damage)
		print("Dealt ", damage, " damage to ", target.name, " while attacking")
	elif target.is_in_group("enemy"):
		print("Enemy detected but no take_damage method: ", target.name)

func start_attack():
	if damage_area:
		is_attacking = true
		attack_timer = 0.3
		damage_area.monitoring = true
		print("Attack started - damage area monitoring: ", damage_area.monitoring)
