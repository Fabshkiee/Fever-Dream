extends ProgressBar

@export var smooth_speed: float = 5.0  # Speed of smooth animation
var target_value: float = 0.0

func _ready() -> void:
	value = 0
	target_value = 0

func set_progress(percent: float) -> void:
	# percent should be 0 - 100
	target_value = clamp(percent, 0, max_value)

func reset_bar() -> void:
	value = 0
	target_value = 0

func _process(delta: float) -> void:
	# Smoothly animate to target_value
	value = lerp(value, target_value, delta * smooth_speed)
