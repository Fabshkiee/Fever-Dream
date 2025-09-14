extends Area2D


func _on_body_entered(body: Node2D) -> void:
	for child in body.get_children():
		if child is slimeEnemy:
			Global.playerDamageAmount = 20
