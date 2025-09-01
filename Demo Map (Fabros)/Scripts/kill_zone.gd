extends Area2D
@onready var timer: Timer = $Timer

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("apply_hit"):
		body.apply_hit()

	if body.has_signal("player_died"):
		var callable = Callable(self, "_on_player_died").bind(body)
		if not body.is_connected("player_died", callable):
			body.connect("player_died", callable)

func _on_player_died(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()
	Engine.time_scale = 0.5
	timer.start()

func _on_timer_timeout() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func kill():
	queue_free()
