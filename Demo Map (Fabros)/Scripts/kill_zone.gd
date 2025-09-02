extends Area2D
@onready var timer: Timer = $Timer
var is_processing_death: bool = false

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("player_died"):
		if not player.is_connected("player_died", Callable(self, "_on_player_died")):
			player.connect("player_died", Callable(self, "_on_player_died").bind(player))
	# Ensure timer is configured and connected
	if timer == null:
		push_error("Timer node not found at $Timer. Please add a Timer node as a child.")
	else:
		if not timer.is_connected("timeout", Callable(self, "_on_timer_timeout")):
			timer.connect("timeout", Callable(self, "_on_timer_timeout"))
		timer.one_shot = true  # Ensure timer only triggers once
		timer.wait_time = 1.0  # Set a default wait time (adjust as needed)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("apply_hit"):
		body.apply_hit()
		monitoring = false

func _on_player_died(body: Node2D) -> void:
	if is_processing_death:
		return
	is_processing_death = true
	Engine.time_scale = 0.5
	if timer != null:
		timer.start()
	else:
		push_error("Timer node is missing. Scene will not reload.")
		# Fallback: reload immediately if timer is missing
		Engine.time_scale = 1.0
		is_processing_death = false
		get_tree().reload_current_scene()

func _on_timer_timeout() -> void:
	Engine.time_scale = 1.0
	is_processing_death = false
	if get_tree() != null:
		get_tree().reload_current_scene()
	else:
		push_error("SceneTree is unavailable. Cannot reload scene.")

func kill():
	queue_free()
