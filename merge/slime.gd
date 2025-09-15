extends CharacterBody2D
class_name slimeEnemy

const speed = 50  # Increased from 10 to make movement more noticeable
var is_slime_chase: bool = true

var health = 80
var health_max = 80
var health_min = 0

var dead: bool = false
var taking_damage: bool = false
var damage_to_deal = 20
var is_dealing_damage: bool = false
var dir: Vector2 = Vector2.RIGHT  # Initialize with a default direction
const gravity = 900
var knockback_force = -50
var is_roaming: bool = false

var player: CharacterBody2D
var player_in_area = false
@onready var slime_death_sfx: AudioStreamPlayer2D = $slime_death_sfx
@onready var slime_hurt_sfx: AudioStreamPlayer2D = $slime_hurt_sfx
@onready var slime_jump: AudioStreamPlayer2D = $slime_jump
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	# Start the direction timer when the slime is added to the scene
	$direction.start()
	#$AnimatedSprite2D.frame_changed.connect(_on_animated_sprite_2d_frame_changed)
func _process(delta):
	if !is_on_floor():
		velocity.y += gravity * delta
		velocity.x = 0
	
	player = Global.playerBody
	
	move(delta)
	handle_animation()
	move_and_slide()

func move(delta):
	if !dead:
		if taking_damage:
			var knockback_dir = position.direction_to(player.position) * knockback_force
			velocity.x = knockback_dir.x
			print("Taking damage - knockback")
		elif is_roaming:  # Player is in area - chase!
			var dir_to_player = position.direction_to(player.position) * speed
			velocity.x = dir_to_player.x
			if velocity.x != 0:
				dir.x = sign(velocity.x)
			print("Chasing player! Velocity: ", velocity.x)
		else:  # Player is not in area - use direction timer to roam!
			# This will use the dir set by the direction timer
			velocity.x = dir.x * speed
			print("Roaming! Direction: ", dir.x, " Velocity: ", velocity.x)
	else:
		velocity.x = 0
		print("Dead - not moving")

func handle_animation():
	var anim_sprite = $AnimatedSprite2D
	
	if dead:
		# Play death animation immediately when dead
		if anim_sprite.animation != "death":
			anim_sprite.play("death")
			# Play death sound here instead of in take_damage
			if slime_death_sfx:
				slime_death_sfx.play()
			await get_tree().create_timer(1.0).timeout
			handle_death()
	elif !dead and taking_damage and !is_dealing_damage:
		anim_sprite.play("hurt")
		
		await get_tree().create_timer(1.0).timeout
		taking_damage = false
	elif !dead and !taking_damage and !is_dealing_damage:
		anim_sprite.play("jump startup")
		if dir.x == -1:
			anim_sprite.flip_h = true
		elif dir.x == 1:
			anim_sprite.flip_h = false
	elif dead and is_roaming:
		is_roaming = false
		anim_sprite.play("death")
		# Play death sound here instead of in take_damage
		if slime_death_sfx:
			slime_death_sfx.play()
		await get_tree().create_timer(1.0).timeout
		handle_death()
		
func handle_death():
	self.queue_free()

func _on_direction_timeout() -> void:
	$direction.wait_time = choose([1.5, 2.0, 2.5])
	if !is_roaming:  # Only change direction when not chasing player
		dir = choose([Vector2.RIGHT, Vector2.LEFT])
		velocity.x = 0
		

func choose(array):
	array.shuffle()
	return array.front()


func _on_slime_hitbox_area_entered(area: Area2D) -> void:
	# Check if this is the player's damage zone AND if the player is attacking
	if area == Global.playerDamageZone and Global.playerBody and Global.playerBody.is_attacking:
		var damage = Global.playerDamageAmount
		take_damage(damage)
		
func take_damage(damage):
	health -= damage
	if slime_hurt_sfx:
				slime_hurt_sfx.play()
	taking_damage = true
	if health <= health_min:
		health = health_min
		dead = true
		# REMOVED the slime_death_sfx.play() from here - moved to handle_animation()
	print(str(self, "current health is ", health))



func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == Global.playerBody:  # Check if it's the player
		is_roaming = true
		print("Player entered area - chasing!")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == Global.playerBody:  # Check if it's the player
		is_roaming = false
		print("Player exited area - roaming!")


func _on_animated_sprite_2d_frame_changed() -> void:
	var current_frame = animated_sprite_2d.frame
	var current_animation = animated_sprite_2d.animation
	
	if current_animation == "jump startup":
		match current_frame:
			16:  # Play sound on frames
				slime_jump.play()
				slime_jump.pitch_scale = randf_range(0.9, 1.1)
