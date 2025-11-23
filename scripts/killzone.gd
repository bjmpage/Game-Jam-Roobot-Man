extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# If the Player touches this zone, respawn them
	if body.has_method("respawn"):
		print("Player fell into void!")
		body.respawn()
