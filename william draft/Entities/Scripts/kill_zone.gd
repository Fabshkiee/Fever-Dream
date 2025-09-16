extends Area2D
@onready var timer: Timer = $Timer
var is_processing_death: bool = false

func _ready():
	var player = get_tree().get_first_node_in_group("Nicole2")
	if player and player.has_signal("player_died"):
		if not player.is_connected("player_died", Callable(self, "_on_player_died")):
			player.connect("player_died", Callable(self, "_on_player_died").bind(player))

	if timer == null:
		push_error("Timer node not found at $Timer.")
	else:
		if not timer.is_connected("timeout", Callable(self, "_on_timer_timeout")):
			timer.connect("timeout", Callable(self, "_on_timer_timeout"))
		timer.one_shot = true
		timer.wait_time = 1.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Nicole2") and body.has_method("apply_hit"):
		body.apply_hit() # No monitoring = false, so multiple hits possible

func _on_player_died(body: Node2D) -> void:
	if is_processing_death:
		return
	is_processing_death = true
	if timer != null:
		timer.start()

func _on_timer_timeout() -> void:
	is_processing_death = false
