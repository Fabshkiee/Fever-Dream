extends ProgressBar

signal infection_maxed  # Signal to notify player of death due to infection

func _ready() -> void:
	min_value = 0
	max_value = 100
	value = 0
	if not visible:
		push_warning("InfectionBar: ProgressBar is not visible. Check 'Visible' property.")
	if size.x <= 0 or size.y <= 0:
		push_warning("InfectionBar: ProgressBar size is invalid (width=%.1f, height=%.1f). Check 'Size' in inspector." % [size.x, size.y])
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("InfectionBar: No node found in 'player' group.")
	else:
		if player.has_signal("infection_changed"):
			if not player.is_connected("infection_changed", Callable(self, "_on_infection_changed")):
				player.connect("infection_changed", Callable(self, "_on_infection_changed"))
				print("InfectionBar: Connected to player's infection_changed signal")
		else:
			push_error("InfectionBar: Player does not have infection_changed signal")
	print("InfectionBar initialized: min=%d, max=%d, value=%.1f" % [min_value, max_value, value])

func _on_infection_changed(infection_level: float) -> void:
	print("InfectionBar: Received infection_changed with value=%.1f" % infection_level)
	value = infection_level
	print("InfectionBar updated: ProgressBar value=%.1f" % value)
	if infection_level >= 100.0:
		print("InfectionBar: Maxed, emitting infection_maxed signal")
		emit_signal("infection_maxed")

func reset_infection() -> void:
	value = 0
	print("InfectionBar reset: value=%.1f" % value)
